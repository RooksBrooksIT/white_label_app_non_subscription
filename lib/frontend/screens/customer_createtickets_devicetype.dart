import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_home_page.dart';
import 'package:subscription_rooks_app/utils/responsive_helper.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

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
            ThemeService.instance.primaryColor
                .toARGB32()
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
  final String customerType; // "amc" or "nonamc"

  const CustomerDeviceType({
    super.key,
    required this.name,
    required this.loggedInName,
    required this.phoneNumber,
    required this.customerId,
    required this.customerType,
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
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Header Banner with Admin Branding Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary,
                  HSLColor.fromColor(primary).withLightness(0.32).toColor(),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 22,
              left: context.responsiveHPadding > 20
                  ? context.responsiveHPadding
                  : 20,
              right: context.responsiveHPadding > 20
                  ? context.responsiveHPadding
                  : 20,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (showDeviceSelection) {
                      setState(() {
                        showDeviceSelection = false;
                        selectedDeviceId = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showDeviceSelection
                            ? 'Select Your Device'
                            : 'Welcome, ${widget.loggedInName} 👋',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showDeviceSelection
                            ? 'Choose your device type'
                            : 'What service do you need today?',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsiveHPadding,
                    ),
                    child: ResponsiveWrapper(
                      maxWidth: 960.0,
                      padding: EdgeInsets.all(
                        ResponsiveHelper.getResponsiveWidth(5),
                      ),
                      child: !showDeviceSelection
                          ? _buildServiceSelection()
                          : _buildDeviceSelection(),
                    ),
                  ),
                ),
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
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 14,
                    color: primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REPAIR & DELIVERY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Our Services',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the service that matches your needs',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Service Cards
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: serviceGridCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isMobile ? 0.72 : 0.90,
          ),
          children: [
            _buildServiceCard(
              title: 'Service',
              subtitle: 'Professional repair & diagnostics',
              icon: Icons.handyman_rounded,
              color: primary,
              onTap: () {
                setState(() {
                  showDeviceSelection = true;
                });
              },
            ),
            _buildServiceCard(
              title: 'Request',
              subtitle: 'Pickup & doorstep drop-off',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF059669),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerHomePage(
                      customerId: widget.customerId,
                      customerName: widget.loggedInName,
                      mobileNumber: widget.phoneNumber,
                      categoryName: '',
                      customerType: widget.customerType,
                      initialJobType: 'Delivery',
                      initialDeviceType: '',
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Guarantee Hero Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary,
                HSLColor.fromColor(primary).withLightness(0.32).toColor(),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '100% Satisfaction Guarantee',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Certified technicians • 90-day warranty • Same-day service',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w500,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelection() {
    final primary = Theme.of(context).primaryColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final devicesGridCount = isMobile
            ? (constraints.maxWidth < 360 ? 2 : 2)
            : (isTablet ? 3 : 5);

        if (isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading Devices...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please wait while we fetch available equipment',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
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
            // Modern Step Progress Banner
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.devices_rounded,
                      size: 22,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Select your device type',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              selectedDeviceId != null ? 'Step 2/2' : 'Step 1/2',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: selectedDeviceId == null ? 0.5 : 1.0,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: primary,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedDeviceId != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
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

            // Available Devices Section Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hardware_rounded,
                        size: 13,
                        color: primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AVAILABLE EQUIPMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Available Devices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Devices Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: devicesGridCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isMobile ? 0.82 : 0.92,
              ),
              itemCount: allDevices.length + 1,
              itemBuilder: (context, index) {
                if (index < allDevices.length) {
                  final device = allDevices[index];
                  final isSelected = selectedDeviceId == device.id;
                  return _buildDeviceCard(device, isSelected);
                }

                // "Other" option card
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
                          ? primary.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOtherSelected ? primary : const Color(0xFFE2E8F0),
                        width: isOtherSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isOtherSelected ? 0.08 : 0.03,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isOtherSelected
                                  ? primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 22,
                              color: isOtherSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Other',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isOtherSelected
                                  ? primary
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Custom Device',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isOtherSelected
                                  ? primary.withValues(alpha: 0.8)
                                  : const Color(0xFF94A3B8),
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

            // Custom Device Input Panel
            if (selectedDeviceId == 'other')
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Custom Device Specification',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
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
                        fillColor: const Color(0xFFF8FAFC),
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
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        prefixIcon: Icon(
                          Icons.devices_other_rounded,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // Continue Primary Button
            if (selectedDeviceId != null)
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedDeviceId == 'other' &&
                          otherDeviceName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please enter device name'),
                            backgroundColor: primary,
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
                            categoryName: ThemeService.instance.appName,
                            customerType: widget.customerType,
                            initialJobType: 'Service',
                            initialDeviceType: isOther ? 'Others' : deviceName,
                            initialCustomDeviceType: isOther ? deviceName : null,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: primary.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildDeviceCard(Device device, bool isSelected) {
    final primary = Theme.of(context).primaryColor;
    final cardColor = isSelected ? primary : const Color(0xFF0F172A);
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDeviceId = isSelected ? null : device.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  device.icon,
                  size: 22,
                  color: isSelected ? Colors.white : primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                device.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: cardColor,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? primary.withValues(alpha: 0.88)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
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
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
