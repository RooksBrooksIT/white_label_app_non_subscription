import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';

class AMCLoginBackend {
  static Future<String?> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  static Future<Map<String, dynamic>> login(
    String email,
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

      // 2. Query User within the specific Organization
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user', tenantId: tenantId)
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
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

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);
        await prefs.setString('tenantId', tenantId); // Store tenant association

        // Sync branding configuration immediately
        await FirestoreService.instance.syncBranding(tenantId);

        // Register FCM token for the customer immediately upon login
        final userId = querySnapshot.docs.first.data()['Id'] ?? '';
        if (userId.isNotEmpty) {
          NotificationService.instance.registerToken(
            role: 'customer',
            userId: userId,
            email: email,
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
