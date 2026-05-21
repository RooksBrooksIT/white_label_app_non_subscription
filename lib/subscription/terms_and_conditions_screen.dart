import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';
import 'package:subscription_rooks_app/subscription/welcome_screen.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final bool isFirstTimeRegistration;
  final bool isPreRegistration;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final String? planName;
  final bool? isYearly;
  final bool? isSixMonths;
  final int? price;
  final int? originalPrice;
  final String? paymentMethod;
  final String? transactionId;
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;

  const TermsAndConditionsScreen({
    super.key,
    this.isFirstTimeRegistration = true,
    this.isPreRegistration = false,
    this.onAccept,
    this.onDecline,
    this.planName,
    this.isYearly,
    this.isSixMonths,
    this.price,
    this.originalPrice,
    this.paymentMethod,
    this.transactionId,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
  });

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with SingleTickerProviderStateMixin {
  bool _agreedToTerms = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _buttonGlowAnimation;
  late Animation<Color?> _buttonColorAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _buttonGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _buttonColorAnimation =
        ColorTween(
          begin: Colors.grey.shade400,
          end: const Color(0xFF0D47A1),
        ).animate(
          CurvedAnimation(
            parent: _buttonAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant TermsAndConditionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_agreedToTerms && _hasScrolledToBottom) {
      _buttonAnimationController.forward();
    } else {
      _buttonAnimationController.reverse();
    }
  }

  Future<void> _handleAccept() async {
    if (!_agreedToTerms || !_hasScrolledToBottom) {
      _showSnackBar('Please read all terms and accept to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!widget.isPreRegistration) {
        final uid = AuthStateService.instance.currentUser?.uid;
        final tenantId = ThemeService.instance.databaseName;

        if (uid != null) {
          await FirestoreService.instance.saveTermsAndConditionsAcceptance(
            uid: uid,
            tenantId: tenantId,
            timestamp: DateTime.now(),
          );
        }
      }

      if (mounted) {
        widget.onAccept?.call();

        if (widget.isPreRegistration) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
          return;
        }

        if (widget.isFirstTimeRegistration) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => BrandingCustomizationScreen(
                planName: widget.planName,
                isYearly: widget.isYearly,
                isSixMonths: widget.isSixMonths,
                price: widget.price,
                originalPrice: widget.originalPrice,
                paymentMethod: widget.paymentMethod,
                transactionId: widget.transactionId,
                limits: widget.limits,
                geoLocation: widget.geoLocation,
                attendance: widget.attendance,
                barcode: widget.barcode,
                reportExport: widget.reportExport,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const admindashboard()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDecline() {
    widget.onDecline?.call();
    if (widget.isPreRegistration) {
      Navigator.pop(context);
    } else if (widget.isFirstTimeRegistration) {
      Navigator.pop(context);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Text('Decline Terms & Conditions'),
            ],
          ),
          content: const Text(
            'You must accept the Terms & Conditions to use this service. Are you sure you want to go back?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonEnabled =
        _agreedToTerms && _hasScrolledToBottom && !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Professional Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF0D47A1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            widget.isPreRegistration
                                ? 'Please review before creating your account'
                                : 'Please read and accept to continue',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // if (!_hasScrolledToBottom)
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 12,
                    //       vertical: 6,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: Colors.amber.shade50,
                    //       borderRadius: BorderRadius.circular(20),
                    //       border: Border.all(color: Colors.amber.shade200),
                    //     ),
                    //     child: Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //       children: [
                    //         Icon(
                    //           Icons.unfold_more,
                    //           size: 16,
                    //           color: Colors.amber.shade700,
                    //         ),
                    //         const SizedBox(width: 6),
                    //         Text(
                    //           'Scroll to end',
                    //           style: TextStyle(
                    //             fontSize: 12,
                    //             color: Colors.amber.shade700,
                    //             fontWeight: FontWeight.w500,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                  ],
                ),
              ),
            ),

            // Terms Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Scroll Progress Bar
                      Container(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: _hasScrolledToBottom
                              ? 1.0
                              : _scrollController.hasClients
                              ? _scrollController.position.pixels /
                                    _scrollController.position.maxScrollExtent
                              : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0D47A1),
                          ),
                        ),
                      ),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Last Updated Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Last Updated: December 2024',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Welcome Section
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0D47A1,
                                  ).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF0D47A1,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF0D47A1),
                                      size: 24,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Welcome to ServNex. By using this application, you agree to the following Terms and Conditions.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1A1A1A),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Terms Sections
                              _buildProfessionalSection(
                                '1. Acceptance of Terms',
                                'By accessing or using ServNex, you agree to be bound by these Terms. If you do not agree, please do not use the app.',
                                Icons.check_circle_outline,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '2. Services',
                                'ServNex provides IT-related services including service booking, tracking, and technical support. Services may change or be discontinued without notice.',
                                Icons.build_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '3. User Account',
                                'You must provide accurate details during registration. You are responsible for maintaining account confidentiality and all activities under your account.',
                                Icons.account_circle_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '4. Payments',
                                'All payments must be made through available methods in the app. Prices are displayed before payment and may include applicable taxes.',
                                Icons.payment_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '5. Subscriptions',
                                'Subscriptions renew automatically unless cancelled. Cancellation will take effect at the end of the billing period. No partial refunds will be issued.',
                                Icons.subscriptions_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '6. Cancellation & Refunds',
                                'Services can be cancelled before completion. Eligible refunds will be processed within 5–7 business days.',
                                Icons.refresh_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '7. User Conduct',
                                'You agree not to misuse the app, provide false information, or interfere with app functionality.',
                                Icons.gavel_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '8. Use License',
                                'You are granted limited permission to use the app for personal use only. You may not copy, modify, reverse engineer, or misuse any part of the service.',
                                Icons.security_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '9. Disclaimer',
                                'All services are provided "as is" without warranties of any kind.',
                                Icons.warning_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '10. Limitation of Liability',
                                'ServNex is not liable for indirect or consequential damages arising from the use of the app.',
                                Icons.balance_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '11. Privacy',
                                'Your use of ServNex is also governed by our Privacy Policy.',
                                Icons.privacy_tip_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '12. Modifications',
                                'We may update these Terms at any time. Continued use of the app indicates acceptance of the updated Terms.',
                                Icons.update_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '13. Governing Law',
                                'These Terms are governed by the laws of India.',
                                Icons.account_balance_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '14. Company Information',
                                'Business Name: ServNex\nAddress: No:17, Jawahar Street, Ramavarmapuram, Nagercoil - 629001\nEmail: support@rookstechnologies.com\nPhone: +91 7358677670',
                                Icons.business_outlined,
                              ),
                              const SizedBox(height: 20),

                              _buildProfessionalSection(
                                '15. Contact',
                                'For any questions, contact us using the details above.',
                                Icons.contact_support_outlined,
                              ),

                              const SizedBox(height: 32),

                              // Contact Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0D47A1,
                                  ).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF0D47A1,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF0D47A1,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.support_agent,
                                        color: Color(0xFF0D47A1),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Need assistance?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'support@rookstechnologies.com | +91 7358677670',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Actions with Highlight Effect
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Professional Checkbox
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _agreedToTerms = !_agreedToTerms;
                          });
                          if (_agreedToTerms && _hasScrolledToBottom) {
                            _buttonAnimationController.forward();
                          } else {
                            _buttonAnimationController.reverse();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _agreedToTerms
                                ? const Color(
                                    0xFF0D47A1,
                                  ).withValues(alpha: 0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _agreedToTerms
                                  ? const Color(0xFF0D47A1)
                                  : Colors.grey.shade300,
                              width: _agreedToTerms ? 2 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _agreedToTerms
                                      ? const Color(0xFF0D47A1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _agreedToTerms
                                        ? const Color(0xFF0D47A1)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: _agreedToTerms
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'I have read and agree to the Terms & Conditions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _agreedToTerms
                                        ? const Color(0xFF0D47A1)
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Animated Accept Button with Highlight Effect
                      AnimatedBuilder(
                        animation: _buttonAnimationController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isButtonEnabled
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0D47A1)
                                            .withValues(
                                              alpha:
                                                  0.4 *
                                                  _buttonGlowAnimation.value,
                                            ),
                                        blurRadius:
                                            20 * _buttonGlowAnimation.value,
                                        spreadRadius:
                                            5 * _buttonGlowAnimation.value,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF0D47A1)
                                            .withValues(
                                              alpha:
                                                  0.2 *
                                                  _buttonGlowAnimation.value,
                                            ),
                                        blurRadius:
                                            30 * _buttonGlowAnimation.value,
                                        spreadRadius:
                                            10 * _buttonGlowAnimation.value,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Transform.scale(
                              scale: _buttonScaleAnimation.value,
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isButtonEnabled
                                      ? _handleAccept
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isButtonEnabled
                                        ? const Color(0xFF0D47A1)
                                        : Colors.grey.shade300,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    elevation: isButtonEnabled ? 3 : 0,
                                    shadowColor: isButtonEnabled
                                        ? const Color(
                                            0xFF0D47A1,
                                          ).withValues(alpha: 0.5)
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (isButtonEnabled)
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 20,
                                              ),
                                            if (isButtonEnabled)
                                              const SizedBox(width: 12),
                                            Text(
                                              widget.isPreRegistration
                                                  ? 'ACCEPT & CREATE ACCOUNT'
                                                  : 'ACCEPT & CONTINUE',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color: isButtonEnabled
                                                    ? Colors.white
                                                    : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Decline Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleDecline,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.grey.shade400,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Helper Text
                      if (!_hasScrolledToBottom)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Please scroll to the end to enable acceptance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalSection(
    String title,
    String content,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0D47A1), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
