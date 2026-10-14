import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'webview_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result returned when the hosted payment page flow completes.
// ─────────────────────────────────────────────────────────────────────────────
class IciciPaymentResult {
  final bool success;
  final String? message;
  final Map<String, String>? queryParams;
  final String? paymentMethod;

  const IciciPaymentResult({
    required this.success,
    this.message,
    this.queryParams,
    this.paymentMethod,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Full-screen WebView for the ICICI Hosted Payment Page.
///
/// Handles:
///  • Card / Net Banking — loaded in-app WebView (no card data in app).
///  • Return URL interception — detects success / failure redirect.
///  • Firestore real-time stream — picks up webhook-confirmed status.
///  • Session expiry — auto-closes after [_sessionTimeoutMinutes] minutes.
///  • Back / cancel guard — shows confirmation dialog.
///  • Deduplication — only the first conclusive result (stream OR URL) is acted on.
// ─────────────────────────────────────────────────────────────────────────────
class IciciPaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String merchantTxnNo;
  final String returnUrl;
  final String paymentMethod;

  /// Optional: override session timeout (default 15 min).
  final Duration sessionTimeout;

  const IciciPaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.merchantTxnNo,
    required this.returnUrl,
    this.paymentMethod = 'Card',
    this.sessionTimeout = const Duration(minutes: 15),
  });

  @override
  State<IciciPaymentWebViewScreen> createState() =>
      _IciciPaymentWebViewScreenState();
}

