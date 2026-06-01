import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class InvoicePdfService {
  InvoicePdfService._();
  static final InvoicePdfService instance = InvoicePdfService._();

  Future<Uint8List> generateInvoicePdf({
    required String invoiceNumber,
    required String transactionId,
    required String customerName,
    required String customerEmail,
    required String planName,
    required bool isYearly,
    required bool isSixMonths,
    required int amountPaid,
    required DateTime paymentDate,
    String? gstNumber,
  }) async {
    final pdf = pw.Document();

    final duration = isYearly ? '1 Year' : isSixMonths ? '6 Months' : '1 Month';
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate);

    // Use a primary color theme for the invoice
    final primaryColor = PdfColor.fromInt(0xFF1A237E);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Invoice Number: $invoiceNumber',
                        style: pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Date: $formattedDate',
                        style: pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Logo can go here if we fetch it, for now company name
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Rooks Brooks IT Solutions',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('support@servnex.com', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('www.servnex.com', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 32),
              
              // Bill To Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text(customerEmail),
                        if (gstNumber != null && gstNumber.isNotEmpty)
                          pw.Text('GSTIN: $gstNumber'),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Payment Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Transaction ID: $transactionId'),
                        pw.Text('Status: SUCCESS', style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 32),
              
              // Items Table Header
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 1, child: pw.Text('Duration', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ),
              
              // Items Table Row
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Subscription - $planName')),
                    pw.Expanded(flex: 1, child: pw.Text(duration)),
                    pw.Expanded(flex: 1, child: pw.Text('Rs. $amountPaid', textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 32),
              
              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Amount Paid:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Rs. $amountPaid', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
