import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/services/subscription_queue_service.dart';
import 'package:subscription_rooks_app/services/invoice_email_service.dart';

import 'transaction_completed_screen.dart';
import 'queued_upgrade_confirmation_screen.dart';
import 'payment_failed_screen.dart';
import 'subscription_plans_screen.dart';
import '../frontend/screens/admin_dashboard.dart';
import '../frontend/screens/role_selection_screen.dart';

class PaymentRecoveryScreen extends StatefulWidget {
  final Map<String, dynamic> pendingPayment;

  const PaymentRecoveryScreen({super.key, required this.pendingPayment});

  @override
  State<PaymentRecoveryScreen> createState() => _PaymentRecoveryScreenState();
}

class _PaymentRecoveryScreenState extends State<PaymentRecoveryScreen> {
  String _statusMessage = 'Recovering your payment...';
  bool _isProcessing = true;

  String _formatPaymentMethod(dynamic method) {
    if (method == null) return 'Card';
    final str = method.toString().trim();
    if (str.isEmpty || str == 'Unknown') return 'Card';
    final upper = str.toUpperCase();
    if (upper.contains('UPI')) return 'UPI';
    if (upper.contains('CARD')) return 'Card';
    if (upper.contains('NETBANKING') ||
        upper.contains('NET_BANKING') ||
        upper.contains('NET BANKING')) {
      return 'Net Banking';
    }
    return str;
  }

