import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';
import 'package:subscription_rooks_app/subscription/subscription_plans_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/amc_customerlogin_page.dart';
import 'package:subscription_rooks_app/subscription/access_restricted_screen.dart';

class AuthStateService extends ChangeNotifier {
  AuthStateService._();
  static final AuthStateService instance = AuthStateService._();

  static const String _kIsRegistered = 'app_is_registered';
  static const String _kUserRole = 'user_role';

  FirebaseAuth? _auth;
  FirebaseAuth get auth {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint('Failed to get FirebaseAuth instance: $e');
      }
    }
    return _auth!;
  }

  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;
  User? get currentUser => _auth?.currentUser;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isRegistered = prefs.getBool(_kIsRegistered) ?? false;

    try {
      _auth = FirebaseAuth.instance;
      // Also check if user is logged in via Firebase
      if (_auth?.currentUser != null) {
        // If Firebase user exists, we consider it a registered session
        _isRegistered = true;
        await prefs.setBool(_kIsRegistered, true);
      }
    } catch (e) {
      debugPrint('Firebase not fully ready during AuthStateService.init: $e');
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Safety check
      if (Firebase.apps.isEmpty) {
        return {'success': false, 'message': 'Firebase is not initialized.'};
      }

      debugPrint('Attempting to register user: $email with role: $role');

      // 1. Create user in Firebase Auth
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Determine proper scope (Company DB)
      String targetScope = ThemeService.instance.appName;

      if (role == 'admin') {
        // Generate dynamic collection name: OrganizationName_YYYYMMDD
        final now = DateTime.now();
        final dateStr =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
        // Clean organization name (remove spaces)
        final cleanOrgName = name.replaceAll(' ', '');
        targetScope = "${cleanOrgName}_$dateStr";
      } else if (additionalData != null &&
          additionalData.containsKey('linkedAppName')) {
        targetScope = additionalData['linkedAppName'];
      }

      // 2. Store details in Firestore (Isolated to Company DB)
      final userData = {
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'registeredAt': FieldValue.serverTimestamp(),
        'isApproved': role == 'admin' ? true : false,
        'active': false, // User starts inactive until subscription is completed
        'tenantId': targetScope, // Store the tenant ID or scope
        ...?additionalData,
      };

      // Store in the specific Company's 'users' collection
      await FirestoreService.instance
          .collection('users', tenantId: targetScope)
          .doc(uid)
          .set(userData);

      // 2b. Register in Global Directory for Login Lookup
      // Every user (including Admin) must be in the global directory to be found during login
      await FirestoreService.instance.saveUserDirectory(
        uid: uid,
        tenantId: targetScope,
        appName: 'data', // Stable ID for primary app
        role: role,
      );

      // 3. Mark as registered locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true);
      await prefs.setString(_kUserRole, role);
      _isRegistered = true;

      if (role == 'admin' || role == 'Owner') {
        // Also register in the 'admin' collection for backward compatibility with AdminLoginBackend
        await FirestoreService.instance
            .collection('admin', tenantId: targetScope)
            .doc(name)
            .set({
              'email': email,
              'password':
                  password, // Note: Existing logic uses plain text password in this collection
              'name': name,
              'tenantId': targetScope,
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });

        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('admin_email', email);
        await prefs.setString('admin_org_collection', targetScope);
        await prefs.setString('last_role', role);

        ThemeService.instance.updateTheme(
          primary: ThemeService.instance.primaryColor,
          secondary: ThemeService.instance.secondaryColor,
          backgroundColor: ThemeService.instance.backgroundColor,
          isDarkMode: ThemeService.instance.isDarkMode,
          fontFamily: ThemeService.instance.fontFamily,
          appName: name,
          databaseName: targetScope,
        );
      }
      notifyListeners();

      return {'success': true, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration Error (FirebaseAuth): ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': 'Auth Error: ${e.message} (Code: ${e.code})',
      };
    } catch (e) {
      debugPrint('Registration Error (App): $e');
      return {'success': false, 'message': 'System Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // 1. Check Global Directory for Tenant Association
      final metadata = await FirestoreService.instance.getUserMetadata(uid);
      String scope = ThemeService.instance.appName;

      if (metadata != null) {
        scope = metadata['tenantId'] ?? scope;
        // Fetch actual branding from 'branding/config' under the tenant
        // Always prefer the stable 'data' bucket for branding
        final brandingDoc = await FirestoreService.instance
            .brandingDoc(tenantId: scope, appId: 'data')
            .get();

        Map<String, dynamic>? brandingData;
        if (brandingDoc.exists) {
          brandingData = brandingDoc.data();
        } else {
          // Fallback check if for some reason 'data' isn't there but a named one is
          final appNameFromMetadata = metadata['appName'];
          if (appNameFromMetadata != null && appNameFromMetadata != 'data') {
            final namedDoc = await FirestoreService.instance
                .brandingDoc(tenantId: scope, appId: appNameFromMetadata)
                .get();
            if (namedDoc.exists) {
              brandingData = namedDoc.data();
            }
          }
        }

        final appName = brandingData?['appName'] ?? metadata['appName'];

        ThemeService.instance.updateTheme(
          primary: brandingData?['primaryColor'] != null
              ? Color(brandingData!['primaryColor'])
              : ThemeService.instance.primaryColor,
          secondary: brandingData?['secondaryColor'] != null
              ? Color(brandingData!['secondaryColor'])
              : ThemeService.instance.secondaryColor,
          backgroundColor: brandingData?['backgroundColor'] != null
              ? Color(brandingData!['backgroundColor'])
              : ThemeService.instance.backgroundColor,
          isDarkMode:
              brandingData?['useDarkMode'] ?? ThemeService.instance.isDarkMode,
          fontFamily:
              brandingData?['fontFamily'] ?? ThemeService.instance.fontFamily,
          appName: appName ?? scope,
          databaseName: scope,
          logoUrl: brandingData?['logoUrl'],
        );
      }

      // Fetch user data from the specific Company DB
      final doc = await FirestoreService.instance
          .collection('users', tenantId: scope)
          .doc(uid)
          .get();

      if (!doc.exists) {
        // Fallback: Check global/default bucket if not found in specific scope?
        // Or return error.
        return {'success': false, 'message': 'User record not found in $scope'};
      }

      final userData = doc.data() as Map<String, dynamic>;
      final role = userData['role'] ?? 'user';

      // 1. Unified Subscription Check for all roles
      // Always look for subscription in the stable 'data' bucket
      final isSubscribed = await FirestoreService.instance.isTenantActive(
        tenantId: scope,
        appId: 'data',
      );

      if (!isSubscribed) {
        if (role == 'admin' || role == 'Owner') {
          // Admins are sent to SubscriptionPlansScreen
          return {
            'success': true,
            'userData': userData,
            'needsSubscription': true,
          };
        } else {
          // Engineers and Customers are blocked from logging in
          return {
            'success': false,
            'message':
                'Your administrator hasn\'t subscribed to a plan. Please contact your admin for access.',
          };
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true); // Ensure this is set
      await prefs.setString(_kUserRole, role);

      if (role == 'admin' || role == 'Owner') {
        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('last_role', role);
      }

      _isRegistered = true;
      notifyListeners();

      return {'success': true, 'userData': userData};
    } on FirebaseAuthException catch (e) {
      debugPrint('Login Error (FirebaseAuth): ${e.code} - ${e.message}');

      String diagnosticMessage = e.message ?? 'Login failed';

      // FALLBACK CHECK: If auth fails, check if user exists only in legacy 'admin' collection
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        try {
          final legacyCheck = await FirestoreService.instance
              .collectionGroup('admin')
              .where('email', isEqualTo: email)
              .get();

          if (legacyCheck.docs.isNotEmpty) {
            diagnosticMessage =
                'This account exists in our legacy system but hasn\'t been migrated to the new secure login. Please use the "Forgot Password" flow or contact support to migrate.';
            debugPrint(
              'Diagnostic: User found in legacy admin collection but Auth failed.',
            );
          }
        } catch (err) {
          debugPrint('Legacy fallback check failed: $err');
        }
      }

      return {'success': false, 'message': diagnosticMessage};
    } catch (e) {
      debugPrint('Login Error (System): $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await auth.signOut();

    final prefs = await SharedPreferences.getInstance();

    // Clear Admin session (but keep org/branding context)
    await prefs.remove('admin_isLoggedIn');
    await prefs.remove('admin_email');

    // Clear Engineer session
    await prefs.remove('engineerName');
    await prefs.remove('engineerEmail');

    // Clear Customer session
    await prefs.remove('email');

    // Clear unified session flags
    await prefs.remove(_kUserRole);
    await prefs.remove('last_role');

    _isRegistered = false;
    notifyListeners();
  }

  /// Determines the initial screen based on persisted login state
  Future<Widget> getInitialScreen() async {
    try {
      debugPrint('AuthStateService: Determining initial screen...');
      final prefs = await SharedPreferences.getInstance();

      // 1. Check for active Firebase Session (Recovery path)
      final user = auth.currentUser;
      if (user != null && !user.isAnonymous) {
        debugPrint(
          'AuthStateService: Firebase session found for ${user.email}',
        );
        final metadata = await FirestoreService.instance.getUserMetadata(
          user.uid,
        );
        if (metadata != null) {
          final role = metadata['role'] as String?;
          final tenantId = metadata['tenantId'] as String?;
          debugPrint(
            'AuthStateService: Recovered metadata - role: $role, tenant: $tenantId',
          );

          // Restore SharedPreferences flags to maintain consistency
          await prefs.setBool(_kIsRegistered, true);
          await prefs.setString(_kUserRole, role ?? 'user');

          if (tenantId != null) {
            await prefs.setString('tenantId', tenantId);
            await prefs.setString('databaseName', tenantId);
            final appName = metadata['appName'] as String?;
            if (appName != null) {
              await prefs.setString('appName', appName);
            }
            // Initialize branding for the recovered tenant
            await FirestoreService.instance.syncBranding(
              tenantId,
              appId: 'data',
            );
          }

          if (role == 'admin' || role == 'Owner') {
            await prefs.setBool('admin_isLoggedIn', true);
            await prefs.setString('admin_email', user.email ?? '');
            if (tenantId != null) {
              await prefs.setString('admin_org_collection', tenantId);
            }
            if (metadata.containsKey('appName')) {
              await prefs.setString('appName', metadata['appName'] ?? '');
            } else if (metadata.containsKey('name')) {
              await prefs.setString('appName', metadata['name'] ?? '');
            }

            // Check subscription before allowing dashboard access
            final effectiveTenant =
                tenantId ?? ThemeService.instance.databaseName;
            final isSubscribed = await FirestoreService.instance.isTenantActive(
              tenantId: effectiveTenant,
              appId: 'data',
            );
            if (!isSubscribed) {
              return const SubscriptionPlansScreen();
            }
            return const admindashboard();
          } else {
            // Engineer or Customer
            final effectiveTenant =
                tenantId ?? ThemeService.instance.databaseName;
            final isSubscribed = await FirestoreService.instance.isTenantActive(
              tenantId: effectiveTenant,
              appId: 'data',
            );

            if (!isSubscribed) {
              return AccessRestrictedScreen(role: role ?? 'user');
            }

            if (role == 'engineer') {
              final name = metadata['name'] ?? metadata['Username'] ?? '';
              await prefs.setString('engineerName', name);
              return EngineerPage(userEmail: user.email ?? '', userName: name);
            } else if (role == 'customer') {
              await prefs.setString('email', user.email ?? '');
              return const AMCCustomerMainPage();
            }
          }
        }
      }

      // 2. Fallback to existing logic if no Firebase user or metadata not found
      // Check Admin
      final bool isAdminLoggedIn = await AdminLoginBackend.checkLoginStatus();
      if (isAdminLoggedIn) {
        final adminTenantId = prefs.getString('admin_org_collection');
        if (adminTenantId != null) {
          // Sync branding for the found session
          await FirestoreService.instance.syncBranding(adminTenantId);

          final isSubscribed = await FirestoreService.instance.isTenantActive(
            tenantId: adminTenantId,
            appId: 'data',
          );
          if (!isSubscribed) {
            return const SubscriptionPlansScreen();
          }
        }
        return const admindashboard();
      }

      // Check Engineer
      final String? engineerName =
          await EngineerLoginBackend.checkLoginStatus();
      if (engineerName != null) {
        final tenantId = prefs.getString('tenantId');
        if (tenantId != null) {
          final isSubscribed = await FirestoreService.instance.isTenantActive(
            tenantId: tenantId,
            appId: 'data',
          );
          if (!isSubscribed) {
            return const AccessRestrictedScreen(role: 'engineer');
          }
        }
        return EngineerPage(userEmail: '', userName: engineerName);
      }

      // Check Customer
      final String? customerEmail = await AMCLoginBackend.checkLoginStatus();
      if (customerEmail != null) {
        final tenantId = prefs.getString('tenantId');
        if (tenantId != null) {
          final isSubscribed = await FirestoreService.instance.isTenantActive(
            tenantId: tenantId,
            appId: 'data',
          );
          if (!isSubscribed) {
            return const AccessRestrictedScreen(role: 'customer');
          }
        }
        return const AMCCustomerMainPage();
      }

      debugPrint(
        'AuthStateService: No session found, checking for last used role',
      );
      final lastRole = prefs.getString('last_role');
      if (lastRole == 'admin' || lastRole == 'Owner') {
        return const AdminLogin();
      }

      return const RoleSelectionScreen();
    } catch (e) {
      debugPrint('AuthStateService: Error determining initial screen: $e');
      // Default to role selection on error
      return const RoleSelectionScreen();
    }
  }
}
