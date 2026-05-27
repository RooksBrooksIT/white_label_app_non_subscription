/**
 * Payment Utilities and Helpers
 * File: lib/utils/payment_utils.dart
 */

import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class PaymentUtils {
  static const uuid = Uuid();

  /// Generate unique Order ID
  /// Format: ORDER_TIMESTAMP_RANDOM
  static String generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'ORDER_${timestamp}_$random';
  }

  /// Generate unique Transaction ID
  static String generateTransactionId() {
    return 'TXN_${uuid.v4().replaceAll('-', '').toUpperCase()}';
  }

  /// Validate Indian mobile number
  static bool isValidMobileNumber(String? number) {
    if (number == null || number.isEmpty) return false;
    
    // Remove spaces and special characters
    final cleaned = number.replaceAll(RegExp(r'\D'), '');
    
    // Check if 10 digits and starts with 6-9
    final regex = RegExp(r'^[6-9]\d{9}$');
    return regex.hasMatch(cleaned);
  }

  /// Validate email
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    return regex.hasMatch(email);
  }

  /// Format amount to 2 decimal places
  static String formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Convert amount to paise (smallest currency unit)
  static int amountToPaise(double amount) {
    return (amount * 100).toInt();
  }

  /// Convert paise to amount
  static double paiseToAmount(int paise) {
    return paise / 100;
  }

  /// Format amount as currency string
  static String formatCurrency(double amount) {
    return '₹${formatAmount(amount)}';
  }

  /// Check if amount is valid for payment
  /// ICICI allows: 1 to 999999
  static bool isValidPaymentAmount(double amount) {
    return amount >= 1 && amount <= 999999;
  }

  /// Get error message for invalid fields
  static String? validatePaymentData({
    required String orderId,
    required double amount,
    required String mobileNumber,
    required String email,
  }) {
    if (orderId.isEmpty) return 'Order ID is required';
    if (!isValidPaymentAmount(amount)) {
      return 'Amount must be between ₹1 and ₹999,999';
    }
    if (!isValidMobileNumber(mobileNumber)) {
      return 'Invalid mobile number (must be 10 digits)';
    }
    if (!isValidEmail(email)) {
      return 'Invalid email address';
    }
    return null;
  }

  /// Get payment status display text
  static String getStatusDisplayText(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return 'Payment Successful';
      case 'FAILED':
        return 'Payment Failed';
      case 'PENDING':
        return 'Processing...';
      case 'INITIATED':
        return 'Awaiting Payment';
      default:
        return 'Unknown Status';
    }
  }

  /// Get status color for UI
  static Color getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'PENDING':
      case 'INITIATED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  static IconData getStatusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.cancel;
      case 'PENDING':
      case 'INITIATED':
        return Icons.hourglass_bottom;
      default:
        return Icons.help;
    }
  }
}
