import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Response Model for ICICI Payment Initiation
class IciciPaymentResponse {
  final bool success;
  final String? txnId;
  final String? redirectUrl;
  final String? error;

  IciciPaymentResponse({
    required this.success,
    this.txnId,
    this.redirectUrl,
    this.error,
  });

  factory IciciPaymentResponse.fromJson(Map<String, dynamic> json) {
    return IciciPaymentResponse(
      success: json['success'] ?? false,
      txnId: json['txnId'] as String?,
      redirectUrl:
          (json['upiQR'] as String?) ?? (json['redirectUrl'] as String?),
      error: json['error'] as String?,
    );
  }
}

class IciciService {
  IciciService._();
  static final IciciService instance = IciciService._();

  static const String _baseUrl =
      'https://us-central1-white-label-app-33300.cloudfunctions.net';
  static const String returnUrl = '$_baseUrl/paymentReturn';
  static const String _createSessionUrl = '$_baseUrl/createPaymentSession';
  static const String _processRefundUrl = '$_baseUrl/processRefund';
  static const String _verifyPaymentUrl = '$_baseUrl/verifyPayment';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Initiates a standard ICICI Payment Session (Cards, NetBanking, UPI)
  Future<IciciPaymentResponse> initiatePayment({
    required String amount,
    required String email,
    required String tenantId,
    required String appId,
    required String paymentMode,
    String? planName,
    String? customerName,
    String? customerMobile,
    bool isYearly = false,
    bool isSixMonths = false,
    Map<String, dynamic>? limits,
    bool? geoLocation,
    bool? attendance,
    bool? barcode,
    bool? reportExport,
    String? returnUrl,
    String? userId, // Optional userId for registration flow
  }) async {
    const TAG = '[ICICI-SERVICE]';
    try {
      final user = FirebaseAuth.instance.currentUser;
      final effectiveUserId = userId ?? user?.uid;

      if (effectiveUserId == null) throw Exception('User not authenticated');

      String? idToken;
      if (user != null) {
        idToken = await user.getIdToken();
      }

      final response = await _dio.post(
        _createSessionUrl,
        options: Options(
          headers: {
            if (idToken != null) 'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'amount': amount,
          'userId': effectiveUserId,
          'email': email,
          'mobile': customerMobile,
          'tenantId': tenantId,
          'appId': appId,
          'paymentMode': paymentMode,
          'planName': planName ?? 'Subscription',
          'customerName': customerName,
          'customerMobile': customerMobile,
          'isYearly': isYearly,
          'isSixMonths': isSixMonths,
          'limits': limits,
          'geoLocation': geoLocation,
          'attendance': attendance,
          'barcode': barcode,
          'reportExport': reportExport,
          'returnUrl': returnUrl ?? IciciService.returnUrl,
        },
      );

      return IciciPaymentResponse.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('$TAG Dio Error Data: ${e.response?.data}');
      return IciciPaymentResponse(
        success: false,
        error: e.response?.data?['error'] ?? 'Network error (${e.message})',
        txnId: e.response?.data?['txnId'],
      );
    } catch (e) {
      debugPrint('$TAG Fatal Error: $e');
      return IciciPaymentResponse(success: false, error: e.toString());
    }
  }

  /// Fetches the customer's data (name and phone) from Firestore user profile.
  Future<Map<String, String>> fetchCustomerData(
    String uid,
    String tenantId,
  ) async {
    String phone = '';
    String name = 'Customer';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(tenantId)
          .doc('data')
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        phone =
            (data?['customerMobile'] as String?) ??
            (data?['phone'] as String?) ??
            '';
        name = (data?['name'] as String?) ?? 'Customer';
      }
    } catch (e) {
      debugPrint('[IciciService] fetchCustomerData error: $e');
    }
    if (phone.isNotEmpty && !phone.startsWith('91')) {
      phone = '91$phone';
    }
    return {'name': name, 'phone': phone};
  }

  /// Stream transaction status from Firestore
  Stream<DocumentSnapshot> streamTransactionStatus(String txnId) {
    return FirebaseFirestore.instance
        .collection('payments')
        .doc(txnId)
        .snapshots();
  }

  /// Initiate a refund for a completed transaction via the backend.
  Future<Map<String, dynamic>?> initiateRefund({
    required String merchantTxnNo,
    required String amount,
  }) async {
    const TAG = '[ICICI-REFUND]';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      final response = await _dio.post(
        _processRefundUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'orderId': merchantTxnNo,
          'transactionId': merchantTxnNo,
          'refundAmount': double.tryParse(amount) ?? 0.0,
          'customerId': user.uid,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$TAG Error: $e');
      return null;
    }
  }

  /// Verify payment status via backend
  Future<Map<String, dynamic>> verifyPaymentStatus({
    required String txnId,
  }) async {
    const TAG = '[ICICI-VERIFY]';
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;
      if (user != null) {
        idToken = await user.getIdToken();
      }

      final response = await _dio.post(
        _verifyPaymentUrl,
        options: Options(
          headers: {
            if (idToken != null) 'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {'txnId': txnId, if (user != null) 'userId': user.uid},
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$TAG Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Compatibility wrapper for legacy generateQR calls
  /// Now routes to the standard initiatePayment flow.
  Future<Map<String, dynamic>?> generateQR({
    required String amount,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    String payType = '1',
    String? uid,
    String? tenantId,
    String? appId,
    String planName = 'Subscription',
  }) async {
    final response = await initiatePayment(
      amount: amount,
      email: customerEmail,
      tenantId: tenantId ?? '',
      appId: appId ?? '',
      paymentMode: 'UPI',
      planName: planName,
      customerName: customerName,
      customerMobile: customerMobile,
    );

    if (response.success) {
      return {
        'success': true,
        'txnId': response.txnId,
        'redirectUrl': response.redirectUrl,
        'merchantTxnNo': response.txnId,
      };
    }
    return null;
  }
}
