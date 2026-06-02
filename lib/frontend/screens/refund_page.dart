import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ─── Submit Refund Request ──────────────────────────────────────────────────
  Future<void> _showRefundRequestDialog(Map<String, dynamic> paymentData,
      String orderId) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final user = FirebaseAuth.instance.currentUser;

    final customerName =
        paymentData['customerName'] ?? paymentData['name'] ?? 'Unknown';
    final customerEmail =
        paymentData['customerEmail'] ?? paymentData['email'] ?? user?.email ?? 'N/A';
    final mobileNumber =
        paymentData['customerMobile'] ?? paymentData['mobileNumber'] ?? 'N/A';
    final transactionId =
        paymentData['merchantTxnNo'] ?? paymentData['transactionId'] ?? paymentData['paymentId'] ?? 'N/A';
    final amount =
        double.tryParse(paymentData['amount']?.toString() ?? '0') ?? 0;

    bool? submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.undo_rounded,
                          color: Colors.red[700], size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Initiate Refund Request',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Order Details Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Order ID', orderId),
                      _detailRow('Transaction ID', transactionId),
                      _detailRow('Customer Name', customerName),
                      _detailRow('Email', customerEmail),
                      _detailRow('Mobile', mobileNumber),
                      _detailRow(
                          'Amount Paid', '₹${amount.toStringAsFixed(2)}',
                          isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Reason
                const Text(
                  'Reason for Refund *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Please describe why you are requesting a refund...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
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
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
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
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Submit Request'),
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

  // ─── Submit to Firestore + trigger support email ─────────────────────────
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

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final formattedNow =
          DateFormat('dd MMM yyyy, hh:mm a').format(now);

      // 1. Create refund_requests record
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

      // 2. Write to mail collection — picked up by processMailDocument CF
      await db.collection('mail').add({
        'to': 'support@rookstechnologies.com',
        'createdAt': FieldValue.serverTimestamp(),
        'status': {'state': 'PENDING'},
        'message': {
          'subject': 'New Refund Request - Order ID $orderId',
          'html': _buildEmailHtml(
            customerName: customerName,
            customerEmail: customerEmail,
            mobileNumber: mobileNumber,
            orderId: orderId,
            transactionId: transactionId,
            amount: amount,
            reason: reason,
            requestedAt: formattedNow,
          ),
        },
      });

      if (!mounted) return;
      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Refund request submitted! Our team will review it within 3–5 business days.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      // Switch to "My Requests" tab
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Email HTML Builder ──────────────────────────────────────────────────
  String _buildEmailHtml({
    required String customerName,
    required String customerEmail,
    required String mobileNumber,
    required String orderId,
    required String transactionId,
    required double amount,
    required String reason,
    required String requestedAt,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Refund Request</title></head>
<body style="margin:0;padding:0;background-color:#F4F6F9;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F9;padding:30px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">
        <tr>
          <td style="background:#C62828;padding:28px 40px;">
            <p style="margin:0;font-size:22px;font-weight:700;color:#fff;">Rooks & Brooks Technologies</p>
            <p style="margin:4px 0 0;font-size:13px;color:#FFCDD2;">New Refund Request Received</p>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 40px;">
            <p style="font-size:15px;color:#212121;margin:0 0 20px;">A customer has submitted a refund request. Please review the details below:</p>
            <table width="100%" cellpadding="10" cellspacing="0" style="background:#F5F5F5;border-radius:8px;font-size:13px;color:#424242;">
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;width:40%;">Customer Name</td><td>$customerName</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Email</td><td>$customerEmail</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Mobile Number</td><td>$mobileNumber</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Order ID</td><td>$orderId</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Transaction ID</td><td>$transactionId</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Payment Amount</td><td style="font-weight:700;color:#C62828;">₹${amount.toStringAsFixed(2)}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td style="font-weight:600;">Request Date</td><td>$requestedAt</td>
              </tr>
              <tr>
                <td style="font-weight:600;vertical-align:top;">Reason</td>
                <td style="white-space:pre-wrap;">$reason</td>
              </tr>
            </table>
            <p style="margin:24px 0 0;font-size:12px;color:#9E9E9E;text-align:center;">
              Rooks & Brooks Technologies | support@rookstechnologies.com<br>
              This is an automatically generated email.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }

  // ─── Helper: detail row inside dialog ──────────────────────────────────────
  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payments & Refunds',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.red[700],
          tabs: const [
            Tab(text: 'My Payments'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Payments ────────────────────────────────────────────
          _PaymentsTab(
            uid: uid,
            onRequestRefund: _showRefundRequestDialog,
          ),

          // ── Tab 2: Refund Requests ─────────────────────────────────────
          _RefundRequestsTab(uid: uid),
        ],
      ),
    );
  }
}

