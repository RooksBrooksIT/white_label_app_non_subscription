import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';
import 'package:subscription_rooks_app/subscription/welcome_screen.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

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

class _TermsSection {
  final String title;
  final String content;
  final IconData icon;

  const _TermsSection(this.title, this.content, this.icon);
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with SingleTickerProviderStateMixin {
  static const String _lastUpdated = 'June 2, 2026';

  static const String _introText =
      'These Terms and Conditions govern your access to and use of the ServNex '
      'mobile application and related services operated by Rooks & Brooks '
      'Technologies Pvt. Ltd. By creating an account, subscribing to a plan, '
      'or using the Service, you agree to be bound by these Terms.';

  static const List<_TermsSection> _termsSections = [
    _TermsSection(
      '1. Definitions',
      '1.1 "Administrator" or "Admin" means an authorized user who registers an '
          'organization and manages subscription, branding, engineers, customers, '
          'and organizational settings.\n\n'
          '1.2 "Customer" means an end user (e.g., AMC or service customer) who '
          'accesses the Service under an organization\'s tenant, typically via '
          'referral code or invitation.\n\n'
          '1.3 "Engineer" means a field or service technician assigned by an '
          'Administrator to perform service tasks, attendance, location updates, '
          'and related operations.\n\n'
          '1.4 "Organization" or "Tenant" means a separate business entity whose '
          'data, branding, and users are isolated within the multi-tenant platform.\n\n'
          '1.5 "Subscription" means a paid or trial plan (e.g., Silver, Gold, '
          'Platinum, or promotional trial) that defines features, usage limits, '
          'and billing cycle.\n\n'
          '1.6 "You" or "User" means any person or entity using the Service in any role.',
      Icons.menu_book_outlined,
    ),
    _TermsSection(
      '2. Acceptance and Eligibility',
      '2.1 You must be at least 18 years of age and have the legal capacity to '
          'enter into a binding agreement, or use the Service only with consent '
          'and supervision of a parent or legal guardian where permitted by law.\n\n'
          '2.2 If you register on behalf of an organization, you represent that '
          'you have authority to bind that organization to these Terms.\n\n'
          '2.3 We may update these Terms from time to time. Material changes will '
          'be indicated by updating the "Last Updated" date. Continued use after '
          'changes constitutes acceptance. For material changes, we may require '
          'renewed acceptance within the app.',
      Icons.check_circle_outline,
    ),
    _TermsSection(
      '3. Description of the Service',
      '3.1 ServNex is a white-label service management platform that enables '
          'organizations to:\n\n'
          '(a) Manage service operations, customers, engineers, and workflows;\n'
          '(b) Customize branding (app name, colors, logo, typography);\n'
          '(c) Subscribe to tiered plans with feature limits (customers, engineers, '
          'storage, geo-location, attendance, barcode, report export, etc.);\n'
          '(d) Process subscription payments through integrated payment gateways;\n'
          '(e) Generate invoices, receipts, and operational reports;\n'
          '(f) Use optional features such as attendance tracking, geo-location, '
          'barcode scanning, notifications, and document uploads.\n\n'
          '3.2 Feature availability depends on your Subscription plan and active '
          'status. We may modify, add, or discontinue features with reasonable notice '
          'where practicable.',
      Icons.apps_outlined,
    ),
    _TermsSection(
      '4. Account Registration and Security',
      '4.1 You agree to provide accurate, current, and complete registration '
          'information (including organization name, contact details, GST number '
          'if applicable, and role-specific data).\n\n'
          '4.2 You are responsible for maintaining the confidentiality of your login '
          'credentials and for all activity under your account.\n\n'
          '4.3 You must notify us promptly at support@rookstechnologies.com of any '
          'unauthorized access or suspected breach.\n\n'
          '4.4 We may suspend or terminate accounts that violate these Terms or pose '
          'security or legal risk.',
      Icons.account_circle_outlined,
    ),
    _TermsSection(
      '5. Subscriptions, Billing, and Payments',
      '5.1 Subscription plans may be offered on monthly, six-month, yearly, or trial '
          'bases as displayed in the app at the time of purchase.\n\n'
          '5.2 Prices, discounts, and plan limits are shown before checkout. '
          'Applicable taxes may apply as required by law.\n\n'
          '5.3 Payments are processed through third-party payment partners (e.g., ICICI '
          'and related hosted payment flows). We do not store full card or banking '
          'credentials on our servers. Payment confirmation is subject to verification '
          'by the payment gateway and our backend systems.\n\n'
          '5.4 Subscriptions renew automatically for the selected billing period unless '
          'cancelled before the renewal date in accordance with app or support instructions.\n\n'
          '5.5 Failed, pending, or disputed payments may result in limited access, '
          'suspension of features, or deactivation until resolved.\n\n'
          '5.6 Refund requests are handled per our refund policy and applicable law. '
          'Contact support@rookstechnologies.com for billing disputes.',
      Icons.payment_outlined,
    ),
    _TermsSection(
      '6. Free Trial',
      '6.1 Free trials, if offered, are limited in duration and features as stated '
          'in the app (e.g., 7-day trial).\n\n'
          '6.2 One trial per organization or user may apply unless we expressly allow otherwise.\n\n'
          '6.3 At trial end, continued use may require selecting a paid Subscription. '
          'Access may be restricted if no active Subscription exists.',
      Icons.timer_outlined,
    ),
    _TermsSection(
      '7. White-Label Branding and Organization Data',
      '7.1 Administrators may upload logos, set colors, fonts, and app display names. '
          'You represent that you have rights to all branding materials you upload.\n\n'
          '7.2 You grant us a license to host, display, and process branding assets '
          'solely to provide the Service to your Organization.\n\n'
          '7.3 Each Tenant\'s operational data is logically separated. You remain '
          'responsible for data you and your users enter into your Tenant.',
      Icons.palette_outlined,
    ),
    _TermsSection(
      '8. Acceptable Use',
      'You agree NOT to:\n\n'
          '8.1 Use the Service for unlawful, fraudulent, or harmful purposes;\n'
          '8.2 Upload malware, attempt unauthorized access, reverse engineer, or disrupt '
          'the Service or infrastructure;\n'
          '8.3 Impersonate others or misrepresent your affiliation;\n'
          '8.4 Harvest data from the Service without authorization;\n'
          '8.5 Exceed plan limits through circumvention or abuse;\n'
          '8.6 Use location, attendance, or customer data in violation of applicable '
          'privacy, employment, or consumer laws;\n'
          '8.7 Share referral codes or credentials in a manner that compromises security.',
      Icons.gavel_outlined,
    ),
    _TermsSection(
      '9. User-Generated and Operational Data',
      '9.1 You retain ownership of content and data you submit (customer records, '
          'service tickets, photos, documents, attendance logs, etc.).\n\n'
          '9.2 You grant us a worldwide, non-exclusive license to use, store, process, '
          'transmit, and display such data as necessary to operate, secure, and improve '
          'the Service, including backups and support.\n\n'
          '9.3 You are responsible for obtaining necessary consents from employees, '
          'engineers, and customers whose personal data you process through the Service.',
      Icons.storage_outlined,
    ),
    _TermsSection(
      '10. Intellectual Property',
      '10.1 The Service, including software, design, trademarks, and documentation '
          '(excluding your content and branding), is owned by the Company or its licensors.\n\n'
          '10.2 No rights are granted except as expressly stated in these Terms.',
      Icons.copyright_outlined,
    ),
    _TermsSection(
      '11. Third-Party Services',
      'The Service integrates with third parties including but not limited to:\n\n'
          '• Google Firebase (authentication, database, storage, messaging)\n'
          '• Payment gateways (e.g., ICICI)\n'
          '• Mapping and location providers\n'
          '• Email and notification services\n\n'
          'Your use of those services may be subject to their separate terms and policies. '
          'We are not responsible for third-party outages or acts.',
      Icons.link_outlined,
    ),
    _TermsSection(
      '12. Disclaimers',
      '12.1 THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" TO THE MAXIMUM EXTENT '
          'PERMITTED BY LAW.\n\n'
          '12.2 WE DO NOT WARRANT UNINTERRUPTED, ERROR-FREE, OR SECURE OPERATION.\n\n'
          '12.3 FIELD SERVICE, LOCATION, AND ATTENDANCE FEATURES ARE TOOLS FOR '
          'OPERATIONAL USE; YOU ARE RESPONSIBLE FOR HOW YOU INTERPRET AND ACT ON SUCH DATA.',
      Icons.warning_amber_outlined,
    ),
    _TermsSection(
      '13. Limitation of Liability',
      '13.1 TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR INDIRECT, '
          'INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR FOR LOSS OF PROFITS, '
          'DATA, OR GOODWILL.\n\n'
          '13.2 OUR TOTAL LIABILITY FOR CLAIMS ARISING FROM OR RELATED TO THE SERVICE '
          'SHALL NOT EXCEED THE AMOUNT YOU PAID US FOR THE SUBSCRIPTION IN THE TWELVE (12) '
          'MONTHS PRECEDING THE CLAIM, OR INR 5,000, WHICHEVER IS GREATER, UNLESS MANDATORY '
          'LAW REQUIRES OTHERWISE.',
      Icons.balance_outlined,
    ),
    _TermsSection(
      '14. Indemnification',
      'You agree to indemnify and hold harmless the Company, its officers, directors, '
          'employees, and agents from claims arising from your use of the Service, your '
          'content, your violation of these Terms, or your violation of any law or '
          'third-party rights.',
      Icons.shield_outlined,
    ),
    _TermsSection(
      '15. Suspension and Termination',
      '15.1 We may suspend or terminate access for non-payment, breach of Terms, '
          'legal requirements, or security reasons.\n\n'
          '15.2 You may stop using the Service at any time. Subscription cancellation '
          'does not automatically entitle you to refunds for unused periods unless required '
          'by law or our refund policy.\n\n'
          '15.3 Upon termination, access to Tenant data may be restricted. Export any '
          'critical data before cancellation where the app provides export features.',
      Icons.block_outlined,
    ),
    _TermsSection(
      '16. Governing Law and Disputes',
      '16.1 These Terms are governed by the laws of India, without regard to conflict '
          'of law principles.\n\n'
          '16.2 Courts at competent courts in India shall have exclusive jurisdiction, '
          'subject to mandatory consumer protections.\n\n'
          '16.3 You agree to attempt good-faith resolution by contacting '
          'support@rookstechnologies.com before formal proceedings where reasonable.',
      Icons.policy_outlined,
    ),
    _TermsSection(
      '17. Contact Information',
      'Rooks & Brooks Technologies Pvt. Ltd.\n'
          'ServNex Platform Support\n\n'
          'Email: support@rookstechnologies.com\n'
          'Phone: +91 7358677670\n'
          'Website: www.rookstechnologies.com\n\n'
          'For privacy-related requests, see our Privacy Policy or email the address above '
          'with subject line "Privacy Request."',
      Icons.contact_mail_outlined,
    ),
    _TermsSection(
      '18. Miscellaneous',
      '18.1 If any provision is held invalid, the remainder remains in effect.\n\n'
          '18.2 Failure to enforce a right is not a waiver.\n\n'
          '18.3 These Terms constitute the entire agreement regarding the Service unless '
          'supplemented by a separate written agreement signed by the Company.\n\n'
          '18.4 White-labeled app names displayed to end users are configured by each '
          'Organization and do not change the legal relationship between you and the '
          'Company for platform services.',
      Icons.more_horiz,
    ),
  ];

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
  child: ResponsiveWrapper(
    maxWidth: kMaxContentWidth,
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
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      color: const Color(0xFF1A1A1A),
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            widget.isPreRegistration
                                ? 'Review before creating account'
                                : 'Accept to continue',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      SizedBox(
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
                                  'Last Updated: $_lastUpdated',
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF0D47A1),
                                      size: 24,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _introText,
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

                              // Full terms from legal/terms_and_conditions.txt
                              ..._termsSections.map(
                                (section) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _buildProfessionalSection(
                                    section.title,
                                    section.content,
                                    section.icon,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _isLoading
                                        ? 'Processing...'
                                        : 'Accept & Continue',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
    ),
    );
  }

  Widget _buildProfessionalSection(
    String title,
    String content,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0D47A1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
