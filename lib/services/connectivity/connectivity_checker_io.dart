import 'dart:async';
import 'dart:io';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'connectivity_checker_base.dart';

/// Native (Android / iOS / Desktop) connectivity checker using direct socket & DNS probes.
class IOConnectivityChecker implements PlatformConnectivityChecker {
  @override
  void initialize({required void Function(bool isOnline) onStatusChanged}) {
    // Native platforms rely on connectivity_plus network interface changes and periodic probes.
  }

  @override
  Future<bool> checkActualInternet() async {
    // 1. Primary Check: DNS resolution for google.com
    try {
      final googleResult = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (googleResult.isNotEmpty && googleResult[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 2. Secondary Check: DNS resolution for Cloudflare (1.1.1.1)
    try {
      final cfResult = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      if (cfResult.isNotEmpty && cfResult[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Direct socket connection to public DNS (1.1.1.1:53)
    try {
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (e) {
      LoggerUtil.d('Native socket probe error: $e');
    }

    return false;
  }

  @override
  void dispose() {}
}

PlatformConnectivityChecker getPlatformConnectivityChecker() =>
    IOConnectivityChecker();
