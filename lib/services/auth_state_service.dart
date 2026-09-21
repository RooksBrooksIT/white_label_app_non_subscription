import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/subscription/payment_recovery_screen.dart';

class AuthStateService extends ChangeNotifier {
  AuthStateService._();
  static final AuthStateService instance = AuthStateService._();

  static const String _kIsRegistered = 'app_is_registered';
  static const String _kUserRole = 'user_role';
  static const String _kBrandingCompleted = 'branding_completed';

  // Standardized session keys for SharedPreferences-based login persistence
  static const String kIsLoggedIn = 'is_logged_in';
  static const String kUserRole = 'user_role';
  static const String kAdminIsLoggedIn = 'admin_isLoggedIn';
  static const String kAdminEmail = 'admin_email';
  static const String kAdminOrgCollection = 'admin_org_collection';
  static const String kEngineerName = 'engineerName';
  static const String kEngineerEmail = 'engineerEmail';
  static const String kCustomerEmail = 'email';
  static const String kTenantId = 'tenantId';
  static const String kDatabaseName = 'databaseName';
  static const String kAppName = 'appName';

  /// Save session for Admin / Business Owner role
  Future<void> saveAdminSession({
    required String email,
    required String tenantId,
    String? appName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIsLoggedIn, true);
    await prefs.setString(kUserRole, 'admin');
    await prefs.setString('last_role', 'admin');
    await prefs.setBool(kAdminIsLoggedIn, true);
    await prefs.setString(kAdminEmail, email);
    await prefs.setBool(_kIsRegistered, true);
    await prefs.setBool(_kBrandingCompleted, true);
    if (tenantId.isNotEmpty) {
      await prefs.setString(kAdminOrgCollection, tenantId);
      await prefs.setString(kTenantId, tenantId);
      await prefs.setString(kDatabaseName, tenantId);
      await prefs.setBool('${_kBrandingCompleted}_$tenantId', true);
    }
    if (appName != null && appName.isNotEmpty) {
      await prefs.setString(kAppName, appName);
    }
    _isRegistered = true;
    notifyListeners();
  }

  /// Save session for Service Engineer role
  Future<void> saveEngineerSession({
    required String username,
    required String tenantId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIsLoggedIn, true);
    await prefs.setString(kUserRole, 'engineer');
    await prefs.setString('last_role', 'engineer');
    await prefs.setString(kEngineerName, username);
    if (email != null && email.isNotEmpty) {
      await prefs.setString(kEngineerEmail, email);
    }
    if (tenantId.isNotEmpty) {
      await prefs.setString(kTenantId, tenantId);
      await prefs.setString(kDatabaseName, tenantId);
    }
    await prefs.setBool(_kIsRegistered, true);
    _isRegistered = true;
    notifyListeners();
  }

  /// Save session for Customer role
  Future<void> saveCustomerSession({
    required String email,
    required String tenantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIsLoggedIn, true);
    await prefs.setString(kUserRole, 'customer');
    await prefs.setString('last_role', 'customer');
    await prefs.setString(kCustomerEmail, email);
    if (tenantId.isNotEmpty) {
      await prefs.setString(kTenantId, tenantId);
      await prefs.setString(kDatabaseName, tenantId);
    }
    await prefs.setBool(_kIsRegistered, true);
    _isRegistered = true;
    notifyListeners();
  }

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

  // Temporary storage for registration data during the multi-step process
  Map<String, dynamic>? _pendingRegistrationData;

