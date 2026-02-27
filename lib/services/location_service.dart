import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTracking = false;
  bool get isTracking => _isTracking;
  String? _currentEngineerId;

  String _sanitizePath(String path) {
    return path.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  Future<void> _ensureAuthenticated() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
          'LocationService: No session found. Attempting Anonymous Auth...',
        );
        final cred = await _auth.signInAnonymously();
        debugPrint(
          'LocationService: Anonymous Auth successful. UID: ${cred.user?.uid}',
        );
      } else {
        debugPrint('LocationService: Already authenticated as ${user.uid}');
      }
    } catch (e) {
      debugPrint('LocationService: Anonymous Auth FATAL ERROR: $e');
      debugPrint(
        'Please check if "Anonymous" sign-in provider is enabled in Firebase Console.',
      );
    }
  }

  /// Starts live location tracking for the specified engineer
  Future<bool> startTracking(String engineerId, {String? bookingId}) async {
    await _ensureAuthenticated();

    if (_isTracking && _currentEngineerId == engineerId) {
      if (bookingId != null) {
        _updateActiveBooking(engineerId, bookingId);
      }
      return true;
    }

    // 1. Request Permissions
    bool hasPermission = await _handlePermissions();
    if (!hasPermission) return false;

    _currentEngineerId = engineerId;

    // 2. Configure Settings (Best for Navigation for Exact Tracking)
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // 2 meters for high precision
      forceLocationManager: false,
      intervalDuration: const Duration(seconds: 3), // 3 seconds for fluidity
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Tracking your location for service tickets",
        notificationTitle: "Live Location On",
        enableWakeLock: true,
      ),
    );

    // 3. Start Listening with robust error handling
    try {
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              updateDatabase(engineerId, position, bookingId: bookingId);
            },
            onError: (error) {
              debugPrint('Location Stream Error: $error');
              // Resume tracking if it's just a temporary glitch
              _reconnectTracking(engineerId);
            },
            cancelOnError: false,
          );

      _isTracking = true;
      _setOnlineStatus(engineerId, true, bookingId: bookingId);
      return true;
    } catch (e) {
      debugPrint('Could not start location stream: $e');
      return false;
    }
  }

  /// Attempts to restart tracking if disconnected
  void _reconnectTracking(String engineerId) {
    debugPrint('Attempting to reconnect location tracking...');
    Future.delayed(const Duration(seconds: 10), () {
      if (_isTracking) startTracking(engineerId);
    });
  }

  /// Stops tracking and updates status to offline
  Future<void> stopTracking(String engineerId) async {
    try {
      await _positionSubscription?.cancel();
    } catch (e) {
      debugPrint('Error canceling location stream: $e');
    }
    _positionSubscription = null;
    _isTracking = false;
    _currentEngineerId = null;
    _setOnlineStatus(engineerId, false);
  }

  Future<void> updateDatabase(
    String engineerId,
    Position position, {
    String? bookingId,
  }) async {
    await _ensureAuthenticated();

    try {
      final sanitizedId = _sanitizePath(engineerId);
      final tenantId = ThemeService.instance.databaseName;
      // Use set() or update() depending on preference. update() is safer for existing data.
      final ref = _db.ref('$tenantId/engineers/$sanitizedId/location');
      await ref.update({
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'lastUpdate': ServerValue.timestamp,
      });

      // If a booking is active, also sync to the order_tracking node
      if (bookingId != null) {
        final sanitizedBookingId = _sanitizePath(bookingId);
        final orderRef = _db.ref(
          '$tenantId/order_tracking/$sanitizedBookingId/lastLocation',
        );
        await orderRef.update({
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint('Database Update Error: $e');
      // If internet is gone, we don't crash, we just wait for next update.
    }
  }

  Future<void> _updateActiveBooking(String engineerId, String bookingId) async {
    await _ensureAuthenticated();
    try {
      final sanitizedId = _sanitizePath(engineerId);
      final tenantId = ThemeService.instance.databaseName;
      await _db.ref('$tenantId/engineers/$sanitizedId').update({
        'activeBookingId': bookingId,
      });
    } catch (e) {
      debugPrint('Error updating active booking: $e');
    }
  }

  Future<void> _setOnlineStatus(
    String engineerId,
    bool isOnline, {
    String? bookingId,
  }) async {
    await _ensureAuthenticated();
    try {
      final sanitizedId = _sanitizePath(engineerId);
      final tenantId = ThemeService.instance.databaseName;
      final ref = _db.ref('$tenantId/engineers/$sanitizedId');
      final updates = {
        'isOnline': isOnline,
        'lastOnline': ServerValue.timestamp,
      };
      if (isOnline && bookingId != null) {
        updates['activeBookingId'] = bookingId;
      }
      await ref.update(updates);
    } catch (e) {
      debugPrint('Status Update Error: $e');
    }
  }

  Future<bool> _handlePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    // Background tracking requires "Always" permission
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      var backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        backgroundStatus = await Permission.locationAlways.request();
        // Note: Users might deny Always but allow In Use. We proceed but it might stop in background.
      }
    }

    return true;
  }

  /// Diagnostic tool to help verify RTDB connection and permissions
  Future<void> testConnection(String testId) async {
    debugPrint('--- LocationService: Diagnostic Test Start ---');
    await _ensureAuthenticated();
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('TEST FAILED: No authenticated user session.');
      return;
    }

    try {
      final sanitizedId = _sanitizePath(testId);
      final tenantId = ThemeService.instance.databaseName;
      final ref = _db.ref('$tenantId/connection_test/$sanitizedId');
      await ref.set({
        'status': 'success',
        'timestamp': ServerValue.timestamp,
        'uid': user.uid,
      });
      debugPrint(
        'TEST SUCCESS: Successfully wrote to RTDB node connection_test/$sanitizedId',
      );
    } catch (e) {
      debugPrint('TEST FAILED: RTDB Write Error: $e');
      debugPrint(
        'If this is Permission Denied, your Rules or Anonymous Auth are likely misconfigured.',
      );
    }
    debugPrint('--- LocationService: Diagnostic Test End ---');
  }
}
