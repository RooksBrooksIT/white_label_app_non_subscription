import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/services/invoice_email_service.dart';
import 'package:subscription_rooks_app/services/subscription_queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'icici_payment_webview_screen.dart';
import 'queued_upgrade_confirmation_screen.dart';

import 'dart:async';

import 'transaction_completed_screen.dart';
import 'payment_failed_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final bool isYearly;
  final bool isSixMonths;
  final int price;
  final int? originalPrice;
  final Map<String, dynamic>? brandingData;
  final bool isFirstTimeRegistration;

  // New fields for plan limits and features
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;

  /// User data for a new user who hasn't registered yet.
  final Map<String, dynamic>? pendingUserData;

  // ── Queue upgrade support ──────────────────────────────────────────────────

  /// True when an existing active plan is present (shows queue checkbox).
  final bool hasActiveSubscription;

  /// Name of the currently active plan (used in queue confirmation UI).
  final String? currentActivePlanName;

  /// Expiry date of the active plan — becomes the scheduled activation date
  /// for the queued plan.
  final DateTime? activePlanExpiryDate;

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.isYearly,
    this.isSixMonths = false,
    required this.price,
    this.originalPrice,
    this.brandingData,
    this.isFirstTimeRegistration = true,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
    this.pendingUserData,
    this.hasActiveSubscription = false,
    this.currentActivePlanName,
    this.activePlanExpiryDate,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  bool _isVerifying = false;
  static const Color brandBlue = Color(0xFF1A237E);
  final String selectedPaymentMethod = 'Card'; // Hardcoded for hosted flow

  String? _activeTxnId;

  /// Whether the user wants to queue the upgrade rather than activate immediately.
  /// Only relevant when [widget.hasActiveSubscription] is true.
  bool _queueUpgrade = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activeTxnId != null) {
      final txnId = _activeTxnId!;
      _activeTxnId = null; // Ensure we only verify once
      _verifyPaymentOnReturn(txnId);
    }
  }

  /// Returns true if the given Firestore/API payment data represents a successful payment.
  /// Checks: status=SUCCESS, txnStatus=SUC, responseCode=000, txnResponseCode=0000.
  /// activationStatus=PENDING is NOT treated as a failure.
  bool _isPaymentSuccess(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toUpperCase();
    final txnStatus = (data['txnStatus'] as String? ?? '').toUpperCase();
    final responseCode = (data['responseCode'] as String? ?? '');
    final txnResponseCode = (data['txnResponseCode'] as String? ?? '');

    debugPrint(
      '[PaymentValidation] status=$status | txnStatus=$txnStatus | '
      'responseCode=$responseCode | txnResponseCode=$txnResponseCode'
    );

    // Primary indicator
    if (status == 'SUCCESS') return true;
    // Secondary indicators from ICICI gateway
    if (txnStatus == 'SUC') return true;
    if (responseCode == '000' && txnResponseCode == '0000') return true;
    return false;
  }

  /// Returns true if the payment is definitively failed/cancelled.
  bool _isPaymentFailed(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toUpperCase();
    return status == 'FAILED' || status == 'CANCELLED';
  }

  String _resolvePaymentMethodFromResult(
    Map<String, dynamic>? result, {
    String fallback = 'CARD',
  }) {
    if (result == null) return fallback;
    
    // 1. Check inside iciciResponse object if available
    final iciciResponse = result['iciciResponse'];
    if (iciciResponse is Map<String, dynamic>) {
      final iciciMode = iciciResponse['paymentMode'] ?? iciciResponse['paymentMethod'];
      if (iciciMode != null && iciciMode.toString().trim().isNotEmpty) {
        return iciciMode.toString().trim().toUpperCase();
      }
    }

    // 2. Fallback to root-level fields
    final rawValue =
        result['paymentMethod'] ??
        result['paymentMode'] ??
        result['payMode'] ??
        result['txnPaymentMode'] ??
        result['mode'];
    final method = rawValue?.toString().trim();
    if (method == null || method.isEmpty) return fallback;
    return method.toUpperCase();
  }

  Future<void> _verifyPaymentOnReturn(String txnId) async {
    if (!mounted) return;
    setState(() { _isVerifying = true; });

    // Show a non-dismissible verifying dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying payment... Please wait.'),
          ],
        ),
      ),
    );

    bool isSuccess = false;
    bool isPending = false;
    Map<String, dynamic>? finalVerifyResult;
    String errorMessage = 'Payment failed or was cancelled.';

    const verificationWindow = Duration(seconds: 5);
    const pollInterval = Duration(seconds: 1);
    final deadline = DateTime.now().add(verificationWindow);

    try {
      int attempts = 0;
      while (DateTime.now().isBefore(deadline)) {
        attempts++;
        if (!mounted) return;

        // ── STEP 1: Always check Firestore first (fastest path, works for both UPI & Hosted) ──
        try {
          final doc = await FirebaseFirestore.instance
              .collection('payments')
              .doc(txnId)
              .get(const GetOptions(source: Source.server)); // force fresh read from server

          if (doc.exists) {
            final firestoreData = doc.data()!;
            debugPrint(
              '[PaymentVerify] Firestore doc (Attempt $attempts): $firestoreData',
            );

            if (_isPaymentSuccess(firestoreData)) {
              debugPrint('[PaymentVerify] ✅ Firestore confirms SUCCESS for $txnId');
              isSuccess = true;
              isPending = false;
              finalVerifyResult = firestoreData;
              break;
            } else if (_isPaymentFailed(firestoreData)) {
              debugPrint('[PaymentVerify] ❌ Firestore confirms FAILED/CANCELLED for $txnId');
              isSuccess = false;
              isPending = false;
              finalVerifyResult = firestoreData;
              errorMessage = firestoreData['error'] ??
                  (firestoreData['status'] == 'CANCELLED'
                      ? 'Payment was cancelled by the user.'
                      : 'Payment failed.');
              break;
            } else {
              // PENDING or any other transient status — keep polling
              debugPrint(
                '[PaymentVerify] Firestore status still transient: ${firestoreData['status']} | activationStatus: ${firestoreData['activationStatus']}',
              );
              isPending = true;
            }
          } else {
            debugPrint('[PaymentVerify] Firestore doc not yet created for $txnId (Attempt $attempts)');
          }
        } catch (firestoreError) {
          debugPrint('[PaymentVerify] Firestore read error: $firestoreError');
        }

        // ── STEP 2: Fallback to API check if Firestore has no conclusive result ──
        try {
          final verifyResult = await IciciService.instance.verifyPaymentStatus(
            txnId: txnId,
          );
          debugPrint(
            '[PaymentVerify] API response (Attempt $attempts): $verifyResult',
          );

          if (verifyResult['success'] == true) {
            // Check all gateway success fields in the API response
            if (_isPaymentSuccess(verifyResult)) {
              debugPrint('[PaymentVerify] ✅ API confirms SUCCESS for $txnId');
              isSuccess = true;
              isPending = false;
              finalVerifyResult = verifyResult;
              break;
            } else if (_isPaymentFailed(verifyResult)) {
              debugPrint('[PaymentVerify] ❌ API confirms FAILED/CANCELLED for $txnId');
              isSuccess = false;
              isPending = false;
              finalVerifyResult = verifyResult;
              errorMessage = verifyResult['error'] ??
                  (verifyResult['status'] == 'CANCELLED'
                      ? 'Payment was cancelled by the user.'
                      : 'Payment failed.');
              break;
            } else {
              isPending = true;
            }
          } else {
            final error = verifyResult['error']?.toString() ?? '';
            if (error.contains('P0039') ||
                error.contains('Transaction Not available') ||
                error.toLowerCase().contains('pending')) {
              debugPrint('[PaymentVerify] Transaction sync delay (P0039). Continuing to poll...');
              isPending = true;
            } else {
              debugPrint('[PaymentVerify] API returned success=false: $error');
              // Don't break — webhook may still arrive; keep polling
              isPending = true;
            }
          }
        } catch (apiError) {
          debugPrint('[PaymentVerify] API Verification error: $apiError');
        }

        // If still PENDING, wait and retry
        if (DateTime.now().isBefore(deadline)) {
          await Future.delayed(pollInterval);
        }
      }
    } catch (e) {
      debugPrint('[PaymentVerify] Outer verification error: $e');
      isSuccess = false;
      errorMessage = 'An error occurred during verification.';
    }

    debugPrint(
      '[PaymentVerify] Final result → isSuccess=$isSuccess | isPending=$isPending | error=$errorMessage',
    );

    if (!mounted) return;
    Navigator.pop(context); // Close verifying dialog
    setState(() { _isVerifying = false; });
    final resolvedPaymentMethod = _resolvePaymentMethodFromResult(
      finalVerifyResult,
      fallback: selectedPaymentMethod.toUpperCase(),
    );

    if (isSuccess) {
      // Show Finalizing Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Finalizing transaction... Please wait.'),
              ],
            ),
          ),
        ),
      );

      // Payment is genuinely successful
      String? uid = AuthStateService.instance.currentUser?.uid;
      
      int actualAmount = widget.price;
      if (finalVerifyResult != null && finalVerifyResult['amount'] != null) {
        dynamic amt = finalVerifyResult['amount'];
        if (amt is int) {
          actualAmount = amt;
        } else if (amt is double) {
          actualAmount = amt.toInt();
        } else if (amt is String) {
          actualAmount = double.tryParse(amt)?.toInt() ?? widget.price;
        }
      }

      try {
        // If we have pending user data, register/create the user now
        if (widget.pendingUserData != null && uid == null) {
          final result = await AuthStateService.instance
              .createAndFinalizeAccount();
          if (result['success']) {
            uid = result['uid'];
          } else {
            if (result['message'].toString().contains('invalid-credential') || 
                result['message'].toString().contains('wrong-password') ||
                result['message'].toString().contains('incorrect, malformed or has expired')) {
                
                final email = widget.pendingUserData?['email'] ?? 'unknown';
                
                try {
                  await FirebaseFirestore.instance.collection('payments').doc(txnId).update({
                    'status': 'SUCCESS_ORPHANED',
                    'email': email,
                    'error': 'User provided wrong password for existing account',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  await FirestoreService.instance.logPaymentTransaction(
                    txnId: txnId,
                    uidOrMobile: email,
                    userId: 'ORPHANED',
                    planName: widget.planName,
                    amount: actualAmount,
                    status: 'SUCCESS_ORPHANED',
                    isYearly: widget.isYearly,
                    isSixMonths: widget.isSixMonths,
                    registrationCompleted: false,
                    firestoreSynced: false,
                    failureReason: 'Wrong password for existing account',
                    customerEmail: email,
                  );
                } catch (e) {
                  debugPrint('Failed to log orphaned payment: $e');
                }

                await PaymentRecoveryService.instance.clearPendingPayment();

                if (!mounted) return;
                Navigator.pop(context); // Pop Finalizing dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentFailedScreen(
                      errorMessage: 'Your payment was successful, but the email provided is already registered with a different password. Please reset your password and contact support with Transaction ID: $txnId to claim your subscription.',
                      paymentMethod: resolvedPaymentMethod,
                      amount: widget.price,
                      transactionId: txnId,
                    ),
                  ),
                );
                return;
            }

            throw Exception(
              result['message'] ?? 'Failed to create and finalize account.',
            );
          }
        } else if (uid != null) {
          // Existing user upgrading - just finalize any pending Firestore logic if needed
          await AuthStateService.instance.finalizeRegistration();
        }

        if (uid != null) {
          final tenantId =
              widget.pendingUserData?['tenantId'] ??
              ThemeService.instance.databaseName;

          // 2. Set user as active (only for immediate upgrades)
          if (!_queueUpgrade) {
            await FirestoreService.instance.setUserActiveStatus(
              uid: uid,
              tenantId: tenantId,
              active: true,
            );

            // 3. Save subscription details (immediate activation)
            await FirestoreService.instance.upsertSubscription(
              uid: uid,
              tenantId: tenantId,
              appId: 'data',
              planName: widget.planName,
              isYearly: widget.isYearly,
              isSixMonths: widget.isSixMonths,
              price: actualAmount,
              originalPrice: widget.originalPrice,
              paymentMethod: resolvedPaymentMethod,
              status: 'active',
              gstNumber: widget.pendingUserData?['gstNumber'],
              limits: widget.limits,
              geoLocation: widget.geoLocation,
              attendance: widget.attendance,
              barcode: widget.barcode,
              reportExport: widget.reportExport,
            );
          } else {
            // 3b. Queue the plan — do NOT touch the active subscription.
            await SubscriptionQueueService.instance.saveQueuedPlan(
              tenantId: tenantId,
              uid: uid,
              planName: widget.planName,
              isYearly: widget.isYearly,
              isSixMonths: widget.isSixMonths,
              price: actualAmount,
              originalPrice: widget.originalPrice,
              paymentMethod: resolvedPaymentMethod,
              transactionId: txnId,
              scheduledActivationDate: widget.activePlanExpiryDate,
              limits: widget.limits,
              geoLocation: widget.geoLocation,
              attendance: widget.attendance,
              barcode: widget.barcode,
              reportExport: widget.reportExport,
            );
          }

          // 4. Update the payment document status in global payments collection
          await FirebaseFirestore.instance
              .collection('payments')
              .doc(txnId)
              .update({
                'uid': uid,
                'userId': uid,
                'status': 'SUCCESS',
                'paymentMethod': resolvedPaymentMethod,
                'paymentMode': resolvedPaymentMethod,
                'updatedAt': FieldValue.serverTimestamp(),
              });

          // 5. Log payment transaction (always creates a NEW unique doc)
          final logDocId = await FirestoreService.instance.logPaymentTransaction(
            txnId: txnId,
            uidOrMobile: uid,
            userId: uid,
            planName: widget.planName,
            newPlan: widget.planName,
            previousPlan: widget.currentActivePlanName,
            amount: actualAmount,
            status: 'SUCCESS',
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            queueStatus: _queueUpgrade ? 'Queued' : 'Immediate',
            registrationCompleted: true,
            firestoreSynced: true,
            tenantId: tenantId,
            customerName: widget.pendingUserData?['name'] ?? 'Customer',
            customerEmail:
                widget.pendingUserData?['email'] ?? 'support@servnex.com',
            customerMobile:
                widget.pendingUserData?['customerMobile'] ??
                widget.pendingUserData?['phone'],
            gatewayResponse: finalVerifyResult ?? {
              'paymentMode': resolvedPaymentMethod,
              'paymentMethod': resolvedPaymentMethod,
              'amount': actualAmount,
              'status': 'SUCCESS',
              'transactionId': txnId,
            },
          );

          // Automatically send the invoice in the background
          InvoiceEmailService.instance.processAndSendInvoice(
            txnId: txnId,
            logDocId: logDocId,
            customerName: widget.pendingUserData?['name'] ?? 'Customer',
            customerEmail:
                widget.pendingUserData?['email'] ?? 'support@servnex.com',
            planName: widget.planName,
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            amountPaid: actualAmount,
            gstNumber: widget.pendingUserData?['gstNumber'],
          );
        }

        // Only clear pending payment after complete success of Firestore writes
        await PaymentRecoveryService.instance.clearPendingPayment();

        // 6. Navigate to the appropriate success screen
        if (_queueUpgrade) {
          _navigateToQueuedConfirmation(txnId, actualAmount);
        } else {
          _navigateToSuccess(txnId, resolvedPaymentMethod, actualAmount);
        }
      } catch (e) {
        debugPrint('Critical Error after successful payment during Firestore sync: $e');
        
        if (!mounted) return;
        Navigator.pop(context); // Pop Finalizing dialog
        
        // Show Synchronization Incomplete Alert dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Sync Incomplete'),
              ],
            ),
            content: Text(
              'Your payment of ₹${widget.price} was successful, but we encountered an issue while saving your registration and subscription details to our servers.\n\n'
              'Don\'t worry! Your payment is perfectly secure. We will automatically retry this synchronization the next time you reopen the app.\n\n'
              'Error details: $e'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  _verifyPaymentOnReturn(txnId); // Retry synchronization
                },
                child: const Text(
                  'RETRY NOW',
                  style: TextStyle(fontWeight: FontWeight.bold, color: brandBlue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  // Exit back to the first route to complete onboarding later
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }
    } 
    else {
      // isPending or FAILED/CANCELLED
      final uid = AuthStateService.instance.currentUser?.uid;
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          ThemeService.instance.databaseName;
      
      final String displayError = isPending 
          ? 'Your payment is currently pending or being processed by the bank. Once confirmed, your subscription will activate automatically. You can check your status in a few minutes.' 
          : errorMessage;

      await FirestoreService.instance.logPaymentTransaction(
        txnId: txnId,
        uidOrMobile: uid ?? widget.pendingUserData?['email'] ?? 'unknown',
        planName: widget.planName,
        amount: widget.price,
        status: isPending ? 'PENDING' : 'FAILED',
        isYearly: widget.isYearly,
        isSixMonths: widget.isSixMonths,
        failureReason: displayError,
        registrationCompleted: false,
        firestoreSynced: true,
      );

      // Retain pending payment state locally if it is PENDING so it can be recovered later.
      // Clear it ONLY if it explicitly FAILED/CANCELLED.
      if (!isPending) {
        await PaymentRecoveryService.instance.clearPendingPayment();
      }

      if (uid != null) {
        try {
          // Record failed/pending attempt but do not finalize registration
          await FirestoreService.instance.upsertSubscription(
            uid: uid,
            tenantId: tenantId,
            appId: tenantId, // Standardized to tenantId to avoid duplication
            planName: widget.planName,
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            price: widget.price,
            originalPrice: widget.originalPrice,
            paymentMethod: resolvedPaymentMethod,
            status: isPending ? 'pending' : 'failed',
            gstNumber: widget.pendingUserData?['gstNumber'],
            limits: widget.limits,
            geoLocation: widget.geoLocation,
            attendance: widget.attendance,
            barcode: widget.barcode,
            reportExport: widget.reportExport,
          );
        } catch (e) {
          debugPrint('Error recording failed/pending payment: $e');
        }
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailedScreen(
            errorMessage: displayError,
            paymentMethod: resolvedPaymentMethod,
            amount: widget.price,
            transactionId: txnId,
          ),
        ),
      );
    }
  }

  // Responsive values based on screen width
  double get titleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 32; // Web
    if (width > 768) return 28; // Tablet
    return 22; // Phone
  }

  double get subtitleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 20;
    if (width > 768) return 18;
    return 16;
  }

  double get priceFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 40;
    if (width > 768) return 34;
    return 28;
  }

  double get buttonFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 18;
  }

  double get buttonHeight {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 64;
    return 56;
  }

  EdgeInsets get screenPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return EdgeInsets.symmetric(horizontal: width * 0.1, vertical: 32);
    }
    if (width > 768) {
      return EdgeInsets.symmetric(horizontal: width * 0.08, vertical: 24);
    }
    return const EdgeInsets.all(20);
  }

  double get containerPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 24;
    return 20;
  }

  double get borderRadius {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 16;
  }

  double get iconSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 28;
    return 24;
  }

  bool get isDesktop => MediaQuery.of(context).size.width > 1200;
  bool get isTablet =>
      MediaQuery.of(context).size.width > 768 &&
      MediaQuery.of(context).size.width <= 1200;
  bool get isMobile => MediaQuery.of(context).size.width <= 768;

  // Get next billing date
  DateTime getNextBillingDate() {
    if (widget.isYearly) {
      return DateTime.now().add(const Duration(days: 365));
    } else if (widget.isSixMonths) {
      // Best way to add 6 months:
      final now = DateTime.now();
      return DateTime(now.year, now.month + 6, now.day);
    } else {
      return DateTime.now().add(const Duration(days: 30));
    }
  }

  // Format date as "Mon YYYY"
  String formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nextBillingDate = getNextBillingDate();
    final formattedDate = formatDate(nextBillingDate);

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: brandBlue,
        colorScheme: const ColorScheme.light(
          primary: brandBlue,
          secondary: brandBlue,
          surface: Colors.white,
        ),
      ),
      child: PopScope(
        canPop: !_isVerifying,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isVerifying) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please wait. Payment verification is in progress. You can go back once the verification process is complete.',
                ),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text(
              'Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () {
                if (_isVerifying) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please wait. Payment verification is in progress. You can go back once the verification process is complete.',
                      ),
                    ),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: screenPadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary Section
                      _buildSubscriptionSummary(formattedDate),

                      const SizedBox(height: 40),
                      _buildSecurityBadges(),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildTermsText(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSubscriptionSummary(String formattedDate) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius + 4),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: isDesktop ? 11 : 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.edit_outlined, size: isDesktop ? 16 : 14),
                label: Text(
                  'Change',
                  style: TextStyle(fontSize: isDesktop ? 13 : 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF6366F1),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Plan info
          Text(
            widget.planName,
            style: TextStyle(
              fontSize: isDesktop ? 22 : 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),

          SizedBox(height: 12),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.price == 0 ? 'Free' : '₹${widget.price}',
                style: TextStyle(
                  fontSize: priceFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (widget.price != 0)
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    widget.isYearly
                        ? '/year'
                        : (widget.isSixMonths ? '/6mo' : '/mo'),
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              if (widget.originalPrice != null) ...[
                SizedBox(width: 8),
                Text(
                  '₹${widget.originalPrice}',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 12,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${((1 - widget.price / widget.originalPrice!) * 100).round()}% OFF',
                    style: TextStyle(
                      fontSize: isDesktop ? 10 : 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: 20),

          // Details card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Billing Cycle',
                  value: widget.price == 0
                      ? '7 Days Free Trial'
                      : widget.isYearly
                      ? 'Billed Annually (12 months)'
                      : widget.isSixMonths
                      ? 'Billed Every 6 Months'
                      : 'Billed Monthly',
                  isDesktop: isDesktop,
                ),
                SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Next Billing',
                  value: formattedDate,
                  isDesktop: isDesktop,
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Features preview
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel anytime • No hidden fees • Secure payment',
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDesktop,
  }) {
    return Row(
      children: [
        Icon(icon, size: isDesktop ? 18 : 16, color: Color(0xFF64748B)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 11 : 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBadges() {
    return Row(
      mainAxisAlignment: isMobile
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        _buildSecurityBadge('256-BIT SSL ENCRYPTED', Icons.lock),
        SizedBox(width: isDesktop ? 32 : 20),
        _buildSecurityBadge('100% SAFE PAYMENTS', Icons.verified_user),
      ],
    );
  }

  Widget _buildSecurityBadge(String text, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: brandBlue, size: isDesktop ? 40 : 32),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: brandBlue,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttonWidth = isDesktop ? 400.0 : double.infinity;

    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: [
        // ── Queue Upgrade Checkbox (shown only when user has an active plan) ──
        if (widget.hasActiveSubscription && !widget.isFirstTimeRegistration)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _queueUpgrade
                  ? const Color(0xFFF0F0FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _queueUpgrade
                    ? const Color(0xFF6C5CE7)
                    : Colors.grey.shade300,
                width: _queueUpgrade ? 1.5 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: _queueUpgrade,
              onChanged: (val) => setState(() => _queueUpgrade = val ?? false),
              title: const Text(
                'Queue Upgrade Until Current Plan Expires',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                _queueUpgrade
                    ? 'Your ${widget.currentActivePlanName ?? 'current'} plan stays active. '
                      '${widget.planName} will activate automatically on expiry.'
                    : '${widget.planName} plan will activate immediately after payment.',
                style: TextStyle(
                  fontSize: 12,
                  color: _queueUpgrade
                      ? const Color(0xFF4A3F99)
                      : Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
              activeColor: const Color(0xFF6C5CE7),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              _processPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              _queueUpgrade ? 'Pay & Queue Upgrade' : 'Pay Now',
              style: TextStyle(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: buttonFontSize - 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20),
        child: Text(
          'By Processing this Payment, you agree to our Terms of Services\nand Return Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    final uid = AuthStateService.instance.currentUser?.uid;

    await _processIciciPayment(uid: uid);
  }

  /// Strips HTML and Exception prefix from error messages for user display.
  String _cleanErrorMessage(String raw) {
    String msg = raw.replaceFirst('Exception: ', '');
    if (msg.trim().startsWith('<')) {
      return 'Payment gateway error. Please try again or contact support.';
    }
    return msg;
  }

  /// Process payment via ICICI initiateSale (Standard Web Flow).
  Future<void> _processIciciPayment({String? uid}) async {
    // Show initiating dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initiating secure payment...'),
          ],
        ),
      ),
    );

    try {
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          ThemeService.instance.databaseName;
      final appId = ThemeService.instance.appName;

      // Use pending email if user is not logged in yet
      final email =
          AuthStateService.instance.currentUser?.email ??
          widget.pendingUserData?['email'] ??
          'customer@example.com';

      // If user is not logged in, we use a placeholder ID for payment initiation
      // This ID will be updated to the real UID after successful payment and registration.
      final effectiveUid =
          uid ?? 'PENDING_${DateTime.now().millisecondsSinceEpoch}';

      // Fetch customer data for pre-filling — use the actual entered mobile number.
      Map<String, String> customerData = {
        'name': 'Customer',
        'phone': '',
      };
      if (uid != null) {
        customerData = await IciciService.instance.fetchCustomerData(
          uid,
          tenantId,
        );
      } else if (widget.pendingUserData != null) {
        // Use the exact mobile number entered by the user during registration.
        final rawPhone = widget.pendingUserData!['phone'] as String? ??
            widget.pendingUserData!['mobile'] as String? ??
            widget.pendingUserData!['customerMobile'] as String? ??
            '';
        customerData = {
          'name': widget.pendingUserData!['name'] as String? ?? 'Customer',
          'phone': rawPhone,
        };
        debugPrint('[PaymentScreen] Using pendingUserData phone: $rawPhone');
      }

      // 1. Initiate Sale via backend
      final paymentMode = selectedPaymentMethod == 'Net Banking'
          ? 'NETBANKING'
          : selectedPaymentMethod.toUpperCase();

      debugPrint("Selected Payment Mode: $paymentMode");
      debugPrint(
        "Request Payload: { amount: ${widget.price}, email: $email, tenantId: $tenantId, appId: $appId, paymentMode: $paymentMode }",
      );

      final response = await IciciService.instance.initiatePayment(
        amount: widget.price.toString(),
        email: email,
        tenantId: tenantId,
        appId: appId,
        paymentMode: paymentMode,
        planName: widget.planName,
        customerName: customerData['name'],
        customerMobile: customerData['phone'],
        isYearly: widget.isYearly,
        isSixMonths: widget.isSixMonths,
        limits: widget.limits,
        geoLocation: widget.geoLocation,
        attendance: widget.attendance,
        barcode: widget.barcode,
        reportExport: widget.reportExport,
        userId: effectiveUid,
      );

      debugPrint(
        "Backend Response: { success: ${response.success}, txnId: ${response.txnId}, error: ${response.error} }",
      );

      if (!mounted) return;
      Navigator.pop(context); // Close initiating dialog

      if (!response.success || response.redirectUrl == null) {
        throw Exception(response.error ?? 'Failed to initiate payment');
      }

      // 2. Save pending payment details for recovery before redirecting
      if (response.txnId != null) {
        await PaymentRecoveryService.instance.savePendingPayment({
          'txnId': response.txnId,
          'planName': widget.planName,
          'price': widget.price,
          'isYearly': widget.isYearly,
          'isSixMonths': widget.isSixMonths,
          'originalPrice': widget.originalPrice,
          'paymentMethod': selectedPaymentMethod,
          'pendingUserData': widget.pendingUserData,
          'limits': widget.limits,
          'geoLocation': widget.geoLocation,
          'attendance': widget.attendance,
          'barcode': widget.barcode,
          'reportExport': widget.reportExport,
        });
      }

      // 3. Handle standard web flow
      await _handleWebFlow(response, effectiveUid);
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final errorMessage = _cleanErrorMessage(e.toString());
      debugPrint("Payment Initiation Error: $errorMessage");

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Instead of navigating away immediately on initiation error,
      // show a helpful snackbar so the user can try again or change method.
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => PaymentFailedScreen(
                    errorMessage: errorMessage,
                    paymentMethod: selectedPaymentMethod,
                    amount: widget.price,
                    transactionId: 'INIT_ERROR',
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _navigateToSuccess(String txnId, String resolvedPaymentMethod, int actualAmount) {
    if (!mounted) return;

    // Ensure all dialogs are closed before navigating to the final screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => TransactionCompletedScreen(
          transactionId: txnId,
          planName: widget.planName,
          amountPaid: actualAmount,
          isYearly: widget.isYearly,
          paymentMethod: resolvedPaymentMethod,
          timestamp: DateTime.now(),
          isFirstTimeRegistration: widget.isFirstTimeRegistration,
          isSixMonths: widget.isSixMonths,
          originalPrice: widget.originalPrice,
          limits: widget.limits,
          geoLocation: widget.geoLocation,
          attendance: widget.attendance,
          barcode: widget.barcode,
          reportExport: widget.reportExport,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigate to the queued plan confirmation screen.
  void _navigateToQueuedConfirmation(String txnId, int actualAmount) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => QueuedUpgradeConfirmationScreen(
          newPlanName: widget.planName,
          currentPlanName:
              widget.currentActivePlanName ?? 'Current Plan',
          amountPaid: actualAmount,
          transactionId: txnId,
          scheduledActivationDate: widget.activePlanExpiryDate,
          isYearly: widget.isYearly,
          isSixMonths: widget.isSixMonths,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Handle Standard Web Flow (Custom Tabs / Browser) — used for Card and NetBanking.
  ///
  /// The ICICI hosted payment page is launched in a Chrome Custom Tab or External Browser.
  /// This method MUST NOT affect the UPI flow; it is only called when [selectedPaymentMethod]
  /// is NOT 'UPI' (see [_processIciciPayment]).
  Future<void> _handleWebFlow(IciciPaymentResponse response, String uid) async {
    final txnId = response.txnId ?? '';
    final url = response.redirectUrl!;

    debugPrint("Launching Hosted Payment URL: $url");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IciciPaymentWebViewScreen(
            paymentUrl: url,
            merchantTxnNo: txnId,
            returnUrl: IciciService.returnUrl,
          ),
        ),
      );

      if (!mounted) return;

      if (result != null && result is IciciPaymentResult) {
        if (result.success) {
          _verifyPaymentOnReturn(txnId);
        } else {
          // Verify on return anyway in case it was a delayed success,
          // or just handle failure directly.
          _verifyPaymentOnReturn(txnId);
        }
      } else {
        // User closed the webview without a conclusive result.
        // We should verify just in case.
        _verifyPaymentOnReturn(txnId);
      }
    } catch (e) {
      debugPrint("Hosted Payment Launch Error: $e");
      rethrow;
    }
  }
}
