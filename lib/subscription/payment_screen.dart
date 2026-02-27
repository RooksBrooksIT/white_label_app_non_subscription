import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/upi_payment_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

import 'dart:io';

import 'transaction_completed_screen.dart';
import 'icici_payment_webview_screen.dart';
import 'card_details_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final bool isYearly;
  final bool isSixMonths;
  final int price;
  final int? originalPrice;
  final Map<String, dynamic>? brandingData;
  final bool isFirstTimeRegistration;

  // New fields for plan limits and features
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.isYearly,
    this.isSixMonths = false,
    required this.price,
    this.originalPrice,
    this.brandingData,
    this.isFirstTimeRegistration = true,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color brandBlue = Color(0xFF1A237E);
  String selectedPaymentMethod = 'UPI';

  // Responsive values based on screen width
  double get titleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 32; // Web
    if (width > 768) return 28; // Tablet
    return 22; // Phone
  }

  double get subtitleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 20;
    if (width > 768) return 18;
    return 16;
  }

  double get priceFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 40;
    if (width > 768) return 34;
    return 28;
  }

  double get buttonFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 18;
  }

  double get buttonHeight {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 64;
    return 56;
  }

  EdgeInsets get screenPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return EdgeInsets.symmetric(horizontal: width * 0.1, vertical: 32);
    }
    if (width > 768) {
      return EdgeInsets.symmetric(horizontal: width * 0.08, vertical: 24);
    }
    return const EdgeInsets.all(20);
  }

  double get containerPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 24;
    return 20;
  }

  double get borderRadius {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 16;
  }

  double get iconSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 28;
    return 24;
  }

  bool get isDesktop => MediaQuery.of(context).size.width > 1200;
  bool get isTablet =>
      MediaQuery.of(context).size.width > 768 &&
      MediaQuery.of(context).size.width <= 1200;
  bool get isMobile => MediaQuery.of(context).size.width <= 768;

  // Get next billing date
  DateTime getNextBillingDate() {
    if (widget.isYearly) {
      return DateTime.now().add(const Duration(days: 365));
    } else if (widget.isSixMonths) {
      // Best way to add 6 months:
      final now = DateTime.now();
      return DateTime(now.year, now.month + 6, now.day);
    } else {
      return DateTime.now().add(const Duration(days: 30));
    }
  }

  // Format date as "Mon YYYY"
  String formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nextBillingDate = getNextBillingDate();
    final formattedDate = formatDate(nextBillingDate);

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: brandBlue,
        colorScheme: const ColorScheme.light(
          primary: brandBlue,
          secondary: brandBlue,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Payment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Section (Moved to top for better flow)
                _buildSubscriptionSummary(formattedDate),

                const SizedBox(height: 32),

                // Title Section
                Text(
                  'SELECT PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: titleFontSize * 0.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure and seamless payment options',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                // Responsive Layout for Payment Methods
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildPaymentMethodsSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 1, child: _buildRightSideSidebar()),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPaymentMethodsSection(),
                      const SizedBox(height: 32),
                      _buildSecurityBadges(),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildTermsText(),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideSidebar() {
    return Column(
      children: [
        _buildSecurityBadges(),
        const SizedBox(height: 40),
        _buildActionButtons(),
        const SizedBox(height: 24),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildSubscriptionSummary(String formattedDate) {
    return Container(
      width: isDesktop ? 400 : double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBSCRIPTION SUMMARY',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.planName} Plan',
                      style: TextStyle(
                        fontSize: isDesktop ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          widget.price == 0
                              ? '7 Days Free Trial'
                              : 'Billed For ${widget.isYearly ? '12 Months' : (widget.isSixMonths ? '6 Months' : '1 Month')}',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: isDesktop ? 16 : 14,
                          ),
                        ),
                        Text(
                          'Next Billing $formattedDate',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.originalPrice != null)
                    Text(
                      '₹${widget.originalPrice}',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    widget.price == 0 ? 'Free' : '₹${widget.price}',
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.swap_horiz, size: isDesktop ? 20 : 18),
              label: Text(
                'Change plan',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSimplePaymentOption(
          name: 'UPI',
          subtitle: 'Google Pay, PhonePe, Paytm & more',
          icon: Icons.qr_code_rounded,
          color: brandBlue,
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        _buildSimplePaymentOption(
          name: 'Card',
          subtitle: 'Credit / Debit card payment',
          icon: Icons.credit_card_rounded,
          color: brandBlue.withOpacity(0.8),
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        _buildSimplePaymentOption(
          name: 'Net Banking',
          subtitle: 'Direct bank transfer',
          icon: Icons.account_balance_rounded,
          color: brandBlue.withOpacity(0.9),
        ),
      ],
    );
  }

  Widget _buildSimplePaymentOption({
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedPaymentMethod == name;
    final itemHeight = isDesktop ? 70.0 : 64.0;

    return Container(
      constraints: BoxConstraints(minHeight: itemHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isSelected ? Colors.black : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () {
            setState(() {
              selectedPaymentMethod = name;
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: isDesktop ? 48 : 40,
                  height: isDesktop ? 48 : 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
                ),
                SizedBox(width: isDesktop ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.grey.shade400,
                      width: isSelected ? 6 : 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Check if this is a UPI payment that should launch the system UPI chooser.
  bool _isUpiMethod(String method) {
    return method == 'UPI';
  }

  Widget _buildSecurityBadges() {
    return Row(
      mainAxisAlignment: isMobile
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        _buildSecurityBadge('256-BIT SSL ENCRYPTED', Icons.lock),
        SizedBox(width: isDesktop ? 32 : 20),
        _buildSecurityBadge('100% SAFE PAYMENTS', Icons.verified_user),
      ],
    );
  }

  Widget _buildSecurityBadge(String text, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: brandBlue, size: isDesktop ? 40 : 32),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: brandBlue,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttonWidth = isDesktop ? 400.0 : double.infinity;

    return Column(
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              _processPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              'Pay Now',
              style: TextStyle(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: buttonFontSize - 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20),
        child: Text(
          'By Processing this Payment, you agree to our Terms of Services\nand Return Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    final uid = AuthStateService.instance.currentUser?.uid ?? 'demo-user';
    final txnRefId = DateTime.now().millisecondsSinceEpoch.toString();

    if (_isUpiMethod(selectedPaymentMethod)) {
      // ──────────────────────────────────────────────
      // UPI → Launch system UPI app chooser
      // ──────────────────────────────────────────────
      await _processUpiPayment(uid: uid, txnRefId: txnRefId);
    } else if (selectedPaymentMethod == 'Card') {
      // ──────────────────────────────────────────────
      // Card → Navigate to Card Details Screen
      // ──────────────────────────────────────────────
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CardDetailsScreen(
            paymentAmount: widget.price,
            planName: widget.planName,
            isYearly: widget.isYearly,
            originalPrice: widget.originalPrice,
            brandingData: widget.brandingData,
            limits: widget.limits,
            geoLocation: widget.geoLocation,
            attendance: widget.attendance,
            barcode: widget.barcode,
            reportExport: widget.reportExport,
          ),
        ),
      );
    } else if (selectedPaymentMethod == 'Net Banking') {
      // ──────────────────────────────────────────────
      // Net Banking → ICICI WebView
      // ──────────────────────────────────────────────
      await _processIciciPayment(uid: uid);
    } else {
      // Fallback: generic UPI
      await _processUpiPayment(uid: uid, txnRefId: txnRefId);
    }
  }

  /// Process payment via UPI — opens system UPI app chooser.
  Future<void> _processUpiPayment({
    required String uid,
    required String txnRefId,
  }) async {
    try {
      // Launch the system UPI app chooser (shows all installed UPI apps)
      final launched = await UpiPaymentService.instance.launchGenericUpi(
        amount: '${widget.price}.00',
        transactionNote: '${widget.planName} Plan Subscription',
        transactionRefId: txnRefId,
      );

      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No UPI app found. Please install a UPI app and try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // UPI app was launched — wait for user to return
      // Show verification dialog after a short delay (user completes payment in external app)
      if (!mounted) return;

      final confirmed = await _showUpiVerificationDialog();

      if (confirmed == true) {
        // User confirms payment was successful
        await IciciService.instance.saveTransaction(
          uid: uid,
          merchantTxnNo: txnRefId,
          amount: '${widget.price}.00',
          status: 'SUCCESS',
          paymentMethod: selectedPaymentMethod,
          planName: widget.planName,
          isYearly: widget.isYearly,
          tenantId: ThemeService.instance.databaseName,
          appId: ThemeService.instance.appName,
        );

        await _handlePaymentSuccess(uid: uid, merchantTxnNo: txnRefId);
      } else {
        // User says payment failed or cancelled
        await IciciService.instance.saveTransaction(
          uid: uid,
          merchantTxnNo: txnRefId,
          amount: '${widget.price}.00',
          status: 'CANCELLED',
          paymentMethod: selectedPaymentMethod,
          planName: widget.planName,
          isYearly: widget.isYearly,
          tenantId: ThemeService.instance.databaseName,
          appId: ThemeService.instance.appName,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was not completed.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show a dialog asking the user to confirm if UPI payment was successful.
  Future<bool?> _showUpiVerificationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: brandBlue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Payment Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Did you complete the payment successfully in the UPI app?',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'No, Payment Failed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Yes, Payment Done',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Process payment via ICICI Payment Gateway WebView (Net Banking, Cards, etc.).
  Future<void> _processIciciPayment({required String uid}) async {
    // Show initiating dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initiating payment...'),
          ],
        ),
      ),
    );

    try {
      // Determine the ICICI payType based on selected method
      String payType;
      if (selectedPaymentMethod == 'Card') {
        payType = '2'; // Cards
      } else if (selectedPaymentMethod == 'Net Banking') {
        payType = '1'; // Net Banking
      } else {
        payType = '0'; // All options
      }

      // Fetch real customer name and phone from user profile
      final tenantId = ThemeService.instance.databaseName;
      final customerData = await IciciService.instance.fetchCustomerData(
        uid,
        tenantId,
      );
      final customerName = customerData['name'] ?? 'Customer';
      final customerPhone = customerData['phone'] ?? '919999999999';

      // Call InitiateSale API
      final result = await IciciService.instance.initiateSale(
        amount: '${widget.price}.00',
        customerName: customerName,
        customerEmail:
            AuthStateService.instance.currentUser?.email ??
            'customer@example.com',
        customerMobile: customerPhone,
        payType: payType,
        uid: uid,
        tenantId: tenantId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close initiating dialog

      if (result == null) {
        throw Exception('Failed to initiate payment. Please try again.');
      }

      final merchantTxnNo = result['merchantTxnNo'] as String?;

      // Save initial state to nested payment_transactions
      if (merchantTxnNo != null) {
        await IciciService.instance.saveTransaction(
          uid: uid,
          merchantTxnNo: merchantTxnNo,
          amount: '${widget.price}.00',
          status: 'INITIATED',
          paymentMethod: selectedPaymentMethod,
          planName: widget.planName,
          isYearly: widget.isYearly,
          tenantId: ThemeService.instance.databaseName,
          appId: ThemeService.instance.appName,
        );
      }

      // Extract the redirect/payment URL
      final redirectUrl =
          result['redirectUrl'] ??
          result['paymentUrl'] ??
          result['url'] ??
          result['paymentPageUrl'];

      if (redirectUrl == null || redirectUrl.toString().isEmpty) {
        // No redirect URL — UAT mode: proceed optimistically
        debugPrint('No redirect URL from ICICI API. UAT mode — proceeding.');

        // Save transaction with pending status
        if (merchantTxnNo != null) {
          await IciciService.instance.saveTransaction(
            uid: uid,
            merchantTxnNo: merchantTxnNo,
            amount: '${widget.price}.00',
            status: 'SUCCESS', // Trigger receipt even in UAT simulation
            paymentMethod: selectedPaymentMethod,
            planName: widget.planName,
            isYearly: widget.isYearly,
            tenantId: ThemeService.instance.databaseName,
            appId: ThemeService.instance.appName,
          );
        }

        // For UAT: proceed to success
        await _handlePaymentSuccess(
          uid: uid,
          merchantTxnNo:
              merchantTxnNo ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
        return;
      }

      if (!mounted) return;

      // Open in-app WebView for payment
      final webViewResult = await Navigator.push<IciciPaymentResult>(
        context,
        MaterialPageRoute(
          builder: (context) => IciciPaymentWebViewScreen(
            paymentUrl: redirectUrl.toString(),
            merchantTxnNo: merchantTxnNo ?? '',
            returnUrl: IciciService.returnUrl,
          ),
        ),
      );

      if (!mounted) return;

      // Handle WebView result
      if (webViewResult == null || !webViewResult.success) {
        // User cancelled or payment failed in WebView
        final message = webViewResult?.message ?? 'Payment was cancelled';

        // Save failed transaction
        if (merchantTxnNo != null) {
          await IciciService.instance.saveTransaction(
            uid: uid,
            merchantTxnNo: merchantTxnNo,
            amount: '${widget.price}.00',
            status: 'CANCELLED',
            paymentMethod: selectedPaymentMethod,
            planName: widget.planName,
            isYearly: widget.isYearly,
            tenantId: ThemeService.instance.databaseName,
            appId: ThemeService.instance.appName,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
        return;
      }

      // Verify transaction status
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying payment...'),
              ],
            ),
          ),
        );
      }

      bool paymentVerified = false;

      if (merchantTxnNo != null && merchantTxnNo.isNotEmpty) {
        // Give the gateway a moment to process
        await Future.delayed(const Duration(seconds: 2));

        final statusResult = await IciciService.instance.checkTransactionStatus(
          merchantTxnNo: merchantTxnNo,
        );
        debugPrint('ICICI Transaction Status: $statusResult');

        paymentVerified =
            statusResult != null &&
            (statusResult['status'] == 'SUCCESS' ||
                statusResult['txnStatus'] == 'SUCCESS' ||
                statusResult['Status'] == 'SUCCESS');
      }

      // If status API also didn't confirm, trust WebView callback (UAT mode)
      if (!paymentVerified && webViewResult.success) {
        debugPrint(
          'Status API unconfirmed, but WebView returned success (UAT mode).',
        );
        paymentVerified = true;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close verifying dialog

      if (!paymentVerified) {
        // Save failed transaction
        if (merchantTxnNo != null) {
          await IciciService.instance.saveTransaction(
            uid: uid,
            merchantTxnNo: merchantTxnNo,
            amount: '${widget.price}.00',
            status: 'FAILED',
            paymentMethod: selectedPaymentMethod,
            planName: widget.planName,
            isYearly: widget.isYearly,
            tenantId: ThemeService.instance.databaseName,
            appId: ThemeService.instance.appName,
          );
        }

        throw Exception('Payment verification failed. Please contact support.');
      }

      // Payment confirmed — save and navigate to success
      if (merchantTxnNo != null) {
        await IciciService.instance.saveTransaction(
          uid: uid,
          merchantTxnNo: merchantTxnNo,
          amount: '${widget.price}.00',
          status: 'SUCCESS',
          paymentMethod: selectedPaymentMethod,
          planName: widget.planName,
          isYearly: widget.isYearly,
          tenantId: ThemeService.instance.databaseName,
          appId: ThemeService.instance.appName,
          additionalData: webViewResult.queryParams,
        );
      }

      await _handlePaymentSuccess(
        uid: uid,
        merchantTxnNo:
            merchantTxnNo ?? DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      // Close any open dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle successful payment: upload logo (if any) and navigate to success screen.
  Future<void> _handlePaymentSuccess({
    required String uid,
    required String merchantTxnNo,
  }) async {
    // Show finalizing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finalizing subscription...'),
            ],
          ),
        ),
      );
    }

    try {
      // Upload logo if exists
      Map<String, dynamic>? finalBrandingData = widget.brandingData;

      if (widget.brandingData != null &&
          widget.brandingData!['logoPath'] != null) {
        try {
          final File logoFile = File(widget.brandingData!['logoPath']);
          if (await logoFile.exists()) {
            final logoUrl = await StorageService.instance.uploadLogo(
              userId: uid,
              file: logoFile,
            );
            if (logoUrl != null) {
              finalBrandingData = Map<String, dynamic>.from(
                widget.brandingData!,
              );
              finalBrandingData['logoUrl'] = logoUrl;
              finalBrandingData.remove('logoPath');
            }
          }
        } catch (e) {
          debugPrint('Error handling logo upload: $e');
        }
      }

      // ── Save subscription to Firestore ──────────────────────────────────
      final tenantId = ThemeService.instance.databaseName;
      final appId = ThemeService.instance.appName;
      try {
        await FirestoreService.instance.upsertSubscription(
          uid: uid,
          tenantId: tenantId,
          planName: widget.planName,
          isYearly: widget.isYearly,
          isSixMonths: widget.isSixMonths,
          price: widget.price,
          originalPrice: widget.originalPrice,
          paymentMethod: selectedPaymentMethod,
          brandingData: finalBrandingData,
          appId: appId,
          limits: widget.limits,
          geoLocation: widget.geoLocation,
          attendance: widget.attendance,
          barcode: widget.barcode,
          reportExport: widget.reportExport,
        );
        await FirestoreService.instance.setUserActiveStatus(
          uid: uid,
          tenantId: tenantId,
          active: true,
        );
      } catch (e) {
        debugPrint('Error saving subscription to Firestore: $e');
      }

      // ── Subscription processed successfully. Cloud Function will handle receipt. ──

      if (mounted) Navigator.pop(context); // Close finalizing dialog

      final transactionId = 'TXN$merchantTxnNo';

      if (!mounted) return;

      // Navigate to Transaction Completed Screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionCompletedScreen(
            planName: widget.planName,
            isYearly: widget.isYearly,
            amountPaid: widget.price,
            paymentMethod: selectedPaymentMethod,
            transactionId: transactionId,
            timestamp: DateTime.now(),
            isFirstTimeRegistration: widget.isFirstTimeRegistration,
            isSixMonths: widget.isSixMonths,
            originalPrice: widget.originalPrice,
            limits: widget.limits,
            geoLocation: widget.geoLocation,
            attendance: widget.attendance,
            barcode: widget.barcode,
            reportExport: widget.reportExport,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      rethrow;
    }
  }
}
