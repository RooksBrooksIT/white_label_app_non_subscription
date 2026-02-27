import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_engineer_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart'
    as customer_var;

class AdminPage_CusDetails extends StatefulWidget {
  final customer_var.Customer? newCustomer;
  const AdminPage_CusDetails({
    super.key,
    this.newCustomer,
    required String statusFilter,
  });

  @override
  _AdminPage_CusDetailsState createState() => _AdminPage_CusDetailsState();
}

class _AdminPage_CusDetailsState extends State<AdminPage_CusDetails> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
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
      'bg': Theme.of(context).primaryColor.withOpacity(0.1),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Service Tickets ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: getProportionalSize(20),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.014),
              _buildSearchBar(screenWidth, getProportionalSize),
              SizedBox(height: screenHeight * 0.014),
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
      ),
    );
  }

  Widget _buildSearchBar(
    double screenWidth,
    double Function(double) getProportionalSize,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Container(
        height: getProportionalSize(48),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(getProportionalSize(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: getProportionalSize(10),
              offset: Offset(0, getProportionalSize(4)),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              searchQuery = value.trim();
            });
          },
          style: TextStyle(
            fontSize: getProportionalSize(15),
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
              size: getProportionalSize(24),
            ),
            hintText: 'Search Booking ID...',
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: getProportionalSize(14),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              vertical: getProportionalSize(14),
            ),
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
        if (value.toLowerCase() != 'n/a' && !value.contains('/')) {
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter Tickets',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 250,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                        value: 'Assigned',
                        child: Text('Assigned'),
                      ),
                      DropdownMenuItem(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'Not Assigned',
                        child: Text('Not Assigned'),
                      ),
                      // DropdownMenuItem(value: 'Open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'Canceled',
                        child: Text('Canceled'),
                      ),
                      DropdownMenuItem(
                        value: 'Appointment',
                        child: Text('Appointment'),
                      ),
                      DropdownMenuItem(value: 'Others', child: Text('Others')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedFilter = value ?? 'All';
                      });
                    },
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        setState(() {}); // refresh filtering
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Apply Filter',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedValue = Curves.easeInOut.transform(animation.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0, curvedValue * -250, 0),
          child: child,
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
        .collection('Admin_details')
        .orderBy('bookingId', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<DocumentSnapshot> docs = snapshot.data?.docs ?? [];

        List<DocumentSnapshot> filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;

          // Check if job type is "Service"
          final jobType = getField(data, [
            'jobType',
            'JobType',
          ], '').toLowerCase().trim();
          if (jobType != 'service') {
            return false; // Skip tickets that are not "Service"
          }

          final engineerStatusRaw = getField(data, [
            'engineerStatus',
            'statusDescription',
          ], '').toLowerCase();
          final adminStatusRaw = getField(data, [
            'adminStatus',
          ], '').toLowerCase();
          final bookingId = getField(data, ['bookingId'], '').toLowerCase();

          if (searchQuery.isNotEmpty &&
              !bookingId.contains(searchQuery.toLowerCase())) {
            return false;
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

          // engineerStatusRaw.isEmpty;

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
          return const Center(child: Text('No Service tickets found.'));
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => SizedBox(height: screenHeight * 0.015),
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

            final status = statusRaw.isEmpty ? 'Completed' : statusRaw;
            final displayStatus = isCanceled
                ? 'Canceled'
                : isAppointment
                ? 'Appointment'
                : status;

            final assignedEmployee = getField(data, [
              'assignedEmployee',
            ], 'Not Assigned');
            final bool isCompleted = status.toLowerCase().contains('complete');

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
  ) {
    // Local helper for status color
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
      if (statusLower == 'canceled' || statusLower == 'cancelled') {
        return Colors.grey;
      }
      if (statusLower == 'appointment') {
        return Colors.pink;
      }
      if (statusLower == 'open' ||
          statusLower == 'pending' ||
          statusLower.contains('progress')) {
        return Colors.orange;
      }
      return Colors.blueGrey;
    }

    // Check if this is an AMC customer
    final isAMC = customer.bookingId.toUpperCase().startsWith('AMC');
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
            );
          },
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: getProportionalSize(16)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(getProportionalSize(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: getProportionalSize(10),
              offset: Offset(0, getProportionalSize(4)),
            ),
          ],
          border: isAMC
              ? Border.all(color: const Color(0xFFFFD700), width: 1.5)
              : Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.014,
          horizontal: screenWidth * 0.032,
        ),
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.all(getProportionalSize(16)),
              child: Row(
                children: [
                  // Icon Box
                  Container(
                    width: getProportionalSize(48),
                    height: getProportionalSize(48),
                    decoration: BoxDecoration(
                      color: isAMC
                          ? const Color(0xFFFFF8E1)
                          : statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        getProportionalSize(12),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isAMC
                            ? Icons.star_rounded
                            : isCompleted
                            ? Icons.check_circle_outline
                            : isCanceled
                            ? Icons.cancel_outlined
                            : isAppointment
                            ? Icons.calendar_today_rounded
                            : Icons.build_circle_outlined,
                        color: isAMC ? const Color(0xFFFFD700) : statusColor,
                        size: getProportionalSize(24),
                      ),
                    ),
                  ),
                  SizedBox(width: getProportionalSize(12)),
                  // Titles
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.bookingId,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getProportionalSize(16),
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        SizedBox(height: getProportionalSize(4)),
                        Text(
                          customer.customerName,
                          style: TextStyle(
                            fontSize: getProportionalSize(14),
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status Chip
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionalSize(12),
                      vertical: getProportionalSize(6),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        getProportionalSize(20),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: getProportionalSize(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),

            // Details Section
            Padding(
              padding: EdgeInsets.all(getProportionalSize(16)),
              child: Column(
                children: [
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: getProportionalSize(16),
                        color: Theme.of(context).hintColor,
                      ),
                      SizedBox(width: getProportionalSize(10)),
                      Expanded(
                        child: Text(
                          customer.address,
                          style: TextStyle(
                            fontSize: getProportionalSize(13),
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getProportionalSize(8)),
                  // Mobile
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: getProportionalSize(16),
                        color: Theme.of(context).hintColor,
                      ),
                      SizedBox(width: getProportionalSize(10)),
                      Text(
                        customer.mobileNumber,
                        style: TextStyle(
                          fontSize: getProportionalSize(13),
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getProportionalSize(8)),
                  // Device
                  Row(
                    children: [
                      Icon(
                        Icons.devices_other,
                        size: getProportionalSize(16),
                        color: Theme.of(context).hintColor,
                      ),
                      SizedBox(width: getProportionalSize(10)),
                      Text(
                        '${customer.deviceBrand} - ${customer.deviceType}',
                        style: TextStyle(
                          fontSize: getProportionalSize(13),
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  if (assignedEmployee != 'Not Assigned') ...[
                    SizedBox(height: getProportionalSize(8)),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: getProportionalSize(16),
                          color: Theme.of(context).hintColor,
                        ),
                        SizedBox(width: getProportionalSize(10)),
                        Text(
                          'Assigned to: $assignedEmployee',
                          style: TextStyle(
                            fontSize: getProportionalSize(13),
                            color: const Color(0xFF2196F3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Replaced Footer logic with new footer
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionalSize(16),
                vertical: getProportionalSize(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: getProportionalSize(14),
                    color: Theme.of(context).hintColor,
                  ),
                  SizedBox(width: getProportionalSize(6)),
                  Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(customer.timestamp.toDate()),
                    style: TextStyle(
                      fontSize: getProportionalSize(12),
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (!isCanceled) ...[
                    Icon(
                      Icons.access_time,
                      size: getProportionalSize(14),
                      color:
                          (durationInfo['color'] as Color?) ??
                          Theme.of(context).primaryColor,
                    ),
                    SizedBox(width: getProportionalSize(6)),
                    Text(
                      (durationInfo['label'] as String?) ?? '',
                      style: TextStyle(
                        fontSize: getProportionalSize(12),
                        color:
                            (durationInfo['color'] as Color?) ??
                            Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Customer cancellation message
            if (isCanceledByCustomer)
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.01),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(getProportionalSize(8)),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: getProportionalSize(16),
                      ),
                      SizedBox(width: screenWidth * 0.015),
                      Expanded(
                        child: Text(
                          'This ticket was cancelled by ${customer.customerName}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: getProportionalSize(12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Duration container (working days)
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
  ) {
    final dt = customer.timestamp.toDate();
    final dateString = DateFormat('dd/MM/yyyy').format(dt);
    final timeString = DateFormat('HH : mm').format(dt);
    final displayStatus = isCanceled
        ? 'Canceled'
        : isAppointment
        ? 'Appointment'
        : isCompleted
        ? 'Completed'
        : status;

    // Check if this is an AMC customer
    final isAMC = customer.bookingId.toUpperCase().startsWith('AMC');

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: isCanceledByCustomer ? 0.68 : 0.64,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, controller) {
          return Container(
            padding: EdgeInsets.only(top: screenHeight * 0.025),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(getProportionalSize(24)),
                topRight: Radius.circular(getProportionalSize(24)),
              ),
            ),
            child: SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: EdgeInsets.only(
                  left: screenWidth * 0.045,
                  right: screenWidth * 0.045,
                  bottom: screenHeight * 0.02,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCanceled
                        ? Theme.of(context).disabledColor.withOpacity(0.1)
                        : isAppointment
                        ? Color(0xFFFFF9C4)
                        : isAMC
                        ? Color(0xFFFFF8E1)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(
                      getProportionalSize(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: getProportionalSize(6),
                        offset: Offset(
                          getProportionalSize(2),
                          getProportionalSize(4),
                        ),
                      ),
                    ],
                    border: isAMC
                        ? Border.all(color: Color(0xFFFFD700), width: 2)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.06,
                          screenHeight * 0.024,
                          screenWidth * 0.04,
                          0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: screenWidth * 0.14,
                              height: screenWidth * 0.14,
                              decoration: BoxDecoration(
                                color: isCanceled
                                    ? Colors.grey
                                    : isAppointment
                                    ? Colors.amber
                                    : isAMC
                                    ? Color(0xFFFFD700)
                                    : isCompleted
                                    ? Colors.green
                                    : Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.07,
                                ),
                              ),
                              child: Center(
                                child: isCanceled
                                    ? Icon(
                                        Icons.cancel,
                                        color: Colors.white,
                                        size: getProportionalSize(24),
                                      )
                                    : isAppointment
                                    ? Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: getProportionalSize(24),
                                      )
                                    : isAMC
                                    ? Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: getProportionalSize(24),
                                      )
                                    : isCompleted
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: getProportionalSize(24),
                                      )
                                    : Text(
                                        serialNumber.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: getProportionalSize(24),
                                          fontFamily: 'Arial',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.05),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Booking ID row
                                  Row(
                                    children: [
                                      Text(
                                        'Booking ID',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Text(
                                        ' : ',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          customer.bookingId,
                                          style: TextStyle(
                                            color: isAMC
                                                ? Color(0xFFFFD700)
                                                : Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: getProportionalSize(14),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.02),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.022,
                                          vertical: screenHeight * 0.003,
                                        ),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(status),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Text(
                                          displayStatus,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: getProportionalSize(13),
                                            fontFamily: 'Arial',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.004),
                                  // Customer row
                                  Row(
                                    children: [
                                      Text(
                                        'Customer',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Text(
                                        ' : ',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          customer.customerName,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: getProportionalSize(14),
                                            fontWeight: FontWeight.w400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: getProportionalSize(4)),
                                  // Customers ID row - FIXED: Safe document reference
                                  Row(
                                    children: [
                                      Text(
                                        'Customer ID',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Text(
                                        ' : ',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Expanded(
                                        child: StreamBuilder<DocumentSnapshot>(
                                          stream: _getCustomerIdStream(
                                            customer,
                                          ),
                                          builder: (context, snapshot) {
                                            String customerId = 'Not Found';

                                            if (snapshot.hasData &&
                                                snapshot.data!.exists) {
                                              final customerData =
                                                  snapshot.data!.data()
                                                      as Map<String, dynamic>?;
                                              if (customerData != null &&
                                                  customerData.containsKey(
                                                    'id',
                                                  )) {
                                                customerId = customerData['id']
                                                    .toString();
                                              }
                                            }

                                            return Text(
                                              customerId,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.color,
                                                fontSize: getProportionalSize(
                                                  14,
                                                ),
                                                fontWeight: FontWeight.w400,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: getProportionalSize(4)),
                                  // Job Type row
                                  Row(
                                    children: [
                                      Text(
                                        'Job Type',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Text(
                                        ' : ',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Service',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontSize: getProportionalSize(14),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: getProportionalSize(4)),
                                  // Assigned Engineer row
                                  Row(
                                    children: [
                                      Text(
                                        'Assigned Engineer',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Text(
                                        ' : ',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                assignedEmployee,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  fontSize: getProportionalSize(
                                                    14,
                                                  ),
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (assignedEmployee.isNotEmpty &&
                                                assignedEmployee !=
                                                    'Unassigned')
                                              TextButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          AdminGeoLocationScreen(
                                                            engineerId:
                                                                assignedEmployee,
                                                            engineerName:
                                                                assignedEmployee,
                                                            bookingDocId: docId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.map_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Live Track',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Customer cancellation message in detail sheet
                      if (isCanceledByCustomer)
                        Padding(
                          padding: EdgeInsets.only(
                            top: screenHeight * 0.015,
                            left: screenWidth * 0.06,
                            right: screenWidth * 0.06,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.012,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(
                                getProportionalSize(8),
                              ),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: Theme.of(context).colorScheme.error,
                                  size: getProportionalSize(20),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cancelled by Customer',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: getProportionalSize(14),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: getProportionalSize(2)),
                                      Text(
                                        'This ticket was cancelled by ${customer.customerName}',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: getProportionalSize(12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // AMC Badge if applicable
                      if (isAMC)
                        Padding(
                          padding: EdgeInsets.only(
                            top: screenHeight * 0.01,
                            left: screenWidth * 0.06,
                            right: screenWidth * 0.06,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.008,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFD700).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Color(0xFFFFD700),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Color(0xFFFFD700),
                                  size: getProportionalSize(16),
                                ),
                                SizedBox(width: getProportionalSize(8)),
                                Text(
                                  'AMC Customer',
                                  style: TextStyle(
                                    color: Color(0xFFB8860B),
                                    fontSize: getProportionalSize(14),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: screenWidth * 0.06,
                          right: screenWidth * 0.04,
                          top: screenHeight * 0.016,
                        ),
                        child: Column(
                          children: [
                            _buildJobTypeRow(
                              customer.jobType,
                              getProportionalSize,
                            ),
                            _ticketDetailRow(
                              'Device',
                              customer.deviceType,
                              getProportionalSize,
                            ),
                            _ticketDetailRow(
                              'Brand',
                              customer.deviceBrand,
                              getProportionalSize,
                            ),
                            _ticketDetailRow(
                              'Condition',
                              customer.deviceCondition,
                              getProportionalSize,
                            ),
                            _ticketDetailRow(
                              'Message',
                              customer.message,
                              getProportionalSize,
                            ),
                            _ticketDetailRow(
                              'Created date',
                              dateString,
                              getProportionalSize,
                            ),
                            // Payment Type field
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirestoreService.instance
                                  .collection('Admin_details')
                                  .doc(customer.bookingId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                String paymentType = 'N/A';

                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final data =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                  if (data != null) {
                                    paymentType = getField(data, [
                                      'PaymentType',
                                      'paymentType',
                                    ], 'N/A');
                                  }
                                }

                                return _ticketDetailRow(
                                  'Payment Type',
                                  paymentType,
                                  getProportionalSize,
                                  valueStyle: TextStyle(
                                    color: _getPaymentTypeColor(paymentType),
                                    fontSize: getProportionalSize(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                            _ticketDetailRow(
                              'Bill Amount',
                              '₹ ${customer.amount}',
                              getProportionalSize,
                              valueStyle: TextStyle(
                                color: Colors.green,
                                fontSize: getProportionalSize(18),
                                fontFamily: 'Times New Roman',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: screenHeight * 0.033,
                        thickness: 1,
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.06,
                          vertical: screenHeight * 0.003,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.075,
                                        child: Icon(
                                          Icons.location_on,
                                          color: Theme.of(context).primaryColor,
                                          size: getProportionalSize(22),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.016),
                                      Expanded(
                                        child: Text(
                                          customer.address,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: getProportionalSize(14),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.075,
                                        child: Icon(
                                          Icons.phone,
                                          color: Theme.of(context).primaryColor,
                                          size: getProportionalSize(22),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.016),
                                      Flexible(
                                        child: Text(
                                          customer.mobileNumber,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: getProportionalSize(14),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.075,
                                        child: Icon(
                                          Icons.calendar_today,
                                          color: Theme.of(context).primaryColor,
                                          size: getProportionalSize(20),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.016),
                                      Text(
                                        dateString,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.075,
                                        child: Icon(
                                          Icons.access_time,
                                          color: Theme.of(context).primaryColor,
                                          size: getProportionalSize(20),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.016),
                                      Text(
                                        timeString,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: getProportionalSize(14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action buttons logic
                      if (!isCompleted) ...[
                        // For cancelled tickets - show reactivate button
                        if (isCanceled)
                          Padding(
                            padding: EdgeInsets.only(
                              right: screenWidth * 0.06,
                              top: screenHeight * 0.022,
                              bottom: screenHeight * 0.013,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.green,
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    shape:
                                        WidgetStateProperty.all<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              getProportionalSize(4),
                                            ),
                                          ),
                                        ),
                                    padding:
                                        WidgetStateProperty.all<EdgeInsets>(
                                          EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.013,
                                          ),
                                        ),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Reactivate Ticket'),
                                        content: const Text(
                                          'Are you sure you want to reactivate this cancelled ticket?',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Keep Cancelled'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text(
                                              'Reactivate',
                                              style: TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await FirestoreService.instance
                                            .collection('Admin_details')
                                            .doc(docId)
                                            .update({
                                              'adminStatus': 'Open',
                                              'Customer_decision': '',
                                              'engineerStatus': 'Assigned',
                                            });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Ticket reactivated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        Navigator.pop(context);
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to reactivate ticket: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(
                                    'REACTIVATE TICKET',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(13),
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        // For Appointment tickets - show different buttons
                        else if (isAppointment)
                          Padding(
                            padding: EdgeInsets.only(
                              right: screenWidth * 0.06,
                              top: screenHeight * 0.022,
                              bottom: screenHeight * 0.013,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // ASSIGN Button for Appointment tickets
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          const Color(0xFF0B3470),
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    shape:
                                        WidgetStateProperty.all<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              getProportionalSize(4),
                                            ),
                                          ),
                                        ),
                                    padding:
                                        WidgetStateProperty.all<EdgeInsets>(
                                          EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.07,
                                            vertical: screenHeight * 0.013,
                                          ),
                                        ),
                                  ),
                                  onPressed: () async {
                                    try {
                                      final docRef = FirestoreService.instance
                                          .collection('Admin_details')
                                          .doc(customer.bookingId);
                                      final docSnapshot = await docRef.get();
                                      if (docSnapshot.exists) {
                                        final data = docSnapshot.data() ?? {};
                                        Map<String, dynamic> updateData = {
                                          'adminStatus': 'Assigned',
                                        };
                                        if (!data.containsKey(
                                          'engineerStatus',
                                        )) {
                                          updateData['engineerStatus'] = 'Open';
                                        }
                                        await docRef.update(updateData);
                                      } else {
                                        await docRef.set({
                                          'adminStatus': 'Assigned',
                                          'engineerStatus': 'Open',
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to update status: $e',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);
                                    _navigateToAssignPage(customer);
                                  },
                                  child: Text(
                                    'ASSIGN',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(13),
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.46,
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                // MARK AS ACTIVE Button - to remove appointment status
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.green,
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    shape:
                                        WidgetStateProperty.all<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              getProportionalSize(4),
                                            ),
                                          ),
                                        ),
                                    padding:
                                        WidgetStateProperty.all<EdgeInsets>(
                                          EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.013,
                                          ),
                                        ),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Mark as Active'),
                                        content: const Text(
                                          'Remove appointment status and mark this ticket as active?',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text(
                                              'Keep Appointment',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text(
                                              'Mark Active',
                                              style: TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await FirestoreService.instance
                                            .collection('Admin_details')
                                            .doc(docId)
                                            .update({'adminStatus': 'Open'});

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Ticket marked as active!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        Navigator.pop(context);
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to update ticket: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(
                                    'MARK ACTIVE',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(13),
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // For regular active tickets (not appointment, not canceled, not completed)
                          Padding(
                            padding: EdgeInsets.only(
                              right: screenWidth * 0.06,
                              top: screenHeight * 0.022,
                              bottom: screenHeight * 0.013,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // APPOINTMENT Button for active tickets
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.purple,
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    shape:
                                        WidgetStateProperty.all<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              getProportionalSize(4),
                                            ),
                                          ),
                                        ),
                                    padding:
                                        WidgetStateProperty.all<EdgeInsets>(
                                          EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.013,
                                          ),
                                        ),
                                  ),
                                  onPressed: () async {
                                    // Show appointment confirmation dialog
                                    final confirmAppointment =
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Schedule Appointment',
                                            ),
                                            content: const Text(
                                              'Set this ticket as Appointment status? This will mark it for scheduled service.',
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text('Later'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text(
                                                  'Schedule Appointment',
                                                  style: TextStyle(
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                    if (confirmAppointment == true) {
                                      try {
                                        // Update Firestore with appointment status
                                        await FirestoreService.instance
                                            .collection('Admin_details')
                                            .doc(docId)
                                            .update({
                                              'adminStatus': 'Appointment',
                                              'appointmentDate':
                                                  FieldValue.serverTimestamp(),
                                            });

                                        // Show success message
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Appointment scheduled successfully!',
                                            ),
                                            backgroundColor: Colors.purple,
                                          ),
                                        );

                                        // Close the bottom sheet
                                        Navigator.pop(context);
                                      } catch (e) {
                                        // Show error message
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to schedule appointment: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(
                                    'APPOINTMENT',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(13),
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.46,
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                // ASSIGN Button for active tickets
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          const Color(0xFF0B3470),
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Colors.white,
                                        ),
                                    shape:
                                        WidgetStateProperty.all<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              getProportionalSize(4),
                                            ),
                                          ),
                                        ),
                                    padding:
                                        WidgetStateProperty.all<EdgeInsets>(
                                          EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.07,
                                            vertical: screenHeight * 0.013,
                                          ),
                                        ),
                                  ),
                                  onPressed: () async {
                                    try {
                                      final docRef = FirestoreService.instance
                                          .collection('Admin_details')
                                          .doc(customer.bookingId);
                                      final docSnapshot = await docRef.get();
                                      if (docSnapshot.exists) {
                                        final data = docSnapshot.data() ?? {};
                                        Map<String, dynamic> updateData = {
                                          'adminStatus': 'Assigned',
                                        };
                                        if (!data.containsKey(
                                          'engineerStatus',
                                        )) {
                                          updateData['engineerStatus'] = 'Open';
                                        }
                                        await docRef.update(updateData);
                                      } else {
                                        await docRef.set({
                                          'adminStatus': 'Assigned',
                                          'engineerStatus': 'Open',
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to update status: $e',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);
                                    _navigateToAssignPage(customer);
                                  },
                                  child: Text(
                                    'ASSIGN',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(13),
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.46,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // CANCEL TICKET button (available for both active and appointment tickets)
                      // Hide cancel button if already canceled by customer
                      if (!isCanceled && !isCompleted)
                        Padding(
                          padding: EdgeInsets.only(
                            right: screenWidth * 0.06,
                            left: screenWidth * 0.06,
                            bottom: screenHeight * 0.03,
                          ),
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all<Color>(
                                Colors.orange,
                              ),
                              foregroundColor: WidgetStateProperty.all<Color>(
                                Colors.white,
                              ),
                              shape:
                                  WidgetStateProperty.all<
                                    RoundedRectangleBorder
                                  >(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        getProportionalSize(4),
                                      ),
                                    ),
                                  ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.07,
                                  vertical: screenHeight * 0.013,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Cancel'),
                                  content: const Text(
                                    'Are you sure you want to cancel this ticket? This action cannot be undone.',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Yes, Cancel',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await FirestoreService.instance
                                      .collection('Admin_details')
                                      .doc(docId)
                                      .update({'adminStatus': 'Canceled'});
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ticket canceled successfully.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to cancel ticket: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'CANCEL TICKET',
                              style: TextStyle(
                                fontSize: getProportionalSize(13),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Show completed message if ticket is completed
                      if (isCompleted)
                        Padding(
                          padding: EdgeInsets.only(
                            top: screenHeight * 0.015,
                            bottom: screenHeight * 0.02,
                          ),
                          child: Center(
                            child: Text(
                              'This ticket has been completed',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: getProportionalSize(16),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Customer feedback card (always visible)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.06,
                          vertical: screenHeight * 0.02,
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              getProportionalSize(12),
                            ),
                          ),
                          shadowColor: Colors.black26,
                          child: Padding(
                            padding: EdgeInsets.all(getProportionalSize(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: EdgeInsets.only(
                                    bottom: getProportionalSize(8),
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color(0xFF0B3470),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Customer feedback',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(20),
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0B3470),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: getProportionalSize(12)),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirestoreService.instance
                                      .collection('Admin_details')
                                      .doc(customer.bookingId)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: SizedBox(
                                          width: getProportionalSize(24),
                                          height: getProportionalSize(24),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        !snapshot.data!.exists) {
                                      return Text(
                                        'No feedback available.',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(16),
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }
                                    Map<String, dynamic>? data =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>?;
                                    String feedback =
                                        data != null &&
                                            data.containsKey('feedback') &&
                                            data['feedback'] != null
                                        ? data['feedback'].toString()
                                        : 'No feedback available.';
                                    return Text(
                                      feedback,
                                      style: TextStyle(
                                        fontSize: getProportionalSize(16),
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Helpers card with table layout including S.No (always visible)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.06,
                          vertical: screenHeight * 0.02,
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              getProportionalSize(12),
                            ),
                          ),
                          shadowColor: Colors.black26,
                          child: Padding(
                            padding: EdgeInsets.all(getProportionalSize(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: EdgeInsets.only(
                                    bottom: getProportionalSize(8),
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color(0xFF0B3470),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Assigned Helpers',
                                    style: TextStyle(
                                      fontSize: getProportionalSize(20),
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0B3470),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: getProportionalSize(12)),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirestoreService.instance
                                      .collection('Admin_details')
                                      .doc(customer.bookingId)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: SizedBox(
                                          width: getProportionalSize(24),
                                          height: getProportionalSize(24),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      );
                                    }

                                    if (!snapshot.hasData ||
                                        !snapshot.data!.exists) {
                                      return Text(
                                        'No helpers assigned.',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(16),
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }

                                    Map<String, dynamic>? data =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>?;

                                    if (data == null) {
                                      return Text(
                                        'No helpers assigned.',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(16),
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }

                                    // Extract and pair helper-reason data
                                    final helperPairs = _extractHelperPairs(
                                      data,
                                    );

                                    if (helperPairs.isEmpty) {
                                      return Text(
                                        'No helpers assigned.',
                                        style: TextStyle(
                                          fontSize: getProportionalSize(16),
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }

                                    return _buildHelpersTable(
                                      helperPairs,
                                      getProportionalSize,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                color: Colors.black.withOpacity(0.5),
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
            color: const Color(0xFF0B3470).withOpacity(0.1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(getProportionalSize(8)),
              topRight: Radius.circular(getProportionalSize(8)),
            ),
            border: Border.all(
              color: const Color(0xFF0B3470).withOpacity(0.3),
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
                      color: const Color(0xFF0B3470).withOpacity(0.3),
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
                        color: const Color(0xFF0B3470).withOpacity(0.3),
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
                color: const Color(0xFF0B3470).withOpacity(0.2),
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
                        color: const Color(0xFF0B3470).withOpacity(0.2),
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
                          color: const Color(0xFF0B3470).withOpacity(0.2),
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
                color: Colors.black.withOpacity(0.5),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignEngineerPage(customer: customer),
      ),
    );
  }
}
