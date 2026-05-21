import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/receipt_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';

class TransactionCompletedScreen extends StatefulWidget {
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
  State<TransactionCompletedScreen> createState() => _TransactionCompletedScreenState();
}

class _TransactionCompletedScreenState extends State<TransactionCompletedScreen> {
  Map<String, dynamic>? _paymentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetails();
  }

  Future<void> _fetchPaymentDetails() async {
    try {
      final docId = widget.transactionId.startsWith('TXN')
          ? widget.transactionId.substring(3)
          : widget.transactionId;
          
      final doc = await FirebaseFirestore.instance.collection('payments').doc(docId).get();
      if (doc.exists && mounted) {
        setState(() {
          _paymentData = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error fetching payment details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = _paymentData?['customerName'] ?? AuthStateService.instance.currentUser?.displayName ?? 'Customer';
    final customerEmail = _paymentData?['customerEmail'] ?? AuthStateService.instance.currentUser?.email ?? '';
    final gatewayMsg = _paymentData?['iciciMessage'] ?? _paymentData?['status'] ?? 'Transaction Authorized Successfully';
    
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
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                const Text(
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
                      _buildDetailRow('STATUS', 'Success', valueColor: Colors.green),
                      _buildDetailRow('TRANSACTION ID', widget.transactionId),
                      _buildDetailRow('REF NO.', _paymentData?['merchantTxnNo'] ?? widget.transactionId.replaceAll('TXN', '')),
                      _buildDetailRow('AMOUNT PAID', '₹ ${widget.amountPaid}'),
                      _buildDetailRow('PAYMENT MODE', widget.paymentMethod),
                      _buildDetailRow(
                        'DATE & TIME',
                        _formatDateTime(widget.timestamp),
                      ),
                      const Divider(height: 32),
                      _buildDetailRow('PLAN', '${widget.planName} Plan'),
                      _buildDetailRow(
                        'BILLING CYCLE',
                        widget.isYearly ? 'Yearly' : (widget.isSixMonths ? '6 Months' : 'Monthly'),
                      ),
                      const Divider(height: 32),
                      _buildDetailRow('CUSTOMER', customerName),
                      if (customerEmail.isNotEmpty)
                        _buildDetailRow('EMAIL', customerEmail),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GATEWAY MESSAGE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gatewayMsg,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
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
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandingCustomizationScreen(
                            planName: widget.planName,
                            isYearly: widget.isYearly,
                            isSixMonths: widget.isSixMonths,
                            price: widget.amountPaid,
                            originalPrice: widget.originalPrice,
                            paymentMethod: widget.paymentMethod,
                            transactionId: widget.transactionId,
                            limits: widget.limits,
                            geoLocation: widget.geoLocation,
                            attendance: widget.attendance,
                            barcode: widget.barcode,
                            reportExport: widget.reportExport,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'GO TO DASHBOARD',
                      style: TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
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
               style: TextStyle(
                 fontSize: 14,
                 color: valueColor ?? Colors.black87,
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
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  Future<void> _viewReceipt(BuildContext context) async {
    try {
      final user = AuthStateService.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        return;
      }

      final pdfFile = await ReceiptService.generateReceipt(
        planName: widget.planName,
        isYearly: widget.isYearly,
        isSixMonths: widget.isSixMonths,
        amount: widget.amountPaid,
        transactionId: widget.transactionId,
        paymentMethod: widget.paymentMethod,
        userName: user.displayName,
        userEmail: user.email,
        appName: 'Rooks White Label',
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final bytes = await pdfFile.readAsBytes();
          return bytes;
        },
        name: 'Receipt_${widget.transactionId}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating receipt: $e')));
    }
  }
}

