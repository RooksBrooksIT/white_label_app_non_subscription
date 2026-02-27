import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_home_page.dart';
import 'package:subscription_rooks_app/utils/responsive_helper.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class Device {
  final String id;
  final String deviceId;
  final String name;
  final String iconData;
  final Color color;
  final String description;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.iconData,
    required this.color,
    required this.description,
  });

  factory Device.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Color parseColor(String colorString) {
      try {
        String hex = colorString.replaceFirst('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex';
        }
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        return ThemeService.instance.primaryColor;
      }
    }

    return Device(
      id: doc.id,
      deviceId: (data['deviceId'] ?? data['brandId'] ?? '').toString(),
      name: (data['deviceType'] ?? 'Unknown Device').toString(),
      iconData: data['icon']?.toString() ?? 'devices',
      color: parseColor(
        data['color'] ??
            ThemeService.instance.primaryColor.value
                .toRadixString(16)
                .padLeft(8, '0'),
      ),
      description: (data['description'] ?? 'Professional Device Service')
          .toString(),
    );
  }

  IconData get icon {
    Map<String, IconData> iconMap = {
      'desktop': Icons.computer_rounded,
      'laptop': Icons.laptop_mac_rounded,
      'printer': Icons.print_rounded,
      'projector': Icons.videocam_rounded,
      'tablet': Icons.tablet_mac_rounded,
      'cctv': Icons.nest_cam_wired_stand_outlined,
      'keyboard': Icons.keyboard_rounded,
      'cpu': Icons.memory_rounded,
      'monitor': Icons.desktop_windows_rounded,
      'router': Icons.router_rounded,
      'phone': Icons.phone_iphone_rounded,
      'scanner': Icons.scanner_rounded,
      'mouse': Icons.mouse_rounded,
      'cable': Icons.usb_rounded,
      'ram': Icons.sd_storage_rounded,
      'hard drive': Icons.storage_rounded,
      'ssd': Icons.sd_card_rounded,
      'others': Icons.devices_rounded,

      // ✨ Hardware
      'webcam': Icons.videocam_rounded,
      'speaker': Icons.speaker_rounded,
      'headset': Icons.headset_rounded,
      'smart watch': Icons.watch_rounded,
      'microphone': Icons.mic_rounded,
      'tv': Icons.tv_rounded,
      'ups': Icons.electrical_services_rounded,
      'access point': Icons.wifi_rounded,
      'barcode scanner': Icons.qr_code_scanner_rounded,
      'game controller': Icons.sports_esports_rounded,
      'bluetooth device': Icons.bluetooth_rounded,
      'server': Icons.dns_rounded,
      'network switch': Icons.swap_horiz_rounded,
      'firewall': Icons.security_rounded,
      'biometrics': Icons.fingerprint_rounded,
      'intercom': Icons.speaker_phone_rounded,
      'access control': Icons.sensor_door_rounded,
      'accesscontrol': Icons.sensor_door_rounded,

      // 🏠 Home Appliances (NEW)
      'fan': Icons.mode_fan_off_rounded,
      'ceiling fan': Icons.mode_fan_off_rounded,
      'ac': Icons.ac_unit_rounded,
      'air conditioner': Icons.ac_unit_rounded,
      'refrigerator': Icons.kitchen_rounded,
      'fridge': Icons.kitchen_rounded,
      'washing machine': Icons.local_laundry_service_rounded,
      'microwave': Icons.microwave_rounded,
      'oven': Icons.microwave_rounded,
      'iron box': Icons.iron_rounded,
      'iron': Icons.iron_rounded,
      'vacuum cleaner': Icons.cleaning_services_rounded,
      'water heater': Icons.hot_tub_rounded,
      'geyser': Icons.hot_tub_rounded,
      'light': Icons.lightbulb_rounded,
      'bulb': Icons.lightbulb_rounded,
      'lamp': Icons.light_rounded,
      'door bell': Icons.doorbell_rounded,
      'doorbell': Icons.doorbell_rounded,
      'gas stove': Icons.local_fire_department_rounded,
      'stove': Icons.local_fire_department_rounded,
    };

    return iconMap[name.toLowerCase()] ?? Icons.devices_rounded;
  }
}

