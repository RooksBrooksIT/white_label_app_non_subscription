import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class RefundPage extends StatefulWidget {
  const RefundPage({super.key});

  @override
  State<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends State<RefundPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showRefundRequestDialog(
    Map<String, dynamic> paymentData,
    String orderId,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final user = FirebaseAuth.instance.currentUser;

    final customerName =
        paymentData['customerName'] ?? paymentData['name'] ?? 'Unknown';
    final customerEmail =
        paymentData['customerEmail'] ??
        paymentData['email'] ??
        user?.email ??
        'N/A';
    final mobileNumber =
        paymentData['customerMobile'] ?? paymentData['mobileNumber'] ?? 'N/A';
    final transactionId =
        paymentData['merchantTxnNo'] ??
        paymentData['transactionId'] ??
        paymentData['paymentId'] ??
        'N/A';
    final amount =
        double.tryParse(paymentData['amount']?.toString() ?? '0') ?? 0;

    bool? submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.undo_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Initiate Refund Request',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Order ID', orderId),
                      _detailRow('Transaction ID', transactionId),
                      _detailRow('Customer Name', customerName),
                      _detailRow('Email', customerEmail),
                      _detailRow('Mobile', mobileNumber),
                      _detailRow(
                        'Amount Paid',
                        '₹${amount.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Reason for Refund *',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Please describe why you are requesting a refund...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  style: GoogleFonts.inter(fontSize: 13.5),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Please enter at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Our support team will review your request and respond within 3–5 business days.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Submit Request',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted == true && mounted) {
      await _submitRefundRequest(
        orderId: orderId,
        transactionId: transactionId,
        customerName: customerName,
        customerEmail: customerEmail,
        mobileNumber: mobileNumber,
        amount: amount,
        reason: reasonController.text.trim(),
        uid: user?.uid ?? '',
      );
    }
  }

  Future<void> _submitRefundRequest({
    required String orderId,
    required String transactionId,
    required String customerName,
    required String customerEmail,
    required String mobileNumber,
    required double amount,
    required String reason,
    required String uid,
  }) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('refund_requests').add({
        'uid': uid,
        'orderId': orderId,
        'transactionId': transactionId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'mobileNumber': mobileNumber,
        'amount': amount,
        'reason': reason,
        'status': 'Pending Review',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      final appName = ThemeService.instance.appName.isNotEmpty
          ? ThemeService.instance.appName
          : 'ServNex';

      await db.collection('mail').add({
        'to': 'support@rookstechnologies.com',
        'appName': appName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': {'state': 'PENDING'},
        'message': {
          'subject': 'New Refund Request - Order ID $orderId | $appName',
          'html': _buildEmailHtml(
            customerName: customerName,
            customerEmail: customerEmail,
            mobileNumber: mobileNumber,
            orderId: orderId,
            transactionId: transactionId,
            amount: amount,
            reason: reason,
          ),
        },
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund request submitted successfully.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit refund request: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _buildEmailHtml({
    required String customerName,
    required String customerEmail,
    required String mobileNumber,
    required String orderId,
    required String transactionId,
    required double amount,
    required String reason,
  }) {
    final appName = ThemeService.instance.appName.isNotEmpty
        ? ThemeService.instance.appName
        : 'ServNex';
    final logoUrl = ThemeService.instance.logoUrl;
    final primaryColor = ThemeService.instance.primaryColor;
    final primaryHex =
        '#${(primaryColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';

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

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Refund Request - $orderId</title>
</head>
<body style="margin:0; padding:0; background-color:#F4F6F9; font-family:'Segoe UI', Arial, Helvetica, sans-serif; color:#334155;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F4F6F9; padding:32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(0,0,0,0.06); border:1px solid #E2E8F0;">
          
          <!-- Top Accent Bar -->
          <tr>
            <td style="height:4px; background-color:$primaryHex;"></td>
          </tr>

          <!-- Header -->
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
                <h1 style="font-size:20px; font-weight:700; color:#DC2626; margin:0; line-height:1.3;">
                  New Refund Request Received
                </h1>
                <p style="font-size:13px; color:#64748B; margin:4px 0 0 0;">Order #$orderId</p>
              </div>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:28px 36px;">
              <p style="font-size:14px; color:#475569; margin:0 0 20px 0; line-height:1.6;">
                A customer has submitted a refund request for their subscription payment on <strong>$appName</strong>. Details are provided below:
              </p>

              <!-- Table -->
              <table width="100%" cellpadding="10" cellspacing="0" border="0" style="background-color:#F8FAFC; border-radius:8px; border:1px solid #E2E8F0; font-size:13px; color:#334155; margin:20px 0;">
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Order ID</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:700; color:#0F172A;">$orderId</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Transaction ID</strong></td>
                  <td align="right" style="padding:10px 14px; font-size:11px; font-family:monospace; color:#64748B;">$transactionId</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Customer Name</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:600;">$customerName</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Customer Email</strong></td>
                  <td align="right" style="padding:10px 14px;">$customerEmail</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Mobile</strong></td>
                  <td align="right" style="padding:10px 14px;">$mobileNumber</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Amount Requested</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:800; color:#DC2626;">₹\${amount.toStringAsFixed(2)}</td>
                </tr>
                <tr>
                  <td style="padding:10px 14px; color:#64748B; vertical-align:top;"><strong>Reason</strong></td>
                  <td align="right" style="padding:10px 14px; color:#1E293B; line-height:1.4;">$reason</td>
                </tr>
              </table>
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
                This is an automated notification. Please review this request in the admin panel.<br>
                &copy; \${DateTime.now().year} $appName &nbsp;|&nbsp; Rooks &amp; Brooks Technologies Pvt. Ltd. All rights reserved.
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
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Payments & Refunds',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: primaryColor,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'My Payments'),
            Tab(text: 'Refund Requests'),
          ],
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: 960,
        child: TabBarView(
          controller: _tabController,
          children: [
            _PaymentsTab(uid: uid, onRequestRefund: _showRefundRequestDialog),
            _RefundRequestsTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final String? uid;
  final Future<void> Function(Map<String, dynamic>, String) onRequestRefund;

  const _PaymentsTab({required this.uid, required this.onRequestRefund});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          DateTime? aDate, bDate;
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          if (aData['createdAt'] is Timestamp) {
            aDate = (aData['createdAt'] as Timestamp).toDate();
          }
          if (bData['createdAt'] is Timestamp) {
            bDate = (bData['createdAt'] as Timestamp).toDate();
          }
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        final eligibleDocs = docs.where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status']?.toString() ?? '';
          return status == 'SUCCESS' ||
              status == 'PARTIAL_REFUND' ||
              status == 'REFUNDED';
        }).toList();

        if (eligibleDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No payments found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: eligibleDocs.length,
          itemBuilder: (context, index) {
            final doc = eligibleDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _PaymentCard(
              data: data,
              docId: doc.id,
              onRequestRefund: onRequestRefund,
            );
          },
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Future<void> Function(Map<String, dynamic>, String) onRequestRefund;

  const _PaymentCard({
    required this.data,
    required this.docId,
    required this.onRequestRefund,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final planName = data['planName'] ?? data['plan'] ?? 'Subscription';
    final status = data['status']?.toString() ?? 'SUCCESS';
    final timestamp = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final dateStr = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp)
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.undo_rounded,
                  size: 14,
                  color: Color(0xFFEF4444),
                ),
                label: Text(
                  'Request Refund',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => onRequestRefund(data, docId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefundRequestsTab extends StatelessWidget {
  final String? uid;

  const _RefundRequestsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_requests')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No refund requests yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amount =
                double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
            final reason = data['reason'] ?? '';
            final status = data['status'] ?? 'Pending Review';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Refund Request',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: $reason',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
