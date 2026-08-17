import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  DateTime? _lastFirestoreUpdate;
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
        try {
          final cred = await _auth.signInAnonymously();
          debugPrint(
            'LocationService: Anonymous Auth successful. UID: ${cred.user?.uid}',
          );
        } catch (e) {
          // If Anonymous provider is disabled, log and continue without auth.
          debugPrint(
            'LocationService: Anonymous Auth failed (likely disabled): $e',
          );
          // Proceed; Realtime Database/Firestore rules must allow unauthenticated writes.
        }
      } else {
        debugPrint('LocationService: Already authenticated as ${user.uid}');
      }
    } catch (e) {
      debugPrint('LocationService: Unexpected auth error: $e');
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
      final engineerRef = _db.ref('$tenantId/engineers/$sanitizedId');
      final locationRef = engineerRef.child('location');

      final updateData = {
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'lastUpdate': ServerValue.timestamp,
      };

      try {
        await locationRef.update(updateData);
      } catch (e) {
        // If parent node or location node was stored as a String/primitive, update() fails.
        // Fallback to set() to replace node with a proper Map.
        try {
          await locationRef.set(updateData);
        } catch (_) {
          await engineerRef.set({
            'isOnline': true,
            'lastOnline': ServerValue.timestamp,
            'location': updateData,
          });
        }
      }

      // 5-minute Firestore heartbeat
      final now = DateTime.now();
      if (_lastFirestoreUpdate == null ||
          now.difference(_lastFirestoreUpdate!).inMinutes >= 5) {
        _lastFirestoreUpdate = now;
        _updateFirestoreHeartbeat(engineerId, position);
      }

      // If a booking is active, also sync to the order_tracking node
      if (bookingId != null) {
        final sanitizedBookingId = _sanitizePath(bookingId);
        final orderRef = _db.ref(
          '$tenantId/order_tracking/$sanitizedBookingId/lastLocation',
        );
        try {
          await orderRef.update({
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': ServerValue.timestamp,
          });
        } catch (_) {
          await orderRef.set({
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': ServerValue.timestamp,
          });
        }
      }
    } catch (e) {
      debugPrint('Database Update Error: $e');
      // If internet is gone, we don't crash, we just wait for next update.
    }
  }

  Future<void> _updateFirestoreHeartbeat(
    String engineerId,
    Position position,
  ) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: engineerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('EngineerLogin')
            .doc(docId)
            .update({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'lastUpdatedTime': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint('Firestore Heartbeat Error: $e');
    }
  }

  Future<void> _updateActiveBooking(String engineerId, String bookingId) async {
    await _ensureAuthenticated();
    try {
      final sanitizedId = _sanitizePath(engineerId);
      final tenantId = ThemeService.instance.databaseName;
      final ref = _db.ref('$tenantId/engineers/$sanitizedId');
      try {
        await ref.update({
          'activeBookingId': bookingId,
        });
      } catch (_) {
        await ref.set({
          'activeBookingId': bookingId,
          'isOnline': true,
          'lastOnline': ServerValue.timestamp,
        });
      }
      // Also store booking reference in Firestore for consistency
      final querySnapshot = await FirebaseFirestore.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: engineerId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('EngineerLogin')
            .doc(docId)
            .update({'activeBookingId': bookingId});
      }
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
      final updates = <String, dynamic>{
        'isOnline': isOnline,
        'lastOnline': ServerValue.timestamp,
      };
      if (isOnline && bookingId != null) {
        updates['activeBookingId'] = bookingId;
      }
      try {
        await ref.update(updates);
      } catch (_) {
        await ref.set(updates);
      }
    } catch (e) {
      debugPrint('Status Update Error: $e');
    }
  }

  Future<bool> _handlePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: Location services are disabled.');
      // Optionally prompt user to enable services
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      debugPrint('LocationService: Permission denied. Requesting...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: Permission denied by user.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('LocationService: Permission denied forever.');
      // Users must manually enable in settings
      return false;
    }

    // For background tracking on Android and iOS (skip on web)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Request 'locationAlways' specifically for background support if needed
      var alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted) {
        debugPrint(
          'LocationService: Requesting "Always" permission for background tracking.',
        );
        alwaysStatus = await Permission.locationAlways.request();

        if (alwaysStatus.isPermanentlyDenied) {
          debugPrint(
            'LocationService: "Always" permission permanently denied.',
          );
          // On some versions of Android, user might need to go to settings
          // openAppSettings();
        }
      }
    }

    debugPrint('LocationService: All necessary permissions granted.');
    return true;
  }

  /// Fetches the current position and reverse geocodes it to an address string
  Future<Map<String, dynamic>?> getCurrentLocationData() async {
    bool hasPermission = await _handlePermissions();
    if (!hasPermission) return null;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String address = "";
      if (kIsWeb) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
          );
          final response = await http.get(url, headers: {
            'User-Agent': 'subscription_rooks_app/1.0',
          });
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            address = data['display_name'] ?? '';
          }
        } catch (e) {
          debugPrint('Web geocoding error: $e');
        }
        if (address.isEmpty) {
          address = "Lat: ${position.latitude}, Lng: ${position.longitude}";
        }
      } else {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          geo.Placemark place = placemarks[0];
          address =
              "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
        }
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
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
