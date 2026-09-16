import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:flutter/services.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';

class CreateTickets extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String mobileNumber;
  final String categoryName;

  const CreateTickets({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.mobileNumber,
    required this.categoryName,
    required String loggedInName,
    required String name,
    required String statusFilter,
  });

  @override
  _CreateTicketsState createState() => _CreateTicketsState();
}

class _CreateTicketsState extends State<CreateTickets> {
  final _formKey = GlobalKey<FormState>();

  // Wizard state: 0 = Customer, 1 = Ticket Type, 2 = Details, 3 = Review, 4 = Success
  int _currentStep = 0;

  // Customer sub-flow selection: 'new' vs 'existing'
  String _customerType = 'existing';

  // Customer Form Controllers
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Search Controllers for Existing Customer
  final TextEditingController _existingSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingCustomers = false;

  // Selected Customer details
  Map<String, dynamic>? _selectedCustomer;

  // Mobile check state
  bool _isCheckingMobileNumber = false;
  String _mobileNumberError = '';
  final FocusNode _mobileNumberFocusNode = FocusNode();

  // Ticket Type: 'Service' or 'Delivery'
  String jobType = 'Service';

  // Ticket Form Controllers
  String deviceType = '';
  String deviceBrand = '';
  String deviceCondition = '';
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customDeviceTypeController = TextEditingController();
  final TextEditingController _customDeviceBrandController = TextEditingController();

  // Lists
  List<String> deviceTypes = ['Laptop', 'Desktop', 'Printer', 'CCTV', 'Server', 'Others'];
  List<String> deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
  final List<String> currentDeviceConditions = [
    'Working',
    'Partially working',
    'Display Problem',
    'Not working',
  ];
  final List<String> jobTypes = ['Service', 'Delivery'];

  bool _isDeviceTypesLoading = false;
  bool _isDeviceBrandsLoading = false;
  bool _isSubmitting = false;

  // Success step results
  String _createdTicketId = '';
  String _createdCustomerId = '';

