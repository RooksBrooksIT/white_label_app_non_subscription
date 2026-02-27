import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

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
  Color get accentColor => primaryColor.withOpacity(0.1);

  @override
  void dispose() {
    _deviceTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  IconData _getIconData(String type) {
    final String lowerType = type.toLowerCase().trim();

    // ✅ Exact match map (FAST lookup)
    const Map<String, IconData> iconMap = {
      // 💻 IT Devices
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

      // 📡 Networking / Security
      'router': Icons.router_rounded,
      'access point': Icons.wifi_rounded,
      'network switch': Icons.swap_horiz_rounded,
      'firewall': Icons.security_rounded,
      'server': Icons.dns_rounded,
      'cctv': Icons.nest_cam_wired_stand_outlined,
      'webcam': Icons.videocam_rounded,
      'biometrics': Icons.fingerprint_rounded,

      // 🔊 Accessories
      'speaker': Icons.speaker_rounded,
      'headset': Icons.headset_rounded,
      'microphone': Icons.mic_rounded,
      'bluetooth device': Icons.bluetooth_rounded,
      'game controller': Icons.sports_esports_rounded,

      // 🏠 Home Appliances
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

    // 🔥 1️⃣ Exact match first
    if (iconMap.containsKey(lowerType)) {
      return iconMap[lowerType]!;
    }

    // 🔥 2️⃣ Smart keyword detection
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

    // ✅ Default fallback
    return Icons.devices_rounded;
  }

  Future<void> _deleteDevice(String deviceType) async {
    try {
      await _firestore.collection('deviceDetails').doc(deviceType).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device "$deviceType" deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting device: $e'),
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
          title: const Text('Edit Device'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editDeviceTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: editDescriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
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
              // Remove explicit icon storage, uses auto-mapping
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
              content: Text('Device updated successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating device: $e'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 30,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(
                  _getIconData(deviceType),
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                deviceType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editDevice(deviceType, description);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Device?'),
                            content: const Text(
                              'Are you sure? This will remove this device configuration.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
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
        const SnackBar(
          content: Text('Please fill all fields'),
          behavior: SnackBarBehavior.floating,
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
          content: Text('"$deviceType" added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _deviceTypeController.clear();
      _descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Device Config',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildAddDeviceCard(),
                  const SizedBox(height: 32),
                  const Text(
                    'Configured Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildDeviceGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_suggest, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your hardware inventory and settings',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddDeviceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Device',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _deviceTypeController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.devices),
                hintText: 'Device Name (e.g. Office PC)',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: 'Technical description...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Register Device',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
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
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No devices configured yet.',
                  style: TextStyle(color: Colors.grey),
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final type = data['deviceType'] ?? 'Unknown';
              final desc = data['description'] ?? '';
              final id = data['deviceId'] ?? '';

              return InkWell(
                onTap: () => _showDeviceOptions(type, desc),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
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
                          color: primaryColor.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconData(type),
                          color: primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        id,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: primaryColor.withOpacity(0.5),
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
