import 'dart:async';

/// Base contract for platform-specific network reachability checks.
abstract class PlatformConnectivityChecker {
  /// Initializes any platform-specific listeners (e.g. browser online/offline events on Web).
  void initialize({required void Function(bool isOnline) onStatusChanged});

  /// Verifies actual internet reachability in a platform-appropriate manner.
  Future<bool> checkActualInternet();

  /// Releases platform-specific resources and event listeners.
  void dispose();
}

/// Fallback factory for unsupported platforms.
PlatformConnectivityChecker getPlatformConnectivityChecker() =>
    throw UnsupportedError('Platform not supported for connectivity checking');
