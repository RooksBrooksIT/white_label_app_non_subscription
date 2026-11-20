import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/invoice_pdf_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class InvoiceEmailService {
  InvoiceEmailService._();
  static final InvoiceEmailService instance = InvoiceEmailService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> processAndSendInvoice({
    required String txnId,
    required String
    logDocId, // Full Firestore doc ID from logPaymentTransaction
    required String customerName,
    required String customerEmail,
    required String planName,
    required bool isYearly,
    required bool isSixMonths,
    int subscriptionYears = 1,
    required int amountPaid,
    String? gstNumber,
  }) async {
    try {
      final docRef = _db.collection('payment_logs').doc(logDocId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        debugPrint(
          'InvoiceEmailService: payment_logs not found for doc $logDocId (txn $txnId)',
        );
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
        subscriptionYears: subscriptionYears,
        amountPaid: amountPaid,
        paymentDate: paymentDate,
        gstNumber: gstNumber,
      );

      final base64Pdf = base64Encode(pdfBytes);

      final appName = ThemeService.instance.appName.isNotEmpty
          ? ThemeService.instance.appName
          : 'ServNex';
      final logoUrl = ThemeService.instance.logoUrl;
      final primaryColor = ThemeService.instance.primaryColor;
      final primaryHex =
          '#${(primaryColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
      final billingCycle = isYearly
          ? (subscriptionYears > 1 ? '$subscriptionYears Years' : 'Yearly')
          : isSixMonths
          ? '6 Months'
          : 'Monthly';

      String logoHtml = '';
      if (logoUrl != null &&
          logoUrl.isNotEmpty &&
          (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))) {
        logoHtml =
            '<img src="$logoUrl" alt="$appName" height="48" style="max-height:48px; max-width:200px; height:auto; object-fit:contain; display:inline-block; margin-bottom:12px; border:0;" />';
      } else {
        final initial = (appName.isNotEmpty ? appName : 'S')
            .trim()[0]
            .toUpperCase();
        logoHtml =
            '''
          <table cellpadding="0" cellspacing="0" border="0" style="margin:0 auto 12px auto;">
            <tr>
              <td align="center" style="width:48px; height:48px; background-color:$primaryHex; border-radius:10px; color:#ffffff; font-size:24px; font-weight:800; line-height:48px; text-align:center;">
                $initial
              </td>
            </tr>
          </table>
        ''';
      }

      final emailHtml =
          '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Payment Confirmed — $invoiceNumber</title>
</head>
<body style="margin:0; padding:0; background-color:#F4F6F9; font-family:'Segoe UI', Arial, Helvetica, sans-serif; -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale; color:#334155;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F4F6F9; padding:32px 16px;">
    <tr>
      <td align="center">
        <!-- Main Card Container -->
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(0,0,0,0.06); border:1px solid #E2E8F0;">
          
          <!-- Top Accent Bar -->
          <tr>
            <td style="height:4px; background-color:$primaryHex;"></td>
          </tr>

          <!-- Application Branding Header -->
          <tr>
            <td style="padding:32px 36px 24px; text-align:center; background-color:#FAFCFE; border-bottom:1px solid #EEF2F6;">
              $logoHtml
              <div style="font-size:22px; font-weight:800; color:#0F172A; letter-spacing:0.8px; text-transform:uppercase; margin:0; line-height:1.2;">
                $appName
              </div>
              <div style="font-size:11px; font-weight:600; color:#64748B; letter-spacing:1.2px; text-transform:uppercase; margin-top:4px;">
                Service Management Platform
              </div>
              <div style="margin-top:18px; padding-top:14px; border-top:1px dashed #E2E8F0;">
                <h1 style="font-size:20px; font-weight:700; color:$primaryHex; margin:0; line-height:1.3;">
                  Payment Confirmed — Receipt &amp; Invoice
                </h1>
                <p style="font-size:13px; color:#64748B; margin:4px 0 0 0;">Invoice #$invoiceNumber</p>
              </div>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td style="padding:28px 36px;">
              <p style="font-size:15px; color:#1E293B; margin:0 0 16px 0; font-weight:600;">
                Hello, $customerName!
              </p>
              <p style="font-size:14px; color:#475569; margin:0 0 20px 0; line-height:1.6;">
                Thank you for subscribing to the <strong>$planName</strong> plan. Your payment was <strong style="color:#16A34A;">successful</strong>. Please find your official tax invoice attached as a PDF.
              </p>

              <!-- Summary Table -->
              <table width="100%" cellpadding="10" cellspacing="0" border="0" style="background-color:#F8FAFC; border-radius:8px; border:1px solid #E2E8F0; font-size:13px; color:#334155; margin:20px 0;">
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Invoice No</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:700; color:#0F172A;">$invoiceNumber</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Plan</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:600; color:$primaryHex;">$planName ($billingCycle)</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Transaction ID</strong></td>
                  <td align="right" style="padding:10px 14px; font-size:11px; font-family:monospace; color:#64748B;">$txnId</td>
                </tr>
                <tr style="background-color:$primaryHex;">
                  <td style="padding:12px 14px; color:#ffffff; font-size:14px; font-weight:700; border-radius:0 0 0 6px;">Total Paid</td>
                  <td align="right" style="padding:12px 14px; color:#ffffff; font-size:16px; font-weight:800; border-radius:0 0 6px 0;">₹$amountPaid</td>
                </tr>
              </table>

              <div style="background-color:#F8FAFC; border:1px solid #E2E8F0; border-radius:8px; padding:12px 16px; margin:20px 0;">
                <p style="font-size:13px; color:#475569; margin:0; line-height:1.5;">
                  📎 A detailed <strong>PDF invoice</strong> is attached to this email for your financial records.
                </p>
              </div>

              <div style="text-align:center; margin:26px 0 10px 0;">
                <span style="display:inline-block; background-color:$primaryHex; color:#ffffff; font-size:13px; font-weight:700; padding:10px 28px; border-radius:6px;">
                  ✓ &nbsp; Subscription Active
                </span>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:24px 36px; background-color:#F8FAFC; border-top:1px solid #EEF2F6; text-align:center;">
              <p style="font-size:13px; font-weight:700; color:#334155; margin:0 0 6px 0;">
                Powered by $appName
              </p>
              <p style="font-size:12px; color:#64748B; margin:0 0 6px 0;">
                Rooks &amp; Brooks Technologies Pvt. Ltd.
              </p>
              <p style="font-size:11px; color:#94A3B8; margin:0 0 12px 0;">
                Support: <a href="mailto:support@rookstechnologies.com" style="color:$primaryHex; text-decoration:none;">support@rookstechnologies.com</a> &nbsp;|&nbsp; +91 7598707071
              </p>
              <p style="font-size:11px; color:#94A3B8; margin:0; line-height:1.4;">
                This is an automated notification. Please do not reply directly to this email.<br>
                &copy; ${DateTime.now().year} $appName &nbsp;|&nbsp; Rooks &amp; Brooks Technologies Pvt. Ltd. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';

      // Write to 'mail' collection for Firebase Trigger Email Extension
      await _db.collection('mail').add({
        'to': customerEmail,
        'appName': appName,
        'message': {
          'subject': 'Payment Confirmed — $planName | $invoiceNumber',
          'text':
              'Dear $customerName,\n\nThank you for subscribing to $planName on $appName. Your payment of Rs. $amountPaid was successful. Please find your official invoice attached.\n\nPowered by $appName\nRooks & Brooks Technologies Pvt. Ltd.',
          'html': emailHtml,
          'attachments': [
            {
              'filename': 'Invoice_$invoiceNumber.pdf',
              'content': base64Pdf,
              'encoding': 'base64',
            },
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

        if (data['status'] == 'SUCCESS' &&
            data['registrationCompleted'] == true) {
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
            subscriptionYears: data['subscriptionYears'] ?? data['billingYears'] ?? 1,
            amountPaid: data['amount'] ?? 0,
          );
        }
      }
    } catch (e) {
      debugPrint('InvoiceEmailService: Error during retry: \$e');
    }
  }
}
