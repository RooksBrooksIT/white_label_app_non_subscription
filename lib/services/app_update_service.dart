import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/widgets/update_dialog.dart';

class AppUpdateInfo {
  final String installedVersion;
  final int installedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String minimumSupportedVersion;
  final int minimumSupportedBuildNumber;
  final bool isMandatory;
  final bool isUpdateAvailable;
  final String updateTitle;
  final String updateMessage;
  final String playStoreUrl;
  final String packageName;
  final int reminderIntervalHours;

  const AppUpdateInfo({
    required this.installedVersion,
    required this.installedBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumSupportedVersion,
    required this.minimumSupportedBuildNumber,
    required this.isMandatory,
    required this.isUpdateAvailable,
    required this.updateTitle,
    required this.updateMessage,
    required this.playStoreUrl,
    required this.packageName,
    this.reminderIntervalHours = 24,
  });

  Map<String, dynamic> toJson() => {
    'installedVersion': installedVersion,
    'installedBuildNumber': installedBuildNumber,
    'latestVersion': latestVersion,
    'latestBuildNumber': latestBuildNumber,
    'minimumSupportedVersion': minimumSupportedVersion,
    'minimumSupportedBuildNumber': minimumSupportedBuildNumber,
    'isMandatory': isMandatory,
    'isUpdateAvailable': isUpdateAvailable,
    'updateTitle': updateTitle,
    'updateMessage': updateMessage,
    'playStoreUrl': playStoreUrl,
    'packageName': packageName,
    'reminderIntervalHours': reminderIntervalHours,
  };
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  static AppUpdateService get instance => _instance;

  AppUpdateService._internal();

  static const String _kCachedConfigKey = 'cached_app_update_config';
  static const String _kLastDismissedTimeKey = 'last_update_dismissed_time';

  /// Flag set when a payment transaction is actively verifying or processing.
  /// Prevents any update dialog from interrupting the payment process.
  static bool isPaymentInProgress = false;

  bool _isChecking = false;
  bool _isDialogShowing = false;
  AppUpdateInfo? _lastKnownInfo;

  bool get isDialogShowing => _isDialogShowing;
  AppUpdateInfo? get lastKnownInfo => _lastKnownInfo;

