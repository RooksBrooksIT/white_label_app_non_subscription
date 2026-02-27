import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';

class CustomerDashboardBackend {
  static Future<Map<String, String?>> getStoredUserInfo(
    String defaultName,
    String defaultPhone,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'userName': prefs.getString('userName') ?? defaultName,
      'phoneNumber': prefs.getString('phoneNumber') ?? defaultPhone,
    };
  }

  static Future<void> saveFcmToken(String id, String email) async {
    try {
      await NotificationService.instance.registerToken(
        role: 'customer',
        userId: id,
        email: email,
      );
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Logout error: $e');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}
