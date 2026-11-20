import 'dart:async';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'connectivity_checker_base.dart';

@JS('navigator.onLine')
external bool? get _navigatorOnLine;

@JS('window.addEventListener')
external void _addEventListener(JSString type, JSFunction listener);

@JS('window.removeEventListener')
external void _removeEventListener(JSString type, JSFunction listener);

/// Browser-compatible connectivity checker for Flutter Web.
/// Listens to window online/offline events, checks navigator.onLine,
/// and uses same-origin / CORS-compliant reachability checks without
/// triggering cross-origin policy failures.
class WebConnectivityChecker implements PlatformConnectivityChecker {
  JSFunction? _onOnlineListener;
  JSFunction? _onOfflineListener;
  void Function(bool isOnline)? _onStatusChanged;

  @override
  void initialize({required void Function(bool isOnline) onStatusChanged}) {
    _onStatusChanged = onStatusChanged;

    try {
      _onOnlineListener = ((JSAny? _) {
        LoggerUtil.d('Browser window received "online" event');
        _onStatusChanged?.call(true);
      }).toJS;

      _onOfflineListener = ((JSAny? _) {
        LoggerUtil.d('Browser window received "offline" event');
        _onStatusChanged?.call(false);
      }).toJS;

      _addEventListener('online'.toJS, _onOnlineListener!);
      _addEventListener('offline'.toJS, _onOfflineListener!);
      LoggerUtil.d('Registered browser online/offline event listeners');
    } catch (e) {
      LoggerUtil.w('Failed to register web online/offline listeners: $e');
    }
  }

  @override
  Future<bool> checkActualInternet() async {
    // 1. Initial check: browser navigator.onLine signal
    if (!_isBrowserOnline()) {
      LoggerUtil.d('Web navigator.onLine is false: device is offline');
      return false;
    }

    // 2. Same-origin probe:
    // Fetching same-origin assets never triggers browser CORS errors.
    bool sameOriginOk = false;
    try {
      final probeUri = Uri.base.resolve(
        'manifest.json?_t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final res = await http.head(probeUri).timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 400) {
        sameOriginOk = true;
      }
    } catch (e) {
      LoggerUtil.d('Web same-origin HEAD check notice: $e');
      // If HEAD is not permitted by static server, attempt GET on favicon.png
      try {
        final faviconUri = Uri.base.resolve(
          'favicon.png?_t=${DateTime.now().millisecondsSinceEpoch}',
        );
        final res = await http.get(faviconUri).timeout(const Duration(seconds: 3));
        if (res.statusCode >= 200 && res.statusCode < 400) {
          sameOriginOk = true;
        }
      } catch (_) {}
    }

    // If deployed on remote server and same-origin succeeds, the internet connection is live
    final host = Uri.base.host.toLowerCase();
    final isLocalhost = host == 'localhost' || host == '127.0.0.1' || host.isEmpty;
    if (sameOriginOk && !isLocalhost) {
      return true;
    }

    // 3. CORS-compliant external probe:
    // Cloudflare Public DNS JSON API explicitly supports CORS (Access-Control-Allow-Origin: *).
    try {
      final res = await http.get(
        Uri.parse('https://1.1.1.1/dns-query?name=cloudflare.com&type=A'),
        headers: {'Accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      LoggerUtil.d('Web external probe notice: $e');
      // CRITICAL: Never treat CORS errors or browser-blocked fetches as proof of disconnection.
      // If same-origin is ok or navigator.onLine is true, keep application online.
      if (sameOriginOk) {
        return true;
      }
    }

    // Fallback: if sameOrigin is ok or navigator reports online, keep application online.
    if (sameOriginOk) return true;
    return _isBrowserOnline();
  }

  bool _isBrowserOnline() {
    try {
      return _navigatorOnLine ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    try {
      if (_onOnlineListener != null) {
        _removeEventListener('online'.toJS, _onOnlineListener!);
      }
      if (_onOfflineListener != null) {
        _removeEventListener('offline'.toJS, _onOfflineListener!);
      }
    } catch (_) {}
  }
}

PlatformConnectivityChecker getPlatformConnectivityChecker() =>
    WebConnectivityChecker();
