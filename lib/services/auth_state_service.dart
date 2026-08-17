import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:subscription_rooks_app/subscription/plan_expired_screen.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/services/payment_recovery_service.dart';
import 'package:subscription_rooks_app/subscription/payment_recovery_screen.dart';

class AuthStateService extends ChangeNotifier {
  AuthStateService._();
  static final AuthStateService instance = AuthStateService._();

  static const String _kIsRegistered = 'app_is_registered';
  static const String _kUserRole = 'user_role';
  static const String _kBrandingCompleted = 'branding_completed';

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
    Map<String, dynamic>? additionalData,
    bool deferAuth = false,
  }) async {
    try {
      if (deferAuth) {
        final auth = FirebaseAuth.instance;

        // 1. Validate credentials by actually creating or signing in the Auth account
        if (auth.currentUser == null || auth.currentUser!.email != email) {
          try {
            await auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              try {
                await auth.signInWithEmailAndPassword(
                  email: email,
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

        // Just store the data in memory for now, but include the uid
        _pendingRegistrationData = {
          'uid': auth.currentUser!.uid,
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'additionalData': additionalData,
        };
        debugPrint('Account auth validated and registration deferred for $email');
        return {'success': true, 'message': 'Account details saved locally.'};
      }

      final auth = FirebaseAuth.instance;

      // 1. Check if user is already logged in with same email
      if (auth.currentUser != null && auth.currentUser!.email == email) {
        debugPrint('User already authenticated: ${auth.currentUser!.uid}');
      } else {
        try {
          await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Attempt to sign in if the account was already created in a previous attempt
            try {
              await auth.signInWithEmailAndPassword(
                email: email,
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
        'email': email,
        'password': password,
        'role': role,
        'additionalData': additionalData,
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
  Future<Map<String, dynamic>> createAndFinalizeAccount() async {
    if (_pendingRegistrationData == null) {
      return {
        'success': false,
        'message': 'No pending registration data found.',
      };
    }

    try {
      final email = _pendingRegistrationData!['email'];
      final password = _pendingRegistrationData!['password'];

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
      _pendingRegistrationData!['uid'] = uid;

      // 2. Now call the standard finalization to create Firestore records
      return await finalizeRegistration();
    } catch (e) {
      debugPrint('Error creating and finalizing account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finalizeRegistration() async {
    if (_pendingRegistrationData == null) {
      return {'success': false, 'message': 'No registration data found.'};
    }

    try {
      final uid = _pendingRegistrationData!['uid'];
      final name = _pendingRegistrationData!['name'];
      final email = _pendingRegistrationData!['email'];
      final password = _pendingRegistrationData!['password'];
      final role = _pendingRegistrationData!['role'];
      final additionalData = _pendingRegistrationData!['additionalData'];

      // Determine proper scope (User/Company DB)
      String targetScope = '';
      if (_pendingRegistrationData != null &&
          _pendingRegistrationData!.containsKey('tenantId') &&
          (_pendingRegistrationData!['tenantId'] as String).isNotEmpty) {
        targetScope = _pendingRegistrationData!['tenantId'];
      } else if (additionalData != null &&
          additionalData.containsKey('linkedAppName')) {
        targetScope = additionalData['linkedAppName'];
      } else {
        targetScope = FirestoreService.generateTenantId(name);
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
        'tenantId': targetScope,
        ...?(additionalData as Map<String, dynamic>?),
      };

      // Store in the specific Company's 'users' collection
      await FirestoreService.instance
          .collection('users', tenantId: targetScope)
          .doc(uid)
          .set(userData);

      // 2b. Register in Global Directory for Login Lookup
      await FirestoreService.instance.saveUserDirectory(
        uid: uid,
        tenantId: targetScope,
        appName: 'data',
        role: role,
      );

      // 3. Mark as registered locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true);
      await prefs.setString(_kUserRole, role);
      _isRegistered = true;

      if (role == 'admin' || role == 'Owner') {
        // Also register in the 'admin' collection for backward compatibility
        await FirestoreService.instance
            .collection('admin', tenantId: targetScope)
            .doc(name)
            .set({
              'email': email,
              'password': password,
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

    // Stop subscription listener on logout
    SubscriptionExpiryService.instance.stopListening();

    _isRegistered = false;
    notifyListeners();
  }

  Future<Widget> _getRestrictedOrExpiredScreen({
    required String tenantId,
    required String role,
    required bool isAdmin,
  }) async {
    try {
      final subDoc = await FirestoreService.instance
          .subscriptionsRef(tenantId: tenantId, appId: 'data')
          .limit(1)
          .get();
      if (subDoc.docs.isNotEmpty) {
        return PlanExpiredScreen(role: role);
      }
    } catch (_) {}
    return isAdmin
        ? const SubscriptionPlansScreen()
        : AccessRestrictedScreen(role: role);
  }

  Future<bool> _isBrandingSetupCompleted({
    required SharedPreferences prefs,
    required String tenantId,
  }) async {
    final tenantKey = '${_kBrandingCompleted}_$tenantId';
    final localCompleted =
        (prefs.getBool(_kBrandingCompleted) ?? false) ||
        (prefs.getBool(tenantKey) ?? false);

    if (localCompleted) {
      if (!(prefs.getBool(tenantKey) ?? false)) {
        await prefs.setBool(tenantKey, true);
      }
      if (!(prefs.getBool(_kBrandingCompleted) ?? false)) {
        await prefs.setBool(_kBrandingCompleted, true);
      }
      return true;
    }

    try {
      final brandingDoc = await FirestoreService.instance
          .brandingDoc(tenantId: tenantId, appId: 'data')
          .get();
      final brandingData = brandingDoc.data();
      final hasBrandingData =
          brandingDoc.exists &&
          brandingData != null &&
          ((brandingData['appName']?.toString().trim().isNotEmpty ?? false) ||
              brandingData['logoUrl'] != null ||
              brandingData['primaryColor'] != null ||
              brandingData['secondaryColor'] != null);

      if (hasBrandingData) {
        await prefs.setBool(_kBrandingCompleted, true);
        await prefs.setBool(tenantKey, true);
        return true;
      }
    } catch (e) {
      debugPrint('AuthStateService: Branding completion validation failed: $e');
    }

    return false;
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
              return await _getRestrictedOrExpiredScreen(
                tenantId: effectiveTenant,
                role: role ?? 'admin',
                isAdmin: true,
              );
            }

            final isBrandingCompleted = await _isBrandingSetupCompleted(
              prefs: prefs,
              tenantId: effectiveTenant,
            );
            if (!isBrandingCompleted) {
              debugPrint(
                'AuthStateService: Branding incomplete for admin, routing to BrandingCustomizationScreen',
              );
              try {
                // Fetch latest payment to populate BrandingCustomizationScreen
                final paymentSnapshot = await FirebaseFirestore.instance
                    .collection('payments')
                    .where('userId', isEqualTo: user.uid)
                    .orderBy('updatedAt', descending: true)
                    .limit(1)
                    .get();

                if (paymentSnapshot.docs.isNotEmpty) {
                  final paymentData = paymentSnapshot.docs.first.data();
                  final rawAmount = paymentData['amount'];
                  final parsedAmount = rawAmount is num
                      ? rawAmount.toInt()
                      : int.tryParse(rawAmount?.toString() ?? '');
                  final rawOriginalPrice = paymentData['originalPrice'];
                  final parsedOriginalPrice = rawOriginalPrice is num
                      ? rawOriginalPrice.toInt()
                      : int.tryParse(rawOriginalPrice?.toString() ?? '');
                  final resolvedPaymentMethod =
                      (paymentData['paymentMethod'] ??
                              paymentData['paymentMode'] ??
                              '')
                          .toString()
                          .trim();
                  return BrandingCustomizationScreen(
                    planName: paymentData['planName'] ?? 'Subscription',
                    isYearly: paymentData['isYearly'] ?? false,
                    isSixMonths: paymentData['isSixMonths'] ?? false,
                    price: parsedAmount,
                    transactionId: paymentSnapshot.docs.first.id,
                    originalPrice: parsedOriginalPrice,
                    paymentMethod: resolvedPaymentMethod.isNotEmpty
                        ? resolvedPaymentMethod
                        : null,
                    limits: paymentData['limits'] as Map<String, dynamic>?,
                    geoLocation: paymentData['geoLocation'] as bool?,
                    attendance: paymentData['attendance'] as bool?,
                    barcode: paymentData['barcode'] as bool?,
                    reportExport: paymentData['reportExport'] as bool?,
                  );
                }
              } catch (e) {
                debugPrint(
                  'AuthStateService: Error fetching latest payment for branding: $e',
                );
              }
              // Fallback if no payment found
              return const BrandingCustomizationScreen(
                planName: 'Subscription',
                isYearly: false,
                price: 0,
              );
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
              return await _getRestrictedOrExpiredScreen(
                tenantId: effectiveTenant,
                role: role ?? 'user',
                isAdmin: false,
              );
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
            return await _getRestrictedOrExpiredScreen(
              tenantId: adminTenantId,
              role: 'admin',
              isAdmin: true,
            );
          }

          final isBrandingCompleted = await _isBrandingSetupCompleted(
            prefs: prefs,
            tenantId: adminTenantId,
          );
          if (!isBrandingCompleted) {
            debugPrint(
              'AuthStateService: Branding incomplete for fallback admin session, routing to BrandingCustomizationScreen',
            );
            return const BrandingCustomizationScreen(
              planName: 'Subscription',
              isYearly: false,
              price: 0,
            );
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
            return await _getRestrictedOrExpiredScreen(
              tenantId: tenantId,
              role: 'engineer',
              isAdmin: false,
            );
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
            return await _getRestrictedOrExpiredScreen(
              tenantId: tenantId,
              role: 'customer',
              isAdmin: false,
            );
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
