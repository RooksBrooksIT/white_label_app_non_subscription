import 'dart:math';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  final List<String> _statusFilters = [
    'All',
    'SUCCESS',
    'FAILED',
    'REFUNDED',
    'INITIATED',
    'CANCELLED',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ThemeService.instance.databaseName;
    final appId = ThemeService.instance.appName;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaction Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Transaction ID or Amount...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((filter) {
                        final isSelected = _selectedStatusFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatusFilter = filter;
                              });
                            },
                            backgroundColor: Colors.grey[50],
                            selectedColor: _getStatusColor(
                              filter,
                            ).withOpacity(0.1),
                            checkmarkColor: _getStatusColor(filter),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getStatusColor(filter)
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? _getStatusColor(filter)
                                  : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Summary
            _buildStatsSummary(),

            // Transactions List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.instance
                    .collection(
                      'payment_transactions',
                      tenantId: tenantId,
                      appId: appId,
                    )
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading transactions',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
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
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When customers make payments,\nthey will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter locally for search query and status
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final txnId = (data['merchantTxnNo'] ?? '')
                        .toString()
                        .toLowerCase();
                    final amount = (data['amount'] ?? '').toString();
                    final status = (data['status'] ?? '')
                        .toString()
                        .toUpperCase();

                    // Apply status filter
                    if (_selectedStatusFilter != 'All' &&
                        status != _selectedStatusFilter.toUpperCase()) {
                      return false;
                    }

                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      return txnId.contains(_searchQuery) ||
                          amount.contains(_searchQuery);
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matching transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final data =
                          filteredDocs[index].data() as Map<String, dynamic>;
                      return _buildTransactionCard(data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection(
            'payment_transactions',
            tenantId: ThemeService.instance.databaseName,
            appId: ThemeService.instance.appName,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data?.docs ?? [];
        double totalRevenue = 0;
        int successCount = 0;
        int refundCount = 0;
        int failedCount = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toUpperCase();
          final amount =
              double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

          if (status == 'SUCCESS' || status == 'UAT_SIMULATED') {
            totalRevenue += amount;
            successCount++;
          } else if (status == 'REFUNDED') {
            refundCount++;
          } else if (status == 'FAILED' || status == 'CANCELLED') {
            failedCount++;
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.currency_rupee,
                  label: 'Revenue',
                  value: '₹${totalRevenue.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Success',
                  value: successCount.toString(),
                  color: Colors.blue,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.refresh,
                  label: 'Refunds',
                  value: refundCount.toString(),
                  color: Colors.orange,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.error,
                  label: 'Failed',
                  value: failedCount.toString(),
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildTransactionCard(Map<String, dynamic> data) {
    final merchantTxnNo = data['merchantTxnNo'] ?? 'Unknown';
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final status = data['status'] ?? 'UNKNOWN';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp)
        : 'N/A';
    final paymentMethod = data['paymentMethod'] ?? 'N/A';
    final customerName = data['customerName'] ?? data['email'] ?? 'Guest';
    final upiId = data['upiId'];
    final bankRefNo = data['bankRefNo'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 24,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${merchantTxnNo.substring(0, min(8, merchantTxnNo.length))}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customerName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _buildDetailRow('Payment Method', paymentMethod),
                  if (upiId != null) _buildDetailRow('UPI ID', upiId),
                  if (bankRefNo != null)
                    _buildDetailRow('Bank Ref No', bankRefNo),
                  _buildDetailRow('Transaction ID', merchantTxnNo),
                  const SizedBox(height: 16),

                  // Refund Button for eligible transactions
                  if (_isRefundable(status))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmRefund(
                          context,
                          merchantTxnNo,
                          amount.toString(),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Process Refund'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (status == 'REFUNDED')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Refund processed successfully',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'UAT_SIMULATED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.orange;
      case 'REFUNDED':
      case 'REFUND_INITIATED':
        return Colors.orange;
      case 'INITIATED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'UAT_SIMULATED':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.cancel;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'REFUNDED':
      case 'REFUND_INITIATED':
        return Icons.refresh;
      case 'INITIATED':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  bool _isRefundable(String status) {
    return status == 'CANCELLED' || status == 'FAILED' || status == 'DECLINED';
  }

  Future<void> _confirmRefund(
    BuildContext context,
    String merchantTxnNo,
    String amount,
  ) async {
    final shouldRefund = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to initiate a refund for this transaction?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildRefundDetailRow('Transaction ID', merchantTxnNo),
                  _buildRefundDetailRow('Amount', '₹$amount'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );

    if (shouldRefund == true && mounted) {
      _processRefund(merchantTxnNo, amount);
    }
  }

  Widget _buildRefundDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _processRefund(String merchantTxnNo, String amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Processing Refund...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await IciciService.instance.initiateRefund(
        merchantTxnNo: merchantTxnNo,
        amount: amount,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result != null &&
          (result['status'] == '0' || result['status'] == 'SUCCESS')) {
        // Success
        _showSuccessSnackbar('Refund initiated successfully!');

        // Update status in Firestore
        final tenantId = ThemeService.instance.databaseName;
        final appId = ThemeService.instance.appName;

        await FirestoreService.instance
            .collection(
              'payment_transactions',
              tenantId: tenantId,
              appId: appId,
            )
            .doc(merchantTxnNo)
            .update({
              'status': 'REFUNDED',
              'refundTimestamp': FieldValue.serverTimestamp(),
              'refundData': result,
            });
      } else {
        // Evaluate failure
        final msg = result?['message'] ?? 'Refund failed. Please try again.';
        _showErrorSnackbar(msg);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showErrorSnackbar('Exception: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
