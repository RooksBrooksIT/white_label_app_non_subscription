import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'connectivity/connectivity_checker.dart';

/// Centralized global internet connectivity monitoring service.
/// Continuously monitors network interfaces (Wi-Fi, Mobile Data) and
/// platform-specific reachability (Android socket/DNS, Web browser events/CORS-safe checks)
/// to prevent false online/offline states and CORS errors.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final PlatformConnectivityChecker _platformChecker =
      createPlatformConnectivityChecker();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicTimer;
  Timer? _debounceTimer;

  bool _isConnected = true;
  bool _isChecking = false;
  bool _initialized = false;
  String? _lastErrorMessage;

  /// Whether the device has confirmed, active internet access.
  bool get isConnected => _isConnected;

  /// Whether an internet verification check is currently in flight.
  bool get isChecking => _isChecking;

  /// Optional debug error message from the last failed verification.
  String? get lastErrorMessage => _lastErrorMessage;

  /// Initializes connectivity monitoring across the entire application.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    LoggerUtil.i('Initializing global ConnectivityService...');

    // 1. Initialize platform-specific listeners (e.g. browser online/offline events for Web)
    _platformChecker.initialize(
      onStatusChanged: (isOnline) {
        if (isOnline) {
          checkConnection();
        } else {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            _updateStatus(false);
          });
        }
      },
    );

    // 2. Listen for network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );

    // 3. Perform initial actual internet verification
    checkConnection();

    // 4. Start background periodic verification
    _startPeriodicChecks();
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    LoggerUtil.d('Network interface state changed: $results');

    _debounceTimer?.cancel();

    final hasNetworkInterface = results.any(
      (r) => r != ConnectivityResult.none,
    );

    if (!hasNetworkInterface) {
      // Network interface is down.
      // Debounce to allow brief transitions (e.g. Wi-Fi to Mobile data handover)
      _debounceTimer = Timer(const Duration(milliseconds: 1200), () async {
        final currentResults = await _connectivity.checkConnectivity();
        if (currentResults.every((r) => r == ConnectivityResult.none)) {
          _updateStatus(false);
        } else {
          checkConnection();
        }
      });
    } else {
      // Network interface is available -> verify actual internet connectivity
      // Debounce slightly (350ms) to allow DHCP/IP routing establishment
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        checkConnection();
      });
    }
  }

  /// Verifies actual internet access and updates connectivity state.
  /// Set [manual] to true when triggered by user action (e.g. Retry button).
  Future<bool> checkConnection({bool manual = false}) async {
    if (_isChecking && !manual) return _isConnected;

    _isChecking = true;
    if (manual) notifyListeners();

    try {
      final hasInternet = await _platformChecker.checkActualInternet();
      _lastErrorMessage = null;
      _updateStatus(hasInternet);
      return hasInternet;
    } catch (e) {
      LoggerUtil.e('Error during internet verification: $e');
      _lastErrorMessage = e.toString();
      // On web, never treat unexpected fetch/CORS errors as disconnection
      if (kIsWeb) {
        _updateStatus(true);
        return true;
      }
      _updateStatus(false);
      return false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void _updateStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      LoggerUtil.i(
        'Global Internet Connectivity changed: ${_isConnected ? "ONLINE (Restored)" : "OFFLINE"}',
      );
      notifyListeners();
      _startPeriodicChecks();
    }
  }

  void _startPeriodicChecks() {
    _periodicTimer?.cancel();
    // When offline, poll more frequently (every 4s) to restore automatically.
    // When online, poll lightly (every 30s) to keep overhead low.
    final interval =
        _isConnected ? const Duration(seconds: 30) : const Duration(seconds: 4);

    _periodicTimer = Timer.periodic(interval, (_) {
      checkConnection();
    });
  }

  /// Hook called when the app resumes from the background state.
  void onAppResumed() {
    LoggerUtil.d('App resumed: re-verifying internet connectivity');
    checkConnection();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _platformChecker.dispose();
    super.dispose();
  }
}
