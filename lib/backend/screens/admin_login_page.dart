import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

class AdminLoginBackend {
  static Future<bool> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isExplicitlyLoggedIn = prefs.getBool(AuthStateService.kIsLoggedIn) ?? false;
    final role = prefs.getString(AuthStateService.kUserRole);
    final adminLoggedIn = prefs.getBool('admin_isLoggedIn') ?? false;
    return (isExplicitlyLoggedIn && role == 'admin') || adminLoggedIn;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final cleanEmail = email.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();

      QuerySnapshot snapshot = await FirestoreService.instance
          .collectionGroup('admin')
          .where('email', isEqualTo: cleanEmail)
          .where('password', isEqualTo: password)
          .get();

      var adminDocs = snapshot.docs;
      if (adminDocs.isEmpty) {
        // Fallback: Check if an existing admin record contains spaces
        final pwdMatches = await FirestoreService.instance
            .collectionGroup('admin')
            .where('password', isEqualTo: password)
            .get();
        for (final doc in pwdMatches.docs) {
          final existingData = doc.data();
          final existingEmail = (existingData['email'] ?? '').toString();
          final normalized = existingEmail.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
          if (normalized.isNotEmpty && normalized == cleanEmail) {
            // Auto-migrate record to clean email
            try {
              await doc.reference.update({'email': cleanEmail});
            } catch (_) {}
            adminDocs = [doc];
            break;
          }
        }
      }

      if (adminDocs.isNotEmpty) {
        final docData = adminDocs.first.data() as Map<String, dynamic>;
        String? tenantId = docData['tenantId'] as String?;
        if (tenantId == null || tenantId.isEmpty) {
          // If tenantId field is missing, extract from the path: {tenantId}/data/admin/{docId}
          tenantId = adminDocs.first.reference.parent.parent?.parent.id;
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('admin_email', cleanEmail);
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

        // Save persistent session via AuthStateService
        await AuthStateService.instance.saveAdminSession(
          email: cleanEmail,
          tenantId: tenantId ?? '',
          appName: docData['name'] as String?,
        );

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
      final cleanEmail = email.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();

      // Check if admin already exists
      QuerySnapshot snapshot = await FirestoreService.instance
          .collectionGroup('admin')
          .where('email', isEqualTo: cleanEmail)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Admin with this email already exists.',
        };
      }

      // Format tenant collection name: cleanName_YYYYMMDD
      final orgCollectionName =
          await FirestoreService.getUniqueTenantId(name);

      // Store in the organizational root collection
      await FirestoreService.instance
          .collection('admin', tenantId: orgCollectionName)
          .doc(name)
          .set({
            'email': cleanEmail,
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
