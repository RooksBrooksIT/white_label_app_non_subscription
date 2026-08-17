import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/services/invoice_email_service.dart';

import 'transaction_completed_screen.dart';
import 'payment_failed_screen.dart';
import '../frontend/screens/role_selection_screen.dart';
import '../frontend/screens/admin_dashboard.dart';

class PaymentRecoveryScreen extends StatefulWidget {
  final Map<String, dynamic> pendingPayment;

  const PaymentRecoveryScreen({super.key, required this.pendingPayment});

  @override
  State<PaymentRecoveryScreen> createState() => _PaymentRecoveryScreenState();
}

class _PaymentRecoveryScreenState extends State<PaymentRecoveryScreen> {
  String _statusMessage = 'Recovering your payment...';
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _recoverPayment();
  }

  Future<void> _recoverPayment() async {
    final txnId = widget.pendingPayment['txnId'];
    final pendingUserData = widget.pendingPayment['pendingUserData'] as Map<String, dynamic>?;

    setState(() {
      _statusMessage = 'Verifying payment status with the bank...';
    });

    bool isSuccess = false;
    bool isPending = false;
    Map<String, dynamic>? finalVerifyResult;
    String errorMessage = 'Payment failed or was cancelled.';

    try {
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        if (!mounted) return;

        final verifyResult = await IciciService.instance.verifyPaymentStatus(
          txnId: txnId,
        );

        if (verifyResult['success'] == true) {
          final status = verifyResult['status'];
          if (status == 'SUCCESS') {
            isSuccess = true;
            isPending = false;
            finalVerifyResult = verifyResult;
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
          final error = verifyResult['error']?.toString() ?? '';
          if (error.contains('P0039') ||
              error.contains('Transaction Not available') ||
              error.toLowerCase().contains('pending')) {
            isPending = true;
          }
        }

        if (isPending && attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('Recovery verification error: $e');
      isSuccess = false;
      errorMessage = 'An error occurred during verification.';
    }

    if (!mounted) return;

    if (isSuccess) {
      setState(() {
        _statusMessage = 'Payment successful. Finalizing registration...';
      });

      String? uid = AuthStateService.instance.currentUser?.uid;

      try {
        if (pendingUserData != null && uid == null) {
          // Re-populate AuthStateService memory
          AuthStateService.instance.restorePendingRegistrationData(pendingUserData);
          final result = await AuthStateService.instance.createAndFinalizeAccount();
          if (result['success']) {
            uid = result['uid'];
          } else {
            if (result['message'].toString().contains('invalid-credential') || 
                result['message'].toString().contains('wrong-password') ||
                result['message'].toString().contains('incorrect, malformed or has expired')) {
                
                final email = pendingUserData['email'] ?? 'unknown';
                
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
                      errorMessage: 'Your payment was successful, but the email provided is already registered with a different password. Please reset your password and contact support with Transaction ID: $txnId to claim your subscription.',
                      paymentMethod: widget.pendingPayment['paymentMethod'] ?? 'Unknown',
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
          final tenantId = pendingUserData?['tenantId'] ?? ThemeService.instance.databaseName;

          await FirestoreService.instance.setUserActiveStatus(
            uid: uid,
            tenantId: tenantId,
            active: true,
          );

          await FirestoreService.instance.upsertSubscription(
            uid: uid,
            tenantId: tenantId,
            appId: 'data',
            planName: widget.pendingPayment['planName'] ?? 'Subscription',
            isYearly: widget.pendingPayment['isYearly'] ?? false,
            isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
            price: widget.pendingPayment['price'] ?? 0,
            originalPrice: widget.pendingPayment['originalPrice'],
            paymentMethod: widget.pendingPayment['paymentMethod'] ?? 'Unknown',
            status: 'active',
            gstNumber: pendingUserData?['gstNumber'],
            limits: widget.pendingPayment['limits'],
            geoLocation: widget.pendingPayment['geoLocation'],
            attendance: widget.pendingPayment['attendance'],
            barcode: widget.pendingPayment['barcode'],
            reportExport: widget.pendingPayment['reportExport'],
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

          final logDocId = await FirestoreService.instance.logPaymentTransaction(
            txnId: txnId,
            uidOrMobile: uid,
            userId: uid,
            planName: widget.pendingPayment['planName'] ?? 'Subscription',
            newPlan: widget.pendingPayment['planName'] ?? 'Subscription',
            amount: widget.pendingPayment['price'] ?? 0,
            status: 'SUCCESS',
            isYearly: widget.pendingPayment['isYearly'] ?? false,
            isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
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
            amountPaid: widget.pendingPayment['price'] ?? 0,
            gstNumber: pendingUserData?['gstNumber'],
          );
        }

        // Only clear pending payment after complete success of Firestore writes
        await PaymentRecoveryService.instance.clearPendingPayment();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => TransactionCompletedScreen(
              transactionId: txnId,
              planName: widget.pendingPayment['planName'] ?? 'Subscription',
              amountPaid: widget.pendingPayment['price'] ?? 0,
              isYearly: widget.pendingPayment['isYearly'] ?? false,
              paymentMethod: widget.pendingPayment['paymentMethod'] ?? 'Unknown',
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
      } catch (e) {
        debugPrint('Critical Error after successful recovery during Firestore sync: $e');
        // Do NOT clear pending payment here!
        setState(() {
          _statusMessage = 'Payment successful, but server sync failed. We will automatically retry this synchronization when you reopen the app.\n\nError: $e';
          _isProcessing = false;
        });
      }
    } else {
      // isPending or FAILED/CANCELLED
      final uid = AuthStateService.instance.currentUser?.uid;
      
      final String displayError = isPending 
          ? 'Your payment is still being processed by the bank. Once confirmed, your subscription will activate automatically. You can check your status in a few minutes.' 
          : errorMessage;

      await FirestoreService.instance.logPaymentTransaction(
        txnId: txnId,
        uidOrMobile: uid ?? pendingUserData?['email'] ?? 'unknown',
        userId: uid,
        planName: widget.pendingPayment['planName'] ?? 'Subscription',
        newPlan: widget.pendingPayment['planName'] ?? 'Subscription',
        amount: widget.pendingPayment['price'] ?? 0,
        status: isPending ? 'PENDING' : 'FAILED',
        isYearly: widget.pendingPayment['isYearly'] ?? false,
        isSixMonths: widget.pendingPayment['isSixMonths'] ?? false,
        failureReason: displayError,
        registrationCompleted: false,
        firestoreSynced: true,
      );

      // Retain pending payment state locally if it is PENDING so it can be recovered later.
      // Clear it ONLY if it explicitly FAILED/CANCELLED.
      if (!isPending) {
        await PaymentRecoveryService.instance.clearPendingPayment();
      }
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailedScreen(
            errorMessage: displayError,
            paymentMethod: widget.pendingPayment['paymentMethod'] ?? 'Unknown',
            amount: widget.pendingPayment['price'] ?? 0,
            transactionId: txnId,
          ),
        ),
      );
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
              if (_isProcessing) const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
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
