import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class AdminDeviceConfigurationPage extends StatefulWidget {
  const AdminDeviceConfigurationPage({super.key});

  @override
  State<AdminDeviceConfigurationPage> createState() =>
      _AdminDeviceConfigurationPageState();
}

class _AdminDeviceConfigurationPageState
    extends State<AdminDeviceConfigurationPage> {
  final TextEditingController _deviceTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirestoreService _firestore = FirestoreService.instance;
  bool _isLoading = false;

  Color get primaryColor => Theme.of(context).primaryColor;
  Color get accentColor => primaryColor.withValues(alpha: 0.1);

  @override
  void dispose() {
    _deviceTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  IconData _getIconData(String type) {
    final String lowerType = type.toLowerCase().trim();

    const Map<String, IconData> iconMap = {
      'desktop': Icons.computer_rounded,
      'pc': Icons.computer_rounded,
      'computer': Icons.computer_rounded,
      'laptop': Icons.laptop_mac_rounded,
      'notebook': Icons.laptop_mac_rounded,
      'tablet': Icons.tablet_mac_rounded,
      'ipad': Icons.tablet_mac_rounded,
      'phone': Icons.phone_iphone_rounded,
      'mobile': Icons.phone_iphone_rounded,
      'printer': Icons.print_rounded,
      'scanner': Icons.scanner_rounded,
      'keyboard': Icons.keyboard_rounded,
      'mouse': Icons.mouse_rounded,
      'monitor': Icons.desktop_windows_rounded,
      'cpu': Icons.memory_rounded,
      'ram': Icons.sd_storage_rounded,
      'ssd': Icons.sd_card_rounded,
      'hard drive': Icons.storage_rounded,
      'router': Icons.router_rounded,
      'access point': Icons.wifi_rounded,
      'network switch': Icons.swap_horiz_rounded,
      'firewall': Icons.security_rounded,
      'server': Icons.dns_rounded,
      'cctv': Icons.videocam_rounded,
      'webcam': Icons.videocam_rounded,
      'biometrics': Icons.fingerprint_rounded,
      'speaker': Icons.speaker_rounded,
      'headset': Icons.headset_rounded,
      'microphone': Icons.mic_rounded,
      'bluetooth device': Icons.bluetooth_rounded,
      'game controller': Icons.sports_esports_rounded,
      'tv': Icons.tv_rounded,
      'television': Icons.tv_rounded,
      'fan': Icons.mode_fan_off_rounded,
      'ac': Icons.ac_unit_rounded,
      'air conditioner': Icons.ac_unit_rounded,
      'fridge': Icons.kitchen_rounded,
      'refrigerator': Icons.kitchen_rounded,
      'washing machine': Icons.local_laundry_service_rounded,
      'microwave': Icons.microwave_rounded,
      'iron': Icons.iron_rounded,
      'geyser': Icons.hot_tub_rounded,
      'water heater': Icons.hot_tub_rounded,
      'light': Icons.lightbulb_rounded,
      'bulb': Icons.lightbulb_rounded,
      'doorbell': Icons.doorbell_rounded,
      'ups': Icons.electrical_services_rounded,
    };

    if (iconMap.containsKey(lowerType)) {
      return iconMap[lowerType]!;
    }

    if (lowerType.contains('desktop') ||
        lowerType.contains('pc') ||
        lowerType.contains('computer')) {
      return Icons.desktop_windows_rounded;
    } else if (lowerType.contains('tv') || lowerType.contains('television')) {
      return Icons.tv_rounded;
    } else if (lowerType.contains('laptop') || lowerType.contains('notebook')) {
      return Icons.laptop_mac_rounded;
    } else if (lowerType.contains('mobile') || lowerType.contains('phone')) {
      return Icons.phone_iphone_rounded;
    } else if (lowerType.contains('tablet') || lowerType.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    } else if (lowerType.contains('printer')) {
      return Icons.print_rounded;
    } else if (lowerType.contains('router') || lowerType.contains('wifi')) {
      return Icons.router_rounded;
    } else if (lowerType.contains('cctv') || lowerType.contains('camera')) {
      return Icons.videocam_rounded;
    } else if (lowerType.contains('fan')) {
      return Icons.mode_fan_off_rounded;
    } else if (lowerType.contains('ac')) {
      return Icons.ac_unit_rounded;
    } else if (lowerType.contains('wash')) {
      return Icons.local_laundry_service_rounded;
    } else if (lowerType.contains('fridge')) {
      return Icons.kitchen_rounded;
    }

    return Icons.devices_rounded;
  }

  Future<void> _deleteDevice(String deviceType) async {
    try {
      await _firestore.collection('deviceDetails').doc(deviceType).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device "$deviceType" deleted successfully', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting device: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editDevice(String deviceType, String currentDescription) async {
    final TextEditingController editDeviceTypeController =
        TextEditingController(text: deviceType);
    final TextEditingController editDescriptionController =
        TextEditingController(text: currentDescription);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Device',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editDeviceTypeController,
                  decoration: InputDecoration(
                    labelText: 'Device Name',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
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
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: editDescriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
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
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final newDeviceType = editDeviceTypeController.text.trim();
      final newDescription = editDescriptionController.text.trim();

      if (newDeviceType.isNotEmpty && newDescription.isNotEmpty) {
        try {
          if (newDeviceType != deviceType) {
            final doc = await _firestore
                .collection('deviceDetails')
                .doc(deviceType)
                .get();
            if (doc.exists) {
              final data = doc.data() as Map<String, dynamic>;
              data['deviceType'] = newDeviceType;
              data['description'] = newDescription;
              data.remove('icon');
              await _firestore
                  .collection('deviceDetails')
                  .doc(deviceType)
                  .delete();
              await _firestore
                  .collection('deviceDetails')
                  .doc(newDeviceType)
                  .set(data);
            }
          } else {
            await _firestore.collection('deviceDetails').doc(deviceType).update(
              {'description': newDescription},
            );
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device updated successfully', style: GoogleFonts.inter()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating device: $e', style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showDeviceOptions(String deviceType, String description) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(deviceType),
                  color: primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                deviceType,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text('Edit Details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editDevice(deviceType, description);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text('Delete Device?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                            content: Text(
                              'Are you sure? This will remove this device configuration.',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  'Delete',
                                  style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _deleteDevice(deviceType);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getNextDeviceId() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('deviceDetails')
        .get();

    int maxNumber = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deviceId = data['deviceId'] as String?;
      if (deviceId != null && deviceId.startsWith('DE')) {
        final numberPart = deviceId.substring(2);
        final num = int.tryParse(numberPart) ?? 0;
        if (num > maxNumber) maxNumber = num;
      }
    }

    return 'DE${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _addDevice() async {
    final String deviceType = _deviceTypeController.text.trim();
    final String description = _descriptionController.text.trim();

    if (deviceType.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nextDeviceId = await _getNextDeviceId();
      await _firestore.collection('deviceDetails').doc(deviceType).set({
        'deviceType': deviceType,
        'description': description,
        'deviceId': nextDeviceId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$deviceType" added successfully', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _deviceTypeController.clear();
      _descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Device Configuration',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: kMaxContentWidth,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddDeviceCard(),
                        const SizedBox(height: 28),
                        Text(
                          'Configured Devices',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                _buildDeviceGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Add New Device',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _deviceTypeController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.devices_rounded, size: 20, color: const Color(0xFF64748B)),
              hintText: 'Device Name (e.g. Office PC)',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
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
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.description_outlined, size: 20, color: const Color(0xFF64748B)),
              hintText: 'Technical description...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
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
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Register Device',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('deviceDetails').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.devices_other_rounded, size: 48, color: const Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'No devices configured yet.',
                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.88,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final type = data['deviceType'] ?? 'Unknown';
              final desc = data['description'] ?? '';
              final id = data['deviceId'] ?? '';

              return InkWell(
                onTap: () => _showDeviceOptions(type, desc),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _getIconData(type),
                          color: primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        type,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11.5),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          id,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: docs.length),
          ),
        );
      },
    );
  }
}
