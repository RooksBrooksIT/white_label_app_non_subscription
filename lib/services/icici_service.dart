import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firestore_service.dart';

/// Service to interact with ICICI Payment Gateway UAT APIs.
///
/// **InitiateSale**: POST to initiate a payment transaction.
/// **Command (Status/Refund)**: POST to check transaction status or initiate refund.
class IciciService {
  IciciService._();
  static final IciciService instance = IciciService._();

  // ─── UAT Endpoints ───────────────────────────────────────────────────
  static final String _initiateSaleUrl =
      dotenv.env['ICICI_INITIATE_SALE_URL'] ??
      'https://pgpayuat.icicibank.com/tsp/pg/api/v2/initiateSale';
  static final String _commandUrl =
      dotenv.env['ICICI_COMMAND_URL'] ??
      'https://pgpayuat.icicibank.com/tsp/pg/api/command';

  // ─── Merchant Configuration (UAT / Test) ─────────────────────────────
  // TODO: Move these to a secure backend or environment config for production.
  static final String merchantId =
      dotenv.env['ICICI_MERCHANT_ID'] ?? '100000000007164';
  static final String aggregatorId =
      dotenv.env['ICICI_AGGREGATOR_ID'] ?? 'A100000000007164';
  static const String currencyCode = '356'; // INR
  static const String transactionType = 'SALE';

  // TODO: Replace with your actual return URL that your app can intercept.
  static final String returnUrl =
      dotenv.env['ICICI_RETURN_URL'] ??
      'https://pgpayuat.icicibank.com/tsp/pg/api/merchant';

  // TODO: Replace with the actual Merchant Secret Key from the ICICI UAT Kit.
  // This MUST be kept secret and ideally used only on the backend.
  static final String _merchantSecretKey =
      dotenv.env['ICICI_MERCHANT_SECRET_KEY'] ?? 'YOUR_MERCHANT_SECRET_KEY';

  /// Generate a unique merchant transaction number.
  String _generateMerchantTxnNo() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Get the current date/time in the format expected by ICICI: yyyyMMddHHmmss
  String _getCurrentTxnDate() {
    return DateFormat('yyyyMMddHHmmss').format(DateTime.now());
  }

