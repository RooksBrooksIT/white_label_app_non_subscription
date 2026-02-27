import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:lottie/lottie.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';

class ProfessionalTheme {
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color primaryDark(BuildContext context) =>
      Theme.of(context).primaryColor;
  static Color primaryLight(BuildContext context) =>
      Theme.of(context).primaryColor.withOpacity(0.8);
  static Color primaryExtraLight(BuildContext context) =>
      Theme.of(context).primaryColor.withOpacity(0.1);

  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) => Theme.of(context).cardColor;
  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).cardColor;

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static Color info(BuildContext context) => Theme.of(context).primaryColor;
  static const Color infoLight = Color(0xFFCFFAFE);

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A);
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B);
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).hintColor;
  static Color textInverse(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static Color borderLight(BuildContext context) =>
      Theme.of(context).dividerColor.withOpacity(0.5);
  static Color borderMedium(BuildContext context) =>
      Theme.of(context).dividerColor;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];
}

// Professional Animations
class ProfessionalAnimations {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  static Curve easeInOut = Curves.easeInOut;
  static Curve elasticOut = Curves.elasticOut;
}

class AmcCustomerHomePage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const AmcCustomerHomePage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  _AmcCustomerHomePageState createState() => _AmcCustomerHomePageState();
}

class _AmcCustomerHomePageState extends State<AmcCustomerHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerIdController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _mobileNumberController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customDeviceTypeController =
      TextEditingController();
  final TextEditingController _customDeviceBrandController =
      TextEditingController();

  late String deviceType = '';
  String deviceBrand = '';
  String deviceCondition = '';

  final List<String> jobTypes = ['Service', 'Delivery'];
  String jobType = '';

  List<String> deviceTypes = [];
  bool _isDeviceTypesLoading = false;

  List<String> deviceBrands = [];
  bool _isDeviceBrandsLoading = false;

  bool _isSubmitting = false;
  bool _isLoadingMobileNumber = true;

  @override
  void initState() {
    super.initState();

    _customerIdController = TextEditingController(text: widget.customerId);
    _customerNameController = TextEditingController(text: widget.customerName);
    _mobileNumberController = TextEditingController();

    // Fetch mobile number and device types
    _fetchMobileNumber();
    _fetchDeviceTypes();
  }

  Future<void> _fetchMobileNumber() async {
    setState(() {
      _isLoadingMobileNumber = true;
    });

    try {
      final docSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .doc(widget.customerId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final mobileNumber =
            data?['mobileNumber']?.toString() ??
            data?['Phone Number']?.toString() ??
            data?['contactNumber']?.toString() ??
            'Not available';

        _mobileNumberController.text = mobileNumber;
      } else {
        _mobileNumberController.text = 'Not found';
      }
    } catch (e) {
      print('Error fetching mobile number: $e');
      _mobileNumberController.text = 'Error loading';
    } finally {
      setState(() {
        _isLoadingMobileNumber = false;
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
    _descriptionController.dispose();
    super.dispose();
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
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      if (!types.contains('Others')) types.add('Others');

      setState(() {
        deviceTypes = types;
      });
    } catch (_) {
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
      String? collectionName;
      switch (deviceType.toLowerCase()) {
        case 'desktop':
          collectionName = 'desktopBrands';
          break;
        case 'laptop':
          collectionName = 'laptopBrands';
          break;
        case 'cctv':
          collectionName = 'cctvBrands';
          break;
        case 'projector':
          collectionName = 'projectorBrands';
          break;
        case 'printer':
          collectionName = 'printerBrands';
          break;
        default:
          collectionName = null;
      }

      if (collectionName != null) {
        final snapshot = await FirestoreService.instance
            .collection(collectionName)
            .get();
        final brands =
            snapshot.docs
                .map(
                  (doc) =>
                      doc['brandName']?.toString() ??
                      doc['name']?.toString() ??
                      doc['brand']?.toString() ??
                      '',
                )
                .where((b) => b.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        if (!brands.contains('Others')) brands.add('Others');

        setState(() {
          deviceBrands = brands;
        });
      } else {
        setState(() {
          deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
        });
      }
    } catch (_) {
      setState(() {
        deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
      });
    } finally {
      setState(() {
        _isDeviceBrandsLoading = false;
      });
    }
  }

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
      int lastId = 1700;
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['lastBookingId'] != null) {
          lastId = data['lastBookingId'] as int;
        }
      }
      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastBookingId': nextId});
      return nextId.toString();
    });
  }

  void _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
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

        Map<String, dynamic> customerData = {
          'id': _customerIdController.text,
          'bookingId': bookingId,
          'customerName': _customerNameController.text,
          'mobileNumber': _mobileNumberController.text,
          'address': _addressController.text,
          'categoryName': "",
          'timestamp': Timestamp.now(),
          'JobType': jobType,
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

        if (!mounted) return;
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
                const Text(
                  'Our team will contact you soon.',
                  textAlign: TextAlign.center,
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool enabled = true,
    bool showLoading = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: enabled
                    ? Theme.of(context).cardColor
                    : Theme.of(context).disabledColor.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 15,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              maxLines: maxLines,
              enabled: enabled,
              validator:
                  validator ??
                  (v) => (v == null || v.isEmpty) ? '$label is required' : null,
              inputFormatters: inputFormatters,
            ),
            if (showLoading && _isLoadingMobileNumber)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 15,
            ),
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          items: options
              .map(
                (val) => DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (v) =>
              (v == null || v.isEmpty) ? '$label is required' : null,
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ProfessionalTheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout,
                  color: ProfessionalTheme.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ProfessionalTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: ProfessionalTheme.borderMedium(context),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: ProfessionalTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _performLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: ProfessionalTheme.textInverse(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performLogout() async {
    if (mounted) {
      Navigator.pop(context);
    }
    await AuthStateService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: CustomerNavigationDrawer(
        userName: widget.customerName,
        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        onLogout: _showLogoutConfirmation,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 140,
              collapsedHeight: 64,
              floating: true,
              pinned: true,
              backgroundColor: ProfessionalTheme.primary(context),
              elevation: 0,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ),
              ],
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: AnimatedOpacity(
                  duration: ProfessionalAnimations.quick,
                  opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                  child: Text(
                    'Customer Dashboard',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ProfessionalTheme.primary(context),
                            ProfessionalTheme.primaryDark(context),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 20,
                      right: 20,
                      child: Row(
                        children: [
                          if (ThemeService.instance.logoUrl != null)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(
                                  ThemeService.instance.logoUrl!,
                                ),
                              ),
                            ),
                          if (ThemeService.instance.logoUrl != null)
                            const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ThemeService.instance.appName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.7),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.customerName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            ),
          ];
        },
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
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
                  showLoading: true,
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
                              setState(() {
                                deviceBrands = [
                                  'DELL',
                                  'HP',
                                  'MAC',
                                  'LENOVO',
                                  'ASUS',
                                  'Others',
                                ];
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
                          deviceBrands.isNotEmpty
                              ? deviceBrands
                              : [
                                  'DELL',
                                  'HP',
                                  'MAC',
                                  'LENOVO',
                                  'ASUS',
                                  'Others',
                                ],
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
                      });
                    },
                    value: deviceCondition.isNotEmpty ? deviceCondition : null,
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
                ),
                const SizedBox(height: 30),
                Center(
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : GradientButton(
                          onPressed: _handleSubmit,
                          text: 'Submit',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
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

class CustomerNavigationDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const CustomerNavigationDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ProfessionalTheme.surface(context),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: ProfessionalTheme.primary(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirestoreService.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .get(),
                  builder: (context, snapshot) {
                    String? photoUrl;
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      photoUrl = data?['photoUrl'] ?? data?['profileImage'];
                    }
                    photoUrl ??= FirebaseAuth.instance.currentUser?.photoURL;

                    return CircleAvatar(
                      radius: 32,
                      backgroundColor: ProfessionalTheme.textInverse(
                        context,
                      ).withOpacity(0.2),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Icon(
                              Icons.person,
                              size: 32,
                              color: ProfessionalTheme.textInverse(context),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalTheme.textInverse(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: ProfessionalTheme.textInverse(
                      context,
                    ).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.logout,
                    title: 'Logout',
                    isLogout: true,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isSelected = false,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? ProfessionalTheme.primary(context).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout
              ? ProfessionalTheme.error
              : (isSelected
                    ? ProfessionalTheme.primary(context)
                    : ProfessionalTheme.textSecondary(context)),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isLogout
                ? ProfessionalTheme.error
                : ProfessionalTheme.textPrimary(context),
          ),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
