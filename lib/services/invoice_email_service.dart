import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/invoice_pdf_service.dart';

class InvoiceEmailService {
  InvoiceEmailService._();
  static final InvoiceEmailService instance = InvoiceEmailService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> processAndSendInvoice({
    required String txnId,
    required String logDocId, // Full Firestore doc ID from logPaymentTransaction
    required String customerName,
    required String customerEmail,
    required String planName,
    required bool isYearly,
    required bool isSixMonths,
    required int amountPaid,
    String? gstNumber,
  }) async {
    try {
      final docRef = _db.collection('payment_logs').doc(logDocId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        debugPrint('InvoiceEmailService: payment_logs not found for doc $logDocId (txn $txnId)');
        return;
      }

      final data = docSnap.data()!;
      if (data['invoiceSent'] == true) {
        debugPrint('InvoiceEmailService: Invoice already sent for $logDocId');
        return;
      }

      // Generate invoice number if not exists
      final invoiceNumber =
          data['invoiceNumber'] ?? 'INV-${txnId.substring(0, 8).toUpperCase()}';

      // Update status to processing
      await FirestoreService.instance.updateInvoiceStatus(
        logDocId,
        invoiceNumber: invoiceNumber,
        status: 'Processing',
      );

      final paymentDate =
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      final pdfBytes = await InvoicePdfService.instance.generateInvoicePdf(
        invoiceNumber: invoiceNumber,
        transactionId: txnId,
        customerName: customerName,
        customerEmail: customerEmail,
        planName: planName,
        isYearly: isYearly,
        isSixMonths: isSixMonths,
        amountPaid: amountPaid,
        paymentDate: paymentDate,
        gstNumber: gstNumber,
      );

      final base64Pdf = base64Encode(pdfBytes);

      // Write to 'mail' collection for Firebase Trigger Email Extension
      await _db.collection('mail').add({
        'to': customerEmail,
        'message': {
          'subject':
              'Your Invoice from Rooks Brooks IT Solutions - $invoiceNumber',
          'text':
              'Dear $customerName,\n\nThank you for your payment of Rs. $amountPaid for the $planName subscription. Please find your invoice attached.\n\nBest Regards,\nRooks Brooks IT Solutions Team',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
              <h2 style="color: #1A237E;">Payment Successful</h2>
              <p>Dear <strong>\$customerName</strong>,</p>
              <p>Thank you for subscribing to the <strong>\$planName</strong> plan. Your payment of <strong>Rs. \$amountPaid</strong> was successful.</p>
              <p>Your invoice is attached to this email as a PDF.</p>
              <p>If you have any questions, feel free to contact us at support@servnex.com.</p>
              <br>
              <p>Best Regards,</p>
              <p><strong>Rooks Brooks IT Solutions Team</strong></p>
            </div>
          ''',
          'attachments': [
            {
              'filename': 'Invoice_\$invoiceNumber.pdf',
              'content': base64Pdf,
              'encoding': 'base64',
            }
          ],
        },
      });

      // Update as sent
      await FirestoreService.instance.updateInvoiceStatus(
        logDocId,
        status: 'Sent',
        invoiceSent: true,
        invoiceSentAt: DateTime.now(),
      );

      debugPrint(
        'InvoiceEmailService: Successfully queued email for doc $logDocId (txn $txnId)',
      );
    } catch (e) {
      debugPrint(
        'InvoiceEmailService: Error sending invoice for doc $logDocId: \$e',
      );
      // Set to Pending for retry later
      await FirestoreService.instance.updateInvoiceStatus(
        logDocId,
        status: 'Pending',
      );
    }
  }

  /// Retries sending any invoices stuck in 'Pending' status.
  Future<void> retryPendingInvoices() async {
    try {
      final snapshot = await _db
          .collection('payment_logs')
          .where('invoiceSent', isEqualTo: false)
          .where('invoiceStatus', isEqualTo: 'Pending')
          .get();

      if (snapshot.docs.isEmpty) return;

      debugPrint(
        'InvoiceEmailService: Found \${snapshot.docs.length} pending invoices to retry',
      );

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Use the stored logDocId; fall back to doc.id for backward compat.
        final logDocId = data['logDocId'] as String? ?? doc.id;
        final txnId = data['transactionId'] as String? ?? doc.id;

        if (data['status'] == 'SUCCESS' && data['registrationCompleted'] == true) {
          final uid = data['userIdOrMobile'];
          String customerName = 'Customer';
          String customerEmail = 'support@servnex.com';

          if (uid != null && uid.toString().isNotEmpty) {
            final userQuery = await _db
                .collectionGroup('users')
                .where(FieldPath.documentId, isEqualTo: uid)
                .limit(1)
                .get();
            if (userQuery.docs.isNotEmpty) {
              final userData = userQuery.docs.first.data();
              customerName = userData['name'] ?? customerName;
              customerEmail = userData['email'] ?? customerEmail;
            }
          }

          await processAndSendInvoice(
            txnId: txnId,
            logDocId: logDocId,
            customerName: customerName,
            customerEmail: customerEmail,
            planName: data['planName'] ?? 'Subscription',
            isYearly: data['isYearly'] ?? false,
            isSixMonths: data['isSixMonths'] ?? false,
            amountPaid: data['amount'] ?? 0,
          );
        }
      }
    } catch (e) {
      debugPrint('InvoiceEmailService: Error during retry: \$e');
    }
  }
}