class CustomerDeviceType extends StatefulWidget {
  final String name;
  final String loggedInName;
  final String phoneNumber;
  final String customerId;

  const CustomerDeviceType({
    super.key,
    required this.name,
    required this.loggedInName,
    required this.phoneNumber,
    required this.customerId,
  });

  @override
  State<CustomerDeviceType> createState() => _CustomerDeviceTypeState();
}

class _CustomerDeviceTypeState extends State<CustomerDeviceType> {
  final FirestoreService _firestore = FirestoreService.instance;
  List<Device> allDevices = [];
  bool isLoading = true;
  bool showDeviceSelection = false;
  String? selectedDeviceId;
  final TextEditingController otherController = TextEditingController();
  String otherDeviceName = '';

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    try {
      print('DEBUG: Fetching devices from deviceDetails...');
      QuerySnapshot querySnapshot = await _firestore
          .collection('deviceDetails')
          .orderBy('deviceType')
          .get();

      print('DEBUG: Fetched ${querySnapshot.docs.length} devices total');
      List<Device> devices = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('DEBUG: Doc ID: ${doc.id}, Data: $data');
        devices.add(Device.fromFirestore(doc));
      }

      setState(() {
        allDevices = devices;
        isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error fetching devices: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);
    final isMobile = ResponsiveHelper.isMobile;
    final isTablet = ResponsiveHelper.isTablet;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Modern App Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: ResponsiveHelper.getResponsiveHeight(6.5),
              bottom: ResponsiveHelper.getResponsiveHeight(3),
              left: ResponsiveHelper.getResponsiveWidth(5),
              right: ResponsiveHelper.getResponsiveWidth(5),
            ),
            child: Row(
              children: [
                if (showDeviceSelection)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        showDeviceSelection = false;
                        selectedDeviceId = null;
                      });
                    },
                    icon: Container(
                      width: ResponsiveHelper.getResponsiveWidth(9),
                      height: ResponsiveHelper.getResponsiveWidth(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: ResponsiveHelper.getResponsiveWidth(4.5),
                        color: Colors.white,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showDeviceSelection
                            ? 'Select Your Device'
                            : 'Welcome, ${widget.loggedInName}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Inter',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showDeviceSelection
                            ? 'Choose your device type'
                            : 'What service do you need today?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ResponsiveHelper.getResponsiveWidth(11),
                  height: ResponsiveHelper.getResponsiveWidth(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: ResponsiveHelper.getResponsiveWidth(5),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(5)),
                child: !showDeviceSelection
                    ? _buildServiceSelection()
                    : _buildDeviceSelection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection() {
    final isMobile = ResponsiveHelper.isMobile;
    final serviceGridCount = isMobile ? 2 : 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).textTheme.titleLarge?.color ??
                const Color(0xFF1E293B),
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the service that matches your needs',
          style: TextStyle(
            fontSize: 14,
            color:
                Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 32),

        // Service Cards
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: serviceGridCount,
            crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(3),
            mainAxisSpacing: ResponsiveHelper.getResponsiveWidth(3),
            childAspectRatio: isMobile ? 0.8 : 1.0,
          ),
          children: [
            _buildServiceCard(
              title: 'Service',
              subtitle: 'Professional repair service',
              icon: Icons.handyman_rounded,
              onTap: () {
                setState(() {
                  showDeviceSelection = true;
                });
              },
            ),
            _buildServiceCard(
              title: 'Request',
              subtitle: 'Pickup & drop-off service',
              icon: Icons.local_shipping_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerHomePage(
                      customerId: widget.customerId,
                      customerName: widget.loggedInName,
                      mobileNumber: widget.phoneNumber,
                      categoryName: '',
                      initialJobType: 'Delivery',
                      initialDeviceType: '',
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Info Card
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '100% Satisfaction Guarantee',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Certified technicians • 90-day warranty • Same-day service',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Theme.of(context).textTheme.bodySmall?.color ??
                      const Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final devicesGridCount = isMobile
            ? (constraints.maxWidth < 360 ? 2 : 3)
            : (isTablet ? 4 : 6);

        if (isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading Devices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we fetch available devices',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).textTheme.bodySmall?.color ??
                        const Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Indicator
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.devices_rounded,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select your device type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: selectedDeviceId == null ? 0.5 : 1.0,
                          backgroundColor: Colors.grey.shade100,
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                  if (selectedDeviceId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Available Devices Header
            Text(
              'Available Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color:
                    Theme.of(context).textTheme.titleLarge?.color ??
                    const Color(0xFF1E293B),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),

            // Devices Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: devicesGridCount,
                crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(3),
                mainAxisSpacing: ResponsiveHelper.getResponsiveWidth(3),
                childAspectRatio: isMobile ? 0.8 : 0.9,
              ),
              itemCount: allDevices.length + 1,
              itemBuilder: (context, index) {
                if (index < allDevices.length) {
                  final device = allDevices[index];
                  final isSelected = selectedDeviceId == device.id;
                  return _buildDeviceCard(device, isSelected);
                }

                // "Other" option
                final isOtherSelected = selectedDeviceId == 'other';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDeviceId = isOtherSelected ? null : 'other';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isOtherSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOtherSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                        width: isOtherSelected ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isOtherSelected ? 0.1 : 0.05,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        ResponsiveHelper.getResponsiveWidth(3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: ResponsiveHelper.getResponsiveWidth(9),
                            height: ResponsiveHelper.getResponsiveWidth(9),
                            decoration: BoxDecoration(
                              color: isOtherSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: ResponsiveHelper.getResponsiveWidth(5),
                              color: isOtherSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(
                            height: ResponsiveHelper.getResponsiveHeight(1.5),
                          ),
                          Text(
                            'Other',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                13,
                              ),
                              fontWeight: FontWeight.w600,
                              color: isOtherSelected
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color ??
                                        const Color(0xFF1E293B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Custom Device Input
            if (selectedDeviceId == 'other')
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Custom Device',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(
                                  context,
                                ).textTheme.titleMedium?.color ??
                                const Color(0xFF1E293B),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otherController,
                      onChanged: (value) =>
                          setState(() => otherDeviceName = value),
                      decoration: InputDecoration(
                        labelText: 'Device Name / Model',
                        hintText: 'e.g., Dell XPS 15, MacBook Pro M2',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(
                          Icons.devices_other_rounded,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Continue Button
            if (selectedDeviceId != null)
              ElevatedButton(
                onPressed: () {
                  if (selectedDeviceId == 'other' && otherDeviceName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter device name'),
                        backgroundColor: Theme.of(context).primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    return;
                  }

                  final isOther = selectedDeviceId == 'other';
                  final deviceName = isOther
                      ? otherDeviceName
                      : allDevices
                            .firstWhere((d) => d.id == selectedDeviceId!)
                            .name;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerHomePage(
                        customerId: widget.customerId,
                        customerName: widget.loggedInName,
                        mobileNumber: widget.phoneNumber,
                        categoryName: ThemeService
                            .instance
                            .appName, // Passing app name as category
                        initialJobType: 'Service',
                        initialDeviceType: isOther ? 'Others' : deviceName,
                        initialCustomDeviceType: isOther ? deviceName : null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceCard(Device device, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDeviceId = isSelected ? null : device.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? device.color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? device.color : Colors.grey.shade200,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: device.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(device.icon, size: 20, color: device.color),
              ),
              const SizedBox(height: 8),
              Text(
                device.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? device.color
                      : (Theme.of(context).textTheme.bodyMedium?.color ??
                            const Color(0xFF1E293B)),
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (device.deviceId.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  device.deviceId,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isSelected ? device.color : Colors.grey.shade500)
                        .withOpacity(0.8),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                device.description,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? device.color : Colors.grey.shade500,
                  fontFamily: 'Inter',
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).textTheme.titleLarge?.color ??
                      const Color(0xFF1E293B),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This service will be available soon',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).hintColor,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
