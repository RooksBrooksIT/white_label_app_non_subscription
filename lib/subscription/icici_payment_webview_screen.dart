import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  const IciciPaymentResult({
    required this.success,
    this.message,
    this.queryParams,
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

  /// Optional: override session timeout (default 15 min).
  final Duration sessionTimeout;

  const IciciPaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.merchantTxnNo,
    required this.returnUrl,
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
    if (!_isUpiIntent) {
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
      _dispatchResult(const IciciPaymentResult(
        success: false,
        message: 'Payment session expired. Please try again.',
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
        _dispatchResult(const IciciPaymentResult(
          success: true,
          message: 'Payment completed successfully',
        ));
      } else if (status == 'FAILED') {
        _dispatchResult(IciciPaymentResult(
          success: false,
          message: data['errorMsg'] ?? data['error'] ?? 'Payment failed',
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

  // ── UPI Intent Launcher ─────────────────────────────────────────────────────
  Future<void> _launchUpiIntent() async {
    final uri = Uri.parse(widget.paymentUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[IciciWebView] Cannot launch UPI URL');
      }
    } catch (e) {
      debugPrint('[IciciWebView] UPI launch error: $e');
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
              debugPrint('[IciciWebView] External scheme: $lower');
              try {
                final uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                debugPrint('[IciciWebView] External launch error: $e');
              }
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
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                '[IciciWebView] WebResource error ${error.errorCode}: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  bool _isExternalScheme(String lower) =>
      lower.startsWith('upi://') ||
      lower.startsWith('phonepe://') ||
      lower.startsWith('paytmmp://') ||
      lower.startsWith('gpay://') ||
      lower.startsWith('tez://') ||
      lower.startsWith('intent://') ||
      lower.startsWith('whatsapp://');

  bool _isReturnUrl(String url) {
    try {
      if (url.contains('paymentReturn')) {
        return true;
      }
      final returnUri = Uri.parse(widget.returnUrl);
      final currentUri = Uri.parse(url);
      return currentUri.host == returnUri.host &&
          currentUri.path == returnUri.path;
    } catch (_) {
      return false;
    }
  }

  /// Parse the return URL query params and derive success/failure.
  void _handleReturnUrl(String url) {
    if (_resultDispatched) return;
    try {
      final uri = Uri.parse(url);
      final q = uri.queryParameters;
      debugPrint('[IciciWebView] Return URL params: $q');

      final rawStatus = q['status'] ??
          q['txnStatus'] ??
          q['Status'] ??
          q['RESPONSE_CODE'] ??
          '';

      final isSuccess = rawStatus.toUpperCase() == 'SUCCESS' ||
          rawStatus.toUpperCase() == 'APPROVED' ||
          rawStatus.toUpperCase() == 'TXN_SUCCESS' ||
          rawStatus == '0' ||
          rawStatus == '00' ||
          rawStatus == 'P1000';

      _dispatchResult(IciciPaymentResult(
        success: isSuccess,
        message: q['message'] ??
            q['statusMessage'] ??
            (isSuccess
                ? 'Payment completed'
                : 'Payment was not completed'),
        queryParams: q.isNotEmpty ? Map<String, String>.from(q) : null,
      ));
    } catch (e) {
      debugPrint('[IciciWebView] Return URL parse error: $e');
    }
  }

  // ── Back / Cancel Guard ─────────────────────────────────────────────────────
  Future<void> _onWillPop() async {
    // Allow WebView internal back navigation first
    if (!_isUpiIntent && await _controller.canGoBack()) {
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
      _dispatchResult(const IciciPaymentResult(
        success: false,
        message: 'Payment cancelled by user',
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
            _isUpiIntent ? 'UPI Payment' : 'Secure Payment',
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
        body: _isUpiIntent ? _buildUpiWaitingBody() : _buildWebViewBody(),
      ),
    );
  }

  Widget _buildWebViewBody() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
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
}