class _IciciPaymentWebViewScreenState
    extends State<IciciPaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0;

  /// Prevents double-navigation if both Firestore stream and return-URL fire.
  bool _resultDispatched = false;

  StreamSubscription<DocumentSnapshot>? _txnSubscription;
  Timer? _sessionTimer;

  // ── UPI Intent Detection ────────────────────────────────────────────────────
  bool get _isUpiIntent =>
      widget.paymentUrl.toLowerCase().startsWith('upi://') ||
      widget.paymentUrl.toLowerCase().startsWith('gpay://') ||
      widget.paymentUrl.toLowerCase().startsWith('phonepe://') ||
      widget.paymentUrl.toLowerCase().startsWith('paytmmp://');

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _launchWebPaymentUrl();
    } else if (!_isUpiIntent) {
      _initWebView();
    } else {
      _launchUpiIntent();
    }
    _listenToTransactionStatus();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _txnSubscription?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Session Timer ───────────────────────────────────────────────────────────
  void _startSessionTimer() {
    _sessionTimer = Timer(widget.sessionTimeout, () {
      if (!mounted || _resultDispatched) return;
      _dispatchResult(IciciPaymentResult(
        success: false,
        message: 'Payment session expired. Please try again.',
        paymentMethod: widget.paymentMethod,
      ));
    });
  }

  // ── Firestore Real-Time Stream ──────────────────────────────────────────────
  void _listenToTransactionStatus() {
    _txnSubscription = IciciService.instance
        .streamTransactionStatus(widget.merchantTxnNo)
        .listen((doc) {
      if (!mounted || _resultDispatched || !doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'];
      if (status == 'SUCCESS') {
        _dispatchResult(IciciPaymentResult(
          success: true,
          message: 'Payment completed successfully',
          paymentMethod: widget.paymentMethod,
        ));
      } else if (status == 'FAILED') {
        _dispatchResult(IciciPaymentResult(
          success: false,
          message: data['errorMsg'] ?? data['error'] ?? 'Payment failed',
          paymentMethod: widget.paymentMethod,
        ));
      }
    });
  }

  // ── Dispatch result (deduplication guard) ───────────────────────────────────
  void _dispatchResult(IciciPaymentResult result) {
    if (_resultDispatched) return;
    _resultDispatched = true;
    _txnSubscription?.cancel();
    _sessionTimer?.cancel();
    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  // ── Web Payment URL Launcher ───────────────────────────────────────────────
  Future<void> _launchWebPaymentUrl() async {
    final uri = Uri.parse(widget.paymentUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[IciciWebView] Cannot launch Web payment URL');
      }
    } catch (e) {
      debugPrint('[IciciWebView] Web payment URL launch error: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── UPI Intent Launcher ─────────────────────────────────────────────────────
  // ── UPI Intent Launcher ─────────────────────────────────────────────────────
  Future<void> _launchUpiIntent() async {
    final handled = await _launchExternalUrl(widget.paymentUrl);
    if (!handled) {
      debugPrint('[IciciWebView] Failed to launch direct UPI URL: ${widget.paymentUrl}');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── WebView Initialization ──────────────────────────────────────────────────
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            debugPrint('[IciciWebView] Navigating to: ${request.url}');

            // 1. Intercept the ICICI return URL
            if (_isReturnUrl(request.url)) {
              debugPrint('[IciciWebView] Return URL intercepted: ${request.url}');
              _handleReturnUrl(request.url);
              return NavigationDecision.prevent;
            }

            // 2. Handle UPI / external app deep-link schemes
            final lower = request.url.toLowerCase();
            if (_isExternalScheme(lower)) {
              debugPrint('[IciciWebView] External scheme intercepted: ${request.url}');
              _launchExternalUrl(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            debugPrint('[IciciWebView] Page finished: $url');
            if (mounted) setState(() => _isLoading = false);
            // Catch redirect that didn't trigger onNavigationRequest
            if (_isReturnUrl(url)) _handleReturnUrl(url);
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100);
            }
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null && _isExternalScheme(url.toLowerCase())) {
              debugPrint('[IciciWebView] External scheme in onUrlChange: $url');
              _launchExternalUrl(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                '[IciciWebView] WebResource error ${error.errorCode}: ${error.description}');
            final url = error.url;
            if (url != null && _isExternalScheme(url.toLowerCase())) {
              debugPrint('[IciciWebView] External scheme in WebResourceError: $url');
              _launchExternalUrl(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  bool _isExternalScheme(String lower) {
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('about:blank') ||
        lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('javascript:')) {
      return false;
    }
    return true;
  }

  Future<bool> _launchExternalUrl(String rawUrl) async {
    debugPrint('[IciciWebView] Launching external payment URL: $rawUrl');

    // 1. On Android, prioritize the native MethodChannel.
    // Native Android utilizes Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
    // and Intent.createChooser so all installed UPI apps (Google Pay, PhonePe, Paytm, BHIM, etc.)
    // are presented consistently across all Android versions.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('com.rooks.subscription/upi_intent');
        final bool? handled = await channel.invokeMethod<bool>(
          'launchUpiIntent',
          {'url': rawUrl},
        );
        if (handled == true) {
          debugPrint('[IciciWebView] Successfully launched via native MethodChannel');
          return true;
        }
      } catch (e) {
        debugPrint('[IciciWebView] Native MethodChannel launch error: $e');
      }
    }

    // 2. Dart-side fallback: Convert intent:// or intent:#Intent to standard upi:// scheme
    String cleanUrl = rawUrl;
    if (rawUrl.toLowerCase().startsWith('intent:')) {
      final converted = _convertIntentToDeepLink(rawUrl);
      if (converted != null && converted.isNotEmpty) {
        cleanUrl = converted;
        debugPrint('[IciciWebView] Converted intent URL to: $cleanUrl');
      }
    }

    // 3. Fallback: try url_launcher directly
    try {
      final uri = Uri.parse(cleanUrl);
      try {
        final success = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (success) return true;
      } catch (e) {
        debugPrint('[IciciWebView] externalNonBrowserApplication error: $e');
      }

      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (success) return true;
    } catch (e) {
      debugPrint('[IciciWebView] url_launcher error: $e');
    }

    // 4. Browser fallback URL if embedded in intent
    if (rawUrl.contains('browser_fallback_url=')) {
      try {
        final match =
            RegExp(r'browser_fallback_url=([^;&]+)').firstMatch(rawUrl);
        if (match != null) {
          final fallbackUrl = Uri.decodeComponent(match.group(1)!);
          debugPrint('[IciciWebView] Launching fallback browser URL: $fallbackUrl');
          return await launchUrl(
            Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (_) {}
    }

    return false;
  }

  String? _convertIntentToDeepLink(String intentUrl) {
    try {
      // 1. Check for data= inside #Intent;...;end
      final dataMatch = RegExp(r'[;#]data=([^;]+)').firstMatch(intentUrl);
      if (dataMatch != null) {
        final rawData = dataMatch.group(1)!;
        final decoded = Uri.decodeComponent(rawData);
        if (decoded.startsWith('upi://') ||
            decoded.startsWith('phonepe://') ||
            decoded.startsWith('paytmmp://') ||
            decoded.startsWith('gpay://') ||
            decoded.startsWith('tez://')) {
          return decoded;
        }
      }

      // 2. Check for scheme= inside #Intent;...;end
      final schemeMatch = RegExp(r'[;#]scheme=([^;]+)').firstMatch(intentUrl);
      final scheme = schemeMatch?.group(1);

      // Extract URI part before #Intent
      final hashIndex = intentUrl.indexOf('#Intent');
      final uriPart =
          hashIndex != -1 ? intentUrl.substring(0, hashIndex) : intentUrl;

      if (scheme != null && scheme.isNotEmpty) {
        if (uriPart.startsWith('intent://')) {
          final rest = uriPart.substring('intent://'.length);
          return '$scheme://$rest';
        } else if (uriPart.startsWith('intent:')) {
          final rest = uriPart.substring('intent:'.length);
          return '$scheme:$rest';
        }
      }

      // 3. Fallback: if it contains 'pay?'
      if (intentUrl.contains('pay?')) {
        final payIndex = intentUrl.indexOf('pay?');
        final endOfParams =
            hashIndex != -1 ? hashIndex : intentUrl.length;
        final params = intentUrl.substring(payIndex, endOfParams);
        return 'upi://$params';
      }
    } catch (e) {
      debugPrint('[IciciWebView] Error converting intent URL: $e');
    }
    return null;
  }

  bool _isReturnUrl(String url) {
    try {
      final lower = url.toLowerCase();
      if (lower.contains('paymentreturn') || lower.contains('paymentcallback')) {
        return true;
      }
      final returnUri = Uri.parse(widget.returnUrl);
      final currentUri = Uri.parse(url);
      return currentUri.host.toLowerCase() == returnUri.host.toLowerCase() &&
          currentUri.path.toLowerCase() == returnUri.path.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Parse the return URL query params and derive success/failure.
  void _handleReturnUrl(String url) {
    if (_resultDispatched) return;
    try {
      final uri = Uri.parse(url);
      final q = Map<String, String>.from(uri.queryParameters);
      debugPrint('[IciciWebView] Return URL intercepted: $url');
      debugPrint('[IciciWebView] Return URL params: $q');

      String? getVal(List<String> keys) {
        for (final k in keys) {
          for (final entry in q.entries) {
            if (entry.key.toLowerCase() == k.toLowerCase() &&
                entry.value.trim().isNotEmpty) {
              return entry.value.trim();
            }
          }
        }
        return null;
      }

      final rawStatus = getVal([
        'status', 'txnStatus', 'TXN_STATUS', 'txn_status', 'Status',
        'RESPONSE_CODE', 'responseCode', 'response_code', 'respCode',
        'txnResponseCode', 'TXN_RESPONSE_CODE', 'returnCode'
      ]) ?? '';

      final upper = rawStatus.toUpperCase();

      final isExplicitFailure = upper == 'FAILED' ||
          upper == 'FAIL' ||
          upper == 'CANCELLED' ||
          upper == 'CANCELED' ||
          upper == '1' ||
          upper == '99' ||
          upper == '111' ||
          upper == '1111';

      final isExplicitSuccess = upper == 'SUCCESS' ||
          upper == 'APPROVED' ||
          upper == 'TXN_SUCCESS' ||
          upper == 'SUC' ||
          upper == '0' ||
          upper == '00' ||
          upper == '000' ||
          upper == '0000' ||
          upper == 'R1000' ||
          upper == 'P1000' ||
          upper == '200';

      if (isExplicitFailure) {
        _dispatchResult(IciciPaymentResult(
          success: false,
          message: getVal(['message', 'statusMessage', 'error', 'errorMsg']) ??
              'Payment was not completed',
          queryParams: q.isNotEmpty ? q : null,
          paymentMethod: widget.paymentMethod,
        ));
        return;
      }

      // If explicit success or return URL reached with pending/empty query:
      // Dispatch success: true so that _verifyPaymentOnReturn can conclusively verify
      // via Firestore webhook and backend statusCheck API.
      _dispatchResult(IciciPaymentResult(
        success: true,
        message: isExplicitSuccess
            ? 'Payment completed'
            : 'Payment returned from gateway, verifying...',
        queryParams: q.isNotEmpty ? q : null,
        paymentMethod: widget.paymentMethod,
      ));
    } catch (e) {
      debugPrint('[IciciWebView] Return URL parse error: $e');
      _dispatchResult(IciciPaymentResult(
        success: true,
        message: 'Payment completed at gateway, verifying...',
        paymentMethod: widget.paymentMethod,
      ));
    }
  }

  Future<void> _onWillPop() async {
    // Allow WebView internal back navigation first
    if (!kIsWeb && !_isUpiIntent && await _controller.canGoBack()) {
      _controller.goBack();
      return;
    }

    if (!mounted) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this payment? '
          'Your transaction will not be completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Continue Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      _dispatchResult(IciciPaymentResult(
        success: false,
        message: 'Payment cancelled by user',
        paymentMethod: widget.paymentMethod,
      ));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            kIsWeb
                ? 'Payment Window'
                : (_isUpiIntent ? 'UPI Payment' : 'Secure Payment'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: _onWillPop,
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1A237E),
                    ),
                  ),
                )
              : null,
        ),
        body: kIsWeb
            ? _buildWebWaitingBody()
            : (_isUpiIntent ? _buildUpiWaitingBody() : _buildWebViewBody()),
      ),
    );
  }

  Widget _buildWebViewBody() {
    return Stack(
      children: [
        // Use Hybrid Composition on Android to prevent the
        // "ID too large, must fit 32-bit integer" crash that prevents
        // TransactionCompletedScreen from being shown after payment.
        buildHybridWebView(_controller),
        // Full-page loader only during initial load
        if (_isLoading && _loadingProgress < 0.3)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1A237E)),
                SizedBox(height: 16),
                Text(
                  'Loading secure payment page…',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUpiWaitingBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            const SizedBox(height: 24),
            const Text(
              'Waiting for payment…',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete the payment in your UPI app.\n'
              'Do not close this screen.',
              style: TextStyle(color: Colors.black54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _launchUpiIntent,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Re-open UPI App'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Color(0xFF1A237E)),
                foregroundColor: const Color(0xFF1A237E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebWaitingBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            const SizedBox(height: 24),
            const Text(
              'Waiting for payment…',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete the payment in the newly opened tab or window.\n'
              'Do not close this screen. Once confirmed, you will be redirected automatically.',
              style: TextStyle(color: Colors.black54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _launchWebPaymentUrl,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Re-open Payment Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
