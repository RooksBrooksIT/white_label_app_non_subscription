import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

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
    'active',
    'inactive',
    'expired',
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
          'Subscription Management',
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
      body: ResponsiveWrapper(
        maxWidth: 1200.0,
        child: Container(
          color: Colors.grey[50],
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
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
                        hintText: 'Search by Plan Name or Price...',
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
                            label: Text(filter[0].toUpperCase() + filter.substring(1)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatusFilter = filter;
                              });
                            },
                            backgroundColor: Colors.grey[50],
                            selectedColor: _getStatusColor(
                              filter,
                            ).withValues(alpha: 0.1),
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

            // Subscriptions List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.instance
                    .subscriptionsRef(
                      tenantId: tenantId,
                      appId: appId,
                    )
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
                            'Error loading subscriptions',
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
                            Icons.card_membership_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No subscriptions found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When customers subscribe,\nthey will appear here',
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
                    final planName = (data['planName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final price = (data['price'] ?? '').toString();
                    final status = (data['status'] ?? '')
                        .toString()
                        .toLowerCase();

                    // Apply status filter
                    if (_selectedStatusFilter != 'All' &&
                        status != _selectedStatusFilter.toLowerCase()) {
                      return false;
                    }

                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      return planName.contains(_searchQuery) ||
                          price.contains(_searchQuery);
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
                            'No matching subscriptions',
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
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildSubscriptionCard(data, doc.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final tenantId = ThemeService.instance.databaseName;
    final appId = ThemeService.instance.appName;

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .subscriptionsRef(
            tenantId: tenantId,
            appId: appId,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data?.docs ?? [];
        double totalRevenue = 0;
        int activeCount = 0;
        int inactiveCount = 0;
        int expiredCount = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final price =
              double.tryParse(data['price']?.toString() ?? '0') ?? 0;

          if (status == 'active') {
            totalRevenue += price;
            activeCount++;
          } else if (status == 'inactive') {
            inactiveCount++;
          } else if (status == 'expired') {
            expiredCount++;
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
                  label: 'Active',
                  value: activeCount.toString(),
                  color: Colors.blue,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.cancel_outlined,
                  label: 'Inactive',
                  value: inactiveCount.toString(),
                  color: Colors.orange,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.timer_off,
                  label: 'Expired',
                  value: expiredCount.toString(),
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

  Widget _buildSubscriptionCard(Map<String, dynamic> data, String docId) {
    final planName = data['planName'] ?? 'Unknown Plan';
    final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
    final status = (data['status'] ?? 'unknown').toString();
    final paymentMethod = data['paymentMethod'] ?? 'N/A';
    final isYearly = data['isYearly'] == true;
    final isSixMonths = data['isSixMonths'] == true;
    final customerMobile = data['customerMobile'];
    final originalPrice = data['originalPrice'];

    // Parse dates
    final startedAt = _parseDate(data['startedAt']);
    final nextBillingAt = _parseDate(data['nextBillingAt']);
    final expiresAt = data['expiresAt'];
    final updatedAt = data['updatedAt'];

    final formattedStartDate = startedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(startedAt)
        : 'N/A';
    final formattedNextBilling = nextBillingAt != null
        ? DateFormat('dd MMM yyyy').format(nextBillingAt)
        : 'N/A';

    String formattedExpiresAt = 'N/A';
    if (expiresAt is Timestamp) {
      formattedExpiresAt =
          DateFormat('dd MMM yyyy').format(expiresAt.toDate());
    } else if (expiresAt is String) {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) {
        formattedExpiresAt = DateFormat('dd MMM yyyy').format(parsed);
      }
    }

    String formattedUpdatedAt = 'N/A';
    if (updatedAt is Timestamp) {
      formattedUpdatedAt =
          DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt.toDate());
    }

    // Billing cycle label
    String billingCycle = 'Monthly';
    if (planName.toString().toLowerCase().contains('trial')) {
      billingCycle = 'Free Trial (7 days)';
    } else if (isYearly) {
      billingCycle = 'Yearly';
    } else if (isSixMonths) {
      billingCycle = '6 Months';
    }

    // Feature flags
    final geoLocation = data['geoLocation'] == true;
    final attendance = data['attendance'] == true;
    final barcode = data['barcode'] == true;
    final reportExport = data['reportExport'] == true;

    // Limits
    final limits = data['limits'] as Map<String, dynamic>?;

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
              color: _getStatusColor(status).withValues(alpha: 0.1),
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
                      planName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${price.toStringAsFixed(2)} / $billingCycle',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
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
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
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
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Started: $formattedStartDate',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event_available, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Next Billing: $formattedNextBilling',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Plan Name', planName),
                  _buildDetailRow('Price', '₹${price.toStringAsFixed(2)}'),
                  if (originalPrice != null)
                    _buildDetailRow(
                      'Original Price',
                      '₹${double.tryParse(originalPrice.toString())?.toStringAsFixed(2) ?? originalPrice.toString()}',
                    ),
                  _buildDetailRow('Billing Cycle', billingCycle),
                  _buildDetailRow('Payment Method', paymentMethod),
                  _buildDetailRow('Status', status[0].toUpperCase() + status.substring(1)),
                  _buildDetailRow('Started At', formattedStartDate),
                  _buildDetailRow('Next Billing', formattedNextBilling),
                  _buildDetailRow('Expires At', formattedExpiresAt),
                  _buildDetailRow('Last Updated', formattedUpdatedAt),
                  if (customerMobile != null && customerMobile.toString().isNotEmpty)
                    _buildDetailRow('Customer Mobile', customerMobile.toString()),
                  _buildDetailRow('Doc ID', docId),

                  // Feature flags section
                  const SizedBox(height: 12),
                  Text(
                    'Features',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip('Geo Location', geoLocation),
                      _buildFeatureChip('Attendance', attendance),
                      _buildFeatureChip('Barcode', barcode),
                      _buildFeatureChip('Report Export', reportExport),
                    ],
                  ),

                  // Limits section
                  if (limits != null && limits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Limits',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...limits.entries.map((entry) {
                      return _buildDetailRow(
                        entry.key,
                        entry.value?.toString() ?? 'N/A',
                      );
                    }),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: enabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? Colors.green[700] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            width: 120,
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'inactive':
        return Icons.pause_circle;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.help_outline;
    }
  }
}