  /// Generate the secure hash for the payload.
  ///
  /// **IMPORTANT**: In production, this MUST be done on your backend server.
  /// The hash is typically computed as SHA-256 of a concatenation of specific
  /// fields in a defined order, using the Merchant Secret Key.
  ///
  /// For now, this uses a placeholder implementation.
  String _generateSecureHash(Map<String, String> payload) {
    // TODO: Implement the actual hashing logic as per ICICI's specification.
    // Typical pattern:
    //   hashInput = merchantId|merchantTxnNo|amount|... (pipe-separated)
    //   secureHash = SHA256(hashInput + merchantSecretKey)
    //
    // Using a placeholder for UAT testing:
    final hashInput =
        '${payload['merchantId']}|'
        '${payload['merchantTxnNo']}|'
        '${payload['amount']}|'
        '${payload['currencyCode']}|'
        '${payload['payType']}|'
        '${payload['txnDate']}|'
        '$_merchantSecretKey';

    final bytes = utf8.encode(hashInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Initiate a payment sale with the ICICI Payment Gateway.
  ///
  /// Returns a [Map] with the API response which typically contains
  /// a redirect URL or token for the payment page.
  ///
  /// [amount] - The payment amount (e.g. "100.00")
  /// [customerName] - Customer's full name
  /// [customerEmail] - Customer's email address
  /// [customerMobile] - Customer's mobile number (with country code, e.g. "919999999999")
  /// [payType] - Payment type: "0" = All, "1" = NB, "2" = Cards, "3" = UPI, etc.
  Future<Map<String, dynamic>?> initiateSale({
    required String amount,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    String payType = '0', // 0 = show all payment options
    String? uid, // uid for logging
    String? tenantId, // tenantId for logging
  }) async {
    try {
      final merchantTxnNo = _generateMerchantTxnNo();
      final txnDate = _getCurrentTxnDate();

      final Map<String, String> payload = {
        'merchantId': merchantId,
        'aggregatorID': aggregatorId,
        'merchantTxnNo': merchantTxnNo,
        'amount': amount,
        'currencyCode': currencyCode,
        'payType': payType,
        'customerEmailID': customerEmail,
        'transactionType': transactionType,
        'returnURL': returnUrl,
        'txnDate': txnDate,
        'customerMobileNo': customerMobile,
        'customerName': customerName,
        'addlParam1': '000',
        'addlParam2': '111',
      };

      // Generate secure hash
      payload['secureHash'] = _generateSecureHash(payload);

      debugPrint('ICICI InitiateSale Request: ${jsonEncode(payload)}');

      // Save the full request payload to Firestore
      await saveSubscriptionPayment(
        payload: payload,
        uid: uid,
        tenantId: tenantId,
        status: 'INITIATED',
      );

      final response = await http.post(
        Uri.parse(_initiateSaleUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint(
        'ICICI InitiateSale Response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          ...responseData,
          'merchantTxnNo': merchantTxnNo, // Return for status checks later
        };
      } else {
        debugPrint(
          'ICICI API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('ICICI initiateSale error: $e');
      return null;
    }
  }

  /// Fetches the customer's data (name and phone) from Firestore user profile.
  /// Falls back to defaults if not found.
  Future<Map<String, String>> fetchCustomerData(
    String uid,
    String tenantId,
  ) async {
    String phone = '';
    String name = 'Customer';
    try {
      final userDoc = await FirestoreService.instance
          .collection('users', tenantId: tenantId)
          .doc(uid)
          .get();
      final data = userDoc.data();
      phone =
          (data?['customerMobile'] as String?) ??
          (data?['phone'] as String?) ??
          '';
      name = (data?['name'] as String?) ?? 'Customer';
    } catch (e) {
      debugPrint('Error fetching customer data: $e');
    }

    // Ensure phone has country code prefix
    if (phone.isNotEmpty && !phone.startsWith('91')) {
      phone = '91$phone';
    }

    return {'name': name, 'phone': phone.isEmpty ? '919999999999' : phone};
  }

  /// Save the ICICI InitiateSale request payload to the [subscriptionPayment]
  /// Firestore collection for audit and reconciliation purposes.
  Future<void> saveSubscriptionPayment({
    required Map<String, String> payload,
    String? uid,
    String? tenantId,
    String status = 'INITIATED',
  }) async {
    try {
      final docId =
          payload['merchantTxnNo'] ??
          DateTime.now().millisecondsSinceEpoch.toString();

      CollectionReference? ref;
      if (uid != null && tenantId != null) {
        // Nested under user profile: {tenant}/data/users/{uid}/subscriptionPayment
        ref = FirestoreService.instance
            .collection('users', tenantId: tenantId)
            .doc(uid)
            .collection('subscriptionPayment');
      } else {
        // Fallback to legacy global collection if IDs missing
        ref = FirebaseFirestore.instance.collection('subscriptionPayment');
      }

      await ref.doc(docId).set({
        ...payload,
        if (uid != null) 'uid': uid,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      debugPrint('ICICI payload saved to subscriptionPayment: $docId');
    } catch (e) {
      debugPrint('Error saving to subscriptionPayment: $e');
    }
  }

  /// Check the status of a transaction using the Command API.
  ///
  /// [merchantTxnNo] - The merchant transaction number used during initiation.
  Future<Map<String, dynamic>?> checkTransactionStatus({
    required String merchantTxnNo,
  }) async {
    try {
      final payload = {
        'merchantId': merchantId,
        'merchantTxnNo': merchantTxnNo,
        'command': 'STATUS',
      };

      debugPrint('ICICI Status Check Request: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse(_commandUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint(
        'ICICI Status Check Response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          'ICICI Status API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('ICICI checkTransactionStatus error: $e');
      return null;
    }
  }

  /// Initiate a refund for a completed transaction.
  ///
  /// [merchantTxnNo] - The original merchant transaction number.
  /// [amount] - The refund amount.
  Future<Map<String, dynamic>?> initiateRefund({
    required String merchantTxnNo,
    required String amount,
  }) async {
    try {
      final payload = {
        'merchantId': merchantId,
        'merchantTxnNo': merchantTxnNo,
        'command': 'REFUND',
        'amount': amount,
      };

      debugPrint('ICICI Refund Request: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse(_commandUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint(
        'ICICI Refund Response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          'ICICI Refund API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('ICICI initiateRefund error: $e');
      return null;
    }
  }

  /// Save a payment transaction record to Firestore.
  ///
  /// This creates a record under `payment_transactions` collection
  /// nested within the tenant/app document for data isolation.
  Future<void> saveTransaction({
    required String uid,
    required String merchantTxnNo,
    required String amount,
    required String status,
    required String paymentMethod,
    String? planName,
    bool? isYearly,
    String? tenantId,
    String? appId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final ref = FirestoreService.instance.collection(
        'payment_transactions',
        tenantId: tenantId,
        appId: appId,
      );

      await ref.doc(merchantTxnNo).set({
        'uid': uid,
        'merchantTxnNo': merchantTxnNo,
        'amount': amount,
        'status': status,
        'paymentMethod': paymentMethod,
        'planName': planName,
        'isYearly': isYearly,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      });

      debugPrint('Transaction saved to Firestore: $merchantTxnNo');
    } catch (e) {
      debugPrint('Error saving transaction to Firestore: $e');
    }
  }
}
