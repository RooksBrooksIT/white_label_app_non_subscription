/**
 * Flutter Service: ICICI Payment Gateway Integration
 * File: lib/services/payment_service.dart
 * 
 * This service handles all payment operations by calling Firebase Cloud Functions
 * ALL sensitive operations (hashing, API calls) happen on backend
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  final _firebaseAuth = FirebaseAuth.instance;
  final _cloudFunctions = FirebaseFunctions.instance;

  // Use appropriate region for your Firebase project
  final _region = 'us-central1';

  PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  /// Get valid ID token for Firebase authentication
  Future<String?> _getIdToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      return await user.getIdToken();
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Initiate payment with ICICI
  ///
  /// Parameters:
  ///   - orderId: Unique order identifier (e.g., 'ORDER_123456')
  ///   - amount: Payment amount (e.g., 500.00)
  ///   - customerId: Customer/User ID
  ///   - mobileNumber: Customer mobile (10 digits)
  ///   - emailId: Customer email
  ///   - productDescription: Description of product/service
  ///
  /// Returns: PaymentResponse with success status and payment details
  Future<PaymentResponse> initiatePayment({
    required String orderId,
    required double amount,
    required String customerId,
    required String mobileNumber,
    required String emailId,
    String? productDescription,
  }) async {
    try {
      // Validate inputs
      if (orderId.isEmpty || amount <= 0) {
        return PaymentResponse.failure('Invalid order or amount');
      }

      // Get auth token
      final idToken = await _getIdToken();
      if (idToken == null) {
        return PaymentResponse.failure('Authentication failed');
      }

      debugPrint(
        '[PAYMENT] Initiating payment for Order: $orderId, Amount: $amount',
      );

      // Call Firebase Cloud Function
      final callable = _cloudFunctions.httpsCallable(
        'initiatePayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final response = await callable.call({
        'orderId': orderId,
        'amount': amount.toStringAsFixed(2),
        'customerId': customerId,
        'mobileNumber': mobileNumber,
        'emailId': emailId,
        'productDescription': productDescription ?? 'Payment',
      });

      // LOG: Backend Response
      debugPrint('[PAYMENT] Backend Response for $orderId: ${response.data}');

      // Handle response
      if (response.data != null && response.data['success'] == true) {
        return PaymentResponse.success(
          orderId: orderId,
          amount: amount,
          transactionId: response.data['transactionId'],
          redirectUrl: response.data['redirectUrl'],
          message: response.data['message'],
        );
      } else {
        final errorMsg = response.data?['error'] ?? 'Payment initiation failed';
        debugPrint('[PAYMENT] Initiation Failed: $errorMsg');
        return PaymentResponse.failure(errorMsg);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PAYMENT] Firebase error: ${e.code} - ${e.message}');
      return PaymentResponse.failure('Payment service error: ${e.message}');
    } catch (e) {
      debugPrint('[PAYMENT] Unexpected error: $e');
      return PaymentResponse.failure('Unexpected error: $e');
    }
  }

  /// Check payment status
  ///
  /// Call this periodically to check if payment was successful
  Future<PaymentStatusResponse> checkPaymentStatus({
    required String orderId,
    required String customerId,
  }) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        return PaymentStatusResponse.failure('Authentication failed');
      }

      debugPrint('[PAYMENT] Checking status for Order: $orderId');

      final callable = _cloudFunctions.httpsCallable(
        'checkPaymentStatus',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final response = await callable.call({
        'orderId': orderId,
        'customerId': customerId,
      });

      // LOG: Status Response
      debugPrint('[PAYMENT] Status Response for $orderId: ${response.data}');

      if (response.data != null && response.data['success'] == true) {
        final status = response.data['status'];

        return PaymentStatusResponse.success(
          orderId: orderId,
          status: status,
          amount: response.data['amount'],
          transactionId: response.data['transactionId'],
        );
      } else {
        final errorMsg = response.data?['error'] ?? 'Status check failed';
        debugPrint('[PAYMENT] Status Check Failed: $errorMsg');
        return PaymentStatusResponse.failure(errorMsg);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PAYMENT] Status check error: ${e.code} - ${e.message}');
      return PaymentStatusResponse.failure(e.message ?? 'Status check failed');
    } catch (e) {
      debugPrint('[PAYMENT] Unexpected error: $e');
      return PaymentStatusResponse.failure('Unexpected error: $e');
    }
  }

  /// Request refund for a transaction
  ///
  /// IMPORTANT: Only call after payment is successful
  Future<RefundResponse> requestRefund({
    required String orderId,
    required String transactionId,
    required double refundAmount,
    required String customerId,
  }) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        return RefundResponse.failure('Authentication failed');
      }

      debugPrint(
        '[PAYMENT] Requesting refund for Order: $orderId, Amount: $refundAmount',
      );

      final callable = _cloudFunctions.httpsCallable(
        'processRefund',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final response = await callable.call({
        'orderId': orderId,
        'transactionId': transactionId,
        'refundAmount': refundAmount.toStringAsFixed(2),
        'customerId': customerId,
      });

      if (response.data['success'] == true) {
        return RefundResponse.success(
          orderId: orderId,
          refundAmount: refundAmount,
          message: response.data['message'],
        );
      } else {
        return RefundResponse.failure(
          response.data['error'] ?? 'Refund request failed',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PAYMENT] Refund error: ${e.code} - ${e.message}');
      return RefundResponse.failure(e.message ?? 'Refund request failed');
    } catch (e) {
      debugPrint('[PAYMENT] Unexpected error: $e');
      return RefundResponse.failure('Unexpected error: $e');
    }
  }
}

// ===== Response Models =====

class PaymentResponse {
  final bool success;
  final String orderId;
  final double? amount;
  final String? transactionId;
  final String? redirectUrl;
  final String message;
  final String? error;

  PaymentResponse({
    required this.success,
    required this.orderId,
    this.amount,
    this.transactionId,
    this.redirectUrl,
    required this.message,
    this.error,
  });

  factory PaymentResponse.success({
    required String orderId,
    required double amount,
    String? transactionId,
    String? redirectUrl,
    String? message,
  }) {
    return PaymentResponse(
      success: true,
      orderId: orderId,
      amount: amount,
      transactionId: transactionId,
      redirectUrl: redirectUrl,
      message: message ?? 'Payment initiated successfully',
    );
  }

  factory PaymentResponse.failure(String error) {
    return PaymentResponse(
      success: false,
      orderId: '',
      message: 'Payment failed',
      error: error,
    );
  }
}

class PaymentStatusResponse {
  final bool success;
  final String orderId;
  final String? status; // SUCCESS, FAILED, PENDING
  final double? amount;
  final String? transactionId;
  final String message;
  final String? error;

  PaymentStatusResponse({
    required this.success,
    required this.orderId,
    this.status,
    this.amount,
    this.transactionId,
    required this.message,
    this.error,
  });

  factory PaymentStatusResponse.success({
    required String orderId,
    String? status,
    double? amount,
    String? transactionId,
  }) {
    return PaymentStatusResponse(
      success: true,
      orderId: orderId,
      status: status,
      amount: amount,
      transactionId: transactionId,
      message: 'Status retrieved successfully',
    );
  }

  factory PaymentStatusResponse.failure(String error) {
    return PaymentStatusResponse(
      success: false,
      orderId: '',
      message: 'Status check failed',
      error: error,
    );
  }
}

class RefundResponse {
  final bool success;
  final String orderId;
  final double? refundAmount;
  final String message;
  final String? error;

  RefundResponse({
    required this.success,
    required this.orderId,
    this.refundAmount,
    required this.message,
    this.error,
  });

  factory RefundResponse.success({
    required String orderId,
    required double refundAmount,
    String? message,
  }) {
    return RefundResponse(
      success: true,
      orderId: orderId,
      refundAmount: refundAmount,
      message: message ?? 'Refund initiated successfully',
    );
  }

  factory RefundResponse.failure(String error) {
    return RefundResponse(
      success: false,
      orderId: '',
      message: 'Refund failed',
      error: error,
    );
  }
}