  void restorePendingRegistrationData(Map<String, dynamic> data) {
    _pendingRegistrationData = data;
  }

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
    String? phone,
    Map<String, dynamic>? additionalData,
    bool deferAuth = false,
  }) async {
    try {
      final cleanEmail = email.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
      final resolvedPhone = phone?.trim() ??
          (additionalData?['phone'] as String?)?.trim() ??
          (additionalData?['customerMobile'] as String?)?.trim() ??
          '';

      final Map<String, dynamic> mergedAdditionalData = {
        if (resolvedPhone.isNotEmpty) ...{
          'phone': resolvedPhone,
          'customerMobile': resolvedPhone,
        },
        ...?additionalData,
      };

      if (deferAuth) {
        final auth = FirebaseAuth.instance;

        // 1. Validate credentials by creating or signing in the Auth account
        if (auth.currentUser == null || auth.currentUser!.email != cleanEmail) {
          try {
            await auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              try {
                await auth.signInWithEmailAndPassword(
                  email: cleanEmail,
                  password: password,
                );
                debugPrint('User already exists, signed in to validate credentials');
              } catch (signInError) {
                return {
                  'success': false,
                  'message': 'Auth Error: The email address is already in use and the password provided is incorrect.',
                };
              }
            } else {
              return {
                'success': false,
                'message': 'Auth Error: ${e.message} (Code: ${e.code})',
              };
            }
          }
        }

        final uid = auth.currentUser!.uid;

        // Determine tenant ID
        String targetScope = '';
        if (mergedAdditionalData.containsKey('tenantId') &&
            (mergedAdditionalData['tenantId'] as String).isNotEmpty) {
          targetScope = mergedAdditionalData['tenantId'];
        } else {
          targetScope = await FirestoreService.getUniqueTenantId(name);
          mergedAdditionalData['tenantId'] = targetScope;
        }

        // Store data in memory
        _pendingRegistrationData = {
          'uid': uid,
          'name': name,
          'email': cleanEmail,
          'password': password,
          'phone': resolvedPhone,
          'role': role,
          'tenantId': targetScope,
          'additionalData': mergedAdditionalData,
        };

        // 2. Immediately write the initial user record to Firestore (with active: false until paid)
        final initialUserData = {
          'uid': uid,
          'name': name,
          'email': cleanEmail,
          if (resolvedPhone.isNotEmpty) ...{
            'phone': resolvedPhone,
            'customerMobile': resolvedPhone,
          },
          'role': role,
          'registeredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isApproved': role == 'admin' ? true : false,
          'active': false,
          'tenantId': targetScope,
          ...mergedAdditionalData,
        };

        await FirestoreService.instance
            .collection('users', tenantId: targetScope)
            .doc(uid)
            .set(initialUserData, SetOptions(merge: true));

        // Register in Global Directory
        await FirestoreService.instance.saveUserDirectory(
          uid: uid,
          tenantId: targetScope,
          appName: 'data',
          role: role,
          email: cleanEmail,
          name: name,
          phone: resolvedPhone,
        );

        // Persist pending tenant to SharedPreferences as safety fallback
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_tenantId', targetScope);
        await prefs.setString('pending_email', cleanEmail);
        if (resolvedPhone.isNotEmpty) {
          await prefs.setString('pending_phone', resolvedPhone);
        }

        debugPrint('Account auth validated & initial record created in Firestore for $cleanEmail ($targetScope)');
        return {'success': true, 'message': 'Account details saved.'};
      }

      final auth = FirebaseAuth.instance;

      // 1. Check if user is already logged in with same email
      if (auth.currentUser != null && auth.currentUser!.email == cleanEmail) {
        debugPrint('User already authenticated: ${auth.currentUser!.uid}');
      } else {
        try {
          await auth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            try {
              await auth.signInWithEmailAndPassword(
                email: cleanEmail,
                password: password,
              );
              debugPrint('User already exists, signed in instead');
            } catch (signInError) {
              return {
                'success': false,
                'message':
                    'Auth Error: The email address is already in use by another account.',
              };
            }
          } else {
            rethrow;
          }
        }
      }

      final uid = auth.currentUser!.uid;

      // Store data for finalization
      _pendingRegistrationData = {
        'uid': uid,
        'name': name,
        'email': cleanEmail,
        'password': password,
        'phone': resolvedPhone,
        'role': role,
        'additionalData': mergedAdditionalData,
        if (mergedAdditionalData.containsKey('tenantId'))
          'tenantId': mergedAdditionalData['tenantId'],
      };

      return await finalizeRegistration();
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

  /// Creates the actual Firebase Auth account and then the Firestore records.
  /// Used after successful payment for new users.
  Future<Map<String, dynamic>> createAndFinalizeAccount({
    Map<String, dynamic>? fallbackData,
  }) async {
    final data = _pendingRegistrationData ?? fallbackData;
    if (data == null) {
      return {
        'success': false,
        'message': 'No pending registration data found.',
      };
    }

    try {
      final email = data['email'];
      final password = data['password'];

      final auth = FirebaseAuth.instance;

      // 1. Create the Auth account if not already logged in
      if (auth.currentUser == null || auth.currentUser!.email != email) {
        try {
          await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            await auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } else {
            rethrow;
          }
        }
      }

      final uid = auth.currentUser!.uid;
      data['uid'] = uid;
      _pendingRegistrationData = data;

      // 2. Call standard finalization to create Firestore records
      return await finalizeRegistration(fallbackData: data);
    } catch (e) {
      debugPrint('Error creating and finalizing account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finalizeRegistration({
    Map<String, dynamic>? fallbackData,
  }) async {
    final data = _pendingRegistrationData ?? fallbackData;
    if (data == null) {
      // Fallback from active Firebase Auth user if available
      final currentAuthUser = auth.currentUser;
      if (currentAuthUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final tenantId = prefs.getString('pending_tenantId') ??
            prefs.getString('admin_org_collection') ??
            ThemeService.instance.databaseName;
        if (tenantId.isNotEmpty) {
          final email = currentAuthUser.email ?? prefs.getString('pending_email') ?? '';
          final phone = prefs.getString('pending_phone') ?? '';
          await FirestoreService.instance
              .collection('users', tenantId: tenantId)
              .doc(currentAuthUser.uid)
              .set({
                'uid': currentAuthUser.uid,
                'email': email,
                if (phone.isNotEmpty) ...{
                  'phone': phone,
                  'customerMobile': phone,
                },
                'tenantId': tenantId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          return {'success': true, 'uid': currentAuthUser.uid};
        }
      }
      return {'success': false, 'message': 'No registration data found.'};
    }

    try {
      final uid = data['uid'] ?? auth.currentUser?.uid;
      if (uid == null) {
        return {'success': false, 'message': 'User authentication ID missing.'};
      }

      final name = data['name'] ?? 'User';
      final email = data['email'] ?? auth.currentUser?.email ?? '';
      final role = data['role'] ?? 'admin';
      final additionalData = data['additionalData'] as Map<String, dynamic>? ?? {};
      final phone = (data['phone'] as String?)?.trim() ??
          (additionalData['phone'] as String?)?.trim() ??
          (additionalData['customerMobile'] as String?)?.trim() ??
          '';

      // Determine proper scope (User/Company DB)
      String targetScope = '';
      if (data.containsKey('tenantId') &&
          (data['tenantId'] as String).isNotEmpty) {
        targetScope = data['tenantId'];
      } else if (additionalData.containsKey('tenantId') &&
          (additionalData['tenantId'] as String).isNotEmpty) {
        targetScope = additionalData['tenantId'];
      } else if (additionalData.containsKey('linkedAppName')) {
        targetScope = additionalData['linkedAppName'];
      } else {
        targetScope = await FirestoreService.getUniqueTenantId(name);
      }

      // 2. Store details in Firestore (Isolated to Company DB)
      final userData = {
        'uid': uid,
        'name': name,
        'email': email,
        if (phone.isNotEmpty) ...{
          'phone': phone,
          'customerMobile': phone,
        },
        'role': role,
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isApproved': role == 'admin' ? true : false,
        'active': true, // User is finalized after successful setup
        'tenantId': targetScope,
        ...additionalData,
      };

      // Store in the specific Company's 'users' collection with merge
      await FirestoreService.instance
          .collection('users', tenantId: targetScope)
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      // 2b. Register in Global Directory for Login Lookup
      await FirestoreService.instance.saveUserDirectory(
        uid: uid,
        tenantId: targetScope,
        appName: 'data',
        role: role,
        email: email,
        name: name,
        phone: phone,
      );

      // 3. Mark as registered and persist session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kIsLoggedIn, true);
      await prefs.setBool(_kIsRegistered, true);
      await prefs.setString(kUserRole, role);
      await prefs.setString(_kUserRole, role);
      _isRegistered = true;

      if (role == 'admin' || role == 'Owner') {
        await saveAdminSession(
          email: email,
          tenantId: targetScope,
          appName: name,
        );

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

      _pendingRegistrationData = null; // Clear after successful save
      notifyListeners();

      return {'success': true, 'uid': uid};
    } catch (e) {
      debugPrint('Finalize Registration Error: $e');
      return {'success': false, 'message': 'Finalize Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final cleanEmail = email.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();

      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
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

      // Check subscription status
      final isSubscribed = await FirestoreService.instance.isTenantActive(
        tenantId: scope,
        appId: 'data',
      );

      if (!isSubscribed) {
        final subDoc = await FirestoreService.instance
            .subscriptionsRef(tenantId: scope, appId: 'data')
            .limit(1)
            .get();
        final alreadyHasSubscription = subDoc.docs.isNotEmpty;

        if (role == 'admin' || role == 'Owner') {
          if (alreadyHasSubscription) {
            return {
              'success': true,
              'userData': userData,
              'subscriptionExpired': true,
            };
          }
          // Admins are sent to SubscriptionPlansScreen
          return {
            'success': true,
            'userData': userData,
            'needsSubscription': true,
          };
        } else {
          if (alreadyHasSubscription) {
            return {
              'success': false,
              'message':
                  'Your organization\'s subscription has expired. Please contact your admin.',
            };
          }
          // Engineers and Customers are blocked from logging in
          return {
            'success': false,
            'message':
                'Your administrator hasn\'t subscribed to a plan. Please contact your admin for access.',
          };
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kIsLoggedIn, true);
      await prefs.setBool(_kIsRegistered, true); // Ensure this is set
      await prefs.setString(kUserRole, role);
      await prefs.setString(_kUserRole, role);
      await prefs.setString(kTenantId, scope);
      await prefs.setString(kDatabaseName, scope);

      if (role == 'admin' || role == 'Owner') {
        await saveAdminSession(
          email: cleanEmail,
          tenantId: scope,
          appName: userData['name'] as String?,
        );
      } else if (role == 'engineer') {
        await saveEngineerSession(
          username: userData['Username'] ?? userData['name'] ?? cleanEmail,
          tenantId: scope,
          email: cleanEmail,
        );
      } else if (role == 'customer') {
        await saveCustomerSession(
          email: cleanEmail,
          tenantId: scope,
        );
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
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('AuthStateService: Error signing out Firebase Auth: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    // Clear standardized session flags
    await prefs.remove(kIsLoggedIn);
    await prefs.remove(kUserRole);
    await prefs.remove(_kUserRole);
    await prefs.remove('last_role');

    // Clear Admin session
    await prefs.remove(kAdminIsLoggedIn);
    await prefs.remove(kAdminEmail);
    await prefs.remove(kAdminOrgCollection);

    // Clear Engineer session
    await prefs.remove(kEngineerName);
    await prefs.remove(kEngineerEmail);

    // Clear Customer session
    await prefs.remove(kCustomerEmail);

    // Clear unified / app flags
    await prefs.remove(_kIsRegistered);
    await prefs.remove(kTenantId);
    await prefs.remove(kDatabaseName);
    await prefs.remove(kAppName);
    await prefs.remove('primaryColor');
    await prefs.remove('secondaryColor');
    await prefs.remove('backgroundColor');
    await prefs.remove('isDarkMode');
    await prefs.remove('fontFamily');
    await prefs.remove('logoUrl');
    await prefs.remove(_kBrandingCompleted);

    // Clear any tenant-specific branding completion flags
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('${_kBrandingCompleted}_')) {
        await prefs.remove(key);
      }
    }

    // Clear pending recovery payment state
    await PaymentRecoveryService.instance.clearPendingPayment();

    // Stop subscription listener on logout
    SubscriptionExpiryService.instance.stopListening();

    // Reset ThemeService in-memory state
    ThemeService.instance.resetToDefault();

    _isRegistered = false;
    _pendingRegistrationData = null;
    notifyListeners();
  }

  /// Determines the initial screen based on persisted login state
  Future<Widget> getInitialScreen() async {
    try {
      debugPrint('AuthStateService: Determining initial screen...');
      final prefs = await SharedPreferences.getInstance();

      // Check for pending payment recovery first
      final pendingPayment = await PaymentRecoveryService.instance
          .getPendingPayment();
      if (pendingPayment != null) {
        debugPrint(
          'AuthStateService: Found pending payment for recovery, redirecting to PaymentRecoveryScreen',
        );
        return PaymentRecoveryScreen(pendingPayment: pendingPayment);
      }

      // ── 1. SharedPreferences-based Session Check (Instant & Offline-friendly) ──
      final bool isExplicitlyLoggedIn = prefs.getBool(kIsLoggedIn) ?? false;
      final bool isAdminLoggedIn = prefs.getBool(kAdminIsLoggedIn) ?? false;
      final String? engineerName = prefs.getString(kEngineerName);
      final String? customerEmail = prefs.getString(kCustomerEmail);
      String? role = prefs.getString(kUserRole) ?? prefs.getString(_kUserRole);

      // Infer role if not explicitly set
      if (role == null || role.isEmpty) {
        if (isAdminLoggedIn) {
          role = 'admin';
        } else if (engineerName != null && engineerName.isNotEmpty) {
          role = 'engineer';
        } else if (customerEmail != null && customerEmail.isNotEmpty) {
          role = 'customer';
        }
      }

      final bool hasSavedSession = isExplicitlyLoggedIn ||
          isAdminLoggedIn ||
          (engineerName != null && engineerName.isNotEmpty) ||
          (customerEmail != null && customerEmail.isNotEmpty);

      if (hasSavedSession && role != null) {
        debugPrint('AuthStateService: Found saved session in SharedPreferences for role: $role');

        // Route directly to Admin Dashboard
        if (role == 'admin' || role == 'Owner') {
          final adminTenantId =
              prefs.getString(kAdminOrgCollection) ?? prefs.getString(kTenantId);
          if (adminTenantId != null && adminTenantId.isNotEmpty) {
            // Trigger branding sync in background
            FirestoreService.instance.syncBranding(adminTenantId).catchError((e) {
              debugPrint('Background syncBranding error: $e');
            });
          }
          return const admindashboard();
        }

        // Route directly to Service Engineer Dashboard
        if (role == 'engineer') {
          final resolvedName = engineerName ?? prefs.getString(kEngineerName) ?? '';
          final email = prefs.getString(kEngineerEmail) ?? '';
          final tenantId = prefs.getString(kTenantId);

          if (tenantId != null && tenantId.isNotEmpty) {
            // Background branding sync
            FirestoreService.instance.syncBranding(tenantId).catchError((e) {});

            // Trigger anonymous auth in background so Firestore security rules succeed
            if (FirebaseAuth.instance.currentUser == null) {
              FirebaseAuth.instance
                  .signInAnonymously()
                  .then<void>((_) {})
                  .catchError((e) {
                debugPrint('Background anonymous auth failed: $e');
              });
            }
          }

          return EngineerPage(userEmail: email, userName: resolvedName);
        }

        // Route directly to Customer Dashboard
        if (role == 'customer') {
          final tenantId = prefs.getString(kTenantId);

          if (tenantId != null && tenantId.isNotEmpty) {
            // Background branding sync
            FirestoreService.instance.syncBranding(tenantId).catchError((e) {});

            // Trigger anonymous auth in background so Firestore security rules succeed
            if (FirebaseAuth.instance.currentUser == null) {
              FirebaseAuth.instance
                  .signInAnonymously()
                  .then<void>((_) {})
                  .catchError((e) {
                debugPrint('Background anonymous auth failed: $e');
              });
            }
          }

          return const AMCCustomerMainPage();
        }
      }

      // ── 2. Firebase Session Fallback (If SharedPreferences was cleared but Auth user exists) ──
      final user = auth.currentUser;
      if (user != null && !user.isAnonymous) {
        debugPrint(
          'AuthStateService: Firebase Auth session found for ${user.email}',
        );
        final metadata = await FirestoreService.instance.getUserMetadata(
          user.uid,
        );
        if (metadata != null) {
          final recoveredRole = metadata['role'] as String?;
          final tenantId = metadata['tenantId'] as String?;

          if (recoveredRole == 'admin' || recoveredRole == 'Owner') {
            await saveAdminSession(
              email: user.email ?? '',
              tenantId: tenantId ?? '',
              appName: metadata['appName'] ?? metadata['name'],
            );
            return const admindashboard();
          } else if (recoveredRole == 'engineer') {
            final name = metadata['name'] ?? metadata['Username'] ?? '';
            await saveEngineerSession(
              username: name,
              tenantId: tenantId ?? '',
              email: user.email,
            );
            return EngineerPage(userEmail: user.email ?? '', userName: name);
          } else if (recoveredRole == 'customer') {
            await saveCustomerSession(
              email: user.email ?? '',
              tenantId: tenantId ?? '',
            );
            return const AMCCustomerMainPage();
          }
        }
      }

      debugPrint(
        'AuthStateService: No active session found, showing RoleSelectionScreen',
      );
      return const RoleSelectionScreen();
    } catch (e) {
      debugPrint('AuthStateService: Error determining initial screen: $e');
      return const RoleSelectionScreen();
    }
  }
}
