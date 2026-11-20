import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PaymentRecoveryService {
  PaymentRecoveryService._();
  static final PaymentRecoveryService instance = PaymentRecoveryService._();

  static const String _kPendingPaymentKey = 'pending_payment_transaction';

  Future<void> savePendingPayment(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapWithTimestamp = Map<String, dynamic>.from(data);
      mapWithTimestamp['savedAt'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_kPendingPaymentKey, jsonEncode(mapWithTimestamp));
      debugPrint('Pending payment saved locally for recovery: ${data['txnId']}');
    } catch (e) {
      debugPrint('Failed to save pending payment: $e');
    }
  }

  Future<Map<String, dynamic>?> getPendingPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_kPendingPaymentKey);
      if (data != null) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        final savedAt = map['savedAt'] as int?;
        if (savedAt != null) {
          final age = DateTime.now().millisecondsSinceEpoch - savedAt;
          // Gateway sessions expire within 15-20 minutes.
          // If transaction was initiated more than 20 minutes ago, auto-discard it.
          if (age > const Duration(minutes: 20).inMilliseconds) {
            debugPrint('Pending payment is older than 20 minutes (expired session). Auto-clearing.');
            await clearPendingPayment();
            return null;
          }
        }
        return map;
      }
    } catch (e) {
      debugPrint('Failed to read pending payment: $e');
    }
    return null;
  }

  Future<void> clearPendingPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingPaymentKey);
      debugPrint('Pending payment cleared from local storage');
    } catch (e) {
      debugPrint('Failed to clear pending payment: $e');
    }
  }
}
