import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assigndelivery_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart'
    as customer_var;

class AdminDeliveryTickets extends StatefulWidget {
  final customer_var.Customer? newCustomer;
  final String statusFilter;

  const AdminDeliveryTickets({
    super.key,
    this.newCustomer,
    required this.statusFilter,
  });

  @override
  _AdminDeliveryTicketsState createState() => _AdminDeliveryTicketsState();
}

class _AdminDeliveryTicketsState extends State<AdminDeliveryTickets> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestore = FirestoreService.instance;

  String searchQuery = "";
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    'All',
    'Not Assigned',
    'Assigned',
    'Delivered',
    'Completed',
    'Canceled',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.statusFilter.isNotEmpty && widget.statusFilter != 'All') {
      _selectedFilter = widget.statusFilter;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculate working days between two dates
  int _workingDaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    DateTime s = DateTime(start.year, start.month, start.day);
    DateTime e = DateTime(end.year, end.month, end.day);
    int days = 0;
    for (DateTime d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        days++;
      }
    }
    return max(0, days - 1);
  }

  Map<String, dynamic> _buildDurationInfo({
    required Map<String, dynamic> ticketData,
    required bool isCompleted,
    required Timestamp createdTs,
  }) {
    Timestamp? completedTs;
    final completedKeys = ['completedAt', 'completedTS', 'completedOn'];
    for (final k in completedKeys) {
      if (ticketData[k] is Timestamp) {
        completedTs = ticketData[k] as Timestamp;
        break;
      }
    }

    final now = DateTime.now();
    final created = createdTs.toDate();

    if (isCompleted && completedTs != null) {
      final completed = completedTs.toDate();
      final wd = _workingDaysBetween(created, completed);
      return {
        'label': 'Delivered in $wd day${wd == 1 ? '' : 's'}',
        'color': Colors.green.shade600,
        'bg': Colors.green.shade50,
      };
    }

    final wdOpen = _workingDaysBetween(created, now);
    return {
      'label': '$wdOpen day${wdOpen == 1 ? '' : 's'} to go',
      'color': Theme.of(context).primaryColor,
      'bg': Theme.of(context).primaryColor.withValues(alpha: 0.1),
    };
  }

  String _getField(
    Map<String, dynamic> data,
    List<String> keys, [
    String defaultValue = '',
  ]) {
    for (final key in keys) {
      if (data.containsKey(key) &&
          data[key] != null &&
          data[key].toString().trim().isNotEmpty) {
        final value = data[key].toString().trim();
        if (value.toLowerCase() != 'n/a') {
          return value;
        }
      }
    }
    return defaultValue;
  }

  Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  void _showFilterDialog() {
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Filter Delivery Tickets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _filterOptions.map((opt) {
                      final isSel = _selectedFilter == opt;
                      return ChoiceChip(
                        label: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: primaryColor,
                        backgroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSel ? primaryColor : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedFilter = opt;
                          });
                          setState(() {
                            _selectedFilter = opt;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Tickets',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: _selectedFilter != 'All'
                      ? Theme.of(context).primaryColor
                      : const Color(0xFF0F172A),
                ),
                onPressed: _showFilterDialog,
              ),
              if (_selectedFilter != 'All')
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildQuickFilterChips(),
            const SizedBox(height: 12),
            Expanded(
              child: _buildDeliveryStreamBuilder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    final primaryColor = Theme.of(context).primaryColor;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilter == option;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = option;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              searchQuery = value.trim();
            });
          },
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
              color: primaryColor,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                : null,
            hintText: 'Search Booking ID, Customer, or Mobile...',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryStreamBuilder() {
    Query query = _firestore
        .collection('Admin_ticket_entry')
        .orderBy('bookingId', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<DocumentSnapshot> docs = snapshot.data?.docs ?? [];

        List<DocumentSnapshot> filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;

          final jobType = _getField(data, ['jobType', 'JobType'], '').toLowerCase().trim();
          if (!jobType.contains('delivery')) {
            return false;
          }

          final engineerStatusRaw = _getField(data, [
            'engineerStatus',
            'statusDescription',
          ], '').toLowerCase();
          final adminStatusRaw = _getField(data, ['adminStatus'], '').toLowerCase();
          final bookingId = _getField(data, ['bookingId'], '').toLowerCase();
          final customerName = _getField(data, [
            'customerName',
            'CustomerName',
          ], '').toLowerCase();
          final mobileNumber = _getField(data, [
            'mobileNumber',
            'MobileNumber',
          ], '').toLowerCase();

          if (searchQuery.isNotEmpty) {
            final queryStr = searchQuery.toLowerCase();
            if (!bookingId.contains(queryStr) &&
                !customerName.contains(queryStr) &&
                !mobileNumber.contains(queryStr)) {
              return false;
            }
          }

          final isCanceled = adminStatusRaw == 'canceled' || engineerStatusRaw == 'canceled';
          final isDelivered = engineerStatusRaw == 'delivered' || adminStatusRaw == 'delivered' || engineerStatusRaw == 'completed';
          final isnotassigned = adminStatusRaw == 'not assigned' || (engineerStatusRaw == 'not assigned' && !isCanceled);
          final isassigned = engineerStatusRaw == 'assigned';
          final isothers =
              engineerStatusRaw.contains('approval') ||
              engineerStatusRaw.contains('spares') ||
              engineerStatusRaw.contains('observation');

          switch (_selectedFilter) {
            case 'Assigned':
              return isassigned;
            case 'Delivered':
            case 'Completed':
              return isDelivered;
            case 'Not Assigned':
              return isnotassigned;
            case 'Canceled':
              return isCanceled;
            case 'Others':
              return isothers;
            case 'All':
            default:
              return true;
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 48, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Text(
                  'No delivery tickets found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>?;
            if (data == null) return const SizedBox.shrink();

            final customer = customer_var.Customer(
              bookingId: _getField(data, ['bookingId']),
              customerName: _getField(data, ['customerName', 'CustomerName']),
              deviceType: _getField(data, ['deviceType', 'description']),
              deviceBrand: _getField(data, ['deviceBrand']),
              deviceCondition: _getField(data, ['deviceCondition']),
              message: _getField(data, ['message', 'Message']),
              timestamp: _parseTimestamp(data['timestamp']),
              address: _getField(data, ['address', 'Address']),
              mobileNumber: _getField(data, ['mobileNumber', 'MobileNumber']),
              jobType: _getField(data, ['jobType', 'JobType']),
              amount: _getField(data, ['amount']),
              customerid: _getField(data, ['customerid', 'id', 'Id']),
              customerFileUrl: _getField(data, ['customerFileUrl']),
              fileName: _getField(data, ['fileName']),
            );

            String statusRaw = _getField(data, [
              'engineerStatus',
              'statusDescription',
              'adminStatus',
            ], 'Not Assigned');

            final bool inferredCompleted = statusRaw.toLowerCase().contains('delivered') || statusRaw.toLowerCase().contains('complete');
            final durationInfo = _buildDurationInfo(
              ticketData: data,
              isCompleted: inferredCompleted,
              createdTs: customer.timestamp,
            );

            final adminStatus = _getField(data, ['adminStatus'], '');
            final isCanceled = adminStatus.toLowerCase() == 'canceled';
            final assignedEmployee = _getField(data, ['assignedEmployee'], 'Not Assigned');

            final double? customerLat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
            final double? customerLng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;

            return _buildDeliveryCard(
              customer,
              index + 1,
              statusRaw,
              assignedEmployee,
              inferredCompleted,
              isCanceled,
              filteredDocs[index].id,
              durationInfo,
              customerLat,
              customerLng,
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryCard(
    customer_var.Customer customer,
    int serialNumber,
    String status,
    String assignedEmployee,
    bool isCompleted,
    bool isCanceled,
    String docId,
    Map<String, dynamic> durationInfo,
    double? customerLat,
    double? customerLng,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    Color getStatusColor(String status) {
      final s = status.toLowerCase().trim();
      if (s == 'assigned') return const Color(0xFF0984E3);
      if (s == 'delivered' || s == 'completed' || s == 'complete') return const Color(0xFF10B981);
      if (s == 'not assigned') return const Color(0xFFEF4444);
      if (s.contains('stock')) return const Color(0xFFF59E0B);
      if (s == 'canceled') return const Color(0xFF64748B);
      return const Color(0xFF3B82F6);
    }

    final statusColor = getStatusColor(status);

    return GestureDetector(
      onTap: () {
        _showDeliveryDetailSheet(
          context,
          customer,
          serialNumber,
          status,
          isCompleted,
          isCanceled,
          assignedEmployee,
          docId,
          durationInfo,
          customerLat,
          customerLng,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : isCanceled
                          ? Icons.cancel_rounded
                          : Icons.local_shipping_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.bookingId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer.customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),

            const Divider(color: Color(0xFFF1F5F9), height: 1),

            // Card Body Information
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          customer.address.isNotEmpty ? customer.address : 'No address provided',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        customer.mobileNumber.isNotEmpty ? customer.mobileNumber : 'No mobile number',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${customer.deviceBrand} - ${customer.deviceType}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (assignedEmployee != 'Not Assigned') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0984E3).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_rounded, size: 14, color: Color(0xFF0984E3)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Assigned: $assignedEmployee',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0984E3),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Footer Bar Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(customer.timestamp.toDate()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCanceled) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      durationInfo['label'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: (durationInfo['color'] as Color?) ?? primaryColor,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryDetailSheet(
    BuildContext context,
    customer_var.Customer customer,
    int serialNumber,
    String status,
    bool isCompleted,
    bool isCanceled,
    String assignedEmployee,
    String docId,
    Map<String, dynamic> durationInfo,
    double? customerLat,
    double? customerLng,
  ) {
    final primaryColor = Theme.of(context).primaryColor;
    final dateString = DateFormat('dd MMM yyyy').format(customer.timestamp.toDate());
    final timeString = DateFormat('hh:mm a').format(customer.timestamp.toDate());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Top Drag Handle & Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.local_shipping_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Ticket Workspace',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Full Details & Dispatch Actions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Section 1: Specifications
                      _buildWorkspaceSectionCard(
                        title: 'Delivery & Item Specifications',
                        icon: Icons.inventory_2_rounded,
                        primaryColor: primaryColor,
                        children: [
                          _buildDetailGridRow('Booking ID', customer.bookingId, isHighlight: true),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Service', customer.jobType.isNotEmpty ? customer.jobType : 'Delivery Service'),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Device Type', customer.deviceType),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Device Brand', customer.deviceBrand),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Condition', customer.deviceCondition),
                          if (customer.message.isNotEmpty) ...[
                            const Divider(color: Color(0xFFF1F5F9), height: 16),
                            _buildDetailGridRow('Instructions', customer.message),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Customer & Assignment
                      _buildWorkspaceSectionCard(
                        title: 'Customer & Assignment Info',
                        icon: Icons.badge_rounded,
                        primaryColor: primaryColor,
                        children: [
                          _buildDetailGridRow('Customer ID', customer.customerid.isNotEmpty ? customer.customerid : 'CR001'),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Contact Number', customer.mobileNumber),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Full Address', customer.address),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Assigned Driver', assignedEmployee, isHighlight: assignedEmployee != 'Not Assigned'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 3: Billing & Date
                      _buildWorkspaceSectionCard(
                        title: 'Payment & Billing',
                        icon: Icons.payments_rounded,
                        primaryColor: primaryColor,
                        children: [
                          _buildDetailGridRow('Payment Method', 'N/A'),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow(
                            'Total Bill Amount',
                            '₹ ${customer.amount}',
                            customValue: Text(
                              '₹ ${customer.amount}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 16),
                          _buildDetailGridRow('Ticket Created', '$dateString at $timeString'),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Attachment if present
                      if (customer.customerFileUrl != null &&
                          customer.customerFileUrl!.isNotEmpty &&
                          customer.customerFileUrl != 'N/A') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(customer.customerFileUrl!);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open file')),
                                );
                              }
                            },
                            icon: const Icon(Icons.file_download_rounded, size: 18, color: Colors.white),
                            label: const Text(
                              'View Attachment',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0984E3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Main Action Buttons Bar (Exactly 2 Buttons: Customer Location & Assign Ticket)
                      if (!isCompleted) ...[
                        if (isCanceled) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Reactivate Ticket'),
                                    content: const Text('Are you sure you want to reactivate this cancelled delivery ticket?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Keep Cancelled'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Reactivate', style: TextStyle(color: Color(0xFF10B981))),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await _firestore.collection('Admin_ticket_entry').doc(docId).update({
                                      'adminStatus': 'Open',
                                      'Customer_decision': '',
                                      'engineerStatus': 'Assigned',
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Delivery ticket reactivated successfully!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to reactivate ticket: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                              label: const Text(
                                'Reactivate Ticket',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AdminGeoLocationScreen(
                                          engineerId: assignedEmployee != 'Not Assigned' ? assignedEmployee : 'N/A',
                                          engineerName: assignedEmployee != 'Not Assigned' ? assignedEmployee : 'N/A',
                                          bookingDocId: docId,
                                          customerLat: customerLat,
                                          customerLng: customerLng,
                                          customerAddress: customer.address,
                                          bookingId: customer.bookingId,
                                          customerName: customer.customerName,
                                          jobType: customer.jobType,
                                          deviceType: customer.deviceType,
                                          deviceBrand: customer.deviceBrand,
                                          assignedEmployee: assignedEmployee != 'Not Assigned' ? assignedEmployee : null,
                                          customerStatus: status,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.location_on_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'Customer Location',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final docRef = _firestore.collection('Admin_ticket_entry').doc(customer.bookingId);
                                      final docSnapshot = await docRef.get();
                                      if (docSnapshot.exists) {
                                        final data = docSnapshot.data() ?? {};
                                        Map<String, dynamic> updateData = {'adminStatus': 'Assigned'};
                                        if (!data.containsKey('engineerStatus')) {
                                          updateData['engineerStatus'] = 'Open';
                                        }
                                        await docRef.update(updateData);
                                      } else {
                                        await docRef.set({'adminStatus': 'Assigned', 'engineerStatus': 'Open'});
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to update status: $e')),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AssigndeliveryCustomerPage(customer: customer),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'Assign Ticket',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceSectionCard({
    required String title,
    required IconData icon,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailGridRow(
    String label,
    String value, {
    bool isHighlight = false,
    Widget? customValue,
  }) {
    final displayVal = (value.isEmpty || value == "N/A") ? "Not Found" : value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: customValue ??
              Text(
                displayVal,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isHighlight
                      ? Theme.of(context).primaryColor
                      : const Color(0xFF0F172A),
                ),
              ),
        ),
      ],
    );
  }
}
