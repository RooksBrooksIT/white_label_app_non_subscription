import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/subscription_queue_service.dart';
import 'package:subscription_rooks_app/subscription/plan_expired_screen.dart';

class SubscriptionExpiryService {
  SubscriptionExpiryService._();
  static final SubscriptionExpiryService instance =
      SubscriptionExpiryService._();

  StreamSubscription<Map<String, dynamic>?>? _subscriptionStream;
  StreamSubscription<User?>? _authStateStream;
  bool _isRedirectedToExpired = false;

  // Global Navigator Key
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void initialize() {
    debugPrint('SubscriptionExpiryService: Initializing...');
    _authStateStream?.cancel();
    _authStateStream = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkPrefsAndStart(user.uid);
      } else {
        stopListening();
      }
    });

    _checkPrefsAndStart('');
  }

  void _checkPrefsAndStart(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId =
        prefs.getString('tenantId') ??
        prefs.getString('admin_org_collection') ??
        prefs.getString('databaseName');
    final role = prefs.getString('user_role') ?? prefs.getString('last_role');

    if (tenantId != null && role != null) {
      startListening(tenantId, role);
    } else if (uid.isNotEmpty) {
      final metadata = await FirestoreService.instance.getUserMetadata(uid);
      if (metadata != null) {
        final fTenantId = metadata['tenantId'] as String?;
        final fRole = metadata['role'] as String? ?? 'user';
        if (fTenantId != null) {
          startListening(fTenantId, fRole);
        }
      }
    }
  }

  void startListening(String tenantId, String role) {
    _isRedirectedToExpired = false;

    // Cancel existing stream if any
    _subscriptionStream?.cancel();
    _subscriptionStream = null;

    debugPrint(
      'SubscriptionExpiryService: Start listening to subscription for tenant: $tenantId, role: $role',
    );

    _subscriptionStream = FirestoreService.instance
        .streamTenantSubscription(tenantId, appId: 'data')
        .listen(
          (data) {
            if (data != null) {
              _checkExpiry(data, role, tenantId);
            } else {
              // If no subscription record exists, we treat it as expired for non-trial scenarios
              // However, for brand new users, they might not have a record yet.
              // We handle this by checking if the user is an admin.
              _triggerExpiredRedirect(role);
            }
          },
          onError: (error) {
            debugPrint(
              'SubscriptionExpiryService: Error listening to subscription: $error',
            );
          },
        );
  }

  void stopListening() {
    debugPrint('SubscriptionExpiryService: Stopping subscription listener...');
    _subscriptionStream?.cancel();
    _subscriptionStream = null;
    _isRedirectedToExpired = false;
  }

  void _checkExpiry(
    Map<String, dynamic> data,
    String role,
    String tenantId,
  ) async {
    final status = data['status'] as String?;
    final expiryDate = _getExpiryDate(data);

    // Primary validation logic: prioritize expiryDate (expiresAt) over status
    // If current time is NOT past expiry date, it's NOT expired, even if status is 'expired'
    bool isExpired = false;

    if (expiryDate != null) {
      // Check if current date is past stored expiry date (using UTC for consistency)
      isExpired = DateTime.now().toUtc().isAfter(expiryDate);
    } else {
      // If no expiry date is found, fallback to status check
      isExpired = (status != 'active');
    }

    if (isExpired) {
      final uid = data['uid'] ?? data['id'] ?? '';
      final user = FirebaseAuth.instance.currentUser;
      final targetDocId = uid.isNotEmpty ? uid : (user?.uid ?? '');

      // Attempt to activate a queued plan before expiring
      bool queuedActivated = false;
      if (targetDocId.isNotEmpty) {
        try {
          queuedActivated = await SubscriptionQueueService.instance
              .activateQueuedPlan(tenantId: tenantId, uid: targetDocId);
        } catch (e) {
          debugPrint(
            'SubscriptionExpiryService: Error activating queued plan: $e',
          );
        }
      }

      if (queuedActivated) {
        debugPrint(
          'SubscriptionExpiryService: Queued plan activated successfully. Avoiding expiry redirect.',
        );
        // _isRedirectedToExpired is false by default, just return.
        return;
      }

      // Update Firestore if it was 'active' but date has actually passed
      if (status == 'active') {
        try {
          if (uid.isNotEmpty) {
            await FirestoreService.instance.setUserActiveStatus(
              uid: uid,
              tenantId: tenantId,
              active: false,
            );
          }
          if (targetDocId.isNotEmpty) {
            await FirestoreService.instance
                .subscriptionsRef(tenantId: tenantId, appId: 'data')
                .doc(targetDocId)
                .update({'status': 'expired'});
          }
        } catch (e) {
          debugPrint(
            'SubscriptionExpiryService: Failed to update expired status: $e',
          );
        }
      }
      _triggerExpiredRedirect(role);
    } else {
      // NOT EXPIRED (Either active status or date is still valid)
      _isRedirectedToExpired = false;

      // Auto-remedy: If the date is valid but status is 'expired', it means the user renewed.
      // We should ideally update the status back to 'active' if it's currently 'expired'.
      if (status == 'expired') {
        debugPrint(
          'SubscriptionExpiryService: Valid expiry date found but status is "expired". Auto-activating...',
        );
        try {
          final uid = data['uid'] ?? data['id'] ?? '';
          final user = FirebaseAuth.instance.currentUser;
          final targetDocId = uid.isNotEmpty ? uid : (user?.uid ?? '');
          if (targetDocId.isNotEmpty) {
            await FirestoreService.instance
                .subscriptionsRef(tenantId: tenantId, appId: 'data')
                .doc(targetDocId)
                .update({'status': 'active'});

            // Also reactivate user
            if (uid.isNotEmpty) {
              await FirestoreService.instance.setUserActiveStatus(
                uid: uid,
                tenantId: tenantId,
                active: true,
              );
            }
          }
        } catch (e) {
          debugPrint('SubscriptionExpiryService: Auto-activation failed: $e');
        }
      }

      // Pre-Expiry Reminder Notification (2 days before)
      if (expiryDate != null) {
        final now = DateTime.now().toUtc();
        final difference = expiryDate.difference(now);

        // Notify if within 48 hours (2 days)
        if (difference.inHours > 0 && difference.inHours <= 48) {
          final prefs = await SharedPreferences.getInstance();
          final lastNotified = prefs.getString('last_notified_expiry_date');
          final expiryIso = expiryDate.toIso8601String();

          // Prevent notification duplication
          if (lastNotified != expiryIso) {
            final formattedDate = DateFormat(
              'dd MMM yyyy',
            ).format(expiryDate.toLocal());
            await NotificationService.instance.showNotification(
              title: 'Subscription Expiring Soon',
              body:
                  'Your subscription plan is about to expire on $formattedDate. Please renew or upgrade to avoid service interruption.',
            );
            await prefs.setString('last_notified_expiry_date', expiryIso);
          }
        }
      }
    }
  }

  void _triggerExpiredRedirect(String role) {
    if (_isRedirectedToExpired) return;

    // Additional safety check: don't redirect if we're already on the PlanExpiredScreen
    // This is handled by _isRedirectedToExpired flag, but let's be extra sure.

    _isRedirectedToExpired = true;

    debugPrint(
      'SubscriptionExpiryService: Redirecting to PlanExpiredScreen for role $role',
    );

    // Use addPostFrameCallback to ensure navigation happens after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Check if we are already on PlanExpiredScreen to avoid redundant push
        bool isAlreadyOnExpiredScreen = false;
        navigatorKey.currentState?.popUntil((route) {
          if (route.settings.name == '/plan_expired') {
            isAlreadyOnExpiredScreen = true;
          }
          return true;
        });

        if (!isAlreadyOnExpiredScreen) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/plan_expired'),
              builder: (_) => PlanExpiredScreen(role: role),
            ),
            (route) => false, // Immediately block access to all app features
          );
        }
      }
    });
  }

  DateTime? _getExpiryDate(Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'];
    if (expiresAt != null) {
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().toUtc();
      } else if (expiresAt is String) {
        return DateTime.tryParse(expiresAt)?.toUtc();
      }
    }
    final nextBillingStr = data['nextBillingAt'] as String?;
    if (nextBillingStr != null) {
      return DateTime.tryParse(nextBillingStr)?.toUtc();
    }
    return null;
  }
}
