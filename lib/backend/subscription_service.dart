import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

/// A service class responsible for handling subscription-related Firestore operations.
class SubscriptionService {
  final FirestoreService _firestore = FirestoreService.instance;

  /// Sanitizes the username by converting it to lowercase and removing all spaces
  /// and special characters.
  String sanitizeUsername(String username) {
    // Convert to lowercase
    String sanitized = username.toLowerCase();
    // Remove all spaces and non-alphanumeric characters
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return sanitized;
  }

  /// Generates the dynamic username_date segment in the format: username_dd_MM_yyyy
  String generateUsernameDateSegment(String username) {
    return FirestoreService.generateTenantId(username);
  }

  /// Saves subscription data to Firestore using a dynamic user tenant path structure:
  /// {username_date} -> subscription -> entries -> {autoDocumentId}
  Future<void> saveSubscription({
    required String appName,
    required String username,
    required String email,
    required String phone,
  }) async {
    try {
      String usernameDate = generateUsernameDateSegment(username);

      // Path: main/{appName}/subscription/{username_date}/entries/{autoId}
      await _firestore
          .collection('subscription')
          .doc(usernameDate)
          .collection('entries')
          .add({
            'username': username,
            'email': email,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error saving subscription: $e');
      rethrow;
    }
  }
}
