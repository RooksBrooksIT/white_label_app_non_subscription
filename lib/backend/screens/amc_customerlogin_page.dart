import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

class AMCLoginBackend {
  static Future<String?> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isExplicitlyLoggedIn = prefs.getBool(AuthStateService.kIsLoggedIn) ?? false;
    final role = prefs.getString(AuthStateService.kUserRole);
    final email = prefs.getString(AuthStateService.kCustomerEmail) ?? prefs.getString('email');
    if (email != null && email.isNotEmpty && (isExplicitlyLoggedIn ? role == 'customer' : true)) {
      return email;
    }
    return null;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
    String referralCode,
  ) async {
    try {
      final cleanEmail = email.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
      final cleanReferralCode = referralCode.replaceAll(RegExp(r'\s+'), '').trim();

      // 1. Identify Tenant via Referral Code
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(cleanReferralCode);
      if (referralData == null) {
        return {'success': false, 'message': 'Invalid Referral Code.'};
      }
      final tenantId = referralData['tenantId']!;
      final referralAppId = referralData['appId'] ?? 'data';

      // 2. Query User within the specific Organization
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user', tenantId: tenantId)
          .where('email', isEqualTo: cleanEmail)
          .where('password', isEqualTo: password)
          .get();

      var userDocs = querySnapshot.docs;
      if (userDocs.isEmpty) {
        // Fallback: Check if an existing account with spaces matches when whitespace is removed
        final pwdMatches = await FirestoreService.instance
            .collection('AMC_user', tenantId: tenantId)
            .where('password', isEqualTo: password)
            .get();
        for (final doc in pwdMatches.docs) {
          final existingEmail = (doc.data()['email'] ?? '').toString();
          final normalized = existingEmail.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
          if (normalized.isNotEmpty && normalized == cleanEmail) {
            // Auto-migrate record to clean email
            try {
              await doc.reference.update({'email': cleanEmail});
            } catch (_) {}
            userDocs = [doc];
            break;
          }
        }
      }

      if (userDocs.isNotEmpty) {
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

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', cleanEmail);
        await prefs.setString('tenantId', tenantId); // Store tenant association
        await prefs.setBool('app_is_registered', true);
        await prefs.setString('user_role', 'customer');
        await prefs.setString('last_role', 'customer');

        // Save persistent session via AuthStateService
        await AuthStateService.instance.saveCustomerSession(
          email: cleanEmail,
          tenantId: tenantId,
        );

        // Sync branding configuration immediately
        await FirestoreService.instance.syncBranding(tenantId);

        // Register FCM token for the customer immediately upon login
        final userId = userDocs.first.data()['Id'] ?? '';
        if (userId.isNotEmpty) {
          NotificationService.instance.registerToken(
            role: 'customer',
            userId: userId,
            email: cleanEmail,
          );
        }

        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Invalid email or password for this organization.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}
