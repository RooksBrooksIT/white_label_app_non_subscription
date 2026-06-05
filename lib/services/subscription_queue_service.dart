/// Flutter Service: Subscription Plan Queue Management
/// File: lib/services/subscription_queue_service.dart
///
/// Handles queued plan upgrades — plans purchased while an existing plan
/// is still active, deferred to activate automatically upon expiry.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class SubscriptionQueueService {
  SubscriptionQueueService._();
  static final SubscriptionQueueService instance = SubscriptionQueueService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore path: {tenantId} → {tenantId} → queued_subscriptions → {uid} ──

  CollectionReference<Map<String, dynamic>> _queueRef(String tenantId) {
    return _db
        .collection(tenantId)
        .doc(tenantId)
        .collection('queued_subscriptions');
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Saves (or replaces) a queued plan for a user.
  /// [scheduledActivationDate] should be the active plan's expiry date.
  Future<void> saveQueuedPlan({
    required String tenantId,
    required String uid,
    required String planName,
    required bool isYearly,
    required bool isSixMonths,
    required int price,
    int? originalPrice,
    required String paymentMethod,
    required String transactionId,
    DateTime? scheduledActivationDate,
    Map<String, dynamic>? limits,
    bool? geoLocation,
    bool? attendance,
    bool? barcode,
    bool? reportExport,
  }) async {
    try {
      final data = <String, dynamic>{
        'planName': planName.trim(),
        'isYearly': isYearly,
        'isSixMonths': isSixMonths,
        'price': price,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'queuedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
        if (originalPrice != null) 'originalPrice': originalPrice,
        if (scheduledActivationDate != null)
          'scheduledActivationDate': Timestamp.fromDate(scheduledActivationDate),
        if (limits != null) 'limits': limits,
        if (geoLocation != null) 'geoLocation': geoLocation,
        if (attendance != null) 'attendance': attendance,
        if (barcode != null) 'barcode': barcode,
        if (reportExport != null) 'reportExport': reportExport,
      };

      await _queueRef(tenantId).doc(uid).set(data);
      debugPrint(
        '[QueueService] Queued plan "$planName" for user $uid '
        '(activates: $scheduledActivationDate)',
      );
    } catch (e) {
      debugPrint('[QueueService] Error saving queued plan: $e');
      rethrow;
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns the queued plan data for a user, or null if none exists.
  Future<Map<String, dynamic>?> getQueuedPlan({
    required String tenantId,
    required String uid,
  }) async {
    try {
      final doc = await _queueRef(tenantId).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('[QueueService] Error fetching queued plan: $e');
    }
    return null;
  }

  /// Real-time stream of the queued plan document for a user.
  Stream<Map<String, dynamic>?> streamQueuedPlan({
    required String tenantId,
    required String uid,
  }) {
    return _queueRef(tenantId).doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return snap.data();
      return null;
    });
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  /// Removes the queued plan for a user (e.g., after activation or cancellation).
  Future<void> clearQueuedPlan({
    required String tenantId,
    required String uid,
  }) async {
    try {
      await _queueRef(tenantId).doc(uid).delete();
      debugPrint('[QueueService] Cleared queued plan for user $uid');
    } catch (e) {
      debugPrint('[QueueService] Error clearing queued plan: $e');
    }
  }

  // ── Activate ────────────────────────────────────────────────────────────────

  /// Promotes a queued plan to the active subscription.
  ///
  /// Called automatically by [SubscriptionExpiryService] when the active plan
  /// expires, or manually when the user disables the queue toggle.
  ///
  /// Returns `true` if a queued plan was found and activated, `false` if none.
  Future<bool> activateQueuedPlan({
    required String tenantId,
    required String uid,
  }) async {
    try {
      final queued = await getQueuedPlan(tenantId: tenantId, uid: uid);
      if (queued == null) {
        debugPrint('[QueueService] No queued plan found for user $uid');
        return false;
      }

      final planName = queued['planName'] as String? ?? '';
      debugPrint(
        '[QueueService] Activating queued plan "$planName" for user $uid',
      );

      // Promote to active subscription
      await FirestoreService.instance.upsertSubscription(
        uid: uid,
        tenantId: tenantId,
        appId: 'data',
        planName: planName,
        isYearly: queued['isYearly'] as bool? ?? false,
        isSixMonths: queued['isSixMonths'] as bool? ?? false,
        price: queued['price'] as int? ?? 0,
        originalPrice: queued['originalPrice'] as int?,
        paymentMethod: queued['paymentMethod'] as String? ?? 'Unknown',
        status: 'active',
        limits: queued['limits'] as Map<String, dynamic>?,
        geoLocation: queued['geoLocation'] as bool?,
        attendance: queued['attendance'] as bool?,
        barcode: queued['barcode'] as bool?,
        reportExport: queued['reportExport'] as bool?,
      );

      // Re-activate the user account
      await FirestoreService.instance.setUserActiveStatus(
        uid: uid,
        tenantId: tenantId,
        active: true,
      );

      // Remove the queue entry
      await clearQueuedPlan(tenantId: tenantId, uid: uid);

      debugPrint(
        '[QueueService] Successfully activated queued plan "$planName" for user $uid',
      );
      return true;
    } catch (e) {
      debugPrint('[QueueService] Error activating queued plan: $e');
      return false;
    }
  }
}
