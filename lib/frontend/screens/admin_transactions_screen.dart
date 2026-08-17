import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  // ── Theme helpers ─────────────────────────────
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;

  // ── State ─────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  final List<String> _statusFilters = [
    'All',
    'Active',
    'Inactive',
    'Expired',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Color & Icon Helpers for Status ───────────
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981); // Emerald Green
      case 'inactive':
        return const Color(0xFFF59E0B); // Amber/Orange
      case 'expired':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle_rounded;
      case 'inactive':
        return Icons.pause_circle_rounded;
      case 'expired':
        return Icons.error_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tenantId = ThemeService.instance.databaseName;
    final appId = ThemeService.instance.appName;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // ── AppBar (Dashboard Style) ─────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Subscription Management',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              child: IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: primaryColor, size: 20),
                onPressed: () => setState(() {}),
                tooltip: 'Refresh Subscriptions',
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Search & Filter Controls Container ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              children: [
                // ── Search Bar ─────────────────
                TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Plan Name or Price...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase().trim();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // ── Filter Pills Row ───────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((filter) {
                      final isSelected =
                          _selectedStatusFilter.toLowerCase() ==
                              filter.toLowerCase();
                      final statusColor = _getStatusColor(filter);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStatusFilter = filter;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (filter == 'All'
                                    ? primaryColor
                                    : statusColor)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? (filter == 'All'
                                      ? primaryColor
                                      : statusColor)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (filter == 'All'
                                              ? primaryColor
                                              : statusColor)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats Summary Banner ───────────────────
          _buildStatsSummary(tenantId, appId),

          // ── Subscriptions List Stream ──────────────
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
                  return _buildErrorView(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(
                    title: 'No Subscriptions Found',
                    subtitle:
                        'When customers subscribe to your plans,\ntheir active subscriptions will show up here.',
                    icon: Icons.card_membership_rounded,
                  );
                }

                // Filter docs locally for search query & status
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final planName =
                      (data['planName'] ?? '').toString().toLowerCase();
                  final price = (data['price'] ?? '').toString();
                  final status =
                      (data['status'] ?? '').toString().toLowerCase();

                  // Status filter
                  if (_selectedStatusFilter != 'All' &&
                      status != _selectedStatusFilter.toLowerCase()) {
                    return false;
                  }

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    return planName.contains(_searchQuery) ||
                        price.contains(_searchQuery);
                  }

                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState(
                    title: 'No Matching Results',
                    subtitle:
                        'We couldn\'t find any subscriptions matching your search or active status filter.',
                    icon: Icons.search_off_rounded,
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
    );
  }

  // ── Modern Metrics Dashboard Banner ────────────
  Widget _buildStatsSummary(String tenantId, String appId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .subscriptionsRef(tenantId: tenantId, appId: appId)
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

        final formatter = NumberFormat.currency(
          symbol: '₹',
          decimalDigits: totalRevenue % 1 == 0 ? 0 : 2,
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Revenue',
                  value: formatter.format(totalRevenue),
                  color: const Color(0xFF10B981),
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Active',
                  value: '$activeCount',
                  color: const Color(0xFF2563EB),
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.pause_circle_rounded,
                  label: 'Inactive',
                  value: '$inactiveCount',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.timer_off_rounded,
                  label: 'Expired',
                  value: '$expiredCount',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 36,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFF1F5F9),
    );
  }

  // ── Customer-friendly Subscription Card ────────
  Widget _buildSubscriptionCard(Map<String, dynamic> data, String docId) {
    final planName = data['planName'] ?? 'Standard Plan';
    final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
    final status = (data['status'] ?? 'active').toString();
    final paymentMethod = data['paymentMethod'] ?? 'Online Payment';
    final isYearly = data['isYearly'] == true;
    final isSixMonths = data['isSixMonths'] == true;
    final customerMobile = data['customerMobile'];
    final originalPrice = data['originalPrice'];

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    // Dates
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

    // Billing cycle text
    String billingCycle = 'Monthly';
    if (planName.toString().toLowerCase().contains('trial')) {
      billingCycle = 'Free Trial (7 Days)';
    } else if (isYearly) {
      billingCycle = 'Yearly';
    } else if (isSixMonths) {
      billingCycle = '6 Months';
    }

    // Features
    final geoLocation = data['geoLocation'] == true;
    final attendance = data['attendance'] == true;
    final barcode = data['barcode'] == true;
    final reportExport = data['reportExport'] == true;

    // Limits
    final limits = data['limits'] as Map<String, dynamic>?;

    final formattedPriceStr =
        '₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$formattedPriceStr / $billingCycle',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Started: $formattedStartDate',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Next Billing: $formattedNextBilling',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0xFFF1F5F9), height: 20),

            // ── Section 1: Subscription Overview ────────
            _sectionHeader(
              icon: Icons.receipt_long_rounded,
              title: 'Plan & Billing Details',
              color: primaryColor,
            ),
            const SizedBox(height: 10),

            _infoRow('Plan Title', planName),
            _infoRow('Price', '$formattedPriceStr / $billingCycle'),
            if (originalPrice != null)
              _infoRow(
                'Original Price',
                '₹${double.tryParse(originalPrice.toString())?.toStringAsFixed(2) ?? originalPrice.toString()}',
              ),
            _infoRow('Payment Method', paymentMethod),
            _infoRow('Subscription Status', status[0].toUpperCase() + status.substring(1)),
            _infoRow('Start Date', formattedStartDate),
            _infoRow('Next Renewal Date', formattedNextBilling),
            _infoRow('Expiration Date', formattedExpiresAt),
            _infoRow('Last Updated', formattedUpdatedAt),
            if (customerMobile != null && customerMobile.toString().isNotEmpty)
              _infoRow('Customer Mobile', customerMobile.toString()),
            _infoRow('Reference ID', docId),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // ── Section 2: Included Features ────────────
            _sectionHeader(
              icon: Icons.stars_rounded,
              title: 'Included Features',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureBadge('Geo Location', geoLocation),
                _buildFeatureBadge('Attendance Tracking', attendance),
                _buildFeatureBadge('Barcode Verification', barcode),
                _buildFeatureBadge('Report Export', reportExport),
              ],
            ),

            // ── Section 3: Limits & Quotas (if available) ─
            if (limits != null && limits.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              _sectionHeader(
                icon: Icons.data_usage_rounded,
                title: 'Plan Limits & Quotas',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 10),
              ...limits.entries.map((entry) {
                final keyFormatted = entry.key
                    .replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ')
                    .replaceAll('_', ' ');
                final titleCaseKey = keyFormatted.isEmpty
                    ? entry.key
                    : keyFormatted[0].toUpperCase() + keyFormatted.substring(1);
                return _infoRow(
                  titleCaseKey,
                  entry.value?.toString() ?? 'N/A',
                );
              }),
            ],
          ],
        ),
      ),
    ),
    );
  }

  // ── Helper Widgets for Detail Rows ────────────
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String label, bool enabled) {
    final color = enabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? const Color(0xFF10B981).withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? const Color(0xFF065F46) : const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State View ──────────────────────────
  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State View ──────────────────────────
  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load subscriptions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
