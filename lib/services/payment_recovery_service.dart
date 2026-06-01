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
      await prefs.setString(_kPendingPaymentKey, jsonEncode(data));
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
        return jsonDecode(data) as Map<String, dynamic>;
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