  /// Compares two semantic version strings (e.g., "2.0.0" and "2.0.1").
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if v1 == v2.
  static int compareSemanticVersions(String v1, String v2) {
    final cleanV1 = v1.split('+').first.trim();
    final cleanV2 = v2.split('+').first.trim();

    final parts1 = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Evaluates whether an update is available based on semantic version and build number.
  static bool checkIsUpdateAvailable({
    required String installedVersion,
    required int installedBuildNumber,
    required String latestVersion,
    required int latestBuildNumber,
  }) {
    final cmp = compareSemanticVersions(latestVersion, installedVersion);
    if (cmp > 0) return true;
    if (cmp == 0 && latestBuildNumber > installedBuildNumber) return true;
    return false;
  }

  /// Evaluates whether an update is mandatory.
  static bool checkIsMandatory({
    required String installedVersion,
    required int installedBuildNumber,
    required String minimumSupportedVersion,
    required int minimumSupportedBuildNumber,
    required bool forceUpdate,
    required bool updateRequired,
  }) {
    if (forceUpdate || updateRequired) return true;
    if (minimumSupportedVersion.isNotEmpty) {
      final cmp = compareSemanticVersions(minimumSupportedVersion, installedVersion);
      if (cmp > 0) return true;
      if (cmp == 0 && minimumSupportedBuildNumber > installedBuildNumber) return true;
    }
    return false;
  }

  /// Fetches and evaluates update information from Firestore (`app_config/version`),
  /// falling back to cached configuration in SharedPreferences if network is unavailable.
  Future<AppUpdateInfo?> checkUpdateInfo({bool forceRefresh = false}) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String installedVersion = packageInfo.version.split('+').first.trim();
      final int installedBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String packageName = packageInfo.packageName.isNotEmpty
          ? packageInfo.packageName
          : 'com.rooks.subscription';

      Map<String, dynamic>? configData;

      try {
        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('version')
            .get()
            .timeout(const Duration(seconds: 4));

        if (doc.exists && doc.data() != null) {
          configData = doc.data() as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kCachedConfigKey, jsonEncode(configData));
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Remote fetch failed ($e). Using cached config if available.');
      }

      // Fallback to cached config if remote fetch failed or document was missing
      if (configData == null) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_kCachedConfigKey);
        if (cached != null) {
          try {
            configData = jsonDecode(cached) as Map<String, dynamic>;
          } catch (_) {}
        }
      }

      if (configData == null) {
        debugPrint('[AppUpdateService] No update configuration available.');
        return null;
      }

      final String latestVersion = (configData['latestVersion'] ?? installedVersion).toString().trim();
      final int latestBuildNumber = int.tryParse(configData['latestBuildNumber']?.toString() ?? '') ?? 0;
      final String minimumSupportedVersion = (configData['minimumSupportedVersion'] ?? '').toString().trim();
      final int minimumSupportedBuildNumber = int.tryParse(configData['minimumSupportedBuildNumber']?.toString() ?? '') ?? 0;
      final bool forceUpdate = configData['forceUpdate'] == true;
      final bool updateRequired = configData['updateRequired'] == true;
      final String updateTitle = configData['updateTitle']?.toString() ?? 'New Update Available!';
      final String updateMessage = configData['updateMessage']?.toString() ??
          'A new version of ServNex is available. Update your application to access the latest improvements, features and bug fixes.';
      final String playStoreUrl = configData['playStoreUrl']?.toString() ??
          'https://play.google.com/store/apps/details?id=$packageName';
      final int reminderIntervalHours = int.tryParse(configData['reminderIntervalHours']?.toString() ?? '') ?? 24;

      final bool isUpdateAvailable = checkIsUpdateAvailable(
        installedVersion: installedVersion,
        installedBuildNumber: installedBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
      );

      final bool isMandatory = checkIsMandatory(
        installedVersion: installedVersion,
        installedBuildNumber: installedBuildNumber,
        minimumSupportedVersion: minimumSupportedVersion,
        minimumSupportedBuildNumber: minimumSupportedBuildNumber,
        forceUpdate: forceUpdate,
        updateRequired: updateRequired,
      );

      final info = AppUpdateInfo(
        installedVersion: installedVersion,
        installedBuildNumber: installedBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
        minimumSupportedVersion: minimumSupportedVersion,
        minimumSupportedBuildNumber: minimumSupportedBuildNumber,
        isMandatory: isMandatory,
        isUpdateAvailable: isUpdateAvailable,
        updateTitle: updateTitle,
        updateMessage: updateMessage,
        playStoreUrl: playStoreUrl,
        packageName: packageName,
        reminderIntervalHours: reminderIntervalHours,
      );

      _lastKnownInfo = info;
      return info;
    } catch (e) {
      debugPrint('[AppUpdateService] checkUpdateInfo error: $e');
      return null;
    }
  }

  /// Checks for available updates and shows the update modal if applicable.
  /// Can be called with a specific [context] or defaults to global navigator key.
  Future<void> checkForUpdate({
    BuildContext? context,
    bool isFromResume = false,
    bool isMandatoryOnly = false,
  }) async {
    if (_isChecking || _isDialogShowing || isPaymentInProgress) {
      return;
    }

    _isChecking = true;
    try {
      final info = await checkUpdateInfo();
      if (info == null || !info.isUpdateAvailable) {
        return;
      }

      if (isMandatoryOnly && !info.isMandatory) {
        return;
      }

      // For optional updates, respect the reminder interval if previously dismissed
      if (!info.isMandatory && !isFromResume) {
        final prefs = await SharedPreferences.getInstance();
        final lastDismissed = prefs.getInt(_kLastDismissedTimeKey);
        if (lastDismissed != null) {
          final dismissedTime = DateTime.fromMillisecondsSinceEpoch(lastDismissed);
          final diffHours = DateTime.now().difference(dismissedTime).inHours;
          if (diffHours < info.reminderIntervalHours) {
            debugPrint(
              '[AppUpdateService] Optional update dismissed $diffHours hours ago (interval: ${info.reminderIntervalHours}h). Skipping dialog.',
            );
            return;
          }
        }
      }

      final targetContext = context ?? SubscriptionExpiryService.instance.navigatorKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        debugPrint('[AppUpdateService] Target context not available to show update dialog.');
        return;
      }

      showUpdateDialog(targetContext, info);
    } catch (e) {
      debugPrint('[AppUpdateService] checkForUpdate error: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Shows the update dialog modal.
  void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    if (_isDialogShowing || isPaymentInProgress) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (dialogCtx) => UpdateDialog(
        title: info.updateTitle,
        message: info.updateMessage,
        installedVersion: info.installedVersion,
        installedBuildNumber: info.installedBuildNumber,
        latestVersion: info.latestVersion,
        latestBuildNumber: info.latestBuildNumber,
        isMandatory: info.isMandatory,
        packageName: info.packageName,
        playStoreUrl: info.playStoreUrl,
        onDismiss: () => _markUpdateDismissed(),
      ),
    ).then((_) {
      _isDialogShowing = false;
    }).catchError((_) {
      _isDialogShowing = false;
    });
  }

  /// Records the timestamp when an optional update was dismissed.
  Future<void> _markUpdateDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastDismissedTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Triggered when the application returns to foreground (resumed).
  Future<void> onAppResumed() async {
    if (_isDialogShowing || isPaymentInProgress) return;
    await checkForUpdate(isFromResume: true);
  }
}
