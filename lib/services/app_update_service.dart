import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:subscription_rooks_app/widgets/update_dialog.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  static AppUpdateService get instance => _instance;

  AppUpdateService._internal();

  bool _hasChecked = false;

  Future<void> checkForUpdate(BuildContext context) async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String installedVersion = packageInfo.version;
      final String packageName = packageInfo.packageName;

      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('AppUpdateService: Version config not found in Firestore.');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final String latestVersion = data['latestVersion'] ?? installedVersion;
      final bool forceUpdate = data['forceUpdate'] ?? false;
      final String updateTitle = data['updateTitle'] ?? 'New Update Available';
      final String updateMessage = data['updateMessage'] ?? 'A newer version of the app is available. Please update to continue.';

      if (_isUpdateAvailable(installedVersion, latestVersion)) {
        if (!context.mounted) return;
        
        await showDialog(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (context) => UpdateDialog(
            title: updateTitle,
            message: updateMessage,
            forceUpdate: forceUpdate,
            packageName: packageName,
          ),
        );
      }
    } catch (e) {
      debugPrint('AppUpdateService: Error checking for update: $e');
    }
  }

  bool _isUpdateAvailable(String installedVersion, String latestVersion) {
    List<int> installedParts = installedVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int installedPart = i < installedParts.length ? installedParts[i] : 0;
      int latestPart = latestParts[i];

      if (latestPart > installedPart) return true;
      if (latestPart < installedPart) return false;
    }
    return false;
  }
}
