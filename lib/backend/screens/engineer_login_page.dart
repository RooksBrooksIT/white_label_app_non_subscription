import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

class EngineerLoginBackend {
  static Future<String?> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isExplicitlyLoggedIn = prefs.getBool(AuthStateService.kIsLoggedIn) ?? false;
    final role = prefs.getString(AuthStateService.kUserRole);
    final name = prefs.getString(AuthStateService.kEngineerName) ?? prefs.getString('engineerName');
    if (name != null && name.isNotEmpty && (isExplicitlyLoggedIn ? role == 'engineer' : true)) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous Auth failed (checkLoginStatus): $e');
      }
      return name;
    }
    return null;
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
      final cleanUsername = username.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanReferralCode = referralCode.replaceAll(RegExp(r'\s+'), '').trim();

      // 1. Identify Tenant via Referral Code
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(cleanReferralCode);
      if (referralData == null) {
        return {'success': false, 'message': 'Invalid Referral Code.'};
      }
      final tenantId = referralData['tenantId']!;
      final referralAppId = referralData['appId'] ?? 'data';

      // 2. Query Engineer within the specific Organization
      var querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: tenantId)
          .where('Username', isEqualTo: cleanUsername)
          .where('Password', isEqualTo: password)
          .get();

      // 3. Compatibility fallback for existing records with spaces (e.g. 'alen roy')
      if (querySnapshot.docs.isEmpty) {
        final legacySnapshot = await FirestoreService.instance
            .collection('EngineerLogin', tenantId: tenantId)
            .where('Password', isEqualTo: password)
            .get();

        for (final doc in legacySnapshot.docs) {
          final storedUsername = doc.data()['Username']?.toString() ?? '';
          final storedClean =
              storedUsername.replaceAll(RegExp(r'\s+'), '').trim();
          if (storedClean.toLowerCase() == cleanUsername.toLowerCase()) {
            // Found existing user record with spaces - auto-migrate to clean username
            await doc.reference.update({'Username': cleanUsername});
            querySnapshot = await FirestoreService.instance
                .collection('EngineerLogin', tenantId: tenantId)
                .where('Username', isEqualTo: cleanUsername)
                .where('Password', isEqualTo: password)
                .get();
            break;
          }
        }
      }

      if (querySnapshot.docs.isNotEmpty) {
        // 4. Check Organization Subscription
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

        final engineerDocData = querySnapshot.docs.first.data();
        final email = (engineerDocData['Email'] ?? engineerDocData['email'] ?? '') as String;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('engineerName', cleanUsername);
        if (email.isNotEmpty) {
          await prefs.setString('engineerEmail', email);
        }
        await prefs.setString('tenantId', tenantId); // Store tenant association
        await prefs.setBool('app_is_registered', true);
        await prefs.setString('user_role', 'engineer');
        await prefs.setString('last_role', 'engineer');
        await registerFcmToken(cleanUsername);

        // Save persistent session via AuthStateService
        await AuthStateService.instance.saveEngineerSession(
          username: cleanUsername,
          tenantId: tenantId,
          email: email.isNotEmpty ? email : null,
        );

        // Sync branding configuration immediately
        await FirestoreService.instance.syncBranding(tenantId);

        // Mark engineer as online
        await FirestoreService.instance.updateEngineerStatus(
          tenantId: tenantId,
          username: cleanUsername,
          isOnline: true,
        );

        return {'success': true, 'username': cleanUsername};
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
      final cleanUsername = username.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanReferralCode = referralCode.replaceAll(RegExp(r'\s+'), '').trim();

      // 1. Identify Tenant via Referral Code
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(cleanReferralCode);
      if (referralData == null) {
        return {'success': false, 'message': 'Invalid Referral Code.'};
      }
      final tenantId = referralData['tenantId']!;

      var query = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: tenantId)
          .where('Username', isEqualTo: cleanUsername)
          .where('Phone', isEqualTo: cleanPhone)
          .get();

      // Compatibility fallback for legacy records with spaces
      if (query.docs.isEmpty) {
        final legacySnapshot = await FirestoreService.instance
            .collection('EngineerLogin', tenantId: tenantId)
            .where('Phone', isEqualTo: cleanPhone)
            .get();

        for (final doc in legacySnapshot.docs) {
          final storedUsername = doc.data()['Username']?.toString() ?? '';
          final storedClean =
              storedUsername.replaceAll(RegExp(r'\s+'), '').trim();
          if (storedClean.toLowerCase() == cleanUsername.toLowerCase()) {
            await doc.reference.update({'Username': cleanUsername});
            query = await FirestoreService.instance
                .collection('EngineerLogin', tenantId: tenantId)
                .where('Username', isEqualTo: cleanUsername)
                .where('Phone', isEqualTo: cleanPhone)
                .get();
            break;
          }
        }
      }

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
