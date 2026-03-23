import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class LocationService {
  LocationService._privateConstructor();
  static final LocationService instance = LocationService._privateConstructor();

  StreamSubscription<Position>? _positionStream;
  final Logger _log = Logger();

  /// Request "always" location permission.
  Future<bool> _requestPermission() async {
    var status = await Permission.locationAlways.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      status = await Permission.locationAlways.request();
    }
    return status.isGranted;
  }

  /// Start listening to location updates. This works in the background on iOS
  /// because `allowsBackgroundLocationUpdates` is set to true in AppDelegate.
  /// Public method used by UI to start background tracking for a specific user.
  Future<void> startTracking([String? userId]) async {
    // userId can be used for analytics or tagging if needed.
    await startLocationUpdates();
  }

  /// Public method used by UI to stop background tracking.
  Future<void> stopTracking([String? userId]) async {
    await stopLocationUpdates();
  }

  Future<void> startLocationUpdates() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      _log.w('Location permission not granted');
      return;
    }

    // Ensure location services are enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log.w('Location services are disabled');
      return;
    }

    // Define high‑accuracy settings suitable for real‑time tracking.
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // receive all updates
      // iOS specific: time interval in milliseconds
      // (Geolocator forwards this to the native API)
      // ignore: avoid_dynamic_calls
      // (the field exists on iOS only, safe to set)
      // timeInterval: 1000,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            // Here you would send the position to your backend or update UI.
            _log.i(
              'Background location: ${position.latitude}, ${position.longitude}',
            );
          },
          onError: (e) {
            _log.e('Location stream error: $e');
          },
        );
  }

  /// Stop listening when the app is terminated or you no longer need updates.
  Future<void> stopLocationUpdates() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