  @override
  void initState() {
    super.initState();
    _fetchDeviceTypes();
    _fetchGlobalDeviceBrands();

    if (widget.customerId.isNotEmpty) {
      _customerType = 'existing';
      _customerIdController.text = widget.customerId;
      _customerNameController.text = widget.customerName;
      _mobileNumberController.text = widget.mobileNumber;
      _selectedCustomer = {
        'id': widget.customerId,
        'customerName': widget.customerName,
        'mobileNumber': widget.mobileNumber,
        'address': '',
      };
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerNameController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _existingSearchController.dispose();
    _messageController.dispose();
    _descriptionController.dispose();
    _customDeviceTypeController.dispose();
    _customDeviceBrandController.dispose();
    _mobileNumberFocusNode.dispose();
    super.dispose();
  }

  // --- ATOMIC FIRESTORE COUNTERS ---

  Future<String> _generateNextCustomerId() async {
    final counterRef = FirestoreService.instance.collection('counters').doc('customerId');
    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 0;
      if (snapshot.exists && snapshot.data() != null && snapshot.data()!['lastId'] != null) {
        lastId = snapshot.data()!['lastId'] as int;
      } else {
        // Scan fallback if counter doc is fresh
        final customersSnapshot = await FirestoreService.instance.collection('customers').get();
        final loginSnapshot = await FirestoreService.instance.collection('CustomerLogindetails').get();
        final RegExp cPattern = RegExp(r'^C(\d+)$');
        int highest = 0;

        for (var doc in customersSnapshot.docs) {
          final id = doc.data()['id']?.toString() ?? '';
          final match = cPattern.firstMatch(id);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > highest) highest = num;
          }
        }
        for (var doc in loginSnapshot.docs) {
          final id = doc.data()['id']?.toString() ?? '';
          final match = cPattern.firstMatch(id);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > highest) highest = num;
          }
        }
        lastId = highest;
      }

      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastId': nextId}, SetOptions(merge: true));
      return 'C${nextId.toString().padLeft(4, '0')}';
    });
  }

  Future<String> _generateNextServiceTicketId() async {
    final counterRef = FirestoreService.instance.collection('counters').doc('serviceTicketId');
    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 0;
      if (snapshot.exists && snapshot.data() != null && snapshot.data()!['lastId'] != null) {
        lastId = snapshot.data()!['lastId'] as int;
      } else {
        final adminSnapshot = await FirestoreService.instance.collection('Admin_ticket_entry').get();
        final RegExp sPattern = RegExp(r'^S(\d+)$');
        int highest = 0;
        for (var doc in adminSnapshot.docs) {
          final bookingId = doc.data()['bookingId']?.toString() ?? '';
          final match = sPattern.firstMatch(bookingId);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > highest) highest = num;
          }
        }
        lastId = highest;
      }
      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastId': nextId}, SetOptions(merge: true));
      return 'S${nextId.toString().padLeft(4, '0')}';
    });
  }

  Future<String> _generateNextDeliveryTicketId() async {
    final counterRef = FirestoreService.instance.collection('counters').doc('deliveryTicketId');
    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 0;
      if (snapshot.exists && snapshot.data() != null && snapshot.data()!['lastId'] != null) {
        lastId = snapshot.data()!['lastId'] as int;
      } else {
        final adminSnapshot = await FirestoreService.instance.collection('Admin_ticket_entry').get();
        final RegExp dPattern = RegExp(r'^D(\d+)$');
        int highest = 0;
        for (var doc in adminSnapshot.docs) {
          final bookingId = doc.data()['bookingId']?.toString() ?? '';
          final match = dPattern.firstMatch(bookingId);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > highest) highest = num;
          }
        }
        lastId = highest;
      }
      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastId': nextId}, SetOptions(merge: true));
      return 'D${nextId.toString().padLeft(4, '0')}';
    });
  }

  // --- EXISTING CUSTOMER SEARCH ---

  Future<void> _searchExistingCustomers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearchingCustomers = true;
    });

    final cleanQuery = query.trim().toLowerCase();
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIds = {};

    try {
      // 1. Search customers collection
      final customersSnap = await FirestoreService.instance.collection('customers').get();
      for (var doc in customersSnap.docs) {
        final data = doc.data();
        final id = (data['id'] ?? doc.id).toString();
        final name = (data['customerName'] ?? '').toString();
        final mobile = (data['mobileNumber'] ?? '').toString();
        final address = (data['address'] ?? '').toString();

        if (id.toLowerCase().contains(cleanQuery) ||
            name.toLowerCase().contains(cleanQuery) ||
            mobile.toLowerCase().contains(cleanQuery)) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            results.add({
              'id': id,
              'customerName': name,
              'mobileNumber': mobile,
              'address': address,
              'source': 'Customers',
            });
          }
        }
      }

      // 2. Search CustomerLogindetails collection
      final loginSnap = await FirestoreService.instance.collection('CustomerLogindetails').get();
      for (var doc in loginSnap.docs) {
        final data = doc.data();
        final id = (data['id'] ?? doc.id).toString();
        final name = (data['name'] ?? '').toString();
        final mobile = (data['phonenumber'] ?? '').toString();
        final address = (data['address'] ?? '').toString();

        if (id.toLowerCase().contains(cleanQuery) ||
            name.toLowerCase().contains(cleanQuery) ||
            mobile.toLowerCase().contains(cleanQuery)) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            results.add({
              'id': id,
              'customerName': name,
              'mobileNumber': mobile,
              'address': address,
              'source': 'Login Details',
            });
          }
        }
      }

      // 3. Search AMC_user collection
      final amcSnap = await FirestoreService.instance.collection('AMC_user').get();
      for (var doc in amcSnap.docs) {
        final data = doc.data();
        final id = (data['Id'] ?? doc.id).toString();
        final name = (data['name'] ?? '').toString();
        final mobile = (data['Phone Number'] ?? '').toString();
        final address = (data['address'] ?? '').toString();

        if (id.toLowerCase().contains(cleanQuery) ||
            name.toLowerCase().contains(cleanQuery) ||
            mobile.toLowerCase().contains(cleanQuery)) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            results.add({
              'id': id,
              'customerName': name,
              'mobileNumber': mobile,
              'address': address,
              'source': 'AMC User',
            });
          }
        }
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Error searching customers: $e');
    } finally {
      setState(() {
        _isSearchingCustomers = false;
      });
    }
  }

  Future<String?> _checkMobileNumberExists(String mobileNumber) async {
    if (mobileNumber.isEmpty || mobileNumber.length != 10) {
      return null;
    }
    setState(() {
      _isCheckingMobileNumber = true;
      _mobileNumberError = '';
    });

    try {
      final customersSnapshot = await FirestoreService.instance
          .collection('customers')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();
      if (customersSnapshot.docs.isNotEmpty) {
        return 'Mobile number already registered in customer database';
      }

      final customerLoginSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();
      if (customerLoginSnapshot.docs.isNotEmpty) {
        return 'Mobile number already registered in customer login details';
      }

      return null;
    } catch (e) {
      return 'Error verifying mobile number availability';
    } finally {
      setState(() {
        _isCheckingMobileNumber = false;
      });
    }
  }

  Future<void> _fetchDeviceTypes() async {
    setState(() => _isDeviceTypesLoading = true);
    try {
      final snapshot =
          await FirestoreService.instance.collection('Devices').get();
      final types = snapshot.docs
          .map((doc) => doc['deviceName']?.toString().trim())
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toSet()   // ← removes duplicates (e.g. multiple "Laptop" docs)
          .toList();
      types.sort();
      if (!types.contains('Others')) types.add('Others');
      setState(() => deviceTypes = types);
    } catch (e) {
      setState(() =>
          deviceTypes = ['Laptop', 'Desktop', 'Printer', 'CCTV', 'Server', 'Others']);
    } finally {
      setState(() => _isDeviceTypesLoading = false);
    }
  }

  Future<void> _fetchGlobalDeviceBrands() async {
    setState(() => _isDeviceBrandsLoading = true);
    try {
      final snapshot =
          await FirestoreService.instance.collection('Devices').get();
      final brands = snapshot.docs
          .map((doc) => doc['brandName']?.toString().trim())
          .where((b) => b != null && b.isNotEmpty)
          .cast<String>()
          .toSet() // removes duplicates (multiple Lenovo docs → one "Lenovo")
          .toList();
      brands.sort();
      if (!brands.contains('Others')) brands.add('Others');
      setState(() => deviceBrands = brands);
    } catch (e) {
      setState(() =>
          deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others']);
    } finally {
      setState(() => _isDeviceBrandsLoading = false);
    }
  }

  // --- SUBMIT FINAL TICKET TRANSACTION ---

  Future<void> _handleFinalTicketCreation() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      String generatedTicketId = '';
      if (jobType == 'Service') {
        generatedTicketId = await _generateNextServiceTicketId();
      } else {
        generatedTicketId = await _generateNextDeliveryTicketId();
      }

      final actualDeviceType = deviceType == 'Others'
          ? _customDeviceTypeController.text.trim()
          : deviceType;
      final actualDeviceBrand = deviceBrand == 'Others'
          ? _customDeviceBrandController.text.trim()
          : deviceBrand;

      final customerIdToUse = _customerIdController.text.isNotEmpty
          ? _customerIdController.text
          : (_selectedCustomer?['id'] ?? 'C0001');

      Map<String, dynamic> ticketData = {
        'id': customerIdToUse,
        'bookingId': generatedTicketId,
        'customerName': _customerNameController.text,
        'mobileNumber': _mobileNumberController.text,
        'address': _addressController.text,
        'categoryName': widget.categoryName,
        'timestamp': Timestamp.now(),
        'JobType': jobType,
        'customerType': _customerType,
        'deviceType': actualDeviceType,
        'deviceBrand': actualDeviceBrand,
        'deviceCondition': jobType == 'Service' ? deviceCondition : 'N/A',
        'message': jobType == 'Delivery' ? _descriptionController.text : _messageController.text,
        'adminStatus': 'Open',
        'customerStatus': 'Ticket Created',
        'engineerStatus': 'Not Assigned',
        'assignedEmployee': 'Not Assigned',
      };

      // Save ticket exclusively to Admin_details collection
      await FirestoreService.instance
          .collection('Admin_ticket_entry')
          .doc(generatedTicketId)
          .set(ticketData);

      setState(() {
        _createdTicketId = generatedTicketId;
        _createdCustomerId = customerIdToUse;
        _currentStep = 4; // Success step
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 4) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Create Ticket',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildStepProgressBar(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP PROGRESS BAR ---

  Widget _buildStepProgressBar() {
    final primaryColor = Theme.of(context).primaryColor;
    final steps = ['Customer', 'Ticket Type', 'Details', 'Review', 'Done'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isActive
                            ? primaryColor
                            : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- CURRENT STEP SWITCHER ---

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0CustomerSelection();
      case 1:
        return _buildStep1TicketTypeSelection();
      case 2:
        return _buildStep2DetailsForm();
      case 3:
        return _buildStep3ReviewTicket();
      case 4:
        return _buildStep4SuccessScreen();
      default:
        return _buildStep0CustomerSelection();
    }
  }

  // --- STEP 0: CUSTOMER SELECTION / REGISTRATION ---

  Widget _buildStep0CustomerSelection() {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Is this ticket for a new or existing customer?',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        // Choice Tabs
        Row(
          children: [
            _buildChoiceCard(
              title: 'New Customer',
              subtitle: 'Register new profile',
              icon: Icons.person_add_rounded,
              isSelected: _customerType == 'new',
              onTap: () {
                setState(() {
                  _customerType = 'new';
                  _selectedCustomer = null;
                  _customerNameController.clear();
                  _mobileNumberController.clear();
                  _addressController.clear();
                  _customerIdController.clear();
                  _mobileNumberError = '';
                });
              },
            ),
            const SizedBox(width: 14),
            _buildChoiceCard(
              title: 'Existing Customer',
              subtitle: 'Search database',
              icon: Icons.search_rounded,
              isSelected: _customerType == 'existing',
              onTap: () {
                setState(() {
                  _customerType = 'existing';
                  _mobileNumberError = '';
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        if (_customerType == 'new') ...[
          // New Customer Registration Form
          Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
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
                      child: Icon(Icons.person_add_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Customer Registration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 16),
                _buildTextField(
                  'Customer Name',
                  'Enter full customer name',
                  Icons.person_rounded,
                  _customerNameController,
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildMobileNumberField(),
                const SizedBox(height: 16),
                _buildTextField(
                  'Customer Address',
                  'Enter complete location address',
                  Icons.location_on_rounded,
                  _addressController,
                  maxLines: 2,
                  required: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleNewCustomerSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              label: Text(
                _isSubmitting ? 'Registering Customer...' : 'Continue to Ticket Type →',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ] else ...[
          // Existing Customer Search View
          Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search Customer Database',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _existingSearchController,
                  onChanged: (val) => _searchExistingCustomers(val),
                  decoration: InputDecoration(
                    hintText: 'Search by Customer ID, Name, or Mobile...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                    suffixIcon: _existingSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _existingSearchController.clear();
                              _searchExistingCustomers('');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                if (_isSearchingCustomers)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                else if (_searchResults.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                      itemBuilder: (context, idx) {
                        final item = _searchResults[idx];
                        final isSel = _selectedCustomer?['id'] == item['id'];

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            tileColor: isSel ? primaryColor.withValues(alpha: 0.1) : null,
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              child: Icon(Icons.person_rounded, color: primaryColor, size: 20),
                            ),
                            title: Text(
                              item['customerName'],
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              'ID: ${item['id']} • Mobile: ${item['mobileNumber']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: isSel
                                ? Icon(Icons.check_circle_rounded, color: primaryColor)
                                : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () {
                              setState(() {
                                _selectedCustomer = item;
                                _customerIdController.text = item['id'] ?? '';
                                _customerNameController.text = item['customerName'] ?? '';
                                _mobileNumberController.text = item['mobileNumber'] ?? '';
                                _addressController.text = item['address'] ?? '';
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ] else if (_existingSearchController.text.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No matching customer profiles found',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],

                // Selected Customer Display Card
                if (_selectedCustomer != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: primaryColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer!['customerName'],
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Customer ID: ${_selectedCustomer!['id']} • Mobile: ${_selectedCustomer!['mobileNumber']}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedCustomer != null
                  ? () {
                      setState(() {
                        _currentStep = 1;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Continue to Ticket Type →',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleNewCustomerSubmit() async {
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }
    if (_mobileNumberController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer address')),
      );
      return;
    }

    final mobileErr = await _checkMobileNumberExists(_mobileNumberController.text.trim());
    if (mobileErr != null) {
      setState(() {
        _mobileNumberError = mobileErr;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final generatedId = await _generateNextCustomerId();
      _customerIdController.text = generatedId;

      final custData = {
        'id': generatedId,
        'customerName': _customerNameController.text.trim(),
        'mobileNumber': _mobileNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'timestamp': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.instance.collection('customers').doc(generatedId).set(custData);

      setState(() {
        _selectedCustomer = custData;
        _currentStep = 1; // Ticket Type Selection
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save customer: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // --- STEP 1: TICKET TYPE SELECTION ---

  Widget _buildStep1TicketTypeSelection() {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ticket Type Selection',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'What type of ticket do you want to create?',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                type: 'Service',
                title: 'Service Ticket',
                subtitle: 'For service, repair, and diagnostic requests',
                icon: Icons.build_circle_rounded,
                accentColor: primaryColor,
                isSelected: jobType == 'Service',
                onTap: () {
                  setState(() {
                    jobType = 'Service';
                  });
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildTypeCard(
                type: 'Delivery',
                title: 'Delivery Ticket',
                subtitle: 'For delivery, dispatch, and item pickup requests',
                icon: Icons.local_shipping_rounded,
                accentColor: const Color(0xFF10B981),
                isSelected: jobType == 'Delivery',
                onTap: () {
                  setState(() {
                    jobType = 'Delivery';
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _currentStep = 2;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Continue to Ticket Details →',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accentColor, size: 24),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: TICKET DETAILS FORM ---

  Widget _buildStep2DetailsForm() {
    final primaryColor = Theme.of(context).primaryColor;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: jobType == 'Service'
                      ? primaryColor.withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  jobType == 'Service' ? Icons.build_circle_rounded : Icons.local_shipping_rounded,
                  color: jobType == 'Service' ? primaryColor : const Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$jobType Ticket Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Text(
                    'Specify device & service requirements',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_isDeviceTypesLoading)
                  Center(child: CircularProgressIndicator(color: primaryColor))
                else ...[
                  _buildDropdownField(
                    'Device Type',
                    deviceTypes,
                    Icons.devices_rounded,
                    (value) {
                      setState(() {
                        deviceType = value ?? '';
                        if (deviceType != 'Others') {
                          _customDeviceTypeController.clear();
                        }
                      });
                    },
                    value: deviceType.isNotEmpty ? deviceType : null,
                  ),
                  if (deviceType == 'Others')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildTextField(
                        'Custom Device Type',
                        'Enter device type name',
                        Icons.devices_other_rounded,
                        _customDeviceTypeController,
                        required: true,
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                if (_isDeviceBrandsLoading)
                  Center(child: CircularProgressIndicator(color: primaryColor))
                else ...[
                  _buildDropdownField(
                    'Device Brand',
                    deviceBrands.isNotEmpty ? deviceBrands : ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'],
                    Icons.branding_watermark_rounded,
                    (value) {
                      setState(() {
                        deviceBrand = value ?? '';
                        if (deviceBrand != 'Others') {
                          _customDeviceBrandController.clear();
                        }
                      });
                    },
                    value: deviceBrand.isNotEmpty ? deviceBrand : null,
                  ),
                  if (deviceBrand == 'Others')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildTextField(
                        'Custom Device Brand',
                        'Enter device brand name',
                        Icons.branding_watermark_rounded,
                        _customDeviceBrandController,
                        required: true,
                      ),
                    ),
                ],

                // Condition (Only shown for Service tickets)
                if (jobType == 'Service') ...[
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Device Condition',
                    currentDeviceConditions,
                    Icons.build_rounded,
                    (value) {
                      setState(() {
                        deviceCondition = value ?? '';
                      });
                    },
                    value: deviceCondition.isNotEmpty ? deviceCondition : null,
                  ),
                ],

                const SizedBox(height: 16),
                if (jobType == 'Delivery') ...[
                  _buildTextField(
                    'Delivery Description',
                    'Enter delivery instructions and item details',
                    Icons.description_rounded,
                    _descriptionController,
                    maxLines: 3,
                    required: false,
                  ),
                ] else ...[
                  _buildTextField(
                    'Additional Message / Issue Details',
                    'Enter detailed description of the service issue',
                    Icons.message_rounded,
                    _messageController,
                    maxLines: 3,
                    required: false,
                  ),
                ],

                const SizedBox(height: 16),
                _buildTextField(
                  'Service Address',
                  'Enter complete location address',
                  Icons.location_on_rounded,
                  _addressController,
                  maxLines: 2,
                  required: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (deviceType.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a Device Type')),
                    );
                    return;
                  }
                  if (deviceBrand.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a Device Brand')),
                    );
                    return;
                  }
                  if (jobType == 'Service' && deviceCondition.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a Device Condition')),
                    );
                    return;
                  }

                  setState(() {
                    _currentStep = 3; // Move to Review Step
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Review Ticket Details →',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: REVIEW TICKET ---

  Widget _buildStep3ReviewTicket() {
    final primaryColor = Theme.of(context).primaryColor;
    final custName = _customerNameController.text.isNotEmpty
        ? _customerNameController.text
        : (_selectedCustomer?['customerName'] ?? 'Customer');
    final custMobile = _mobileNumberController.text.isNotEmpty
        ? _mobileNumberController.text
        : (_selectedCustomer?['mobileNumber'] ?? '');
    final custId = _customerIdController.text.isNotEmpty
        ? _customerIdController.text
        : (_selectedCustomer?['id'] ?? '');

    final displayDeviceType = deviceType == 'Others' ? _customDeviceTypeController.text : deviceType;
    final displayDeviceBrand = deviceBrand == 'Others' ? _customDeviceBrandController.text : deviceBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Ticket Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Verify all specifications before final creation',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        // Summary Card 1: Customer
        _buildReviewCard(
          title: 'Customer Information',
          icon: Icons.person_rounded,
          children: [
            _buildReviewRow('Customer ID', custId, isHighlight: true),
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildReviewRow('Customer Name', custName),
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildReviewRow('Mobile Number', custMobile),
          ],
        ),

        const SizedBox(height: 14),

        // Summary Card 2: Ticket Type & Specifications
        _buildReviewCard(
          title: 'Ticket Specifications',
          icon: jobType == 'Service' ? Icons.build_circle_rounded : Icons.local_shipping_rounded,
          children: [
            _buildReviewRow('Ticket Type', jobType, isHighlight: true),
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildReviewRow('Device Type', displayDeviceType),
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildReviewRow('Device Brand', displayDeviceBrand),
            if (jobType == 'Service') ...[
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildReviewRow('Condition', deviceCondition),
              if (_messageController.text.isNotEmpty) ...[
                const Divider(color: Color(0xFFF1F5F9), height: 16),
                _buildReviewRow('Issue Details', _messageController.text),
              ],
            ],
            if (jobType == 'Delivery' && _descriptionController.text.isNotEmpty) ...[
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildReviewRow('Delivery Instructions', _descriptionController.text),
            ],
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildReviewRow('Service Address', _addressController.text),
          ],
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleFinalTicketCreation,
            style: ElevatedButton.styleFrom(
              backgroundColor: jobType == 'Service' ? primaryColor : const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    jobType == 'Service' ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
            label: Text(
              _isSubmitting
                  ? 'Generating Ticket...'
                  : 'Create $jobType Ticket',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primaryColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
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

  Widget _buildReviewRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isHighlight ? Theme.of(context).primaryColor : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 4: SUCCESS CONFIRMATION SCREEN ---

  Widget _buildStep4SuccessScreen() {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checkmark Badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),

            Text(
              '✓ $jobType Ticket Created',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The ticket has been logged into the workspace database.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),

            const SizedBox(height: 24),

            // Summary IDs Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ticket Number',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      Text(
                        _createdTicketId,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: jobType == 'Service' ? primaryColor : const Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE2E8F0), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customer ID',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      Text(
                        _createdCustomerId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (jobType == 'Service') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPage_CusDetails(statusFilter: ""),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminDeliveryTickets(statusFilter: ""),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View Ticket',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE UI HELPERS ---

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? primaryColor : const Color(0xFF64748B), size: 24),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? primaryColor : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool required = true,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildMobileNumberField() {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Mobile Number',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _mobileNumberController,
          focusNode: _mobileNumberFocusNode,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            hintText: 'Enter 10-digit mobile number',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _mobileNumberError.isNotEmpty ? Colors.red.shade400 : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            prefixIcon: Icon(Icons.phone_android_rounded, color: primaryColor, size: 20),
            suffixIcon: _isCheckingMobileNumber
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Mobile number is required';
            if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
            return null;
          },
        ),
        if (_mobileNumberError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _mobileNumberError,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> options,
    IconData icon,
    Function(String?) onChanged, {
    String? value,
    bool required = true,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
            ),
            dropdownColor: Colors.white,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            items: options.map((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              );
            }).toList(),
            onChanged: onChanged,
            validator: required
                ? (v) => v == null || v.isEmpty ? '$label is required' : null
                : null,
          ),
        ),
      ],
    );
  }
}