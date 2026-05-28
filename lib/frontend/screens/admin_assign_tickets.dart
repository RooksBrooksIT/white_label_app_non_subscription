import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/backend/brand_model_backend.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

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
  late TextEditingController _customerIdController;
  late TextEditingController _customerNameController;
  late TextEditingController _mobileNumberController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customDeviceTypeController =
      TextEditingController();
  final TextEditingController _customDeviceBrandController =
      TextEditingController();

  late String deviceType;
  String deviceBrand = '';
  String deviceCondition = '';

  final List<String> jobTypes = ['Service', 'Delivery'];
  String jobType = '';

  List<String> deviceTypes = [];
  bool _isDeviceTypesLoading = false;

  List<String> deviceBrands = [];
  bool _isDeviceBrandsLoading = false;

  bool _isSubmitting = false;
  bool _isGeneratingCustomerId = false;
  bool _isCheckingMobileNumber = false;
  final BrandModelBackend _brandBackend = BrandModelBackend();

  late FocusNode _customerIdFocusNode;
  late FocusNode _mobileNumberFocusNode;

  // Track customer type: 'existing' or 'new'
  String _customerType = 'existing';
  String _mobileNumberError = '';

  @override
  void initState() {
    _customerIdFocusNode = FocusNode();
    _mobileNumberFocusNode = FocusNode();

    super.initState();

    _customerIdController = TextEditingController(text: widget.customerId);
    _customerNameController = TextEditingController(text: widget.customerName);
    _mobileNumberController = TextEditingController(text: widget.mobileNumber);

    _customerIdFocusNode.addListener(() {
      if (!_customerIdFocusNode.hasFocus &&
          _customerType == 'existing' &&
          _customerIdController.text.trim().isNotEmpty) {
        _fetchCustomerDetailsByCustomerId(_customerIdController.text.trim());
      }
    });

    _mobileNumberFocusNode.addListener(() {
      if (!_mobileNumberFocusNode.hasFocus &&
          _customerType == 'existing' &&
          _mobileNumberController.text.trim().isNotEmpty) {
        _fetchCustomerDetailsByMobileNumber(
          _mobileNumberController.text.trim(),
        );
      }
    });

    _fetchDeviceTypes();
    _fetchGlobalDeviceBrands();
    deviceType = '';

    // Only fetch by name if we have a customer name and it's existing customer
    if (widget.customerName.isNotEmpty && _customerType == 'existing') {
      _fetchCustomerDetailsByName();
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerNameController.dispose();
    _mobileNumberController.dispose();
    _messageController.dispose();
    _addressController.dispose();
    _customDeviceTypeController.dispose();
    _customDeviceBrandController.dispose();
    _descriptionController.dispose();
    _customerIdFocusNode.dispose();
    _mobileNumberFocusNode.dispose();
    super.dispose();
  }

  // Method to fetch customer data from multiple collections by ID
  Future<Map<String, dynamic>?> _fetchCustomerDataById(
    String customerId,
  ) async {
    try {
      // Try customers collection first
      final customersSnapshot = await FirestoreService.instance
          .collection('customers')
          .where('id', isEqualTo: customerId)
          .limit(1)
          .get();

      if (customersSnapshot.docs.isNotEmpty) {
        final data = customersSnapshot.docs.first.data();
        return {
          'id': data['id'],
          'customerName': data['customerName'],
          'mobileNumber': data['mobileNumber'],
          'address': data['address'] ?? '',
        };
      }

      // Try CustomerLogindetails collection
      final loginDetailsSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('id', isEqualTo: customerId)
          .limit(1)
          .get();

      if (loginDetailsSnapshot.docs.isNotEmpty) {
        final data = loginDetailsSnapshot.docs.first.data();
        return {
          'id': data['id'],
          'customerName': data['name'],
          'mobileNumber': data['phonenumber'],
          'address': data['address'] ?? '',
        };
      }

      // Try AMC_user collection
      final amcUserSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('Id', isEqualTo: customerId)
          .limit(1)
          .get();

      if (amcUserSnapshot.docs.isNotEmpty) {
        final data = amcUserSnapshot.docs.first.data();
        return {
          'id': data['Id'],
          'customerName': data['name'],
          'mobileNumber': data['Phone Number'],
          'address': data['address'] ?? '',
        };
      }

      return null;
    } catch (e) {
      print('Error fetching customer data by ID: $e');
      return null;
    }
  }

  // Method to fetch customer data from multiple collections by mobile number
  Future<Map<String, dynamic>?> _fetchCustomerDataByMobile(
    String mobileNumber,
  ) async {
    try {
      // Try customers collection first
      final customersSnapshot = await FirestoreService.instance
          .collection('customers')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (customersSnapshot.docs.isNotEmpty) {
        final data = customersSnapshot.docs.first.data();
        return {
          'id': data['id'],
          'customerName': data['customerName'],
          'mobileNumber': data['mobileNumber'],
          'address': data['address'] ?? '',
        };
      }

      // Try CustomerLogindetails collection
      final loginDetailsSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (loginDetailsSnapshot.docs.isNotEmpty) {
        final data = loginDetailsSnapshot.docs.first.data();
        return {
          'id': data['id'],
          'customerName': data['name'],
          'mobileNumber': data['phonenumber'],
          'address': data['address'] ?? '',
        };
      }

      // Try AMC_user collection
      final amcUserSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('Phone Number', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (amcUserSnapshot.docs.isNotEmpty) {
        final data = amcUserSnapshot.docs.first.data();
        return {
          'id': data['Id'],
          'customerName': data['name'],
          'mobileNumber': data['Phone Number'],
          'address': data['address'] ?? '',
        };
      }

      return null;
    } catch (e) {
      print('Error fetching customer data by mobile: $e');
      return null;
    }
  }

  Future<void> _fetchCustomerDetailsByName() async {
    try {
      // Search in customers collection
      final customersSnapshot = await FirestoreService.instance
          .collection('customers')
          .where('customerName', isEqualTo: widget.customerName)
          .limit(1)
          .get();

      if (customersSnapshot.docs.isNotEmpty) {
        final doc = customersSnapshot.docs.first;
        final data = doc.data();
        setState(() {
          _customerIdController.text = data['id'] ?? '';
          _mobileNumberController.text = data['mobileNumber'] ?? '';
          _addressController.text = data['address'] ?? '';
        });
        return;
      }

      // Try CustomerLogindetails collection
      final loginDetailsSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('name', isEqualTo: widget.customerName)
          .limit(1)
          .get();

      if (loginDetailsSnapshot.docs.isNotEmpty) {
        final doc = loginDetailsSnapshot.docs.first;
        final data = doc.data();
        setState(() {
          _customerIdController.text = data['id'] ?? '';
          _mobileNumberController.text = data['phonenumber'] ?? '';
          _addressController.text = data['address'] ?? '';
        });
        return;
      }

      // Try AMC_user collection
      final amcUserSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('name', isEqualTo: widget.customerName)
          .limit(1)
          .get();

      if (amcUserSnapshot.docs.isNotEmpty) {
        final doc = amcUserSnapshot.docs.first;
        final data = doc.data();
        setState(() {
          _customerIdController.text = data['Id'] ?? '';
          _mobileNumberController.text = data['Phone Number'] ?? '';
          _addressController.text = data['address'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching customer by name: $e');
    }
  }

  Future<void> _fetchCustomerDetailsByCustomerId(String customerId) async {
    if (customerId.isEmpty) return;

    try {
      final customerData = await _fetchCustomerDataById(customerId);

      if (customerData != null) {
        setState(() {
          _customerIdController.text = customerData['id'] ?? customerId;
          _customerNameController.text = customerData['customerName'] ?? '';
          _mobileNumberController.text = customerData['mobileNumber'] ?? '';
          _addressController.text = customerData['address'] ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer details loaded successfully from ${_getCollectionSource(customerData['id'])}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Clear fields if no customer found
        setState(() {
          _customerNameController.clear();
          _mobileNumberController.clear();
          _addressController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer with ID $customerId not found in any collection',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error fetching customer details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching customer details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchCustomerDetailsByMobileNumber(String mobileNumber) async {
    if (mobileNumber.isEmpty) return;

    try {
      final customerData = await _fetchCustomerDataByMobile(mobileNumber);

      if (customerData != null) {
        setState(() {
          _customerIdController.text = customerData['id'] ?? '';
          _customerNameController.text = customerData['customerName'] ?? '';
          _mobileNumberController.text = mobileNumber;
          _addressController.text = customerData['address'] ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer details loaded successfully from ${_getCollectionSource(customerData['id'])}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Clear fields if no customer found
        setState(() {
          _customerIdController.clear();
          _customerNameController.clear();
          _addressController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer with mobile $mobileNumber not found in any collection',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error fetching customer by mobile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching customer details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to determine which collection the data came from
  String _getCollectionSource(String? customerId) {
    if (customerId == null) return 'unknown collection';

    // Check which collection pattern matches
    if (customerId.startsWith('CR')) {
      return 'customers collection';
    } else if (customerId.startsWith('AMC')) {
      return 'AMC_user collection';
    } else {
      return 'CustomerLogindetails collection';
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
        return 'Mobile number already exists in customers collection';
      }

      final customerLoginSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (customerLoginSnapshot.docs.isNotEmpty) {
        return 'Mobile number already exists in customer login details';
      }

      final amcUserSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('Phone Number', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (amcUserSnapshot.docs.isNotEmpty) {
        return 'Mobile number already exists in AMC users';
      }

      return null;
    } catch (e) {
      return 'Error checking mobile number availability';
    } finally {
      setState(() {
        _isCheckingMobileNumber = false;
      });
    }
  }

  Future<String> _generateCustomerId() async {
    setState(() {
      _isGeneratingCustomerId = true;
    });

    try {
      final List<String> allCustomerIds = [];

      // Get IDs from CustomerLogindetails
      final customerLoginSnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .get();
      for (var doc in customerLoginSnapshot.docs) {
        final data = doc.data();
        if (data['id'] != null && data['id'] is String) {
          allCustomerIds.add(data['id'] as String);
        }
      }

      // Get IDs from customers
      final customersSnapshot = await FirestoreService.instance
          .collection('customers')
          .get();
      for (var doc in customersSnapshot.docs) {
        final data = doc.data();
        if (data['id'] != null && data['id'] is String) {
          allCustomerIds.add(data['id'] as String);
        }
      }

      // Get IDs from AMC_user
      final amcUserSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .get();
      for (var doc in amcUserSnapshot.docs) {
        final data = doc.data();
        if (data['Id'] != null && data['Id'] is String) {
          allCustomerIds.add(data['Id'] as String);
        }
      }

      int highestId = 0;
      final RegExp crIdPattern = RegExp(r'^CR(\d+)$');

      for (String id in allCustomerIds) {
        final match = crIdPattern.firstMatch(id);
        if (match != null) {
          final number = int.tryParse(match.group(1)!);
          if (number != null && number > highestId) {
            highestId = number;
          }
        }
      }

      final nextId = highestId + 1;
      final customerId = 'CR${nextId.toString().padLeft(3, '0')}';

      return customerId;
    } catch (e) {
      return 'CR001';
    } finally {
      setState(() {
        _isGeneratingCustomerId = false;
      });
    }
  }

  Future<void> _saveCustomerToLoginDetails() async {
    if (_customerType == 'new' &&
        _customerNameController.text.isNotEmpty &&
        _mobileNumberController.text.isNotEmpty &&
        _customerIdController.text.isNotEmpty) {
      try {
        await FirestoreService.instance
            .collection('CustomerLogindetails')
            .doc(_customerIdController.text)
            .set({
              'id': _customerIdController.text,
              'name': _customerNameController.text,
              'phonenumber': _mobileNumberController.text,
              'timestamp': Timestamp.now(),
              'createdAt': FieldValue.serverTimestamp(),
              "otpstatus": "verified",
            });
      } catch (e) {
        // Continue flow even if this fails
      }
    }
  }

  Future<void> _fetchDeviceTypes() async {
    setState(() {
      _isDeviceTypesLoading = true;
    });
    try {
      final snapshot = await FirestoreService.instance
          .collection('deviceDetails')
          .get();
      final types = snapshot.docs
          .map((doc) => doc['deviceType']?.toString().trim())
          .where((type) => type != null && type.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      // Sort the types alphabetically
      types.sort();

      // Add 'Others' if not already present
      if (!types.contains('Others')) {
        types.add('Others');
      }

      setState(() {
        deviceTypes = types;
      });
    } catch (e) {
      print('Error fetching device types: $e');
      setState(() {
        deviceTypes = ['Others'];
      });
    } finally {
      setState(() {
        _isDeviceTypesLoading = false;
      });
    }
  }

  Future<void> _fetchGlobalDeviceBrands() async {
    setState(() {
      _isDeviceBrandsLoading = true;
    });
    try {
      final brands = await _brandBackend.fetchAllDeviceBrands();
      setState(() {
        deviceBrands = brands;
        if (!deviceBrands.contains('Others')) {
          deviceBrands.add('Others');
        }
      });
    } catch (e) {
      print('Error fetching global device brands: $e');
      setState(() {
        deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
      });
    } finally {
      setState(() {
        _isDeviceBrandsLoading = false;
      });
    }
  }

  /* Future<void> _fetchDeviceBrands(String deviceType) async {
    // This method is kept for reference but we are now using _fetchGlobalDeviceBrands
  } */

  List<String> get currentDeviceConditions {
    if (deviceType.toLowerCase() == 'cctv') {
      return [
        'Completely down',
        'Partially working',
        'Maintenance',
        'New Installation',
      ];
    }
    return ['Completely down', 'Partially working'];
  }

  Future<String> _generateBookingId() async {
    final counterRef = FirestoreService.instance
        .collection('counters')
        .doc('bookingId');

    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 0;
      if (snapshot.exists &&
          snapshot.data() != null &&
          snapshot.data()!['lastBookingId'] != null) {
        lastId = snapshot.data()!['lastBookingId'] as int;
      }
      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastBookingId': nextId});
      return nextId.toString();
    });
  }

  void _handleSubmit() async {
    setState(() {
      _mobileNumberError = '';
    });

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_customerType == 'new') {
        final mobileError = await _checkMobileNumberExists(
          _mobileNumberController.text.trim(),
        );
        if (mobileError != null) {
          setState(() {
            _mobileNumberError = mobileError;
          });
          return;
        }
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        if (_customerType == 'new') {
          await _saveCustomerToLoginDetails();
        }

        final bookingId = await _generateBookingId();
        final actualDeviceType = deviceType == 'Others'
            ? _customDeviceTypeController.text.trim()
            : deviceType;
        final actualDeviceBrand = deviceBrand == 'Others'
            ? _customDeviceBrandController.text.trim()
            : deviceBrand;

        Map<String, dynamic> customerData = {
          'id': _customerIdController.text,
          'bookingId': bookingId,
          'customerName': _customerNameController.text,
          'mobileNumber': _mobileNumberController.text,
          'address': _addressController.text,
          'categoryName': widget.categoryName,
          'timestamp': Timestamp.now(),
          'JobType': jobType,
          'customerType': _customerType,
        };

        if (jobType == 'Service') {
          customerData.addAll({
            'deviceType': actualDeviceType,
            'deviceBrand': actualDeviceBrand,
            'deviceCondition': deviceCondition,
            'message': _messageController.text,
          });
        } else if (jobType == 'Delivery') {
          customerData.addAll({'message': _descriptionController.text});
        }

        final adminData = Map<String, dynamic>.from(customerData);
        adminData['adminStatus'] = 'Open';
        adminData['customerStatus'] = 'Ticket Created';
        adminData['engineerStatus'] = 'Not Assigned';

        String docId = bookingId;

        await FirestoreService.instance
            .collection('customers')
            .doc(docId)
            .set(customerData);

        await FirestoreService.instance
            .collection('Admin_details')
            .doc(docId)
            .set(adminData);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/success.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Details Submitted Successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _customerType == 'new'
                      ? 'New customer registered and ticket created!'
                      : 'Our team will contact you soon.',
                  textAlign: TextAlign.center,
                ),
                if (_customerType == 'new')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Customer ID: ${_customerIdController.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearFormForNewCustomer() async {
    setState(() {
      _customerNameController.clear();
      _mobileNumberController.clear();
      _addressController.clear();
      _messageController.clear();
      _descriptionController.clear();
      _customDeviceTypeController.clear();
      _customDeviceBrandController.clear();
      jobType = '';
      deviceType = '';
      deviceBrand = '';
      deviceCondition = '';
      _mobileNumberError = '';
    });

    final newCustomerId = await _generateCustomerId();
    setState(() {
      _customerIdController.text = newCustomerId;
    });
  }

  Widget _buildCustomerTypeButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          elevation: isSelected ? 4 : 1,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Expanded(
            child: Divider(
              color: Theme.of(context).dividerColor,
              thickness: 1,
              indent: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          focusNode: focusNode,
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 13,
            ),
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          maxLines: maxLines,
          validator:
              required
                  ? (validator ??
                      (value) =>
                          value == null || value.isEmpty
                              ? '$label is required'
                              : null)
                  : null,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }

  Widget _buildMobileNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Mobile Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _mobileNumberError.isNotEmpty
                  ? Colors.red.shade400
                  : Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _mobileNumberController,
            focusNode: _mobileNumberFocusNode,
            decoration: InputDecoration(
              hintText: 'Enter 10-digit mobile number',
              hintStyle: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              prefixIcon: Icon(
                Icons.phone_android,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              suffixIcon:
                  _isCheckingMobileNumber
                      ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      )
                      : _mobileNumberError.isNotEmpty
                      ? Icon(Icons.error_outline, color: Colors.red.shade400)
                      : null,
            ),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Mobile Number is required';
              }
              if (value.length != 10) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
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
                    style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                  ),
                ),
              ],
            ),
          ),
        if (_customerType == 'new' && _mobileNumberError.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'We\'ll check if this number is already registered',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              prefixIcon: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            ),
            dropdownColor: Theme.of(context).cardColor,
            icon: Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).primaryColor,
            ),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            items: options.map((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Text(
                  val,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator:
                required
                    ? (value) =>
                        value == null || value.isEmpty
                            ? '$label is required'
                            : null
                    : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Create New Ticket",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader('Customer Information', Icons.person_outline),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCustomerTypeButton(
                    'Existing Customer',
                    _customerType == 'existing',
                    () {
                      setState(() {
                        _customerType = 'existing';
                        _mobileNumberError = '';
                        _customerIdController.text = widget.customerId;
                        _customerNameController.text = widget.customerName;
                        _mobileNumberController.text = widget.mobileNumber;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildCustomerTypeButton(
                    'New Customer',
                    _customerType == 'new',
                    () {
                      setState(() {
                        _customerType = 'new';
                        _mobileNumberError = '';
                      });
                      _clearFormForNewCustomer();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                title: _customerType == 'existing' ? 'Find Customer' : 'Register New Customer',
                icon: _customerType == 'existing' ? Icons.search : Icons.person_add,
                color: Theme.of(context).primaryColor,
                child: Column(
                  children: [
                    _buildCustomerIdField(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Customer Name',
                      'Enter full name',
                      Icons.person,
                      _customerNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildMobileNumberField(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Job Details', Icons.work_outline),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: 'Service Information',
                icon: Icons.build_circle,
                color: Colors.orange.shade600,
                child: Column(
                  children: [
                    _buildDropdownField(
                      'Job Type',
                      jobTypes,
                      Icons.work,
                      (value) {
                        setState(() {
                          jobType = value ?? '';
                          if (jobType == 'Delivery') {
                            deviceType = '';
                            deviceBrand = '';
                            deviceCondition = '';
                            _messageController.clear();
                            _customDeviceTypeController.clear();
                            _customDeviceBrandController.clear();
                          } else {
                            _descriptionController.clear();
                          }
                        });
                      },
                      value: jobType.isNotEmpty ? jobType : null,
                    ),
                    if (jobType == 'Service') ...[
                      const SizedBox(height: 16),
                      if (_isDeviceTypesLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        _buildDropdownField(
                          'Device Type',
                          deviceTypes,
                          Icons.devices,
                          (value) async {
                            setState(() {
                              deviceType = value ?? '';
                              if (deviceType != 'Others') {
                                _customDeviceTypeController.clear();
                              }
                              deviceBrand = '';
                              _customDeviceBrandController.clear();
                            });
                          },
                          value: deviceType.isNotEmpty ? deviceType : null,
                        ),
                        if (deviceType == 'Others')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildTextField(
                              'Custom Device Type',
                              'Enter your device type',
                              Icons.devices_other,
                              _customDeviceTypeController,
                              required: true,
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      if (_isDeviceBrandsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        _buildDropdownField(
                          'Device Brand',
                          deviceBrands.isNotEmpty
                              ? deviceBrands
                              : ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'],
                          Icons.branding_watermark,
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
                              'Enter your device brand',
                              Icons.branding_watermark,
                              _customDeviceBrandController,
                              required: true,
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        'Device Condition',
                        currentDeviceConditions,
                        Icons.build,
                        (value) {
                          setState(() {
                            deviceCondition = value ?? '';
                          });
                        },
                        value: deviceCondition.isNotEmpty ? deviceCondition : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Additional Message',
                        'Enter any additional details about the issue',
                        Icons.message,
                        _messageController,
                        maxLines: 3,
                        required: false,
                      ),
                    ],
                    if (jobType == 'Delivery') ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Delivery Description',
                        'Enter delivery details',
                        Icons.description,
                        _descriptionController,
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Address',
                      'Enter complete address',
                      Icons.location_on,
                      _addressController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: _isSubmitting
                    ? CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      )
                    : GradientButton(onPressed: _handleSubmit, text: 'Submit Ticket'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Customer ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _customerType == 'new'
                ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _customerIdController,
            focusNode: _customerIdFocusNode,
            readOnly: _customerType == 'new',
            decoration: InputDecoration(
              hintText: _customerType == 'new' ? 'Auto-generated' : 'Enter customer ID',
              hintStyle: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
                fontStyle: _customerType == 'new' ? FontStyle.italic : FontStyle.normal,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              prefixIcon: Icon(
                Icons.perm_identity,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              suffixIcon:
                  _customerType == 'new' && _isGeneratingCustomerId
                      ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      )
                      : null,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  _customerType == 'new' ? FontWeight.w500 : FontWeight.normal,
              color:
                  _customerType == 'new'
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Customer ID is required' : null,
          ),
        ),
        if (_customerType == 'new')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Customer ID is automatically generated and read-only',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}