import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminLoginBackend {
  static Future<bool> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('admin_isLoggedIn') ?? false;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      QuerySnapshot snapshot = await FirestoreService.instance
          .collectionGroup('admin')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docData = snapshot.docs.first.data() as Map<String, dynamic>;
        String? tenantId = docData['tenantId'] as String?;
        if (tenantId == null || tenantId.isEmpty) {
          // If tenantId field is missing, extract from the path: {tenantId}/data/admin/{docId}
          tenantId = snapshot.docs.first.reference.parent.parent?.parent.id;
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('admin_email', email);
        await prefs.setBool('app_is_registered', true);
        await prefs.setString('user_role', 'admin');
        await prefs.setString('last_role', 'admin');

        if (tenantId != null && tenantId.isNotEmpty) {
          await prefs.setString('admin_org_collection', tenantId);
          await prefs.setString('databaseName', tenantId);
          await prefs.setString('tenantId', tenantId);
          if (docData.containsKey('name')) {
            await prefs.setString('appName', docData['name']);
          }

          // Sync branding configuration immediately for this specific tenant!
          await FirestoreService.instance.syncBranding(
            tenantId,
            appId: 'data',
          );
        }

        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Invalid email or password. Please try again.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String name,
  ) async {
    try {
      // Check if admin already exists
      QuerySnapshot snapshot = await FirestoreService.instance
          .collection('admin')
          .where('email', isEqualTo: email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Admin with this email already exists.',
        };
      }

      // Format tenant collection name: cleanName_dd_mm_yyyy
      final orgCollectionName = FirestoreService.generateTenantId(name);

      // Store in the organizational root collection
      await FirestoreService.instance
          .collection('admin', tenantId: orgCollectionName)
          .doc(name)
          .set({
            'email': email,
            'password': password,
            'name': name,
            'tenantId': orgCollectionName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Also mark in global directory if needed or just use SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_org_collection', orgCollectionName);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