// ─── Tab 1: Payments ──────────────────────────────────────────────────────────
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

        // Sort newest first
        docs.sort((a, b) {
          DateTime? aDate, bDate;
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          if (aData['createdAt'] is Timestamp) aDate = (aData['createdAt'] as Timestamp).toDate();
          if (bData['createdAt'] is Timestamp) bDate = (bData['createdAt'] as Timestamp).toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        final eligibleDocs = docs.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status']?.toString() ?? '';
          return status == 'SUCCESS' || status == 'PARTIAL_REFUND' || status == 'REFUNDED';
        }).toList();

        if (eligibleDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No payments found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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

  const _PaymentCard(
      {required this.data,
      required this.docId,
      required this.onRequestRefund});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'UNKNOWN';
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final refundedAmount =
        double.tryParse(data['refundedAmount']?.toString() ?? '0') ?? 0;
    final customerName = data['customerName'] ?? data['name'] ?? 'Unknown Customer';
    final customerEmail = data['customerEmail'] ?? data['email'] ?? 'N/A';
    final planName = data['planName'] ?? 'Unknown Plan';

    DateTime? paymentDate;
    if (data['createdAt'] is Timestamp) {
      paymentDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['updatedAt'] is Timestamp) {
      paymentDate = (data['updatedAt'] as Timestamp).toDate();
    }

    final formattedDate = paymentDate != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate)
        : 'N/A';

    final canRequest = (status == 'SUCCESS' || status == 'PARTIAL_REFUND') &&
        (amount - refundedAmount) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Order ID: $docId',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                _statusBadge(status),
              ],
            ),
            const Divider(height: 20),
            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(customerEmail,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 3),
                      Text('Plan: $planName',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(formattedDate,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (refundedAmount > 0)
                      Text(
                          'Refunded: ₹${refundedAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            // Refund Request Button
            if (canRequest) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onRequestRefund(data, docId),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Initiate Refund Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SUCCESS': return Colors.green;
      case 'PARTIAL_REFUND': return Colors.orange;
      case 'REFUNDED': return Colors.red;
      default: return Colors.blueGrey;
    }
  }
}

// ─── Tab 2: Refund Requests ───────────────────────────────────────────────────
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

        final docs = snapshot.data?.docs.toList() ?? [];

        // Sort newest first
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['requestedAt'];
          final bTs = (b.data() as Map<String, dynamic>)['requestedAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No refund requests yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Submit a request from the My Payments tab.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _RefundRequestCard(data: data);
          },
        );
      },
    );
  }
}

class _RefundRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RefundRequestCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final requestStatus = data['status'] ?? 'Pending Review';
    final orderId = data['orderId'] ?? 'N/A';
    final transactionId = data['transactionId'] ?? 'N/A';
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final reason = data['reason'] ?? 'N/A';

    DateTime? requestedAt;
    if (data['requestedAt'] is Timestamp) {
      requestedAt = (data['requestedAt'] as Timestamp).toDate();
    }
    final formattedDate = requestedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(requestedAt)
        : 'N/A';

    final statusColor = _requestStatusColor(requestStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Order: $orderId',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(requestStatus,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('Amount', '₹${amount.toStringAsFixed(2)}'),
            _row('Txn ID', transactionId),
            _row('Requested', formattedDate),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reason:',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(reason,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 12))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Color _requestStatusColor(String status) {
    switch (status) {
      case 'Pending Review': return Colors.orange;
      case 'Approved': return Colors.blue;
      case 'Rejected': return Colors.red;
      case 'Refunded': return Colors.green;
      default: return Colors.grey;
    }
  }
}
