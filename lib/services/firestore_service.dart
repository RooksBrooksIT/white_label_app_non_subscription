import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates a consistent tenant ID based on user/organization name and registration date.
  /// Format: {CleanName}_{YYYYMMDD} (e.g. Abi_20260610)
  static String generateTenantId(String name, [DateTime? registrationDate]) {
    final date = registrationDate ?? DateTime.now();
    final yearStr = date.year.toString();
    final monthStr = date.month.toString().padLeft(2, '0');
    final dayStr = date.day.toString().padLeft(2, '0');
    final dateStr = "$yearStr$monthStr$dayStr";
    // Clean name: alphanumeric only, remove spaces/special chars (preserve case)
    final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return "${cleanName}_$dateStr";
  }

  /// Returns a collection reference rooted under:
  /// {tenantId} (coll) -> {appId} (doc) -> {collectionName} (coll)
  /// Standardized tenant collection path: {tenantId} (coll) -> data (doc) -> {subCollection} (coll)
  CollectionReference<Map<String, dynamic>> collection(
    String collectionName, {
    String? tenantId,
    String? appId,
  }) {
    String effectiveTenant = (tenantId != null && tenantId.isNotEmpty)
        ? tenantId
        : ThemeService.instance.databaseName;
    if (effectiveTenant.isEmpty) {
      effectiveTenant = 'global_user_directory';
    }
    final effectiveApp = appId ?? 'data';
    return _db
        .collection(effectiveTenant)
        .doc(effectiveApp)
        .collection(collectionName);
  }

  /// Exposes collectionGroup query
  Query<Map<String, dynamic>> collectionGroup(String collectionPath) {
    return _db.collectionGroup(collectionPath);
  }

  /// Tenant-specific reference for subscriptions
  CollectionReference<Map<String, dynamic>> subscriptionsRef({
    required String tenantId,
    String? appId,
  }) {
    // Force use of tenantId as the document bucket for subscriptions to avoid duplicates.
    // This ensures path is always: {tenantId} (coll) -> {tenantId} (doc) -> subscription (coll)
    // instead of defaulting to 'data' or being split between 'data' and the appName.
    return collection('subscription', tenantId: tenantId, appId: tenantId);
  }

  /// Tenant-specific reference for referral codes
  CollectionReference<Map<String, dynamic>> referralCodesRef({
    required String tenantId,
    String? appId,
  }) => collection('referral_codes', tenantId: tenantId, appId: appId);

  /// Tenant-specific reference for branding
  DocumentReference<Map<String, dynamic>> brandingDoc({
    required String tenantId,
    String? appId,
  }) => collection('branding', tenantId: tenantId, appId: appId).doc('config');

  // --- Global User Directory ---
  // Maps UID -> AppName/TenantID
  Future<void> saveUserDirectory({
    required String uid,
    required String tenantId,
    required String role,
    String? appName,
  }) async {
    // 1. Local tenant mapping (for tenant-specific user management)
    await collection('users', tenantId: tenantId).doc(uid).set({
      'tenantId': tenantId,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Global lookup (for routing during login)
    await _db.collection('global_user_directory').doc(uid).set({
      'tenantId': tenantId,
      'appName': appName,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserTenantAssociation(String uid) async {
    try {
      final doc = await _db.collection('global_user_directory').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['tenantId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Generates a new ticket ID in the sequential format: T001, T002, T003...
  Future<String> generateTicketId({
    String? customerName,
    String? customerType,
  }) async {
    // Reference to counter document
    final counterRef = collection('counters').doc('ticket_counter');

    return runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      // Get current counter value (or start at 0)
      int currentCount = 0;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!['lastTicketCount'] as int? ?? 0;
        currentCount = data;
      }

      // Increment counter
      final newCount = currentCount + 1;

      // Update counter
      transaction.set(counterRef, {
        'lastTicketCount': newCount,
      }, SetOptions(merge: true));

      // Generate padded to 3 digits (e.g. T001, T002...)
      final paddedNumber = newCount.toString().padLeft(3, '0');

      return 'T$paddedNumber';
    });
  }

  /// New: Get User Role and Org/App associations
  Future<Map<String, dynamic>?> getUserMetadata(String uid) async {
    try {
      final doc = await _db.collection('global_user_directory').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return _db.runTransaction(updateFunction);
  }

  /// Updates the online status of an engineer in the EngineerLogin collection.
  Future<void> updateEngineerStatus({
    required String tenantId,
    required String username,
    required bool isOnline,
  }) async {
    try {
      // Find the document ID for the given username
      final querySnapshot = await collection(
        'EngineerLogin',
        tenantId: tenantId,
      ).where('Username', isEqualTo: username).get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await collection('EngineerLogin', tenantId: tenantId).doc(docId).update(
          {
            'isOnline': isOnline,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (e) {
      debugPrint('Error updating engineer status: $e');
    }
  }

  // Create/update current subscription for a tenant user
  Future<void> upsertSubscription({
    required String uid,
    required String tenantId,
    required String planName,
    required bool isYearly,
    bool isSixMonths = false,
    required int price,
    int? originalPrice,
    String paymentMethod = 'unknown',
    String status = 'active', // Add status parameter
    Map<String, dynamic>? brandingData,
    String? appId,
    String? customerMobile, // stored for future payment lookups
    String? gstNumber, // optional GST number
    Map<String, dynamic>? limits,
    bool? geoLocation,
    bool? attendance,
    bool? barcode,
    bool? reportExport,
  }) async {
    final normalizedPlanName = planName.trim();
    if (normalizedPlanName.isEmpty) {
      throw ArgumentError('planName must not be empty');
    }
    if (price < 0) {
      throw ArgumentError('price must be zero or greater');
    }
    final normalizedPaymentMethod = paymentMethod.trim().isEmpty
        ? 'Unknown'
        : paymentMethod.trim();

    final now = DateTime.now();
    DateTime nextBilling;

    if (normalizedPlanName.toLowerCase().contains('trial')) {
      // Free Trial is exactly 7 days
      nextBilling = now.add(const Duration(days: 7));
    } else if (isYearly) {
      nextBilling = DateTime(now.year + 1, now.month, now.day);
    } else if (isSixMonths) {
      nextBilling = DateTime(now.year, now.month + 6, now.day);
    } else {
      nextBilling = DateTime(now.year, now.month + 1, now.day);
    }

    final data = <String, dynamic>{
      'planName': normalizedPlanName,
      'isYearly': isYearly,
      'isSixMonths': isSixMonths,
      'price': price,
      'paymentMethod': normalizedPaymentMethod,
      'status': status,
      'startedAt': now.toIso8601String(),
      'nextBillingAt': nextBilling.toIso8601String(),
      'expiresAt':
          nextBilling, // DateTime is converted to Timestamp by Firestore
      'updatedAt': FieldValue.serverTimestamp(),
      'originalPrice': ?originalPrice,
      if (customerMobile != null && customerMobile.isNotEmpty)
        'customerMobile': customerMobile,
      if (gstNumber != null && gstNumber.isNotEmpty) 'gstNumber': gstNumber,
      'limits': ?limits,
      'geoLocation': ?geoLocation,
      'attendance': ?attendance,
      'barcode': ?barcode,
      'reportExport': ?reportExport,
    };

    if (brandingData != null) {
      data['branding'] = brandingData;
    }

    await subscriptionsRef(
      tenantId: tenantId,
      appId: appId,
    ).doc(uid).set(data, SetOptions(merge: true));
  }

  /// Check if a user has an active subscription within a tenant
  /// Also checks if the subscription has expired based on expiresAt/nextBillingAt
  Future<bool> hasActiveSubscription({
    required String uid,
    required String tenantId,
    String? appId,
  }) async {
    try {
      final doc = await subscriptionsRef(
        tenantId: tenantId,
        appId: appId,
      ).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['status'] != 'active') return false;

        final expiryDate = _getExpiryDate(data);
        if (expiryDate == null || DateTime.now().toUtc().isAfter(expiryDate)) {
          // Subscription has expired — mark as expired and deactivate user
          await subscriptionsRef(
            tenantId: tenantId,
            appId: appId,
          ).doc(uid).update({'status': 'expired'});
          await setUserActiveStatus(
            uid: uid,
            tenantId: tenantId,
            active: false,
          );
          return false;
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Check if an organization (tenant) has any active subscription.
  /// Useful for gating access for non-admin users (Engineers, Customers).
  Future<bool> isTenantActive({required String tenantId, String? appId}) async {
    try {
      // Check in the standardized bucket (now forced to tenantId bucket in subscriptionsRef)
      var querySnapshot = await subscriptionsRef(
        tenantId: tenantId,
        appId: appId,
      ).where('status', isEqualTo: 'active').limit(1).get();

      if (querySnapshot.docs.isEmpty) return false;

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final expiryDate = _getExpiryDate(data);
      if (expiryDate == null || DateTime.now().toUtc().isAfter(expiryDate)) {
        // Found an active doc but it's expired -> Update status to expired
        await doc.reference.update({'status': 'expired'});
        // Deactivate the admin user associated with this doc
        await setUserActiveStatus(
          uid: doc.id,
          tenantId: tenantId,
          active: false,
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking tenant active status: $e');
      return false;
    }
  }

  /// Fetches the subscription data for a tenant to check for features like geoLocation
  Future<Map<String, dynamic>?> getTenantSubscriptionData({
    required String tenantId,
    String? appId,
  }) async {
    try {
      // Check in the standardized bucket
      var querySnapshot = await subscriptionsRef(
        tenantId: tenantId,
        appId: appId,
      ).where('status', isEqualTo: 'active').limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
    } catch (e) {
      debugPrint('Error fetching tenant subscription data: $e');
    }
    return null;
  }

  /// Expiry date helper for timezone consistency
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

  /// Set the active status flag on a user document
  Future<void> setUserActiveStatus({
    required String uid,
    required String tenantId,
    required bool active,
  }) async {
    await collection(
      'users',
      tenantId: tenantId,
    ).doc(uid).update({'active': active});
  }

  // Stream subscription for a specific user within a tenant
  Stream<Map<String, dynamic>?> streamSubscription(
    String uid,
    String tenantId, {
    String? appId,
  }) {
    return subscriptionsRef(
      tenantId: tenantId,
      appId: appId,
    ).doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    });
  }

  // Stream any subscription for a tenant (useful when doc ID is unknown)
  Stream<Map<String, dynamic>?> streamTenantSubscription(
    String tenantId, {
    String? appId,
  }) {
    return subscriptionsRef(tenantId: tenantId, appId: appId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.docs.isNotEmpty) {
        // Try to find one that is active or just return the first one
        try {
          return snapshot.docs.firstWhere((doc) {
            final data = doc.data();
            return data['status'] == 'active';
          }).data();
        } catch (_) {
          return snapshot.docs.first.data();
        }
      }
      return null;
    });
  }

  Future<String?> getActiveSubscriptionAppId({
    required String tenantId,
    String? appId,
  }) async {
    var querySnapshot = await subscriptionsRef(
      tenantId: tenantId,
      appId: appId,
    ).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) return tenantId;

    return tenantId;
  }

  // Update only branding data for a tenant
  Future<void> updateBranding({
    required String tenantId,
    required Map<String, dynamic> brandingData,
    String? appId,
  }) async {
    await brandingDoc(tenantId: tenantId, appId: appId).set({
      ...brandingData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Create an app-specific collection to store branding configuration
  Future<void> saveAppBranding({
    required String tenantId,
    required Map<String, dynamic> brandingData,
    String? appId,
  }) async {
    await brandingDoc(
      tenantId: tenantId,
      appId: appId,
    ).set({...brandingData, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // Fetch and apply branding configuration for a tenant
  Future<void> syncBranding(String tenantId, {String? appId}) async {
    try {
      final doc = await brandingDoc(tenantId: tenantId, appId: appId).get();
      if (doc.exists && doc.data() != null) {
        ThemeService.instance.loadFromMap({
          ...doc.data()!,
          'databaseName': tenantId, // Ensure databaseName is restored
        });
      }
    } catch (e) {
      // debugPrint('Error syncing branding: $e');
    }
  }

  // --- Referral Code Logic ---

  // Check if a referral code matches any active subscription/app
  // Returns the appName associated with the code if valid, null otherwise.
  Future<String?> validateReferralCode(
    String code,
    String tenantId, {
    String? appId,
  }) async {
    try {
      final doc = await referralCodesRef(
        tenantId: tenantId,
        appId: appId,
      ).doc(code).get();
      if (doc.exists) {
        return doc.data()?['tenantId'] as String?;
      }
    } catch (e) {
      // debugPrint('Error checking referral code: $e');
    }
    return null;
  }

  // Save a new referral code linked to a tenant
  Future<void> saveReferralCode({
    required String code,
    required String tenantId,
    required String adminUid,
    String? appId,
  }) async {
    await referralCodesRef(tenantId: tenantId, appId: appId).doc(code).set({
      'code': code,
      'tenantId': tenantId,
      'adminUid': adminUid,
      'appId': appId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  /// Global lookup for referral codes across all tenants (used during registration)
  /// Returns a map containing 'tenantId' and 'appId' if found.
  Future<Map<String, String?>?> validateGlobalReferralCode(String code) async {
    try {
      final snapshot = await _db
          .collectionGroup('referral_codes')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'tenantId': doc.get('tenantId') as String?,
          'appId': doc.data().containsKey('appId')
              ? doc.get('appId') as String?
              : 'data',
        };
      }
    } catch (e) {
      // debugPrint('Error validating global referral code: $e');
    }
    return null;
  }

  /// Get the referral code for a specific admin
  Future<String?> getReferralCodeForAdmin(String adminUid) async {
    try {
      final snapshot = await _db
          .collectionGroup('referral_codes')
          .where('adminUid', isEqualTo: adminUid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.get('code') as String?;
      }
    } catch (e) {
      // debugPrint('Error fetching admin referral code: $e');
    }
    return null;
  }

  /// Save Terms & Conditions acceptance for a user
  Future<void> saveTermsAndConditionsAcceptance({
    required String uid,
    required String tenantId,
    required DateTime timestamp,
    String? appId,
  }) async {
    try {
      await collection(
        'users',
        tenantId: tenantId,
        appId: appId,
      ).doc(uid).update({
        'termsAndConditionsAccepted': true,
        'termsAcceptedAt': timestamp.toIso8601String(),
        'termsAcceptedTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving T&C acceptance: $e');
      rethrow;
    }
  }

  /// Check if a user has accepted Terms & Conditions
  Future<bool> hasAcceptedTermsAndConditions({
    required String uid,
    required String tenantId,
    String? appId,
  }) async {
    try {
      final doc = await collection(
        'users',
        tenantId: tenantId,
        appId: appId,
      ).doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return doc.data()?['termsAndConditionsAccepted'] == true;
      }
    } catch (e) {
      debugPrint('Error checking T&C acceptance: $e');
    }
    return false;
  }

  /// Get Terms & Conditions acceptance details for a user
  Future<Map<String, dynamic>?> getTermsAndConditionsDetails({
    required String uid,
    required String tenantId,
    String? appId,
  }) async {
    try {
      final doc = await collection(
        'users',
        tenantId: tenantId,
        appId: appId,
      ).doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'accepted': data['termsAndConditionsAccepted'] ?? false,
          'acceptedAt': data['termsAcceptedAt'],
          'acceptedTimestamp': data['termsAcceptedTimestamp'],
        };
      }
    } catch (e) {
      debugPrint('Error fetching T&C details: $e');
    }
    return null;
  }

  /// Logs a payment transaction to the centralized 'payment_logs' collection
  /// and the user's tenant-specific 'payment_logs' subcollection.
  ///
  /// Every call creates a **new** Firestore document with a unique composite ID
  /// `{txnId}_{timestampMs}` — existing records are never overwritten.
  ///
  /// Returns the full Firestore document ID of the created log record,
  /// which callers must pass to [updateInvoiceStatus] and invoice services.
  Future<String> logPaymentTransaction({
    required String txnId,
    required String uidOrMobile,
    required String planName,
    required int amount,
    required String status,
    bool isYearly = false,
    bool isSixMonths = false,
    String? failureReason,
    bool registrationCompleted = false,
    bool firestoreSynced = false,
    String? tenantId,
    String? customerName,
    String? customerEmail,
    String? customerMobile,
    Map<String, dynamic>? gatewayResponse,
    // Queue metadata
    String queueStatus = 'Immediate', // 'Immediate' | 'Queued'
    String? previousPlan,
    String? newPlan,
    String? userId,
  }) async {
    // Unique doc ID = txnId + current timestamp in ms to ensure no overwrites.
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final logDocId = '${txnId}_$timestampMs';

    try {
      // 1. Create a NEW document in the centralized global collection.
      final docRef = _db.collection('payment_logs').doc(logDocId);

      final data = <String, dynamic>{
        'logDocId': logDocId,
        'transactionId': txnId,
        'userId': userId ?? uidOrMobile,
        'userIdOrMobile': uidOrMobile,
        'planName': planName,
        'newPlan': newPlan ?? planName,
        'previousPlan': ?previousPlan,
        'amount': amount,
        'status': status,
        'isYearly': isYearly,
        'isSixMonths': isSixMonths,
        'queueStatus': queueStatus,
        'failureReason': ?failureReason,
        'timestamp': FieldValue.serverTimestamp(),
        'registrationCompleted': registrationCompleted,
        'firestoreSynced': firestoreSynced,
        // Invoice fields — always initialized on creation
        'invoiceSent': false,
        'invoiceStatus': 'Pending',
        'invoiceDetails': {
          'planName': planName,
          'amount': amount,
          'billingCycle': isYearly
              ? 'Yearly'
              : (isSixMonths ? '6 Months' : 'Monthly'),
          'customerName': ?customerName,
          'customerEmail': ?customerEmail,
        },
      };

      await docRef.set(data);

      // 2. Mirror to tenant-specific payment_logs subcollection.
      final effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isNotEmpty) {
        final userLogData = <String, dynamic>{
          'logDocId': logDocId,
          'transactionId': txnId,
          'orderId': txnId,
          'userId': userId ?? uidOrMobile,
          'userIdOrMobile': uidOrMobile,
          'amount': amount,
          'currency': 'INR',
          'paymentStatus': status,
          'paymentMethod':
              gatewayResponse?['paymentMode'] ??
              gatewayResponse?['paymentMethod'] ??
              'Unknown',
          'customerName': customerName ?? 'Customer',
          'customerEmail': customerEmail ?? '',
          'customerMobile': customerMobile ?? '',
          'planName': planName,
          'queueStatus': queueStatus,
          'previousPlan': ?previousPlan,
          'newPlan': newPlan ?? planName,
          'gatewayResponse': gatewayResponse ?? {},
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _db
            .collection(effectiveTenant)
            .doc('data')
            .collection('payment_logs')
            .doc(logDocId)
            .set(userLogData);
      }
    } catch (e) {
      debugPrint('Error logging payment transaction ($logDocId): $e');
    }

    return logDocId;
  }

  /// Updates invoice delivery status in payment_logs.
  ///
  /// [logDocId] is the full Firestore document ID returned by [logPaymentTransaction]
  /// (format: `{txnId}_{timestampMs}`). Do NOT pass a bare txnId.
  Future<void> updateInvoiceStatus(
    String logDocId, {
    String? invoiceNumber,
    String? status,
    bool? invoiceSent,
    DateTime? invoiceSentAt,
  }) async {
    try {
      final docRef = _db.collection('payment_logs').doc(logDocId);
      final updates = <String, dynamic>{};

      if (invoiceNumber != null) updates['invoiceNumber'] = invoiceNumber;
      if (status != null) updates['invoiceStatus'] = status;
      if (invoiceSent != null) updates['invoiceSent'] = invoiceSent;
      if (invoiceSentAt != null) {
        updates['invoiceSentAt'] = invoiceSentAt.toIso8601String();
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e) {
      debugPrint('Error updating invoice status for doc $logDocId: $e');
    }
  }

  /// Reference to the queued_subscriptions collection for a tenant.
  /// Path: {tenantId} → {tenantId} → queued_subscriptions
  CollectionReference<Map<String, dynamic>> queuedSubscriptionsRef({
    required String tenantId,
  }) {
    return _db
        .collection(tenantId)
        .doc(tenantId)
        .collection('queued_subscriptions');
  }
}
