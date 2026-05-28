import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/backend/brand_model_backend.dart';
import 'package:lottie/lottie.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:flutter/services.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/location_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'dart:io';

// -- CustomerHomePage now gets these values upon navigation --
class CustomerHomePage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String mobileNumber;
  final String categoryName;
  final String? initialJobType;
  final String? initialDeviceType;
  final String? initialCustomDeviceType;

  const CustomerHomePage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.mobileNumber,
    required this.categoryName,
    this.initialJobType,
    this.initialDeviceType,
    this.initialCustomDeviceType,
  });

  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
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
  final TextEditingController _customDeviceConditionController =
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
  bool _isFetchingLocation = false;
  bool _isGeoLocationEnabled = true; // Default to true until checked
  picker.PlatformFile? _selectedFile;
  Map<String, dynamic>? _currentLocationData;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with passed values
    _customerIdController = TextEditingController(text: widget.customerId);
    _customerNameController = TextEditingController(text: widget.customerName);
    _mobileNumberController = TextEditingController(text: widget.mobileNumber);

    _checkGeoLocationSetting();
    _fetchDeviceTypes();
    jobType = widget.initialJobType ?? '';
    deviceType = widget.initialDeviceType ?? '';
    if (widget.initialCustomDeviceType != null) {
      _customDeviceTypeController.text = widget.initialCustomDeviceType!;
    }

    // Auto-fetch brands if device type is pre-selected
    if (deviceType.isNotEmpty) {
      _fetchDeviceBrands(deviceType);
    }

    // Fetch customer details by name to automatically fill ID and mobile
    _fetchCustomerDetailsByName();

    // Register FCM token for redundancy
    if (widget.customerId.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      NotificationService.instance.registerToken(
        role: 'customer',
        userId: widget.customerId,
        email: email,
      );
    }
  }

  Future<void> _fetchCustomerDetailsByName() async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('name', isEqualTo: widget.customerName)
          .where('Phone Number', isEqualTo: widget.mobileNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _customerIdController.text = doc['Id'] ?? '';
          _mobileNumberController.text = doc['Phone Number'] ?? '';
        });
      }
    } catch (e) {
      // Optionally handle the error (e.g., show Snackbar or log)
    }
  }

  Future<void> _checkGeoLocationSetting() async {
    try {
      final databaseName = ThemeService.instance.databaseName;
      final subscriptionData = await FirestoreService.instance
          .getTenantSubscriptionData(tenantId: databaseName, appId: 'data');

      if (subscriptionData != null) {
        setState(() {
          // If geoLocation field exists, use its value, otherwise default to true
          _isGeoLocationEnabled = subscriptionData['geoLocation'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error checking geoLocation setting: $e');
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
          .map((doc) => doc['deviceType']?.toString())
          .where((type) => type != null && type.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      if (!types.contains('Others')) {
        types.add('Others');
      }
      setState(() {
        deviceTypes = types;
      });
    } catch (e) {
      setState(() {
        deviceTypes = ['Others'];
      });
    } finally {
      setState(() {
        _isDeviceTypesLoading = false;
      });
    }
  }

  Future<void> _fetchDeviceBrands(String deviceType) async {
    setState(() {
      _isDeviceBrandsLoading = true;
      deviceBrands = [];
    });

    try {
      // Strictly fetch from the master 'devicesbrands' collection as requested
      final brands = await BrandModelBackend().fetchAllDeviceBrands();

      if (!brands.contains('Others')) {
        brands.add('Others');
      }

      setState(() {
        deviceBrands = brands;
      });
    } catch (e) {
      print('Error fetching device brands: $e');
      setState(() {
        deviceBrands = ['Others'];
      });
    } finally {
      setState(() {
        _isDeviceBrandsLoading = false;
      });
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
    _customDeviceConditionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NotificationService.instance.showNotification(
            title: 'Test Notification',
            body: 'If you see this, local notifications are working!',
          );
        },
        child: const Icon(Icons.notifications_active),
      ),
      appBar: AppBar(
        title: Text(
          ThemeService.instance.appName,
          style: TextStyle(
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTextField(
                'Customer ID',
                '',
                Icons.perm_identity,
                _customerIdController,
                enabled: false,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Customer Name',
                '',
                Icons.person,
                _customerNameController,
                enabled: false,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Mobile Number',
                '',
                Icons.phone,
                _mobileNumberController,
                enabled: false,
              ),
              const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _isDeviceTypesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDropdownField(
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
                          if (value != null && value != 'Others') {
                            await _fetchDeviceBrands(value);
                          } else {
                            // Fetch dynamic brands from master collection for "Others" or null
                            final brands = await BrandModelBackend()
                                .fetchAllDeviceBrands();
                            if (!brands.contains('Others')) {
                              brands.add('Others');
                            }
                            setState(() {
                              deviceBrands = brands;
                            });
                          }
                        },
                        value: deviceType.isNotEmpty ? deviceType : null,
                      ),
                if (deviceType == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                      'Custom Device Type',
                      'Enter your device type',
                      Icons.devices_other,
                      _customDeviceTypeController,
                    ),
                  ),
                const SizedBox(height: 20),
                _isDeviceBrandsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDropdownField(
                        'Device Brand',
                        deviceBrands.isNotEmpty ? deviceBrands : ['Others'],
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
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                      'Custom Device Brand',
                      'Enter your device brand',
                      Icons.branding_watermark,
                      _customDeviceBrandController,
                    ),
                  ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  'Device Condition',
                  currentDeviceConditions,
                  Icons.build,
                  (value) {
                    setState(() {
                      deviceCondition = value ?? '';
                      if (deviceCondition != 'Others') {
                        _customDeviceConditionController.clear();
                      }
                    });
                  },
                  value: deviceCondition.isNotEmpty ? deviceCondition : null,
                ),
                if (deviceCondition == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                      'Custom Device Condition',
                      'Enter device condition',
                      Icons.build_circle,
                      _customDeviceConditionController,
                    ),
                  ),
                const SizedBox(height: 20),
                _buildTextField(
                  'Message',
                  'Enter additional details',
                  Icons.message,
                  _messageController,
                  maxLines: 3,
                ),
              ],
              if (jobType == 'Delivery') ...[
                const SizedBox(height: 20),
                _buildTextField(
                  'Description',
                  'Enter delivery description',
                  Icons.description,
                  _descriptionController,
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              _buildTextField(
                'Address',
                'Enter your address',
                Icons.location_on,
                _addressController,
                maxLines: 2,
                suffixIcon: _isGeoLocationEnabled
                    ? IconButton(
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.my_location,
                                color: Theme.of(context).primaryColor,
                              ),
                        onPressed: _isFetchingLocation
                            ? null
                            : _handleLocationPinTap,
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              _buildFileUploadField(),
              const SizedBox(height: 30),
              Center(
                child: _isSubmitting
                    ? CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      )
                    : GradientButton(onPressed: _handleSubmit, text: 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please fill in the service request details below',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
    bool enabled = true,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: enabled
                  ? Theme.of(context).cardColor
                  : Theme.of(context).disabledColor.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 15,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              suffixIcon: suffixIcon,
            ),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
            maxLines: maxLines,
            enabled: enabled,
            validator:
                validator ??
                (value) => value == null || value.isEmpty
                    ? '$label is required'
                    : null,
            inputFormatters: inputFormatters,
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents / Files',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _handleFilePick,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFile != null
                      ? Icons.file_present
                      : Icons.upload_file,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFile != null
                        ? _selectedFile!.name
                        : 'Upload Customer Documents (PDF, JPG, PNG, DOC)',
                    style: TextStyle(
                      color: _selectedFile != null
                          ? Colors.black87
                          : Colors.grey,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
              ],
            ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 15,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Theme.of(context).primaryColor),
              ),
            ),
            items: options.map((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Text(val, style: const TextStyle(color: Colors.black87)),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (value) =>
                value == null || value.isEmpty ? '$label is required' : null,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  List<String> get currentDeviceConditions {
    if (deviceType.toLowerCase() == 'cctv') {
      return [
        'Completely down',
        'Partially working',
        'Maintenance',
        'New Installation',
        'Others',
      ];
    }
    return ['Completely down', 'Partially working', 'Others'];
  }

  Future<String> _generateBookingId() async {
    final counterRef = FirestoreService.instance
        .collection('counters')
        .doc('bookingId');
    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 1700;
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

  Future<void> _handleLocationPinTap() async {
    setState(() => _isFetchingLocation = true);
    try {
      final locationData = await LocationService.instance
          .getCurrentLocationData();
      if (locationData != null) {
        setState(() {
          _currentLocationData = locationData;
          _addressController.text = locationData['address'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please check permissions.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _handleFilePick() async {
    try {
      final result = await picker.FilePicker.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx', 'jpeg'],
      );

      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _selectedFile = result.files.first;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File selected successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSubmitting = true;
      });

      try {
        final bookingId = await _generateBookingId();
        final actualDeviceType = deviceType == 'Others'
            ? _customDeviceTypeController.text.trim()
            : deviceType;
        final actualDeviceBrand = deviceBrand == 'Others'
            ? _customDeviceBrandController.text.trim()
            : deviceBrand;
        final actualDeviceCondition = deviceCondition == 'Others'
            ? _customDeviceConditionController.text.trim()
            : deviceCondition;

        // Handle file upload if a file is selected
        String? fileUrl;
        if (_selectedFile != null && _selectedFile!.path != null) {
          fileUrl = await StorageService.instance.uploadCustomerFile(
            customerId: _customerIdController.text,
            file: File(_selectedFile!.path!),
            originalFileName: _selectedFile!.name,
          );
        }

        Map<String, dynamic> customerData = {
          'id': _customerIdController.text, // Add fixed customer id
          'bookingId': bookingId,
          'customerName': _customerNameController.text,
          'mobileNumber': _mobileNumberController.text,
          'address': _addressController.text,
          'categoryName': widget.categoryName,
          'timestamp': Timestamp.now(),
          'JobType': jobType,
          'customerFileUrl': fileUrl,
          'fileName': _selectedFile?.name,
        };

        // Add location data if available
        if (_currentLocationData != null) {
          customerData['latitude'] = _currentLocationData!['latitude'];
          customerData['longitude'] = _currentLocationData!['longitude'];
        }

        if (jobType == 'Service') {
          customerData.addAll({
            'deviceType': actualDeviceType,
            'deviceBrand': actualDeviceBrand,
            'deviceCondition': actualDeviceCondition,
            'message': _messageController.text,
          });
        } else if (jobType == 'Delivery') {
          customerData.addAll({'message': _descriptionController.text});
        }

        // Also store in Admin_details
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

        // Add real-time notification for Admin
        try {
          await FirestoreService.instance.collection('notifications').add({
            'audience': 'admin',
            'title': 'New Ticket Received',
            'body': 'A new ticket ($bookingId) has been raised by ${_customerNameController.text}',
            'timestamp': FieldValue.serverTimestamp(),
            'seen': false,
            'type': 'new_ticket',
            'bookingId': bookingId,
            'customerName': _customerNameController.text,
          });
        } catch (e) {
          debugPrint('Error adding admin notification: $e');
        }

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                Text(
                  'Details Submitted Successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our team will contact you soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  'OK',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
