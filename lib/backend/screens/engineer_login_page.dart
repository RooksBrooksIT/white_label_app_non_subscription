import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';

class EngineerLoginBackend {
  static Future<String?> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('engineerName');
    if (name != null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous Auth failed (checkLoginStatus): $e');
      }
    }
    return name;
  }

  static Future<void> registerFcmToken(String engineerName) async {
    try {
      // Use the unified NotificationService for consistency
      await NotificationService.instance.registerToken(
        userId: engineerName,
        role: 'engineer',
      );
    } catch (e) {
      debugPrint('Error registering engineer FCM token: $e');
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
    String referralCode,
  ) async {
    try {
      // 1. Identify Tenant via Referral Code
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(referralCode);
      if (referralData == null) {
        return {'success': false, 'message': 'Invalid Referral Code.'};
      }
      final tenantId = referralData['tenantId']!;
      final referralAppId = referralData['appId'] ?? 'data';

      // 2. Query Engineer within the specific Organization
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: tenantId)
          .where('Username', isEqualTo: username)
          .where('Password', isEqualTo: password)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 3. Check Organization Subscription
        final isSubscribed = await FirestoreService.instance.isTenantActive(
          tenantId: tenantId,
          appId: referralAppId,
        );
        if (!isSubscribed) {
          return {
            'success': false,
            'message':
                'Your organization\'s subscription has expired. Please contact your admin.',
          };
        }

        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (e) {
          debugPrint('Anonymous Auth failed (login): $e');
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('engineerName', username);
        await prefs.setString('tenantId', tenantId); // Store tenant association
        await registerFcmToken(username);

        // Sync branding configuration immediately
        await FirestoreService.instance.syncBranding(tenantId);

        // Mark engineer as online
        await FirestoreService.instance.updateEngineerStatus(
          tenantId: tenantId,
          username: username,
          isOnline: true,
        );

        return {'success': true, 'username': username};
      } else {
        return {
          'success': false,
          'message': 'Invalid credentials for this organization.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
    String username,
    String phone,
    String newPass,
    String referralCode,
  ) async {
    try {
      // 1. Identify Tenant via Referral Code
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(referralCode);
      if (referralData == null) {
        return {'success': false, 'message': 'Invalid Referral Code.'};
      }
      final tenantId = referralData['tenantId']!;

      final query = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: tenantId)
          .where('Username', isEqualTo: username)
          .where('Phone', isEqualTo: phone)
          .get();

      if (query.docs.isNotEmpty) {
        final docId = query.docs.first.id;
        await FirestoreService.instance
            .collection('EngineerLogin', tenantId: tenantId)
            .doc(docId)
            .update({'Password': newPass});
        return {'success': true, 'message': 'Password updated successfully.'};
      } else {
        return {
          'success': false,
          'message': 'Username, phone number, or referral code is incorrect.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to update password.'};
    }
  }
}
