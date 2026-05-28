import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AttendanceService {
  static final AttendanceService instance = AttendanceService._internal();
  AttendanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkIn(String engineerName) async {
    try {
      // 1. Verify GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // 2. Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 3. Get Current Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Update EngineerLogin collection in Firebase
      
      // Find the engineer document
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: engineerName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Engineer profile not found in database.');
      }

      final docId = querySnapshot.docs.first.id;

      // Update the fields in the document
      // Direct Firestore update with tenant handling
      final tenantId = ThemeService.instance.databaseName;
      final docRef = FirebaseFirestore.instance
          .collection(tenantId)
          .doc('data')
          .collection('EngineerLogin')
          .doc(docId);
      await docRef.update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdatedTime': FieldValue.serverTimestamp(),
        'isCheckedIn': true,
        'isLocationEnabled': true,
      });

      return true;
    } catch (e) {
      debugPrint('CheckIn Error: $e');
      rethrow;
    }
  }

  // Check if engineer is checked in
  Future<bool> hasCheckedInToday(String engineerName) async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: engineerName)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['isCheckedIn'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('hasCheckedInToday Error: $e');
      return false; // Fail safe
    }
  }
}
