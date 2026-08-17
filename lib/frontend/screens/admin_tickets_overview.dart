import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_engineer_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assigndelivery_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_tickets.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart'
    as customer_var;

class AdminPage_CusDetails extends StatefulWidget {
  final customer_var.Customer? newCustomer;
  final String? searchQuery;
  const AdminPage_CusDetails({
    super.key,
    this.newCustomer,
    required String statusFilter,
    this.searchQuery,
  });

  @override
  _AdminPage_CusDetailsState createState() => _AdminPage_CusDetailsState();
}

class _AdminPage_CusDetailsState extends State<AdminPage_CusDetails> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String selectedFilter = 'All';
  String ticketTypeFilter = 'All'; // 'All', 'Service', 'Delivery'

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null) {
      searchQuery = widget.searchQuery!;
      _searchController.text = widget.searchQuery!;
    }
  }

  // Calculate working days between two dates (excludes Sat/Sun)
  int _workingDaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    // Normalize to dates only
    DateTime s = DateTime(start.year, start.month, start.day);
    DateTime e = DateTime(end.year, end.month, end.day);

    int days = 0;
    for (DateTime d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        days++;
      }
    }
    return max(
      0,
      days - 1,
    ); // exclude start day from count (e.g., same day -> 0)
  }

  // Build duration label and style based on ticket status
  Map<String, dynamic> _buildDurationInfo({
    required Map<String, dynamic> ticketData,
    required bool isCompleted,
    required Timestamp createdTs,
  }) {
    // Prefer explicit completed timestamp fields if present
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
        'label': 'This ticket was completed in $wd day${wd == 1 ? '' : 's'}',
        'color': Colors.green.shade600,
        'bg': Colors.green.shade50,
      };
    }

    // Open/in-progress ticket: countdown to today from created
    final wdOpen = _workingDaysBetween(created, now);
    return {
      'label': '$wdOpen day${wdOpen == 1 ? '' : 's'} to go',
      'color': Theme.of(context).primaryColor,
      'bg': Theme.of(context).primaryColor.withValues(alpha: 0.1),
    };
  }

  // Helper method to safely get customer document stream
  Stream<DocumentSnapshot> _getCustomerIdStream(
    customer_var.Customer customer,
  ) {
    try {
      String customerId = customer.customerid;

      // Validate and clean the customer ID
      if (customerId.isEmpty ||
          customerId.toLowerCase() == 'n/a' ||
          customerId.contains('/') ||
          customerId.trim().isEmpty) {
        customerId = customer.bookingId;
      }

      // Final validation
      if (customerId.isEmpty || customerId.contains('/')) {
        return Stream<DocumentSnapshot>.empty();
      }

      return FirestoreService.instance
          .collection('customers')
          .doc(customerId)
          .snapshots();
    } catch (e) {
      // Return empty stream if any error occurs during setup
      return Stream<DocumentSnapshot>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    double getProportionalSize(double size) {
      final baseSize = screenWidth < screenHeight ? screenWidth : screenHeight;
      return size * (baseSize / 375);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'All Tickets',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateTickets(
                      statusFilter: '',
                      customerId: '',
                      customerName: '',
                      mobileNumber: '',
                      categoryName: '',
                      loggedInName: '',
                      name: '',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create Ticket',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: selectedFilter != 'All'
                      ? Theme.of(context).primaryColor
                      : const Color(0xFF0F172A),
                ),
                onPressed: _showFilterDialog,
              ),
              if (selectedFilter != 'All')
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
            _buildTopDomainBanner(),
            const SizedBox(height: 8),
            _buildSearchBar(screenWidth, getProportionalSize),
            const SizedBox(height: 12),
            _buildTicketTypeSegmentedControl(),
            const SizedBox(height: 12),
            _buildQuickFilterChips(),
            const SizedBox(height: 12),
            Expanded(
              child: _buildCustomerStreamBuilder(
                screenWidth,
                screenHeight,
                getProportionalSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDomainBanner() {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ticket Workspace',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track, assign, and manage all customer tickets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryColor.withValues(alpha: 0.85),
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

  Widget _buildTicketTypeSegmentedControl() {
    final primaryColor = Theme.of(context).primaryColor;
    final options = [
      {'label': 'All', 'value': 'All', 'icon': null},
      {'label': 'Service', 'value': 'Service', 'icon': Icons.build_circle_rounded},
      {'label': 'Delivery', 'value': 'Delivery', 'icon': Icons.local_shipping_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: options.map((opt) {
            final val = opt['value'] as String;
            final isSelected = ticketTypeFilter == val;
            final icon = opt['icon'] as IconData?;
            final label = opt['label'] as String;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    ticketTypeFilter = val;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? (val == 'Delivery' ? const Color(0xFF10B981) : primaryColor)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    final primaryColor = Theme.of(context).primaryColor;
    final filterOptions = ['All', 'Not Assigned', 'Assigned', 'Completed', 'Canceled', 'Others'];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filterOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = filterOptions[index];
          final isSelected = selectedFilter == option;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = option;
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

  Widget _buildSearchBar(
    double screenWidth,
    double Function(double) getProportionalSize,
  ) {
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

  String getField(
    Map<String, dynamic> data,
    List<String> keys, [
    String defaultValue = '',
  ]) {
    for (final key in keys) {
      if (data.containsKey(key) &&
          data[key] != null &&
          data[key].toString().trim().isNotEmpty) {
        final value = data[key].toString().trim();
        // Avoid returning 'N/A' or similar invalid values
        if (value.toLowerCase() != 'n/a') {
          return value;
        }
      }
    }
    return defaultValue;
  }

  Timestamp parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  void _showFilterDialog() {
    final primaryColor = Theme.of(context).primaryColor;
    final filterOptions = [
      'All',
      'Not Assigned',
      'Assigned',
      'Completed',
      'Canceled',
      'Others',
    ];

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
                        'Filter Service Tickets',
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
                    children: filterOptions.map((opt) {
                      final isSel = selectedFilter == opt;
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
                            selectedFilter = opt;
                          });
                          setState(() {
                            selectedFilter = opt;
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

  Widget _buildCustomerStreamBuilder(
    double screenWidth,
    double screenHeight,
    double Function(double) getProportionalSize,
  ) {
    // Modified query to order by bookingId in descending order
    Query query = FirestoreService.instance
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

          final bookingIdRaw = getField(data, ['bookingId'], '');
          final jobTypeRaw = getField(data, [
            'jobType',
            'JobType',
          ], '').toLowerCase().trim();

          final bool isDeliveryTicket = jobTypeRaw == 'delivery' || bookingIdRaw.toUpperCase().startsWith('D');
          final bool isServiceTicket = jobTypeRaw == 'service' || bookingIdRaw.toUpperCase().startsWith('S') || !isDeliveryTicket;

          // Ticket Type Segment Filter
          if (ticketTypeFilter == 'Service' && !isServiceTicket) {
            return false;
          }
          if (ticketTypeFilter == 'Delivery' && !isDeliveryTicket) {
            return false;
          }

          final engineerStatusRaw = getField(data, [
            'engineerStatus',
            'statusDescription',
          ], '').toLowerCase();
          final adminStatusRaw = getField(data, [
            'adminStatus',
          ], '').toLowerCase();
          final bookingId = bookingIdRaw.toLowerCase();
          final customerName = getField(data, [
            'customerName',
            'CustomerName',
          ], '').toLowerCase();
          final mobileNumber = getField(data, [
            'mobileNumber',
            'MobileNumber',
          ], '').toLowerCase();

          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            if (!bookingId.contains(query) &&
                !customerName.contains(query) &&
                !mobileNumber.contains(query)) {
              return false;
            }
          }

          // Check ticket status
          final isCanceled = adminStatusRaw == 'canceled';
          final isAppointment = adminStatusRaw == 'appointment';
          final isnotassigned =
              adminStatusRaw == 'Not Assigned' ||
              engineerStatusRaw == 'not assigned' &&
                  adminStatusRaw != 'canceled';
          final iscompleted = engineerStatusRaw == 'completed';
          final isassigned = engineerStatusRaw == 'Assigned'.toLowerCase();
          final isothers =
              engineerStatusRaw == 'Pending for Approval'.toLowerCase() ||
              engineerStatusRaw == 'Pending for Spares'.toLowerCase() ||
              engineerStatusRaw == 'Under Observation'.toLowerCase();

          switch (selectedFilter) {
            case 'Assigned':
              return isassigned;
            case 'Completed':
              return iscompleted;
            case 'Not Assigned':
              return isnotassigned;
            case 'Open':
              return engineerStatusRaw == selectedFilter.toLowerCase();
            case 'Canceled':
              return isCanceled;
            case 'Appointment':
              return isAppointment;
            case 'Others':
              return isothers;
            case 'All':
            default:
              return true;
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          IconData emptyIcon = Icons.inbox_rounded;
          String emptyTitle = 'No tickets found';
          String emptySubtitle = 'Service and delivery tickets will appear here.';

          if (ticketTypeFilter == 'Service') {
            emptyIcon = Icons.build_circle_outlined;
            emptyTitle = 'No service tickets found';
            emptySubtitle = 'Create a service ticket to get started.';
          } else if (ticketTypeFilter == 'Delivery') {
            emptyIcon = Icons.local_shipping_outlined;
            emptyTitle = 'No delivery tickets found';
            emptySubtitle = 'Create a delivery ticket to get started.';
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 48, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                Text(
                  emptyTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emptySubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
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
              bookingId: getField(data, ['bookingId']),
              customerName: getField(data, ['customerName', 'CustomerName']),
              deviceType: getField(data, ['deviceType', 'description']),
              deviceBrand: getField(data, ['deviceBrand']),
              deviceCondition: getField(data, ['deviceCondition']),
              message: getField(data, ['message', 'Message']),
              timestamp: parseTimestamp(data['timestamp']),
              address: getField(data, ['address', 'Address']),
              mobileNumber: getField(data, ['mobileNumber', 'MobileNumber']),
              jobType: getField(data, ['jobType', 'JobType']),
              amount: getField(data, ['amount']),
              customerid: getField(data, ['customerid', 'id', 'Id']),
              customerFileUrl: getField(data, ['customerFileUrl']),
              fileName: getField(data, ['fileName']),
            );
            String statusRaw = getField(data, [
              'engineerStatus',
              'statusDescription',
            ], '');
            final bool inferredCompleted = statusRaw.toLowerCase().contains(
              'complete',
            );
            final durationInfo = _buildDurationInfo(
              ticketData: data,
              isCompleted: inferredCompleted,
              createdTs: customer.timestamp,
            );
            final adminStatus = getField(data, ['adminStatus'], '');
            final isCanceled = adminStatus.toLowerCase() == 'canceled';
            final isAppointment = adminStatus.toLowerCase() == 'appointment';

            // Check if canceled by customer
            final customerDecision = getField(data, [
              'Customer_decision',
            ], '').toLowerCase();
            final isCanceledByCustomer =
                isCanceled && customerDecision == 'canceled';

            final status = statusRaw.isEmpty ? 'Not Assigned' : statusRaw;
            final displayStatus = isCanceled
                ? 'Canceled'
                : isAppointment
                ? 'Appointment'
                : status;

            final assignedEmployee = getField(data, [
              'assignedEmployee',
            ], 'Not Assigned');
            final bool isCompleted = status.toLowerCase().contains('complete');

            final double? customerLat = data['latitude'] != null
                ? (data['latitude'] as num).toDouble()
                : null;
            final double? customerLng = data['longitude'] != null
                ? (data['longitude'] as num).toDouble()
                : null;

            return _buildCustomerCard(
              customer,
              index + 1,
              displayStatus,
              assignedEmployee,
              isCompleted,
              isCanceled,
              isAppointment,
              isCanceledByCustomer,
              filteredDocs[index].id,
              screenWidth,
              screenHeight,
              getProportionalSize,
              durationInfo,
              customerLat,
              customerLng,
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(
    customer_var.Customer customer,
    int serialNumber,
    String status,
    String assignedEmployee,
    bool isCompleted,
    bool isCanceled,
    bool isAppointment,
    bool isCanceledByCustomer,
    String docId,
    double screenWidth,
    double screenHeight,
    double Function(double) getProportionalSize,
    Map<String, dynamic> durationInfo,
    double? customerLat,
    double? customerLng,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    Color getStatusColor(String status) {
      final s = status.toLowerCase().trim();
      if (s == 'assigned') return const Color(0xFF0984E3);
      if (s == 'completed' || s == 'complete' || s == 'delivered') return const Color(0xFF10B981);
      if (s == 'not assigned' || s == 'not assinged') return const Color(0xFFEF4444);
      if (s.contains('approval')) return const Color(0xFF8B5CF6);
      if (s.contains('spare')) return const Color(0xFFF59E0B);
      if (s.contains('observation')) return const Color(0xFF06B6D4);
      if (s == 'canceled' || s == 'cancelled') return const Color(0xFF64748B);
      if (s == 'appointment') return const Color(0xFFEC4899);
      return const Color(0xFF3B82F6);
    }

    final isAMC = customer.bookingId.toUpperCase().startsWith('AMC');
    final isDelivery = customer.jobType.toLowerCase().trim() == 'delivery' || customer.bookingId.toUpperCase().startsWith('D');
    final statusColor = getStatusColor(status);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return _buildTicketDetailSheet(
              context,
              customer,
              serialNumber,
              status,
              isCompleted,
              isCanceled,
              isAppointment,
              isCanceledByCustomer,
              assignedEmployee,
              docId,
              screenWidth,
              screenHeight,
              getProportionalSize,
              customerLat,
              customerLng,
            );
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isAMC ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isAMC ? 1.5 : 1,
          ),
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
                      color: isDelivery
                          ? const Color(0xFFECFDF5)
                          : isAMC
                          ? const Color(0xFFFFFBEB)
                          : statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isDelivery
                          ? Icons.local_shipping_rounded
                          : isAMC
                          ? Icons.star_rounded
                          : isCompleted
                          ? Icons.check_circle_rounded
                          : isCanceled
                          ? Icons.cancel_rounded
                          : isAppointment
                          ? Icons.calendar_today_rounded
                          : Icons.build_circle_rounded,
                      color: isDelivery
                          ? const Color(0xFF10B981)
                          : isAMC
                          ? const Color(0xFFF59E0B)
                          : statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            if (isAMC) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AMC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                        child: const Icon(Icons.laptop_mac_rounded, size: 14, color: Color(0xFF64748B)),
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
            if (isCanceledByCustomer)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This ticket was cancelled by ${customer.customerName}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildTicketDetailSheet(
    BuildContext context,
    customer_var.Customer customer,
    int serialNumber,
    String status,
    bool isCompleted,
    bool isCanceled,
    bool isAppointment,
    bool isCanceledByCustomer,
    String assignedEmployee,
    String docId,
    double screenWidth,
    double screenHeight,
    double Function(double) getProportionalSize,
    double? customerLat,
    double? customerLng,
  ) {
    final dt = customer.timestamp.toDate();
    final dateString = DateFormat('dd MMM yyyy').format(dt);
    final timeString = DateFormat('hh:mm a').format(dt);
    final displayStatus = isCanceled
        ? 'Canceled'
        : isAppointment
        ? 'Appointment'
        : isCompleted
        ? 'Completed'
        : status;

    final primaryColor = Theme.of(context).primaryColor;
    final isAMC = customer.bookingId.toUpperCase().startsWith('AMC');

    Color getStatusColor(String status) {
      final s = status.toLowerCase().trim();
      if (s == 'assigned') return const Color(0xFF0984E3);
      if (s == 'completed' || s == 'complete' || s == 'delivered') return const Color(0xFF10B981);
      if (s == 'not assigned' || s == 'not assinged') return const Color(0xFFEF4444);
      if (s.contains('approval')) return const Color(0xFF8B5CF6);
      if (s.contains('spare')) return const Color(0xFFF59E0B);
      if (s.contains('observation')) return const Color(0xFF06B6D4);
      if (s == 'canceled' || s == 'cancelled') return const Color(0xFF64748B);
      if (s == 'appointment') return const Color(0xFFEC4899);
      return const Color(0xFF3B82F6);
    }

    final statusColor = getStatusColor(displayStatus);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Sheet Handle Bar & Close Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt_long_rounded, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Ticket Details Workspace',
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
                    ],
                  ),
                ),

                const Divider(color: Color(0xFFF1F5F9), height: 1),

                // Sheet Content Body
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Customer & Booking Header Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isAMC
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAMC ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                              width: isAMC ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isAMC
                                      ? const Color(0xFFF59E0B)
                                      : statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isAMC
                                      ? Icons.star_rounded
                                      : isCompleted
                                      ? Icons.check_circle_rounded
                                      : isCanceled
                                      ? Icons.cancel_rounded
                                      : isAppointment
                                      ? Icons.calendar_today_rounded
                                      : Icons.build_circle_rounded,
                                  color: isAMC ? Colors.white : statusColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Booking ID: #${customer.bookingId}',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        if (isAMC) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'AMC',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Customer: ${customer.customerName}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  displayStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Special Status Banners
                        if (isCompleted && assignedEmployee.isNotEmpty && assignedEmployee != 'Not Assigned') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Service Completed',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                      Text(
                                        'Completed by $assignedEmployee',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (isCanceledByCustomer) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_rounded, color: Color(0xFFEF4444), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This service ticket was cancelled by ${customer.customerName}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Section: Device & Service Details Card
                        _buildSectionCard(
                          title: 'Service & Device Specifications',
                          icon: Icons.laptop_mac_rounded,
                          child: Column(
                            children: [
                              _buildDetailGridRow('Job Type', customer.jobType, isHighlight: true),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow('Device Type', customer.deviceType),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow('Device Brand', customer.deviceBrand),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow('Condition', customer.deviceCondition),
                              if (customer.message.isNotEmpty) ...[
                                const Divider(color: Color(0xFFF1F5F9), height: 16),
                                _buildDetailGridRow('Issue Description', customer.message),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Section: Customer & Address Information Card
                        _buildSectionCard(
                          title: 'Customer & Assignment Info',
                          icon: Icons.person_pin_rounded,
                          child: Column(
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: _getCustomerIdStream(customer),
                                builder: (context, snapshot) {
                                  String customerId = 'Not Found';
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final customerData = snapshot.data!.data() as Map<String, dynamic>?;
                                    if (customerData != null && customerData.containsKey('id')) {
                                      customerId = customerData['id'].toString();
                                    }
                                  }
                                  return _buildDetailGridRow('Customer ID', customerId);
                                },
                              ),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow('Contact Number', customer.mobileNumber.isNotEmpty ? customer.mobileNumber : 'N/A'),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow('Full Address', customer.address.isNotEmpty ? customer.address : 'N/A', isFullWidth: true),
                              const Divider(color: Color(0xFFF1F5F9), height: 16),
                              _buildDetailGridRow(
                                'Assigned Engineer',
                                assignedEmployee,
                                customValue: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      assignedEmployee,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: assignedEmployee != 'Not Assigned'
                                            ? const Color(0xFF0984E3)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    if (assignedEmployee.isNotEmpty && assignedEmployee != 'Not Assigned' && assignedEmployee != 'Unassigned') ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AdminGeoLocationScreen(
                                                engineerId: assignedEmployee,
                                                engineerName: assignedEmployee,
                                                bookingDocId: docId,
                                                customerLat: customerLat,
                                                customerLng: customerLng,
                                                customerAddress: customer.address,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0984E3).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.map_rounded, size: 12, color: Color(0xFF0984E3)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Live Track',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0984E3),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Section: Payment & Billing Card
                        _buildSectionCard(
                          title: 'Payment & Billing',
                          icon: Icons.payments_rounded,
                          child: Column(
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirestoreService.instance
                                    .collection('Admin_ticket_entry')
                                    .doc(customer.bookingId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  String paymentType = 'N/A';
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                                    if (data != null) {
                                      paymentType = getField(data, ['PaymentType', 'paymentType'], 'N/A');
                                    }
                                  }
                                  return _buildDetailGridRow('Payment Method', paymentType);
                                },
                              ),
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
                        ),

                        const SizedBox(height: 20),

                        // Optional Attachment Action
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
                                      content: const Text('Are you sure you want to reactivate this cancelled ticket?'),
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
                                      await FirestoreService.instance
                                          .collection('Admin_ticket_entry')
                                          .doc(docId)
                                          .update({
                                        'adminStatus': 'Open',
                                        'Customer_decision': '',
                                        'engineerStatus': 'Assigned',
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Ticket reactivated successfully!'),
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
                                            customerStatus: displayStatus,
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
                                        final docRef = FirestoreService.instance.collection('Admin_ticket_entry').doc(customer.bookingId);
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
                                      _navigateToAssignPage(customer);
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGridRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isFullWidth = false,
    Widget? customValue,
  }) {
    if (isFullWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          customValue ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                  color: isHighlight ? Theme.of(context).primaryColor : const Color(0xFF0F172A),
                  height: 1.4,
                ),
              ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: customValue ??
              Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                  color: isHighlight ? Theme.of(context).primaryColor : const Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        ),
      ],
    );
  }

  // Custom method for Job Type row with special handling
  Widget _buildJobTypeRow(
    String jobType,
    double Function(double) getProportionalSize,
  ) {
    // Handle "Service" and "N/A" values specifically
    String displayValue;
    TextStyle? valueStyle;

    if (jobType.toLowerCase() == 'service') {
      displayValue = 'Service';
      valueStyle = TextStyle(
        color: Colors.blue,
        fontSize: getProportionalSize(14),
        fontWeight: FontWeight.bold,
      );
    } else if (jobType.toLowerCase() == 'n/a' || jobType.isEmpty) {
      displayValue = 'N/A';
      valueStyle = TextStyle(
        color: Colors.grey,
        fontSize: getProportionalSize(14),
        fontStyle: FontStyle.italic,
      );
    } else {
      displayValue = jobType;
      valueStyle = TextStyle(
        color: Colors.black,
        fontSize: getProportionalSize(14),
        fontFamily: 'Arial',
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: getProportionalSize(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: getProportionalSize(100),
            child: Text(
              'Job Type',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: getProportionalSize(14),
                fontFamily: 'Arial',
              ),
            ),
          ),
          Text(': ', style: TextStyle(fontSize: getProportionalSize(14))),
          Expanded(child: Text(displayValue, style: valueStyle)),
        ],
      ),
    );
  }

  // Helper method to build helpers table with S.No
  Widget _buildHelpersTable(
    List<Map<String, String>> helperPairs,
    double Function(double) getProportionalSize,
  ) {
    return Column(
      children: [
        // Table Header
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B3470).withValues(alpha: 0.1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(getProportionalSize(8)),
              topRight: Radius.circular(getProportionalSize(8)),
            ),
            border: Border.all(
              color: const Color(0xFF0B3470).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // S.No Column Header
              Container(
                width: getProportionalSize(60),
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionalSize(8),
                  vertical: getProportionalSize(10),
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: const Color(0xFF0B3470).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'S.No',
                  style: TextStyle(
                    fontSize: getProportionalSize(14),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B3470),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Helper Column Header
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionalSize(12),
                    vertical: getProportionalSize(10),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: const Color(0xFF0B3470).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    'HELPER',
                    style: TextStyle(
                      fontSize: getProportionalSize(14),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B3470),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Reason Column Header
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionalSize(12),
                    vertical: getProportionalSize(10),
                  ),
                  child: Text(
                    'REASON',
                    style: TextStyle(
                      fontSize: getProportionalSize(14),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B3470),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table Rows
        ...helperPairs.asMap().entries.map((entry) {
          final index = entry.key;
          final pair = entry.value;
          final isLast = index == helperPairs.length - 1;
          final serialNumber = index + 1;

          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF0B3470).withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: isLast
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(getProportionalSize(8)),
                      bottomRight: Radius.circular(getProportionalSize(8)),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // S.No Cell
                Container(
                  width: getProportionalSize(60),
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionalSize(8),
                    vertical: getProportionalSize(10),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: const Color(0xFF0B3470).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    color: index.isEven ? Colors.white : Colors.grey[50],
                  ),
                  child: Text(
                    serialNumber.toString(),
                    style: TextStyle(
                      fontSize: getProportionalSize(14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0B3470),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Helper Cell
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionalSize(12),
                      vertical: getProportionalSize(10),
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: const Color(0xFF0B3470).withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      color: index.isEven ? Colors.white : Colors.grey[50],
                    ),
                    child: Text(
                      pair['helperName'] ?? 'Unknown Helper',
                      style: TextStyle(
                        fontSize: getProportionalSize(14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B3470),
                      ),
                    ),
                  ),
                ),
                // Reason Cell
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionalSize(12),
                      vertical: getProportionalSize(10),
                    ),
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    child: Text(
                      pair['reason'] ?? '—',
                      style: TextStyle(
                        fontSize: getProportionalSize(14),
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Helper method to extract and pair helper-reason data from document
  List<Map<String, String>> _extractHelperPairs(Map<String, dynamic> data) {
    final List<Map<String, String>> pairs = [];

    // Regular expression to match Helper1, Helper2, etc.
    final helperRegex = RegExp(r'^Helper(\d+)$');

    // Find all helper keys and sort them numerically
    final helperKeys =
        data.keys.where((key) => helperRegex.hasMatch(key)).toList()
          ..sort((a, b) {
            final aMatch = helperRegex.firstMatch(a);
            final bMatch = helperRegex.firstMatch(b);
            final aIndex = int.tryParse(aMatch?.group(1) ?? '0') ?? 0;
            final bIndex = int.tryParse(bMatch?.group(1) ?? '0') ?? 0;
            return aIndex.compareTo(bIndex);
          });

    // Pair each helper with its corresponding reason
    for (final helperKey in helperKeys) {
      final match = helperRegex.firstMatch(helperKey);
      if (match != null) {
        final index = match.group(1);
        final reasonKey = 'Helper${index}_Reason';

        final helperName = data[helperKey]?.toString() ?? 'Unknown Helper';
        final reason = data[reasonKey]?.toString() ?? '—';

        pairs.add({'helperName': helperName, 'reason': reason});
      }
    }

    return pairs;
  }

  Widget _ticketDetailRow(
    String label,
    String value,
    double Function(double) getProportionalSize, {
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: getProportionalSize(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: getProportionalSize(100),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: getProportionalSize(14),
                fontFamily: 'Arial',
              ),
            ),
          ),
          Text(': ', style: TextStyle(fontSize: getProportionalSize(14))),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  TextStyle(
                    color: Colors.black,
                    fontSize: getProportionalSize(14),
                    fontFamily: 'Arial',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get color for payment type
  Color _getPaymentTypeColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cash':
        return Colors.blue;
      case 'online':
        return Colors.purple;
      case 'card':
        return Colors.teal;
      default:
        return Colors.black;
    }
  }

  Color getStatusColor(String status) {
    final statusLower = status.toLowerCase().trim();
    if (statusLower == 'assigned' ||
        statusLower == 'completed' ||
        statusLower == 'complete' ||
        statusLower == 'delivered') {
      return Colors.green;
    }
    if (statusLower == 'not assigned' || statusLower == 'not assinged') {
      return Colors.red;
    }
    if (statusLower.contains('approval')) {
      return Colors.purple;
    }
    if (statusLower.contains('spare')) {
      return Colors.amber;
    }
    if (statusLower.contains('observation')) {
      return Colors.cyan;
    }
    if (statusLower == 'canceled' ||
        statusLower == 'cancelled' ||
        statusLower.contains('cancel')) {
      return Colors.grey;
    }
    if (statusLower.contains('appointment')) {
      return Colors.pink;
    }
    if (statusLower == 'open' ||
        statusLower == 'pending' ||
        statusLower.contains('progress')) {
      return Colors.orange;
    }
    return Colors.blueGrey;
  }

  void _navigateToAssignPage(customer_var.Customer customer) {
    final isDelivery = customer.jobType.toLowerCase().trim() == 'delivery' || customer.bookingId.toUpperCase().startsWith('D');
    if (isDelivery) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssigndeliveryCustomerPage(customer: customer),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssignEngineerPage(customer: customer),
        ),
      );
    }
  }
}
