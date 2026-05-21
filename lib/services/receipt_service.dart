import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/pdf_utils.dart';

class ReceiptService {
  static Future<File> generateReceipt({
    required String planName,
    required bool isYearly,
    required bool isSixMonths,
    required int amount,
    required String transactionId,
    required String paymentMethod,
    String? userName,
    String? userEmail,
    String? logoUrl,
    String appName = 'Rooks White Label',
  }) async {
    final pdf = pw.Document();

    // Load logo if available
    pw.MemoryImage? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      logoImage = await PdfUtils.fetchNetworkImage(logoUrl);
    }

    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final duration = isYearly
        ? '12 Months'
        : (isSixMonths ? '6 Months' : '1 Month');

    // Calculate GST (18%)
    final gstRate = 0.18;
    final baseAmount = (amount / (1 + gstRate)).round();
    final gstAmount = (amount - baseAmount).round();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Image(logoImage, width: 80, height: 80)
                        else
                          pw.Text(
                            appName,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Payment Receipt',
                          style: pw.TextStyle(
                            fontSize: 18,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date: $dateStr'),
                        pw.Text('Receipt #: $transactionId'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // User Details
                if (userName != null || userEmail != null) ...[
                  pw.Text(
                    'Customer Details',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  if (userName != null) _buildRow('Name', userName),
                  if (userEmail != null) _buildRow('Email', userEmail),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 20),
                ],

                // Subscription Details
                pw.Text(
                  'Subscription Details',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildRow('Plan Name', planName),
                _buildRow('Billing Cycle', duration),
                _buildRow('Payment Method', paymentMethod),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Amount Breakdown
                pw.Text(
                  'Payment Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildRow('Subtotal (ex-GST)', 'INR $baseAmount.00'),
                _buildRow('GST (18%)', 'INR $gstAmount.00'),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Paid',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'INR $amount.00',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1A237E),
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for choosing $appName!',
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'This is a computer-generated receipt.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt_$transactionId.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
