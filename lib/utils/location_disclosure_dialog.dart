import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


class LocationDisclosure {
  static Future<bool> showDisclosure(BuildContext context) async {
    // Check if permission is already granted
    final status = await Permission.location.status;
    if (status.isGranted) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('We value your privacy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ServNex collects location data to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Show nearby service providers'),
              Text('• Improve service availability'),
              SizedBox(height: 12),
              Text(
                'Your location may be shared with service providers to fulfill requests.',
              ),
              SizedBox(height: 12),
              Text(
                'Do you want to continue?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Deny', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
