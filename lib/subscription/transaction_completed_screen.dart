import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:subscription_rooks_app/services/receipt_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';

class TransactionCompletedScreen extends StatelessWidget {
  final String planName;
  final bool isYearly;
  final int amountPaid;
  final String paymentMethod;
  final String transactionId;
  final DateTime timestamp;
  final bool isFirstTimeRegistration;

  // Fields needed for BrandingCustomizationScreen navigation
  final bool isSixMonths;
  final int? originalPrice;
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;

  const TransactionCompletedScreen({
    super.key,
    required this.planName,
    required this.isYearly,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
    required this.timestamp,
    this.isFirstTimeRegistration = false,
    this.isSixMonths = false,
    this.originalPrice,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.blueAccent,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Success Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 70,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                const Text(
                  'PAYMENT SUCCESSFUL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'Thank you for your purchase!\nYour subscription is now active.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Details Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'TRANSACTION DETAILS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black45,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildDetailRow('PLAN', '$planName Plan'),
                      _buildDetailRow(
                        'BILLING CYCLE',
                        isYearly ? 'Yearly' : 'Monthly',
                      ),
                      _buildDetailRow('AMOUNT PAID', '₹ $amountPaid'),
                      _buildDetailRow('PAYMENT METHOD', paymentMethod),
                      _buildDetailRow('TRANSACTION ID', transactionId),
                      _buildDetailRow(
                        'DATE & TIME',
                        _formatDateTime(timestamp),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isFirstTimeRegistration) {
                        // First-time user → go to Branding Customization
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrandingCustomizationScreen(
                              planName: planName,
                              isYearly: isYearly,
                              isSixMonths: isSixMonths,
                              price: amountPaid,
                              originalPrice: originalPrice,
                              paymentMethod: paymentMethod,
                              transactionId: transactionId,
                              limits: limits,
                              geoLocation: geoLocation,
                              attendance: attendance,
                              barcode: barcode,
                              reportExport: reportExport,
                            ),
                          ),
                          (route) => false,
                        );
                      } else {
                        // Existing user → go to Dashboard
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const admindashboard(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isFirstTimeRegistration
                          ? 'CUSTOMIZE YOUR APP'
                          : 'GO BACK TO DASHBOARD',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // View Receipt Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: () => _viewReceipt(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black87, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'VIEW RECEIPT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary Action Button
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // Simple formatter. Use intl package if available, but staying simple.
    final months = [
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
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  Future<void> _viewReceipt(BuildContext context) async {
    try {
      // Get current user info
      final user = AuthStateService.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
        return;
      }

      // Generate PDF receipt
      final pdfFile = await ReceiptService.generateReceipt(
        planName: planName,
        isYearly: isYearly,
        isSixMonths: false, // Assuming not 6 months for now
        amount: amountPaid,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        userName: user.displayName,
        userEmail: user.email,
        appName: 'Rooks White Label',
      );

      // Display PDF using printing package
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final bytes = await pdfFile.readAsBytes();
          return bytes;
        },
        name: 'Receipt_$transactionId.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating receipt: $e')));
    }
  }
}
