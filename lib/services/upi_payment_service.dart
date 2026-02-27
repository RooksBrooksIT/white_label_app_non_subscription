import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to handle UPI payments by launching native UPI apps.
///
/// Supports Google Pay, PhonePe, Paytm, and generic UPI.
class UpiPaymentService {
  UpiPaymentService._();
  static final UpiPaymentService instance = UpiPaymentService._();

  // ─── Merchant Configuration ────────────────────────────────────────────
  // TODO: Replace with your actual merchant UPI VPA (Virtual Payment Address)
  static const String merchantVpa = 'merchant@icici';
  static const String merchantName = 'Rooks Tech';
  static const String currency = 'INR';

  /// UPI app configurations: scheme and package name for each app.
  static const Map<String, _UpiAppConfig> _appConfigs = {
    'Google Pay': _UpiAppConfig(
      scheme: 'tez',
      package: 'com.google.android.apps.nbu.paisa.user',
    ),
    'Phone Pay': _UpiAppConfig(scheme: 'phonepe', package: 'com.phonepe.app'),
    'Paytm': _UpiAppConfig(scheme: 'paytm', package: 'net.one97.paytm'),
  };

  /// Build a UPI payment URI.
  ///
  /// [scheme] - The UPI scheme (e.g., 'upi', 'tez', 'phonepe', 'paytm')
  /// [amount] - Payment amount
  /// [transactionNote] - Description of the payment
  /// [transactionRefId] - Unique transaction reference ID
  Uri _buildUpiUri({
    required String scheme,
    required String amount,
    required String transactionNote,
    required String transactionRefId,
  }) {
    return Uri(
      scheme: scheme,
      host: 'pay',
      queryParameters: {
        'pa': merchantVpa,
        'pn': merchantName,
        'am': amount,
        'cu': currency,
        'tn': transactionNote,
        'tr': transactionRefId,
      },
    );
  }

  /// Check if a specific UPI app is available on the device.
  Future<bool> isAppAvailable(String appName) async {
    final config = _appConfigs[appName];
    if (config == null) return false;

    final uri = Uri(scheme: config.scheme, host: 'pay');
    try {
      return await canLaunchUrl(uri);
    } catch (e) {
      debugPrint('Error checking UPI app availability: $e');
      return false;
    }
  }

  /// Launch a UPI payment in the specified app.
  ///
  /// Returns `true` if the app was launched successfully.
  /// The actual payment result needs to be verified separately.
  ///
  /// [appName] - Name of the UPI app ('Google Pay', 'Phone Pay', 'Paytm')
  /// [amount] - Payment amount as string (e.g., '100.00')
  /// [transactionNote] - Description shown in the UPI app
  /// [transactionRefId] - Unique reference for this transaction
  Future<bool> launchUpiPayment({
    required String appName,
    required String amount,
    required String transactionNote,
    required String transactionRefId,
  }) async {
    try {
      final config = _appConfigs[appName];
      final scheme = config?.scheme ?? 'upi';

      final uri = _buildUpiUri(
        scheme: scheme,
        amount: amount,
        transactionNote: transactionNote,
        transactionRefId: transactionRefId,
      );

      debugPrint('Launching UPI payment: $uri');

      // Try app-specific scheme first
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }

      // Fallback to generic UPI scheme
      if (scheme != 'upi') {
        final genericUri = _buildUpiUri(
          scheme: 'upi',
          amount: amount,
          transactionNote: transactionNote,
          transactionRefId: transactionRefId,
        );

        debugPrint('Falling back to generic UPI: $genericUri');

        if (await canLaunchUrl(genericUri)) {
          return await launchUrl(
            genericUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }

      debugPrint('No UPI app available for: $appName');
      return false;
    } catch (e) {
      debugPrint('Error launching UPI payment: $e');
      return false;
    }
  }

  /// Launch a generic UPI payment (system chooser will show available apps).
  Future<bool> launchGenericUpi({
    required String amount,
    required String transactionNote,
    required String transactionRefId,
  }) async {
    try {
      final uri = _buildUpiUri(
        scheme: 'upi',
        amount: amount,
        transactionNote: transactionNote,
        transactionRefId: transactionRefId,
      );

      debugPrint('Launching generic UPI: $uri');

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return false;
    } catch (e) {
      debugPrint('Error launching generic UPI: $e');
      return false;
    }
  }
}

/// Internal configuration for a UPI app.
class _UpiAppConfig {
  final String scheme;
  final String package;

  const _UpiAppConfig({required this.scheme, required this.package});
}
