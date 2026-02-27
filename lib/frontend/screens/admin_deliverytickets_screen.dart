import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assigndelivery_page.dart';
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
  final Map<String, String> _deliveryStatusMap = {};
  final Map<String, bool> _isTicketCanceled = {};
  final Map<String, String> _customerCancelInfo = {};

  // Filter variables
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    // 'Appointment',
    'Assigned',
    'Delivered',
    'Out of Stock',
    'Canceled',
    'Not Assigned',
    'Others',
  ];

  // Define valid dropdown values as constants to avoid duplication
  static const String _selectStatusValue = 'Not Assigned';
  // static const String _appointmentValue = 'Appointment';
  static const String _deliveredValue = 'Delivered';
  static const String _outOfStockValue = 'Out of Stock';

  final List<String> _validDropdownValues = [
    _selectStatusValue,
    // _appointmentValue,
    _deliveredValue,
    _outOfStockValue,
  ];

  @override
  void initState() {
    super.initState();
    _initializeDeliveryStatusMap();
  }

  Future<void> _initializeDeliveryStatusMap() async {
    try {
      final snapshot = await _firestore.collection('Admin_details').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final adminStatus = _getField(data, ['adminStatus'], '');
        final customerDecision = _getField(data, ['Customer_decision'], '');

        // Normalize the status to match dropdown values exactly
        String normalizedStatus;
        if (adminStatus == _deliveredValue || adminStatus == _outOfStockValue
        // ||adminStatus == _appointmentValue
        ) {
          normalizedStatus = adminStatus;
        } else {
          normalizedStatus = _selectStatusValue;
        }

        _deliveryStatusMap[doc.id] = normalizedStatus;

        // Initialize canceled status
        _isTicketCanceled[doc.id] = adminStatus == 'Canceled';

        // Store customer cancellation information
        if (customerDecision == "Canceled") {
          final customerName = _getField(data, [
            'customerName',
            'CustomerName',
          ], 'Customer');
          _customerCancelInfo[doc.id] = customerName;
        }
      }
      setState(() {});
    } catch (e) {
      print('Error initializing delivery status map: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Delivery Tickets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            fontSize: screenWidth * 0.05,
          ),
        ),

        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.04),
            child: _buildFilterButton(screenWidth),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.014),
              _buildSearchBar(screenWidth),
              if (_selectedFilter != 'All') _buildActiveFilterChip(screenWidth),
              SizedBox(height: screenHeight * 0.014),
              Expanded(
                child: _buildDeliveryStreamBuilder(screenWidth, screenHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(double screenWidth) {
    return IconButton(
      icon: Stack(
        children: [
          Icon(
            Icons.filter_list,
            color: Theme.of(context).iconTheme.color,
            size: screenWidth * 0.064,
          ),
          if (_selectedFilter != 'All')
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.005),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: screenWidth * 0.032,
                  minHeight: screenWidth * 0.032,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        _showFilterBottomSheet(screenWidth);
      },
    );
  }

  Widget _buildActiveFilterChip(double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Row(
        children: [
          Text(
            'Filter: ',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: screenWidth * 0.037,
              fontWeight: FontWeight.w500,
            ),
          ),
          Chip(
            label: Text(
              _selectedFilter,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.032,
              ),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            deleteIcon: Icon(
              Icons.close,
              size: screenWidth * 0.042,
              color: Colors.white,
            ),
            onDeleted: () {
              setState(() {
                _selectedFilter = 'All';
              });
            },
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(double screenWidth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Added to prevent overflow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth * 0.053),
        ),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(screenWidth * 0.053),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: screenWidth * 0.15,
                  height: screenWidth * 0.012,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(screenWidth * 0.01),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.032), // Reduced spacing
              Text(
                'Filter Delivery Tickets',
                style: TextStyle(
                  fontSize: screenWidth * 0.044, // Slightly smaller
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: screenWidth * 0.032), // Reduced spacing
              // Filter options with reduced height
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _filterOptions.map((filter) {
                      return SizedBox(
                        height: screenWidth * 0.12, // Fixed height
                        child: ListTile(
                          dense: true, // Reduced height
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02,
                          ),
                          leading: Icon(
                            _getFilterIcon(filter),
                            color: _selectedFilter == filter
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                            size: screenWidth * 0.055, // Smaller icons
                          ),
                          title: Text(
                            filter,
                            style: TextStyle(
                              fontWeight: _selectedFilter == filter
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedFilter == filter
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                              fontSize: screenWidth * 0.038, // Smaller font
                            ),
                          ),
                          trailing: _selectedFilter == filter
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).primaryColor,
                                  size: screenWidth * 0.055, // Smaller icons
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedFilter = filter;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              SizedBox(height: screenWidth * 0.032), // Reduced spacing
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = 'All';
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.026, // Reduced padding
                        ),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      child: Text(
                        'Clear Filter',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: screenWidth * 0.038, // Smaller font
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.026), // Reduced spacing
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.026, // Reduced padding
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: screenWidth * 0.038, // Smaller font
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        );
      },
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.all_inclusive;
      // case 'Appointment':
      //   return Icons.calendar_today;
      case 'Assigned':
        return Icons.engineering;
      case 'Delivered':
        return Icons.check_circle;
      case 'Out of Stock':
        return Icons.inventory_2;
      case 'Canceled':
        return Icons.cancel;
      case 'Not Assigned':
        return Icons.person_off;
      case 'Others':
        return Icons.more_horiz;
      default:
        return Icons.filter_list;
    }
  }

  Widget _buildSearchBar(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Container(
        height: screenWidth * 0.117,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.032),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: screenWidth * 0.016,
              offset: Offset(0, screenWidth * 0.01),
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
          style: TextStyle(
            fontSize: screenWidth * 0.037,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
            fontFamily: 'Arial',
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).primaryColor,
              size: screenWidth * 0.058,
            ),
            hintText: 'Search by Booking ID',
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w700,
              fontSize: screenWidth * 0.034,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: screenWidth * 0.034),
          ),
        ),
      ),
    );
  }

  String _getField(
    Map<String, dynamic> data,
    List<String> keys, [
    String defaultValue = 'N/A',
  ]) {
    for (final key in keys) {
      if (data.containsKey(key) &&
          data[key] != null &&
          data[key].toString().trim().isNotEmpty) {
        return data[key].toString();
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

  Widget _buildDeliveryStreamBuilder(double screenWidth, double screenHeight) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Admin_details').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.04,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No delivery tickets found.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.042,
              ),
            ),
          );
        }

        List<DocumentSnapshot> docs = snapshot.data!.docs;
        List<DocumentSnapshot> filteredDocs = _filterDeliveryTickets(docs);

        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aBookingId = _getField(aData, ['bookingId'], '');
          final bBookingId = _getField(bData, ['bookingId'], '');
          return bBookingId.compareTo(aBookingId);
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No matching delivery tickets found.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.042,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => SizedBox(height: screenHeight * 0.015),
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            return _buildDeliveryCard(
              data,
              filteredDocs[index].id,
              index + 1,
              screenWidth,
              screenHeight,
            );
          },
        );
      },
    );
  }

  List<DocumentSnapshot> _filterDeliveryTickets(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final jobType = _getField(data, ['jobType', 'JobType'], '').toLowerCase();
      if (!jobType.contains('delivery')) return false;

      final bookingId = _getField(data, ['bookingId'], '').toLowerCase();
      if (searchQuery.isNotEmpty &&
          !bookingId.contains(searchQuery.toLowerCase())) {
        return false;
      }

      if (_selectedFilter != 'All') {
        final engineerStatus = _getField(data, [
          'engineerStatus',
          'statusDescription',
        ], '').toLowerCase();
        final adminStatus = _getField(data, ['adminStatus'], '').toLowerCase();
        final assignedEmployee = _getField(data, ['assignedEmployee'], '');
        final customerDecision = _getField(data, [
          'Customer_decision',
        ], '').toLowerCase();

        switch (_selectedFilter) {
          // case 'Appointment':
          //   if (engineerStatus != 'appointment' &&
          //       adminStatus != 'appointment') {
          //     return false;
          //   }
          //   break;
          case 'Assigned':
            if (engineerStatus != 'Assigned'.toLowerCase()) {
              return false;
            }
            break;
          case 'Delivered':
            if (engineerStatus != 'delivered' && adminStatus != 'delivered') {
              return false;
            }
            break;
          case 'Out of Stock':
            if (adminStatus != 'out of stock') {
              return false;
            }
            break;
          case 'Canceled':
            if (adminStatus != 'canceled' &&
                engineerStatus != 'canceled' &&
                customerDecision != 'canceled') {
              return false;
            }
            break;
          case 'Not Assigned':
            if (assignedEmployee != 'Not Assigned' &&
                    assignedEmployee == 'canceled' ||
                assignedEmployee.isNotEmpty) {
              return false;
            }
            break;
          case 'Others':
            if (!(engineerStatus == 'Pending for Approval'.toLowerCase() ||
                engineerStatus == 'Pending for Spares'.toLowerCase() ||
                engineerStatus == 'Under Observation'.toLowerCase())) {
              return false;
            }
            break;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildDeliveryCard(
    Map<String, dynamic> data,
    String docId,
    int serialNumber,
    double screenWidth,
    double screenHeight,
  ) {
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
      customerid: _getField(data, ['id', 'Id', 'customerid']),
    );

    final statusInfo = _getStatusInfo(data);
    final assignedEmployee = _getField(data, [
      'assignedEmployee',
    ], 'Not Assigned');
    final currentAdminStatus = _getField(data, ['adminStatus'], '');
    final isCanceled = _isTicketCanceled[docId] ?? false;
    final isDelivered = currentAdminStatus == 'Delivered';

    final customerDecision = _getField(data, ['Customer_decision'], '');
    final isCanceledByCustomer = customerDecision == "Canceled";
    final customerName = _getField(data, [
      'customerName',
      'CustomerName',
    ], 'Customer');

    return GestureDetector(
      onTap: () {
        _showDeliveryDetailSheet(
          context,
          customer,
          serialNumber,
          statusInfo,
          assignedEmployee,
          docId,
          screenWidth,
          screenHeight,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: statusInfo.backgroundColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.032),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: screenWidth * 0.016,
              offset: Offset(screenWidth * 0.005, screenWidth * 0.01),
            ),
          ],
          border: statusInfo.hasBorder
              ? Border.all(color: statusInfo.borderColor!, width: 2)
              : null,
        ),
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.014,
          horizontal: screenWidth * 0.032,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: screenWidth * 0.14,
                  height: screenWidth * 0.14,
                  decoration: BoxDecoration(
                    color: statusInfo.iconColor,
                    borderRadius: BorderRadius.circular(screenWidth * 0.07),
                  ),
                  child: Center(
                    child:
                        statusInfo.icon ??
                        Text(
                          serialNumber.toString(),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: screenWidth * 0.064,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.034),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Booking ID',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: screenWidth * 0.037,
                              fontFamily: 'Arial',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            ' : ',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: screenWidth * 0.037,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              customer.bookingId,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.037,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.005,
                            ),
                            decoration: BoxDecoration(
                              color: statusInfo.statusColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              statusInfo.displayStatus,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontSize: screenWidth * 0.034,
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      _buildInfoRow(
                        'Customer',
                        customer.customerName,
                        screenWidth,
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      _buildInfoRow(
                        'Customer Id',
                        customer.customerid,
                        screenWidth,
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      _buildInfoRow(
                        'Delivery Address',
                        customer.address,
                        screenWidth,
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      _buildInfoRow(
                        'Assigned Driver',
                        assignedEmployee,
                        screenWidth,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.01),

            if (isCanceledByCustomer)
              _buildCustomerCanceledMessage(customerName, screenWidth),

            if (!isCanceled && !isDelivered && !isCanceledByCustomer)
              _buildDeliveryStatusDropdown(
                docId,
                currentAdminStatus,
                screenWidth,
              ),
            if (isDelivered) _buildDeliveredMessage(screenWidth),
            if (isCanceled && !isCanceledByCustomer)
              _buildCanceledMessage(screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCanceledMessage(
    String customerName,
    double screenWidth,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.021,
        horizontal: screenWidth * 0.032,
      ),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(screenWidth * 0.021),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_off,
            color: Colors.orange,
            size: screenWidth * 0.042,
          ),
          SizedBox(width: screenWidth * 0.021),
          Expanded(
            child: Text(
              'This ticket was cancelled by customer',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerIdRow(String docId, double screenWidth) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Admin_details').doc(docId).snapshots(),
      builder: (context, snapshot) {
        String customerId = 'Not Found';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            customerId = _getField(data, [
              'customerid',
              'customerId',
            ], 'Not Found');

            if (customerId == 'Not Found') {
              final customerDocRef = data['customerDocRef'];
              if (customerDocRef != null &&
                  customerDocRef is DocumentReference) {
                customerId = customerDocRef.id;
              }
            }
          }
        }

        return Row(
          children: [
            Text(
              'Customer ID',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.037,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(' : ', style: TextStyle(fontSize: screenWidth * 0.037)),
            Flexible(
              child: Text(
                customerId,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _getCustomerIdColor(customerId),
                  fontSize: screenWidth * 0.037,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getCustomerIdColor(String customerId) {
    return customerId == 'Not Found'
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  Widget _buildDeliveryStatusDropdown(
    String docId,
    String currentStatus,
    double screenWidth,
  ) {
    String currentValue = _deliveryStatusMap[docId] ?? _selectStatusValue;

    if (!_validDropdownValues.contains(currentValue)) {
      currentValue = _selectStatusValue;
      _deliveryStatusMap[docId] = currentValue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.021),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.021),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        isExpanded: true,
        underline: SizedBox(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: Theme.of(context).primaryColor,
          size: screenWidth * 0.064,
        ),
        style: TextStyle(
          fontSize: screenWidth * 0.037,
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w500,
        ),
        items: [
          DropdownMenuItem(
            value: _selectStatusValue,
            child: Text(
              'Select Delivery Status',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: screenWidth * 0.037,
              ),
            ),
          ),
          // DropdownMenuItem(
          //   value: _appointmentValue,
          //   child: Row(
          //     children: [
          //       Icon(
          //         Icons.calendar_today,
          //         color: Colors.blue,
          //         size: screenWidth * 0.048,
          //       ),
          //       SizedBox(width: screenWidth * 0.021),
          //       Text(
          //         'Appointment',
          //         style: TextStyle(fontSize: screenWidth * 0.037),
          //       ),
          //     ],
          //   ),
          // ),
          DropdownMenuItem(
            value: _deliveredValue,
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: screenWidth * 0.048,
                ),
                SizedBox(width: screenWidth * 0.021),
                Text(
                  'Delivered',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: _outOfStockValue,
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: Colors.orange,
                  size: screenWidth * 0.048,
                ),
                SizedBox(width: screenWidth * 0.021),
                Text(
                  'Out of Stock',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
              ],
            ),
          ),
        ],
        onChanged: (String? newValue) {
          if (newValue != null && newValue != _selectStatusValue) {
            if (newValue == _deliveredValue) {
              _showDeliveredConfirmationDialog(docId);
            } else {
              _updateDeliveryStatus(docId, newValue);
            }
          }
        },
      ),
    );
  }

  Widget _buildDeliveredMessage(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.021,
        horizontal: screenWidth * 0.032,
      ),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(screenWidth * 0.021),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: screenWidth * 0.042,
          ),
          SizedBox(width: screenWidth * 0.021),
          Expanded(
            child: Text(
              'Delivered',
              style: TextStyle(
                color: Colors.green[800],
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanceledMessage(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.021,
        horizontal: screenWidth * 0.032,
      ),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(screenWidth * 0.021),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red, size: screenWidth * 0.042),
          SizedBox(width: screenWidth * 0.021),
          Expanded(
            child: Text(
              'Ticket Canceled ',
              style: TextStyle(
                color: Colors.red[800],
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeliveredConfirmationDialog(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as Delivered'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to mark this ticket as Delivered?'),
            SizedBox(height: 8),
            Text(
              'Once delivered, the ticket will become read-only.',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Confirm Delivery',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateDeliveryStatus(docId, _deliveredValue);
    }
  }

  Future<void> _updateDeliveryStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('Admin_details').doc(docId).update({
        'adminStatus': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _deliveryStatusMap[docId] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery status updated to: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, double screenWidth) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: screenWidth * 0.037,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(' : ', style: TextStyle(fontSize: screenWidth * 0.037)),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: screenWidth * 0.037,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _activateTicket(BuildContext context, String docId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Activate Ticket'),
          content: Text('Are you sure you want to activate this ticket?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Activate', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _firestore.collection('Admin_details').doc(docId).update({
          'adminStatus': _selectStatusValue,
          'engineerStatus': 'Not Assigned',
          'assignedEmployee': 'Not Assigned',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isTicketCanceled[docId] = false;
          _deliveryStatusMap[docId] = _selectStatusValue;
        });

        // Close the bottom sheet if it's open
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket activated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error activating ticket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeliveryDetailSheet(
    BuildContext context,
    customer_var.Customer customer,
    int serialNumber,
    StatusInfo statusInfo,
    String assignedEmployee,
    String docId,
    double screenWidth,
    double screenHeight,
  ) {
    final dt = customer.timestamp.toDate();
    final dateString = DateFormat('dd/MM/yyyy').format(dt);
    final timeString = DateFormat('HH : mm').format(dt);
    final currentAdminStatus = _getField(
      {'adminStatus': statusInfo.displayStatus},
      ['adminStatus'],
      '',
    );
    final isCanceled = _isTicketCanceled[docId] ?? false;
    final isDelivered = currentAdminStatus == 'Delivered';

    final customerDecision = _getField(
      {'Customer_decision': ''},
      ['Customer_decision'],
      '',
    );
    final isCanceledByCustomer = customerDecision == "Canceled";
    final customerName = _getField(
      {'customerName': customer.customerName},
      ['customerName', 'CustomerName'],
      'Customer',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(screenWidth * 0.064),
                    topRight: Radius.circular(screenWidth * 0.064),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.021,
                      ),
                      child: Center(
                        child: Container(
                          width: screenWidth * 0.15,
                          height: screenWidth * 0.012,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.01,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (isCanceledByCustomer)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.032,
                          horizontal: screenWidth * 0.042,
                        ),
                        color: Colors.orange[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              color: Colors.orange,
                              size: screenWidth * 0.053,
                            ),
                            SizedBox(width: screenWidth * 0.021),
                            Expanded(
                              child: Text(
                                'This ticket was cancelled by $customerName',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.037,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if ((isDelivered || isCanceled) && !isCanceledByCustomer)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.032,
                          horizontal: screenWidth * 0.042,
                        ),
                        color: isDelivered ? Colors.green[50] : Colors.red[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDelivered ? Icons.check_circle : Icons.cancel,
                              color: isDelivered ? Colors.green : Colors.red,
                              size: screenWidth * 0.053,
                            ),
                            SizedBox(width: screenWidth * 0.021),
                            Text(
                              isDelivered
                                  ? 'TICKET DELIVERED - It is no longer Accessible'
                                  : 'TICKET CANCELED',
                              style: TextStyle(
                                color: isDelivered
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.037,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.045,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: statusInfo.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.032,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).shadowColor.withOpacity(0.1),
                                  blurRadius: screenWidth * 0.016,
                                  offset: Offset(
                                    screenWidth * 0.005,
                                    screenWidth * 0.01,
                                  ),
                                ),
                              ],
                              border: statusInfo.hasBorder
                                  ? Border.all(
                                      color: statusInfo.borderColor!,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.042),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: screenWidth * 0.14,
                                        height: screenWidth * 0.14,
                                        decoration: BoxDecoration(
                                          color: statusInfo.iconColor,
                                          borderRadius: BorderRadius.circular(
                                            screenWidth * 0.07,
                                          ),
                                        ),
                                        child: Center(
                                          child:
                                              statusInfo.icon ??
                                              Text(
                                                serialNumber.toString(),
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  fontSize: screenWidth * 0.064,
                                                  fontFamily: 'Arial',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.042),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Booking ID: ${customer.bookingId}',
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          screenWidth * 0.037,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        screenWidth * 0.021,
                                                    vertical:
                                                        screenWidth * 0.01,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        statusInfo.statusColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          100,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    statusInfo.displayStatus,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                      fontSize:
                                                          screenWidth * 0.032,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: screenWidth * 0.01,
                                            ),
                                            Text(
                                              'Customer: ${customer.customerName}',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.037,
                                              ),
                                            ),
                                            SizedBox(
                                              height: screenWidth * 0.01,
                                            ),
                                            _buildDetailCustomerIdRow(
                                              docId,
                                              screenWidth,
                                            ),
                                            SizedBox(
                                              height: screenWidth * 0.01,
                                            ),
                                            Text(
                                              'Address: ${customer.address}',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.037,
                                              ),
                                            ),
                                            SizedBox(
                                              height: screenWidth * 0.01,
                                            ),
                                            Text(
                                              'Driver: $assignedEmployee',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.037,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (!isCanceled &&
                                    !isDelivered &&
                                    !isCanceledByCustomer)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.042,
                                      vertical: screenWidth * 0.021,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Status:',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.042,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                        SizedBox(height: screenWidth * 0.021),
                                        _buildDeliveryStatusDropdown(
                                          docId,
                                          currentAdminStatus,
                                          screenWidth,
                                        ),
                                      ],
                                    ),
                                  ),

                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.042,
                                  ),
                                  child: Column(
                                    children: [
                                      _detailRow(
                                        'Job Type',
                                        customer.jobType,
                                        screenWidth,
                                      ),
                                      _detailRow(
                                        'Message',
                                        customer.message,
                                        screenWidth,
                                      ),
                                      _detailRow(
                                        'Created Date',
                                        dateString,
                                        screenWidth,
                                      ),
                                      _buildPaymentTypeRow(
                                        customer.bookingId,
                                        screenWidth,
                                      ),
                                      _detailRow(
                                        'Delivery Charge',
                                        '₹ ${customer.amount}',
                                        screenWidth,
                                        valueStyle: TextStyle(
                                          color: Colors.green,
                                          fontSize: screenWidth * 0.048,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.042),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: screenWidth * 0.053,
                                          ),
                                          SizedBox(width: screenWidth * 0.021),
                                          Expanded(
                                            child: Text(
                                              customer.address,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.037,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.phone,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: screenWidth * 0.053,
                                          ),
                                          SizedBox(width: screenWidth * 0.021),
                                          Text(
                                            customer.mobileNumber,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.037,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: screenWidth * 0.032),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: screenWidth * 0.053,
                                          ),
                                          SizedBox(width: screenWidth * 0.021),
                                          Text(
                                            dateString,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.037,
                                            ),
                                          ),
                                          Spacer(),
                                          Icon(
                                            Icons.access_time,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: screenWidth * 0.053,
                                          ),
                                          SizedBox(width: screenWidth * 0.021),
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.037,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                if (!isCanceled &&
                                    !isDelivered &&
                                    !isCanceledByCustomer) ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.042,
                                      vertical: screenWidth * 0.021,
                                    ),
                                    child: Row(
                                      children: [
                                        if (assignedEmployee == 'Not Assigned')
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.032,
                                                ),
                                              ),
                                              onPressed: () => _assignDriver(
                                                context,
                                                customer,
                                                docId,
                                              ),
                                              child: Text(
                                                'ASSIGN DRIVER',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  fontSize: screenWidth * 0.037,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.032,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _assignToDelivery(
                                                    context,
                                                    customer,
                                                    docId,
                                                  ),
                                              child: Text(
                                                'ASSIGN',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  fontSize: screenWidth * 0.037,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (statusInfo.isOutForDelivery &&
                                    !isCanceled &&
                                    !isDelivered &&
                                    !isCanceledByCustomer) ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.042,
                                      vertical: screenWidth * 0.021,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: EdgeInsets.symmetric(
                                          vertical: screenWidth * 0.032,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _markAsDelivered(context, docId),
                                      child: Text(
                                        'MARK AS DELIVERED',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: screenWidth * 0.037,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                if (!isDelivered && !isCanceledByCustomer) ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.042,
                                      vertical: screenWidth * 0.021,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCanceled
                                            ? Colors.green
                                            : Colors.red,
                                        padding: EdgeInsets.symmetric(
                                          vertical: screenWidth * 0.032,
                                        ),
                                      ),
                                      onPressed: () => isCanceled
                                          ? _activateTicket(context, docId)
                                          : _cancelTicket(context, docId),
                                      child: Text(
                                        isCanceled
                                            ? 'ACTIVATE TICKET'
                                            : 'CANCEL TICKET',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: screenWidth * 0.037,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                _buildCustomerFeedback(
                                  customer.bookingId,
                                  screenWidth,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailCustomerIdRow(String docId, double screenWidth) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Admin_details').doc(docId).snapshots(),
      builder: (context, snapshot) {
        String customerId = 'Not Found';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            customerId = _getField(data, [
              'customerid',
              'customerId',
            ], 'Not Found');

            if (customerId == 'Not Found') {
              final customerDocRef = data['customerDocRef'];
              if (customerDocRef != null &&
                  customerDocRef is DocumentReference) {
                customerId = customerDocRef.id;
              }
            }
          }
        }

        return Row(
          children: [
            Text(
              'Customer ID:',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.037,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: screenWidth * 0.021),
            Text(
              customerId,
              style: TextStyle(
                color: _getCustomerIdColor(customerId),
                fontSize: screenWidth * 0.037,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
    double screenWidth, {
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * 0.32,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: screenWidth * 0.037,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: screenWidth * 0.037,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeRow(String bookingId, double screenWidth) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Admin_details').doc(bookingId).snapshots(),
      builder: (context, snapshot) {
        String paymentType = 'N/A';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          paymentType = data != null
              ? _getField(data, ['PaymentType', 'paymentType'], 'N/A')
              : 'N/A';
        }

        return _detailRow(
          'Payment Type',
          paymentType,
          screenWidth,
          valueStyle: TextStyle(
            color: _getPaymentTypeColor(paymentType),
            fontSize: screenWidth * 0.037,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Widget _buildCustomerFeedback(String bookingId, double screenWidth) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.042),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.032),
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.042),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Feedback',
                style: TextStyle(
                  fontSize: screenWidth * 0.048,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: screenWidth * 0.021),
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('Admin_details')
                    .doc(bookingId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  String feedback = 'No feedback available.';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null &&
                        data.containsKey('FeedBack') &&
                        data['FeedBack'] != null) {
                      feedback = data['FeedBack'].toString();
                    }
                  }

                  return Text(
                    feedback,
                    style: TextStyle(fontSize: screenWidth * 0.037),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPaymentTypeColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'paid':
      case 'completed':
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
        return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    }
  }

  StatusInfo _getStatusInfo(Map<String, dynamic> data) {
    final engineerStatus = _getField(data, [
      'engineerStatus',
      'statusDescription',
    ], '').toLowerCase();
    final adminStatus = _getField(data, ['adminStatus'], '').toLowerCase();
    final customerDecision = _getField(data, [
      'Customer_decision',
    ], '').toLowerCase();

    final isCanceled =
        adminStatus == 'canceled' || customerDecision == 'canceled';
    final isDelivered =
        engineerStatus == 'delivered' || adminStatus == 'delivered';
    final isOutForDelivery = engineerStatus == 'Assigned'.toLowerCase();
    // final isAppointment =
    //     engineerStatus == 'appointment' || adminStatus == 'appointment';
    final isCompleted = engineerStatus == 'completed' || isDelivered;
    final isAssigned =
        engineerStatus == 'assigned' || adminStatus == 'assigned';
    final isOutOfStock = adminStatus == 'out of stock';
    final isCanceledByCustomer = customerDecision == 'canceled';

    String displayStatus = engineerStatus.isNotEmpty
        ? engineerStatus
        : 'Completed';
    if (isCanceledByCustomer) {
      displayStatus = 'Canceled by Customer';
    } else if (isCanceled)
      displayStatus = 'Canceled';
    if (isDelivered) displayStatus = 'Delivered';
    if (isOutForDelivery) displayStatus = 'Assigned';
    // if (isAppointment) displayStatus = 'Appointment';
    if (isOutOfStock) displayStatus = 'Out of Stock';

    Color statusColor;
    Color backgroundColor;
    Color iconColor;
    Color? borderColor;
    bool hasBorder = false;
    Widget? icon;

    if (isCanceledByCustomer) {
      statusColor = Colors.orange;
      backgroundColor = Colors.orange[50]!;
      iconColor = Colors.orange;
      borderColor = Colors.orange;
      hasBorder = true;
      icon = Icon(Icons.person_off, color: Colors.white, size: 24);
    } else if (isCanceled) {
      statusColor = Colors.grey;
      backgroundColor = Colors.grey[100]!;
      iconColor = Colors.grey;
      icon = Icon(Icons.cancel, color: Colors.white, size: 24);
    } else if (isDelivered) {
      statusColor = Colors.green;
      backgroundColor = const Color(0xFFE8F5E9);
      iconColor = Colors.green;
      borderColor = Colors.green;
      hasBorder = true;
      icon = Icon(Icons.check_circle, color: Colors.white, size: 24);
    } else if (isOutForDelivery) {
      statusColor = Colors.green;
      backgroundColor = const Color(0xFFE8F5E9);
      iconColor = Colors.green;
      borderColor = Colors.green;
      hasBorder = true;
      icon = Icon(Icons.local_shipping, color: Colors.white, size: 24);
    } else if (isOutOfStock) {
      statusColor = Colors.amber;
      backgroundColor = Colors.amber[50]!;
      iconColor = Colors.amber;
      borderColor = Colors.amber;
      hasBorder = true;
      icon = Icon(Icons.inventory_2, color: Colors.white, size: 24);
    }
    //  else if (isAppointment) {
    //   statusColor = Colors.blue;
    //   backgroundColor = Color(0xFFE3F2FD);
    //   iconColor = Colors.blue;
    //   borderColor = Colors.blue;
    //   hasBorder = true;
    //   icon = Icon(Icons.calendar_today, color: Colors.white, size: 24);
    // }
    else if (isCompleted) {
      statusColor = Colors.green;
      backgroundColor = Color(0xFFE8F5E8);
      iconColor = Colors.green;
      icon = Icon(Icons.check, color: Colors.white, size: 24);
    } else if (isAssigned) {
      statusColor = Theme.of(context).primaryColor;
      backgroundColor = Theme.of(context).primaryColor.withOpacity(0.1);
      iconColor = Theme.of(context).primaryColor;
    } else {
      statusColor = Theme.of(context).disabledColor;
      backgroundColor = Theme.of(context).disabledColor.withOpacity(0.1);
      iconColor = Theme.of(context).disabledColor;
    }

    return StatusInfo(
      displayStatus: displayStatus,
      statusColor: statusColor,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      borderColor: borderColor,
      hasBorder: hasBorder,
      icon: icon,
      isCanceled: isCanceled,
      isDelivered: isDelivered,
      isOutForDelivery: isOutForDelivery,
    );
  }

  Future<void> _assignDriver(
    BuildContext context,
    customer_var.Customer customer,
    String docId,
  ) async {
    try {
      final docRef = _firestore.collection('Admin_details').doc(docId);
      await docRef.update({
        'adminStatus': 'Assigned',
        'engineerStatus': 'Open',
      });

      Navigator.pop(context);
      _navigateToAssignPage(customer);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign driver: $e')));
    }
  }

  Future<void> _assignToDelivery(
    BuildContext context,
    customer_var.Customer customer,
    String docId,
  ) async {
    try {
      Navigator.pop(context);
      _navigateToAssignPage(customer);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to navigate to assign page: $e')),
      );
    }
  }

  Future<void> _markAsDelivered(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as Delivered'),
        content: Text('Mark this delivery as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirm', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('Admin_details').doc(docId).update({
          'engineerStatus': 'Delivered',
          'adminStatus': 'Delivered',
        });
        setState(() {
          _deliveryStatusMap[docId] = 'Delivered';
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery marked as completed!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _cancelTicket(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this ticket?'),
            SizedBox(height: 8),
            Text(
              'Once canceled, the ticket will become read-only and cannot be edited.',
              style: TextStyle(
                color: Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes, Cancel Ticket',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('Admin_details').doc(docId).update({
          'adminStatus': 'Canceled',
          'engineerStatus': 'Canceled',
        });
        setState(() {
          _isTicketCanceled[docId] = true;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket canceled successfully.'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAssignPage(customer_var.Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssigndeliveryCustomerPage(customer: customer),
      ),
    );
  }
}

class StatusInfo {
  final String displayStatus;
  final Color statusColor;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final bool hasBorder;
  final Widget? icon;
  final bool isCanceled;
  final bool isDelivered;
  final bool isOutForDelivery;

  StatusInfo({
    required this.displayStatus,
    required this.statusColor,
    required this.backgroundColor,
    required this.iconColor,
    this.borderColor,
    required this.hasBorder,
    this.icon,
    required this.isCanceled,
    required this.isDelivered,
    required this.isOutForDelivery,
  });
}