  DateTime? _getExpiryDate(Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'];
    if (expiresAt != null) {
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().toUtc();
      } else if (expiresAt is String) {
        return DateTime.tryParse(expiresAt)?.toUtc();
      }
    }
    final nextBillingStr = data['nextBillingAt'] as String?;
    if (nextBillingStr != null) {
      return DateTime.tryParse(nextBillingStr)?.toUtc();
    }
    return null;
  }

  bool _isPaymentSuccess(Map<String, dynamic> raw) {
    final data = (raw['data'] is Map<String, dynamic>)
        ? raw['data'] as Map<String, dynamic>
        : raw;
    final status = (data['status'] as String? ?? raw['status'] as String? ?? '').toUpperCase();
    final txnStatus = (data['txnStatus'] as String? ?? raw['txnStatus'] as String? ?? '').toUpperCase();
    final responseCode = (data['responseCode'] as String? ?? raw['responseCode'] as String? ?? '');
    final txnResponseCode = (data['txnResponseCode'] as String? ?? raw['txnResponseCode'] as String? ?? '');

    if (status == 'SUCCESS') return true;
    if (txnStatus == 'SUC') return true;
    if (responseCode == '000' && (txnResponseCode == '0000' || txnResponseCode.isEmpty)) return true;
    return false;
  }

  bool _isPaymentFailed(Map<String, dynamic> raw) {
    final data = (raw['data'] is Map<String, dynamic>)
        ? raw['data'] as Map<String, dynamic>
        : raw;
    final status = (data['status'] as String? ?? raw['status'] as String? ?? '').toUpperCase();
    final txnStatus = (data['txnStatus'] as String? ?? raw['txnStatus'] as String? ?? '').toUpperCase();
    return status == 'FAILED' ||
        status == 'CANCELLED' ||
        txnStatus == 'F' ||
        txnStatus == 'FAIL' ||
        txnStatus == 'CANCELLED';
  }

  Timer? _safetyWatchdog;

  @override
  void initState() {
    super.initState();
    // Safety watchdog: ensure verification UI never hangs indefinitely (Requirement 6)
    _safetyWatchdog = Timer(const Duration(seconds: 10), () async {
      if (mounted && _isProcessing) {
        debugPrint('PaymentRecovery: Safety watchdog triggered after 10s.');
        final prefs = await SharedPreferences.getInstance();
        final tenantId = widget.pendingPayment['tenantId'] as String? ??
            prefs.getString(AuthStateService.kTenantId) ??
            prefs.getString(AuthStateService.kDatabaseName) ??
            ThemeService.instance.databaseName;
        bool active = false;
        if (tenantId.isNotEmpty) {
          active = await FirestoreService.instance
              .isTenantActive(tenantId: tenantId)
              .catchError((_) => false);
        }
        if (active && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const admindashboard()),
            (route) => false,
          );
          return;
        }
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage =
                'Payment verification timed out. If your payment was completed, your subscription will update once confirmed.';
          });
        }
      }
    });
    _recoverPayment();
  }

  @override
  void dispose() {
    _safetyWatchdog?.cancel();
    super.dispose();
  }

  Future<void> _recoverPayment() async {
    final txnId = widget.pendingPayment['txnId']?.toString() ?? '';
    final pendingUserData =
        widget.pendingPayment['pendingUserData'] as Map<String, dynamic>?;

    setState(() {
      _statusMessage = 'Verifying payment status with the bank...';
      _isProcessing = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final tenantId = widget.pendingPayment['tenantId'] as String? ??
        pendingUserData?['tenantId'] as String? ??
        prefs.getString(AuthStateService.kTenantId) ??
        prefs.getString(AuthStateService.kDatabaseName) ??
        ThemeService.instance.databaseName;

    // 0. Quick pre-check: If already subscribed in backend, do not verify again! (Requirement 3)
    if (tenantId.isNotEmpty) {
      try {
        final isSubscribed = await FirestoreService.instance.isTenantActive(
          tenantId: tenantId,
        );
        if (isSubscribed) {
          debugPrint(
            'PaymentRecovery: Tenant already has an active subscription. Skipping verification and routing to dashboard.',
          );
          await PaymentRecoveryService.instance.clearPendingPayment();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const admindashboard()),
            (route) => false,
          );
          return;
        }
      } catch (e) {
        debugPrint('Pre-check subscription error: $e');
      }
    }

    bool isSuccess = false;
    bool isPending = false;
    Map<String, dynamic>? finalVerifyResult;
    String errorMessage = 'Payment failed or was cancelled.';

    try {
      int attempts = 0;
      const maxAttempts = 2;

      while (attempts < maxAttempts) {
        attempts++;
        if (!mounted) return;

        // 1. Check Firestore first (server read)
        try {
          final doc = await FirebaseFirestore.instance
              .collection('payments')
              .doc(txnId)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 5));
          if (doc.exists) {
            final data = doc.data()!;
            if (_isPaymentSuccess(data)) {
              isSuccess = true;
              isPending = false;
              finalVerifyResult = data;
              break;
            } else if (_isPaymentFailed(data)) {
              isSuccess = false;
              isPending = false;
              finalVerifyResult = data;
              errorMessage = data['error'] ?? 'Payment failed or was cancelled.';
              break;
            }
          }
        } catch (e) {
          debugPrint('Recovery Firestore check error: $e');
        }

        // 2. Check ICICI status API
        try {
          final verifyResult = await IciciService.instance
              .verifyPaymentStatus(txnId: txnId)
              .timeout(
                const Duration(seconds: 6),
                onTimeout: () => {'success': false, 'error': 'Gateway timeout'},
              );
          if (verifyResult['success'] == true) {
            if (_isPaymentSuccess(verifyResult)) {
              isSuccess = true;
              isPending = false;
              finalVerifyResult = verifyResult;
              break;
            } else if (_isPaymentFailed(verifyResult)) {
              isSuccess = false;
              isPending = false;
              finalVerifyResult = verifyResult;
              errorMessage =
                  verifyResult['error'] ?? 'Payment failed or was cancelled.';
              break;
            } else {
              isPending = true;
            }
          } else {
            final error = verifyResult['error']?.toString() ?? '';
            if (error.contains('P0039') ||
                error.contains('Transaction Not available') ||
                error.toLowerCase().contains('pending')) {
              isPending = true;
            }
          }
        } catch (e) {
          debugPrint('Recovery API check error: $e');
        }

        if (isPending && attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      debugPrint('Recovery verification error: $e');
      isSuccess = false;
      errorMessage = 'An error occurred during verification.';
    }

    if (!mounted) return;

    try {
      if (isSuccess) {
        setState(() {
          _statusMessage = 'Payment successful. Updating subscription...';
        });

        String? uid = widget.pendingPayment['userId'] as String? ??
            AuthStateService.instance.currentUser?.uid;
        final prefs = await SharedPreferences.getInstance();
        final tenantId = widget.pendingPayment['tenantId'] as String? ??
            pendingUserData?['tenantId'] as String? ??
            prefs.getString(AuthStateService.kTenantId) ??
            prefs.getString(AuthStateService.kDatabaseName) ??
            ThemeService.instance.databaseName;

        try {
          if (pendingUserData != null && uid == null) {
            // Re-populate AuthStateService memory for new account
            AuthStateService.instance.restorePendingRegistrationData(
              pendingUserData,
            );
            final result =
                await AuthStateService.instance.createAndFinalizeAccount();
            if (result['success']) {
              uid = result['uid'];
            } else {
              if (result['message'].toString().contains('invalid-credential') ||
                  result['message'].toString().contains('wrong-password') ||
                  result['message'].toString().contains(
                    'incorrect, malformed or has expired',
                  )) {
                final email = pendingUserData['email'] ?? 'unknown';

                try {
                  await FirebaseFirestore.instance
                      .collection('payments')
                      .doc(txnId)
                      .update({
                        'status': 'SUCCESS_ORPHANED',
                        'email': email,
                        'error':
                            'User provided wrong password for existing account',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  await FirestoreService.instance.logPaymentTransaction(
                    txnId: txnId,
                    uidOrMobile: email,
                    userId: 'ORPHANED',
                    tenantId: tenantId,
                    planName: widget.pendingPayment['planName'] ?? 'Subscription',
                    amount: widget.pendingPayment['price'] ?? 0,
                    status: 'SUCCESS_ORPHANED',
                    isYearly: widget.pendingPayment['isYearly'] ?? false,
                    isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                    registrationCompleted: false,
                    firestoreSynced: false,
                    failureReason: 'Wrong password for existing account',
                  );
                } catch (e) {
                  debugPrint('Failed to log orphaned payment: $e');
                }

                await PaymentRecoveryService.instance.clearPendingPayment();

                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => PaymentFailedScreen(
                      errorMessage:
                          'Your payment was successful, but the email provided is already registered with a different password. Please reset your password and contact support with Transaction ID: $txnId to claim your subscription.',
                      paymentMethod: _formatPaymentMethod(
                        widget.pendingPayment['paymentMethod'],
                      ),
                      amount: widget.pendingPayment['price'] ?? 0,
                      transactionId: txnId,
                    ),
                  ),
                  (route) => false,
                );
                return;
              }
              throw Exception(result['message'] ?? 'Failed to finalize account.');
            }
          } else if (uid != null) {
            await AuthStateService.instance.finalizeRegistration();
          }

          if (uid != null) {
            final isQueue = widget.pendingPayment['queueUpgrade'] == true;
            final resolvedPaymentMethod = _formatPaymentMethod(
              finalVerifyResult?['paymentMethod'] ??
                  finalVerifyResult?['paymentMode'] ??
                  widget.pendingPayment['paymentMethod'],
            );
            final actualAmount =
                (finalVerifyResult?['amount'] as num?)?.toInt() ??
                widget.pendingPayment['price'] as int? ??
                0;

            if (!isQueue) {
              await FirestoreService.instance.setUserActiveStatus(
                uid: uid,
                tenantId: tenantId,
                active: true,
              );

              await FirestoreService.instance.upsertSubscription(
                uid: uid,
                tenantId: tenantId,
                appId: tenantId,
                planName: widget.pendingPayment['planName'] ?? 'Subscription',
                isYearly: widget.pendingPayment['isYearly'] ?? false,
                isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                price: actualAmount,
                originalPrice: widget.pendingPayment['originalPrice'],
                paymentMethod: resolvedPaymentMethod,
                status: 'active',
                gstNumber: pendingUserData?['gstNumber'],
                limits: widget.pendingPayment['limits'],
                geoLocation: widget.pendingPayment['geoLocation'],
                attendance: widget.pendingPayment['attendance'],
                barcode: widget.pendingPayment['barcode'],
                reportExport: widget.pendingPayment['reportExport'],
              );
            } else {
              DateTime? scheduledActivation;
              final expStr =
                  widget.pendingPayment['activePlanExpiryDate'] as String?;
              if (expStr != null) {
                scheduledActivation = DateTime.tryParse(expStr);
              }
              await SubscriptionQueueService.instance.saveQueuedPlan(
                tenantId: tenantId,
                uid: uid,
                planName: widget.pendingPayment['planName'] ?? 'Subscription',
                isYearly: widget.pendingPayment['isYearly'] ?? false,
                isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                price: actualAmount,
                originalPrice: widget.pendingPayment['originalPrice'],
                paymentMethod: resolvedPaymentMethod,
                transactionId: txnId,
                scheduledActivationDate: scheduledActivation,
                limits: widget.pendingPayment['limits'],
                geoLocation: widget.pendingPayment['geoLocation'],
                attendance: widget.pendingPayment['attendance'],
                barcode: widget.pendingPayment['barcode'],
                reportExport: widget.pendingPayment['reportExport'],
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

            final logDocId = await FirestoreService.instance
                .logPaymentTransaction(
                  txnId: txnId,
                  uidOrMobile: uid,
                  userId: uid,
                  tenantId: tenantId,
                  planName: widget.pendingPayment['planName'] ?? 'Subscription',
                  newPlan: widget.pendingPayment['planName'] ?? 'Subscription',
                  previousPlan: widget.pendingPayment['currentActivePlanName'],
                  amount: actualAmount,
                  status: 'SUCCESS',
                  isYearly: widget.pendingPayment['isYearly'] ?? false,
                  isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                  queueStatus: isQueue ? 'Queued' : 'Immediate',
                  registrationCompleted: true,
                  firestoreSynced: true,
                );

            // Automatically send the invoice in the background
            InvoiceEmailService.instance.processAndSendInvoice(
              txnId: txnId,
              logDocId: logDocId,
              customerName: pendingUserData?['name'] ?? 'Customer',
              customerEmail: pendingUserData?['email'] ?? 'support@servnex.com',
              planName: widget.pendingPayment['planName'] ?? 'Subscription',
              isYearly: widget.pendingPayment['isYearly'] ?? false,
              isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
              amountPaid: actualAmount,
              gstNumber: pendingUserData?['gstNumber'],
            );
          }

          // Only clear pending payment after complete success of Firestore writes
          await PaymentRecoveryService.instance.clearPendingPayment();

          if (!mounted) return;
          final isQueue = widget.pendingPayment['queueUpgrade'] == true;
          if (isQueue) {
            DateTime? scheduledActivation;
            final expStr =
                widget.pendingPayment['activePlanExpiryDate'] as String?;
            if (expStr != null) {
              scheduledActivation = DateTime.tryParse(expStr);
            }
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => QueuedUpgradeConfirmationScreen(
                  newPlanName:
                      widget.pendingPayment['planName'] ?? 'Subscription',
                  currentPlanName:
                      widget.pendingPayment['currentActivePlanName'] ??
                      'Current Plan',
                  amountPaid: widget.pendingPayment['price'] ?? 0,
                  transactionId: txnId,
                  scheduledActivationDate: scheduledActivation,
                  isYearly: widget.pendingPayment['isYearly'] ?? false,
                  isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                ),
              ),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => TransactionCompletedScreen(
                  transactionId: txnId,
                  planName: widget.pendingPayment['planName'] ?? 'Subscription',
                  amountPaid: widget.pendingPayment['price'] ?? 0,
                  isYearly: widget.pendingPayment['isYearly'] ?? false,
                  paymentMethod: _formatPaymentMethod(
                    widget.pendingPayment['paymentMethod'],
                  ),
                  timestamp: DateTime.now(),
                  isFirstTimeRegistration: pendingUserData != null,
                  isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
                  originalPrice: widget.pendingPayment['originalPrice'],
                  limits: widget.pendingPayment['limits'],
                  geoLocation: widget.pendingPayment['geoLocation'],
                  attendance: widget.pendingPayment['attendance'],
                  barcode: widget.pendingPayment['barcode'],
                  reportExport: widget.pendingPayment['reportExport'],
                ),
              ),
              (route) => false,
            );
          }
        } catch (e) {
          debugPrint(
            'Critical Error after successful recovery during Firestore sync: $e',
          );
          setState(() {
            _statusMessage =
                'Payment successful, but server sync failed. We will automatically retry this synchronization when you reopen the app.\n\nError: $e';
            _isProcessing = false;
          });
        }
      } else {
        // isPending or FAILED/CANCELLED
        final prefs = await SharedPreferences.getInstance();
        final uid = widget.pendingPayment['userId'] as String? ??
            AuthStateService.instance.currentUser?.uid;
        final tenantId = widget.pendingPayment['tenantId'] as String? ??
            pendingUserData?['tenantId'] as String? ??
            prefs.getString(AuthStateService.kTenantId) ??
            prefs.getString(AuthStateService.kDatabaseName) ??
            ThemeService.instance.databaseName;

        final String displayError = isPending
            ? 'Your payment is still being processed by the bank. Once confirmed, your subscription will activate automatically. You can check your status in a few minutes.'
            : errorMessage;

        try {
          await FirestoreService.instance.logPaymentTransaction(
            txnId: txnId,
            uidOrMobile: uid ?? pendingUserData?['email'] ?? 'unknown',
            userId: uid,
            tenantId: tenantId,
            planName: widget.pendingPayment['planName'] ?? 'Subscription',
            newPlan: widget.pendingPayment['planName'] ?? 'Subscription',
            previousPlan: widget.pendingPayment['currentActivePlanName'],
            amount: widget.pendingPayment['price'] ?? 0,
            status: isPending ? 'PENDING' : 'FAILED',
            isYearly: widget.pendingPayment['isYearly'] ?? false,
            isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
            failureReason: displayError,
            registrationCompleted: false,
            firestoreSynced: true,
          );
        } catch (logErr) {
          debugPrint('Error logging payment transaction during recovery: $logErr');
        }

        // Clear pending payment state locally if failed/cancelled so it doesn't repeatedly prompt
        if (!isPending) {
          await PaymentRecoveryService.instance.clearPendingPayment();
        }

        // Check if user has an active subscription in Firestore
        bool hasActiveSub = false;
        String? activePlanName;
        if (tenantId.isNotEmpty) {
          try {
            if (uid != null && uid.isNotEmpty) {
              final subDoc = await FirestoreService.instance
                  .subscriptionsRef(tenantId: tenantId)
                  .doc(uid)
                  .get();
              if (subDoc.exists && subDoc.data() != null) {
                final subData = subDoc.data()!;
                final expiry = _getExpiryDate(subData);
                if (subData['status'] == 'active' &&
                    (expiry == null || DateTime.now().toUtc().isBefore(expiry))) {
                  hasActiveSub = true;
                  activePlanName = subData['planName'] as String?;
                }
              }
            }
            if (!hasActiveSub) {
              final subSnap = await FirestoreService.instance
                  .subscriptionsRef(tenantId: tenantId)
                  .limit(5)
                  .get();
              for (final doc in subSnap.docs) {
                final subData = doc.data();
                final expiry = _getExpiryDate(subData);
                if (subData['status'] == 'active' &&
                    (expiry == null || DateTime.now().toUtc().isBefore(expiry))) {
                  hasActiveSub = true;
                  activePlanName = subData['planName'] as String?;
                  break;
                }
              }
            }
          } catch (e) {
            debugPrint('PaymentRecovery: Error checking backend subscription: $e');
          }
        }

        if (hasActiveSub) {
          debugPrint(
            'PaymentRecovery: Upgrade payment was ${isPending ? 'PENDING' : 'FAILED'}, '
            'but user has active $activePlanName subscription. Retaining active subscription and launching dashboard.',
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const admindashboard()),
            (route) => false,
          );
          return;
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              errorMessage: displayError,
              paymentMethod: _formatPaymentMethod(
                widget.pendingPayment['paymentMethod'],
              ),
              amount: widget.pendingPayment['price'] ?? 0,
              transactionId: txnId,
            ),
          ),
        );
      }
    } catch (fatalError) {
      debugPrint('Fatal error in PaymentRecovery: $fatalError');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Could not verify payment status with bank.\n\n$errorMessage';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
              ],
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    _safetyWatchdog?.cancel();
                    final nav = Navigator.of(context);
                    final prefs = await SharedPreferences.getInstance();
                    final tenantId = widget.pendingPayment['tenantId'] as String? ??
                        prefs.getString(AuthStateService.kTenantId) ??
                        prefs.getString(AuthStateService.kDatabaseName) ??
                        ThemeService.instance.databaseName;
                    bool active = false;
                    if (tenantId.isNotEmpty) {
                      active = await FirestoreService.instance
                          .isTenantActive(tenantId: tenantId)
                          .catchError((_) => false);
                    }
                    if (!mounted) return;
                    if (active) {
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const admindashboard()),
                        (route) => false,
                      );
                    } else {
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'Cancel & Continue to App',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (!_isProcessing) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isProcessing = true;
                      _statusMessage = 'Retrying registration...';
                    });
                    _recoverPayment();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry Sync Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
