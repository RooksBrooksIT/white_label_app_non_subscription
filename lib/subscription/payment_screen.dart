import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/services/invoice_email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'icici_payment_webview_screen.dart';

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
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  static const Color brandBlue = Color(0xFF1A237E);
  final String selectedPaymentMethod = 'Card'; // Hardcoded for hosted flow

  String? _activeTxnId;

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

  Future<void> _verifyPaymentOnReturn(String txnId) async {
    if (!mounted) return;

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
    String errorMessage = 'Payment failed or was cancelled.';

    final bool isHosted = selectedPaymentMethod != 'UPI';

    if (!isHosted) {
      // Wait 2 seconds before the first check to give the webhook a head start
      await Future.delayed(const Duration(seconds: 2));
    }

    try {
      int attempts = 0;
      const maxAttempts = 10; // Increased for ~80s total polling (10 * 8s)

      while (attempts < maxAttempts) {
        attempts++;
        if (!mounted) return;

        if (!isHosted) {
          // 1. Check Firestore first (fastest if webhook arrived)
          final doc = await FirebaseFirestore.instance
              .collection('payments')
              .doc(txnId)
              .get();
          if (doc.exists) {
            final status = doc.data()?['status'];
            debugPrint(
              'Firestore Status for $txnId (Attempt $attempts): $status',
            );

            if (status == 'SUCCESS') {
              isSuccess = true;
              isPending = false;
              break;
            } else if (status == 'FAILED') {
              isSuccess = false;
              isPending = false;
              errorMessage = doc.data()?['error'] ?? 'Payment failed.';
              break;
            } else if (status == 'PENDING') {
              isPending = true;
            }
          }
        }

        // 2. Fallback to API check if Firestore is still PENDING or missing (or if Hosted payment)
        try {
          final verifyResult = await IciciService.instance.verifyPaymentStatus(
            txnId: txnId,
          );
          debugPrint(
            'API Status for $txnId (Attempt $attempts): ${verifyResult['status']} | Error: ${verifyResult['error']}',
          );

          if (verifyResult['success'] == true) {
            final status = verifyResult['status'];
            if (status == 'SUCCESS') {
              isSuccess = true;
              isPending = false;
              break;
            } else if (status == 'FAILED') {
              isSuccess = false;
              isPending = false;
              errorMessage = verifyResult['error'] ?? 'Payment failed.';
              break;
            } else {
              isPending = true;
            }
          } else {
            // If API check itself returns success: false, it might be P0039 if not handled by backend
            final error = verifyResult['error']?.toString() ?? '';
            if (error.contains('P0039') ||
                error.contains('Transaction Not available') ||
                error.toLowerCase().contains('pending')) {
              debugPrint(
                'Transaction sync delay detected (P0039). Continuing to poll...',
              );
              isPending = true;
            }
          }
        } catch (e) {
          debugPrint('API Verification error during polling: $e');
        }

        // If still PENDING, wait and retry
        if (attempts < maxAttempts) {
          await Future.delayed(
            Duration(seconds: isHosted ? 4 : 8),
          ); // Shorter delay for hosted flow
        }
      }
    } catch (e) {
      debugPrint('Verification error: $e');
      isSuccess = false;
      errorMessage = 'An error occurred during verification.';
    }

    if (!mounted) return;
    Navigator.pop(context); // Close verifying dialog

    if (isSuccess) {
      // Payment is genuinely successful
      String? uid = AuthStateService.instance.currentUser?.uid;

      try {
        // If we have pending user data, register/create the user now
        if (widget.pendingUserData != null && uid == null) {
          final result = await AuthStateService.instance
              .createAndFinalizeAccount();
          if (result['success']) {
            uid = result['uid'];
          } else {
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

          // 2. Set user as active
          await FirestoreService.instance.setUserActiveStatus(
            uid: uid,
            tenantId: tenantId,
            active: true,
          );

          // 3. Save subscription details
          await FirestoreService.instance.upsertSubscription(
            uid: uid,
            tenantId: tenantId,
            appId: 'data',
            planName: widget.planName,
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            price: widget.price,
            originalPrice: widget.originalPrice,
            paymentMethod: selectedPaymentMethod,
            status: 'active',
            gstNumber: widget.pendingUserData?['gstNumber'],
            limits: widget.limits,
            geoLocation: widget.geoLocation,
            attendance: widget.attendance,
            barcode: widget.barcode,
            reportExport: widget.reportExport,
          );

          // 4. Update the payment document status in global payments collection
          // only after payment verification and Firestore data synchronization are completed.
          await FirebaseFirestore.instance
              .collection('payments')
              .doc(txnId)
              .update({
                'uid': uid,
                'userId': uid,
                'status': 'SUCCESS',
                'updatedAt': FieldValue.serverTimestamp(),
              });

          // 5. Store the payment transaction details in the payment_logs collection
          await FirestoreService.instance.logPaymentTransaction(
            txnId: txnId,
            uidOrMobile: uid,
            planName: widget.planName,
            amount: widget.price,
            status: 'SUCCESS',
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            registrationCompleted: true,
            firestoreSynced: true,
          );

          // Automatically send the invoice in the background
          InvoiceEmailService.instance.processAndSendInvoice(
            txnId: txnId,
            customerName: widget.pendingUserData?['name'] ?? 'Customer',
            customerEmail: widget.pendingUserData?['email'] ?? 'support@servnex.com',
            planName: widget.planName,
            isYearly: widget.isYearly,
            isSixMonths: widget.isSixMonths,
            amountPaid: widget.price,
            gstNumber: widget.pendingUserData?['gstNumber'],
          );
        }

        // Only clear pending payment after complete success of Firestore writes
        await PaymentRecoveryService.instance.clearPendingPayment();

        // 6. Finally navigate to success screen
        _navigateToSuccess(txnId);
      } catch (e) {
        debugPrint('Critical Error after successful payment during Firestore sync: $e');
        
        if (!mounted) return;
        
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
      final tenantId = ThemeService.instance.databaseName;
      
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
            paymentMethod: selectedPaymentMethod,
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
            paymentMethod: selectedPaymentMethod,
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Section (Moved to top for better flow)
                _buildSubscriptionSummary(formattedDate),

                const SizedBox(height: 100),

                // Responsive Layout for Payment Actions
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        flex: 2,
                        child: SizedBox(),
                      ), // Placeholder for balance
                      const SizedBox(width: 32),
                      Expanded(flex: 1, child: _buildRightSideSidebar()),
                    ],
                  )
                else
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildSecurityBadges(),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildTermsText(),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideSidebar() {
    return Column(
      children: [
        _buildSecurityBadges(),
        const SizedBox(height: 40),
        _buildActionButtons(),
        const SizedBox(height: 24),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildSubscriptionSummary(String formattedDate) {
    return Container(
      width: isDesktop ? 400 : double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius + 4),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
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
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
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
              'Pay Now',
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
      final tenantId = ThemeService.instance.databaseName;
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

      // Fetch customer data for pre-filling
      Map<String, String> customerData = {
        'name': 'Customer',
        'phone': '919999999999',
      };
      if (uid != null) {
        customerData = await IciciService.instance.fetchCustomerData(
          uid,
          tenantId,
        );
      } else if (widget.pendingUserData != null) {
        customerData = {
          'name': widget.pendingUserData!['name'] ?? 'Customer',
          'phone': '919999999999', // Default if not in pending data
        };
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

  void _navigateToSuccess(String txnId) {
    if (!mounted) return;

    // Ensure all dialogs are closed before navigating to the final screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => TransactionCompletedScreen(
          transactionId: txnId,
          planName: widget.planName,
          amountPaid: widget.price,
          isYearly: widget.isYearly,
          paymentMethod: selectedPaymentMethod,
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
      (route) => route.isFirst, // Go back to dashboard/first route
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
