import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_screen.dart';
import 'branding_customization_screen.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

enum BillingDuration { freeTrial, monthly, sixMonths, yearly }

class SubscriptionPlansScreen extends StatefulWidget {
  /// Optionally pass the admin's current plan name to highlight it on the screen.
  final String? currentPlanName;

  /// When true, hides the Free Trial tab/banner.
  final bool hideTrial;

  /// Remaining days on the active plan.
  final int? remainingDays;

  /// Billing cycle of the active plan e.g. 'Monthly', 'Yearly', '6 Months'.
  final String? billingCycle;

  /// User data for a new user who hasn't registered yet.
  final Map<String, dynamic>? pendingUserData;

  const SubscriptionPlansScreen({
    super.key,
    this.currentPlanName,
    this.hideTrial = false,
    this.remainingDays,
    this.billingCycle,
    this.pendingUserData,
  });

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen>
    with SingleTickerProviderStateMixin {
  BillingDuration _billingDuration = BillingDuration.monthly;
  int _selectedPlanIndex = 1; // Default: Gold (Index 1)
  bool _hasNavigated = false;

  String? _fetchedPlanName;
  int? _fetchedRemainingDays;
  String? _fetchedBillingCycle;
  Map<String, dynamic>? _fetchedLimits;
  bool _isLoadingSubscription = true;

  // Page controller for mobile swipe view
  late PageController _pageController;

  static const String _businessPhone = '+91 73586 77670';
  static const String _businessPhoneClean = '+917358677670';
  static const String _businessEmail = 'support@rookstechnologies.com';

  // Plan data for Paid tiers & Enterprise
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Silver',
      'badge': 'Starter',
      'tagline': 'Essential tools for small teams & freelancers',
      'monthlyPrice': 99,
      'monthlyOriginalPrice': 149,
      'sixMonthPrice': 594, // 99 * 6
      'sixMonthOriginalPrice': 894,
      'yearlyPrice': 999, // ~83/mo (save 16%)
      'yearlyOriginalPrice': 1788,
      'isEnterprise': false,
      'isPopular': false,
      'limits': {
        'maxCustomers': 20,
        'maxEngineers': 5,
        'maxPhotosPerCustomer': 10,
        'maxPdfUploadsPerCustomer': 5,
        'maxStorageGB': 1,
      },
      'features': [
        'Up to 20 Customers',
        'Up to 5 Service Engineers',
        '1 GB High-Speed Cloud Storage',
        'Standard Email & Web Support',
        'Basic Dashboard & Statistics',
        'Customer Service History Log',
      ],
      'geoLocation': false,
      'attendance': false,
      'barcode': false,
      'reportExport': false,
      'accentColor': const Color(0xFF475569),
      'lightColor': const Color(0xFFF1F5F9),
    },
    {
      'name': 'Gold',
      'badge': '★ Most Popular',
      'tagline': 'Ideal for growing teams needing live tracking',
      'monthlyPrice': 199,
      'monthlyOriginalPrice': 299,
      'sixMonthPrice': 1194, // 199 * 6
      'sixMonthOriginalPrice': 1794,
      'yearlyPrice': 1990, // ~165/mo (save 17%)
      'yearlyOriginalPrice': 3588,
      'isEnterprise': false,
      'isPopular': true,
      'limits': {
        'maxCustomers': 50,
        'maxEngineers': 10,
        'maxPhotosPerCustomer': 30,
        'maxPdfUploadsPerCustomer': 15,
        'maxStorageGB': 5,
      },
      'features': [
        'Up to 50 Customers',
        'Up to 10 Service Engineers',
        '5 GB Cloud Storage & Backups',
        'Geo-Location Tracking Enabled',
        'Automated PDF Report Exports',
        'Priority Web & Email Support',
        'Smart Engineer Auto-Assignment',
      ],
      'geoLocation': true,
      'attendance': false,
      'barcode': false,
      'reportExport': true,
      'accentColor': const Color(0xFFD97706),
      'lightColor': const Color(0xFFFEF3C7),
    },
    {
      'name': 'Platinum',
      'badge': 'Pro Power',
      'tagline': 'Complete automated suite for scaling enterprises',
      'monthlyPrice': 299,
      'monthlyOriginalPrice': 449,
      'sixMonthPrice': 1794, // 299 * 6
      'sixMonthOriginalPrice': 2694,
      'yearlyPrice': 2990, // ~249/mo (save 17%)
      'yearlyOriginalPrice': 5388,
      'isEnterprise': false,
      'isPopular': false,
      'limits': {
        'maxCustomers': 999,
        'maxEngineers': 999,
        'maxPhotosPerCustomer': 999,
        'maxPdfUploadsPerCustomer': 999,
        'maxStorageGB': 100,
      },
      'features': [
        'Unlimited Customers & Contacts',
        'Unlimited Service Engineers',
        '100 GB Cloud Storage',
        'Real-Time GPS Tracking & Routes',
        'Full Geofenced Attendance System',
        'Barcode & QR Scanner Asset Tracking',
        'Unlimited Report & Data Exports',
        '24/7 Dedicated Priority Support',
      ],
      'geoLocation': true,
      'attendance': true,
      'barcode': true,
      'reportExport': true,
      'accentColor': const Color(0xFF4F46E5),
      'lightColor': const Color(0xFFEEF2FF),
    },
    {
      'name': 'Enterprise',
      'badge': 'Custom Plan',
      'tagline': 'Dedicated infrastructure & bespoke integrations',
      'monthlyPrice': 0,
      'monthlyOriginalPrice': 0,
      'sixMonthPrice': 0,
      'sixMonthOriginalPrice': 0,
      'yearlyPrice': 0,
      'yearlyOriginalPrice': 0,
      'isEnterprise': true,
      'isPopular': false,
      'limits': {
        'maxCustomers': -1,
        'maxEngineers': -1,
        'maxPhotosPerCustomer': -1,
        'maxPdfUploadsPerCustomer': -1,
        'maxStorageGB': -1,
      },
      'features': [
        'Everything in Platinum Plan',
        'Custom User & Storage Quotas',
        'Dedicated Account Manager',
        'Custom ERP & API Integrations',
        'White-Label Custom Domain Setup',
        '99.99% Uptime SLA Guarantee',
        'Personalized Staff Onboarding & Training',
        'Direct Phone & WhatsApp Hotline',
      ],
      'geoLocation': true,
      'attendance': true,
      'barcode': true,
      'reportExport': true,
      'accentColor': const Color(0xFF0284C7),
      'lightColor': const Color(0xFFE0F2FE),
    },
  ];

  // Data for Trial tier
  final Map<String, dynamic> trialPlan = {
    'name': '7-Day Free Trial',
    'badge': 'Free Trial',
    'price': 0,
    'originalPrice': 0,
    'subtitle': 'Full access to premium features for 7 days',
    'limits': {
      'maxCustomers': 10,
      'maxEngineers': 3,
      'maxPhotosPerCustomer': 10,
      'maxPdfUploadsPerCustomer': 5,
      'maxStorageGB': 2,
    },
    'features': [
      'Full access to Gold & Platinum features',
      'Experience Geo-Location & Barcode Scanner',
      'Test Attendance System & Reports',
      'No credit card required',
      'Automatic expiration after 7 days',
    ],
    'geoLocation': true,
    'attendance': true,
    'barcode': true,
    'reportExport': true,
    'color': const Color(0xFFE3F2FD),
  };

  StreamSubscription<Map<String, dynamic>?>? _subscriptionListener;

  String get _consistentAppId => ThemeService.instance.appName;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: _selectedPlanIndex, viewportFraction: 0.88);

    if (widget.currentPlanName != null) {
      _fetchedPlanName = widget.currentPlanName;
      _fetchedRemainingDays = widget.remainingDays;
      _fetchedBillingCycle = widget.billingCycle;
      final idx = plans.indexWhere(
        (p) =>
            p['name'].toString().toLowerCase() ==
            widget.currentPlanName!.toString().toLowerCase(),
      );
      if (idx != -1) {
        _selectedPlanIndex = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(idx);
          }
        });
      }
    }

    _startSubscriptionListener();
    _fetchSubscriptionData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _subscriptionListener?.cancel();
    super.dispose();
  }

  void _startSubscriptionListener() {
    if (widget.currentPlanName != null || widget.hideTrial) {
      return;
    }

    final user = AuthStateService.instance.currentUser;
    final tenantId =
        widget.pendingUserData?['tenantId'] ??
        ThemeService.instance.databaseName;

    if (user != null) {
      _subscriptionListener = FirestoreService.instance
          .streamSubscription(user.uid, tenantId, appId: _consistentAppId)
          .listen((subData) {
            if (subData != null && subData['status'] == 'active') {
              if (mounted && !_hasNavigated) {
                _handleSubscriptionActive();
              }
            }
          });
    }
  }

  void _handleSubscriptionActive() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const admindashboard()),
      (route) => false,
    );
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      final user = AuthStateService.instance.currentUser;
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          ThemeService.instance.databaseName;

      if (user == null && widget.pendingUserData == null) {
        setState(() => _isLoadingSubscription = false);
        return;
      }

      final querySnapshot = await FirestoreService.instance
          .collection(
            'payment_transactions',
            tenantId: tenantId,
            appId: _consistentAppId,
          )
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      Map<String, dynamic>? activeData;
      for (var doc in querySnapshot.docs) {
        final map = doc.data();
        final transactionUserId = map['userId']?.toString() ?? '';
        final currentUserId =
            user?.uid ?? widget.pendingUserData?['userId']?.toString() ?? '';

        if (transactionUserId != currentUserId) continue;

        final status = (map['status'] ?? '').toString().toUpperCase();
        if (status == 'SUCCESS' || status == 'UAT_SIMULATED') {
          activeData = map;
          break;
        }
      }

      if (activeData != null && mounted) {
        setState(() {
          _fetchedPlanName =
              activeData!['planName'] as String? ?? 'Subscription';
          final isYearly = activeData['isYearly'] as bool? ?? false;
          final isSixMonths = activeData['isSixMonths'] as bool? ?? false;

          if (_fetchedPlanName?.toLowerCase().contains('trial') ?? false) {
            _fetchedBillingCycle = '7 Days';
            _billingDuration = BillingDuration.freeTrial;
          } else if (isYearly) {
            _fetchedBillingCycle = 'Yearly';
            _billingDuration = BillingDuration.yearly;
          } else if (isSixMonths) {
            _fetchedBillingCycle = '6 Months';
            _billingDuration = BillingDuration.sixMonths;
          } else {
            _fetchedBillingCycle = 'Monthly';
            _billingDuration = BillingDuration.monthly;
          }

          final timestamp = activeData['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final startedAt = timestamp.toDate();
            DateTime nextBilling;
            if (_fetchedPlanName?.toLowerCase().contains('trial') ?? false) {
              nextBilling = startedAt.add(const Duration(days: 7));
            } else if (isYearly) {
              int year = startedAt.year + 1;
              int month = startedAt.month;
              int day = startedAt.day;
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            } else if (isSixMonths) {
              int year = startedAt.year;
              int month = startedAt.month + 6;
              if (month > 12) {
                year += (month - 1) ~/ 12;
                month = (month - 1) % 12 + 1;
              }
              int day = startedAt.day;
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            } else {
              int year = startedAt.year;
              int month = startedAt.month + 1;
              if (month > 12) {
                year += 1;
                month = 1;
              }
              int day = startedAt.day;
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            }

            _fetchedRemainingDays =
                nextBilling.difference(DateTime.now()).inDays;
            if (_fetchedRemainingDays! < 0) _fetchedRemainingDays = 0;
          }

          if (activeData.containsKey('limits')) {
            _fetchedLimits = activeData['limits'] as Map<String, dynamic>?;
          }

          final idx = plans.indexWhere(
            (p) =>
                p['name'].toString().toLowerCase() ==
                _fetchedPlanName.toString().toLowerCase(),
          );
          if (idx != -1) {
            _selectedPlanIndex = idx;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(idx);
            }
          }
          _isLoadingSubscription = false;
        });
      } else {
        setState(() => _isLoadingSubscription = false);
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      if (mounted) setState(() => _isLoadingSubscription = false);
    }
  }

  bool _isCurrentPlan(Map<String, dynamic> plan) {
    if (_fetchedPlanName == null) return false;
    if (plan['name'].toString().toLowerCase() !=
        _fetchedPlanName!.toLowerCase()) {
      return false;
    }
    if (_fetchedBillingCycle == null) return true;
    final selectedCycle = _billingDuration == BillingDuration.yearly
        ? 'Yearly'
        : (_billingDuration == BillingDuration.sixMonths
            ? '6 Months'
            : (_billingDuration == BillingDuration.freeTrial
                ? '7 Days'
                : 'Monthly'));
    return selectedCycle == _fetchedBillingCycle;
  }

  // ── Enterprise Contact Actions ─────────────────────────────────────────────
  Future<void> _makePhoneCall() async {
    final Uri uri = Uri(scheme: 'tel', path: _businessPhoneClean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Unable to launch phone dialer.');
      }
    } catch (e) {
      _showSnack('Error launching phone dialer: $e');
    }
  }

  Future<void> _sendEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: _businessEmail,
      queryParameters: {
        'subject': 'Enterprise Plan Inquiry - ServNex',
        'body':
            'Hello ServNex Sales Team,\n\nI would like to inquire about the Enterprise Subscription Plan for our company.\n\nCompany Name:\nTeam Size (Engineers/Technicians):\nEstimated Customers:\nSpecial Requirements:\n\nLooking forward to hearing from you.\n\nBest regards,',
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Unable to open email client.');
      }
    } catch (e) {
      _showSnack('Error opening email client: $e');
    }
  }

  Future<void> _openWhatsApp() async {
    final Uri uri = Uri.parse(
      'https://wa.me/917358677670?text=${Uri.encodeComponent('Hello ServNex Team! I would like to inquire about the Enterprise Subscription Plan for our company.')}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('WhatsApp is not installed or supported on this device.');
      }
    } catch (e) {
      _showSnack('Error opening WhatsApp: $e');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied to clipboard');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  void _showEnterpriseContactModal() {
    final primaryColor = ThemeService.instance.primaryColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_center_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enterprise Inquiries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Connect directly with our solutions team',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Direct Contact Channels',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),

              // Phone Call
              _buildContactActionTile(
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Direct Phone Support',
                subtitle: _businessPhone,
                buttonText: 'Call Now',
                onAction: _makePhoneCall,
                onCopy: () => _copyToClipboard(_businessPhone, 'Phone number'),
              ),
              const SizedBox(height: 8),

              // WhatsApp
              _buildContactActionTile(
                icon: Icons.chat_bubble_rounded,
                iconColor: const Color(0xFF16A34A),
                title: 'WhatsApp Solutions Desk',
                subtitle: _businessPhone,
                buttonText: 'Chat',
                onAction: _openWhatsApp,
                onCopy: () =>
                    _copyToClipboard(_businessPhoneClean, 'WhatsApp number'),
              ),
              const SizedBox(height: 8),

              // Email
              _buildContactActionTile(
                icon: Icons.mail_rounded,
                iconColor: primaryColor,
                title: 'Email Solutions Team',
                subtitle: _businessEmail,
                buttonText: 'Send Mail',
                onAction: _sendEmail,
                onCopy: () => _copyToClipboard(_businessEmail, 'Email address'),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dedicated Support: Mon – Sat, 9:00 AM – 6:00 PM IST\nGuaranteed Enterprise SLA response within 1 hour',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onAction,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(
              Icons.copy_rounded,
              size: 15,
              color: Color(0xFF94A3B8),
            ),
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan Selection Logic ───────────────────────────────────────────────────
  Future<void> _checkTrialEligibility() async {
    try {
      final user = AuthStateService.instance.currentUser;
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          ThemeService.instance.databaseName;

      if (user == null) return;

      final querySnapshot = await FirestoreService.instance
          .collection(
            'payment_transactions',
            tenantId: tenantId,
            appId: _consistentAppId,
          )
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final planName = data['planName']?.toString().toLowerCase() ?? '';
        if (planName.contains('trial')) {
          _showSnack(
            'You have already used your free trial. Please select a paid plan.',
          );
          throw Exception('Trial already used');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void _startFreeTrial() async {
    try {
      await _checkTrialEligibility();
    } catch (e) {
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandingCustomizationScreen(
          planName: trialPlan['name'],
          price: 0,
          originalPrice: 0,
          isYearly: false,
          isSixMonths: false,
          paymentMethod: 'Free Trial',
          transactionId: 'trial_${DateTime.now().millisecondsSinceEpoch}',
          limits: trialPlan['limits'],
          geoLocation: trialPlan['geoLocation'],
          attendance: trialPlan['attendance'],
          barcode: trialPlan['barcode'],
          reportExport: trialPlan['reportExport'],
          pendingUserData: widget.pendingUserData,
        ),
      ),
    );
  }

  void _handlePlanAction(Map<String, dynamic> selectedPlan) {
    if (selectedPlan['isEnterprise'] == true) {
      _showEnterpriseContactModal();
      return;
    }

    final isYearly = _billingDuration == BillingDuration.yearly;
    final isSixMonths = _billingDuration == BillingDuration.sixMonths;

    int price;
    int? originalPrice;

    if (isYearly) {
      price = (selectedPlan['yearlyPrice'] as num?)?.toInt() ?? 0;
      originalPrice = (selectedPlan['yearlyOriginalPrice'] as num?)?.toInt();
    } else if (isSixMonths) {
      price = (selectedPlan['sixMonthPrice'] as num?)?.toInt() ?? 0;
      originalPrice = (selectedPlan['sixMonthOriginalPrice'] as num?)?.toInt();
    } else {
      price = (selectedPlan['monthlyPrice'] as num?)?.toInt() ?? 0;
      originalPrice = (selectedPlan['monthlyOriginalPrice'] as num?)?.toInt();
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            planName: selectedPlan['name']?.toString() ?? 'Plan',
            price: price,
            originalPrice: originalPrice,
            isYearly: isYearly,
            isSixMonths: isSixMonths,
            isFirstTimeRegistration: widget.pendingUserData != null,
            limits: selectedPlan['limits'] as Map<String, dynamic>?,
            geoLocation: selectedPlan['geoLocation'] as bool?,
            attendance: selectedPlan['attendance'] as bool?,
            barcode: selectedPlan['barcode'] as bool?,
            reportExport: selectedPlan['reportExport'] as bool?,
            pendingUserData: widget.pendingUserData,
            hasActiveSubscription:
                widget.currentPlanName != null &&
                widget.currentPlanName!.isNotEmpty,
            currentActivePlanName: widget.currentPlanName,
            activePlanExpiryDate: widget.remainingDays != null
                ? DateTime.now().add(Duration(days: widget.remainingDays!))
                : null,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoadingSubscription
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              )
            : ResponsiveWrapper(
                maxWidth: 1200.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    final isTablet =
                        constraints.maxWidth >= 600 &&
                        constraints.maxWidth < 900;

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // App Bar & Hero Header
                        SliverToBoxAdapter(child: _buildHeroSection()),

                        // Active Subscription Banner (if present)
                        if (_fetchedPlanName != null)
                          SliverToBoxAdapter(child: _buildActivePlanCard()),

                        // Billing Duration Toggle (Free Trial vs Monthly vs 6 Months vs 1 Year)
                        SliverToBoxAdapter(child: _buildDurationToggle()),

                        // Main Pricing Section or Dedicated Free Trial Showcase
                        if (_billingDuration == BillingDuration.freeTrial)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 460),
                                  child: _buildFreeTrialFullCard(),
                                ),
                              ),
                            ),
                          )
                        else if (isDesktop)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: _buildDesktopGridView(),
                            ),
                          )
                        else if (isTablet)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: _buildTabletGridView(),
                            ),
                          )
                        else
                          SliverToBoxAdapter(child: _buildMobileCarouselView()),

                        // Trust & Security Section
                        SliverToBoxAdapter(child: _buildTrustAndFaqSection()),

                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  // ── HERO SECTION ───────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            const Color(0xFFF1F5F9).withValues(alpha: 0.6),
            const Color(0xFFF8FAFC),
          ],
        ),
      ),
      child: Column(
        children: [
          // Top row with Back Button & Brand Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shadowColor: Colors.black.withValues(alpha: 0.05),
                  elevation: 2,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFBBF24),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'FLEXIBLE SAAS PLANS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 38),
            ],
          ),

          const SizedBox(height: 10),

          // Main Heading
          const Text(
            'Simple, Transparent Pricing',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Unlock powerful service tracking, technician attendance, and automated reports.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIVE PLAN BANNER ─────────────────────────────────────────────────────
  Widget _buildActivePlanCard() {
    final planName =
        _fetchedPlanName ?? widget.currentPlanName ?? 'Active Plan';
    final days = _fetchedRemainingDays ?? widget.remainingDays;
    final cycle = _fetchedBillingCycle ?? widget.billingCycle ?? 'Monthly';
    final isExpiringSoon = days != null && days <= 7;

    Map<String, dynamic> activeLimits = _fetchedLimits ?? {};
    if (activeLimits.isEmpty) {
      final found = plans.firstWhere(
        (p) => p['name'].toString().toLowerCase() == planName.toLowerCase(),
        orElse: () => {},
      );
      if (found.isNotEmpty && found.containsKey('limits')) {
        activeLimits = found['limits'] as Map<String, dynamic>;
      }
    }

    final customers = activeLimits['maxCustomers'] == -1
        ? 'Unlimited'
        : '${activeLimits['maxCustomers'] ?? 0}';
    final engineers = activeLimits['maxEngineers'] == -1
        ? 'Unlimited'
        : '${activeLimits['maxEngineers'] ?? 0}';
    final storage = activeLimits['maxStorageGB'] == -1
        ? 'Unlimited'
        : '${activeLimits['maxStorageGB'] ?? 0}GB';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpiringSoon
              ? const Color(0xFFFFFBEB)
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpiringSoon
                ? const Color(0xFFFCD34D)
                : const Color(0xFF86EFAC),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        (isExpiringSoon
                                ? const Color(0xFFD97706)
                                : const Color(0xFF16A34A))
                            .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpiringSoon
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: isExpiringSoon
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'CURRENT: $planName',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isExpiringSoon
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF166534),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isExpiringSoon
                                    ? const Color(0xFFFCD34D)
                                    : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Text(
                              cycle,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isExpiringSoon
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        days != null
                            ? (isExpiringSoon
                                  ? '⚠ Expires in $days day${days == 1 ? '' : 's'} — renew soon'
                                  : '$days days remaining on your active cycle')
                            : 'Active subscription status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isExpiringSoon
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isExpiringSoon
                              ? const Color(0xFFB45309)
                              : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (activeLimits.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '👥 $customers Cust',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isExpiringSoon
                            ? const Color(0xFF92400E)
                            : const Color(0xFF166534),
                      ),
                    ),
                    Text(
                      '🔧 $engineers Eng',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isExpiringSoon
                            ? const Color(0xFF92400E)
                            : const Color(0xFF166534),
                      ),
                    ),
                    Text(
                      '☁️ $storage Storage',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isExpiringSoon
                            ? const Color(0xFF92400E)
                            : const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── DURATION TOGGLE (Bigger, High-Visibility Horizontal Scrollable Pills) ────
  Widget _buildDurationToggle() {
    final showTrial = !widget.hideTrial &&
        (_fetchedPlanName == null ||
            !_fetchedPlanName!.toLowerCase().contains('trial'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Free Trial
                  if (showTrial)
                    _buildDurationSegment(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Free Trial',
                      badge: '7D FREE',
                      duration: BillingDuration.freeTrial,
                    ),
                  // Monthly
                  _buildDurationSegment(
                    icon: Icons.calendar_view_month_rounded,
                    title: 'Monthly',
                    duration: BillingDuration.monthly,
                  ),
                  // 6 Months
                  _buildDurationSegment(
                    icon: Icons.date_range_rounded,
                    title: '6 Months',
                    badge: 'POPULAR',
                    duration: BillingDuration.sixMonths,
                  ),
                  // 1 Year (With Badge)
                  _buildDurationSegment(
                    icon: Icons.offline_bolt_rounded,
                    title: '1 Year',
                    badge: 'SAVE ~17%',
                    duration: BillingDuration.yearly,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _billingDuration == BillingDuration.freeTrial
                ? '🎁 7-Day Free Trial selected — Full feature access, no card needed'
                : (_billingDuration == BillingDuration.yearly
                    ? '⚡ Annual billing selected — Best savings with full feature access'
                    : (_billingDuration == BillingDuration.sixMonths
                        ? '💡 Semi-annual billing selected — Flexible 6-month commitment'
                        : '📅 Monthly billing selected — Cancel or switch anytime')),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSegment({
    required IconData icon,
    required String title,
    String? badge,
    required BillingDuration duration,
  }) {
    final isSelected = _billingDuration == duration;
    final isYearly = duration == BillingDuration.yearly;
    final isTrial = duration == BillingDuration.freeTrial;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          if (_billingDuration != duration) {
            setState(() {
              _billingDuration = duration;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isTrial
                    ? const Color(0xFF2563EB)
                    : (isYearly
                        ? const Color(0xFF0F172A)
                        : Colors.white))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? (isYearly || isTrial
                        ? Colors.white
                        : const Color(0xFF0F172A))
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? (isYearly || isTrial
                          ? Colors.white
                          : const Color(0xFF0F172A))
                      : const Color(0xFF475569),
                  letterSpacing: -0.2,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isTrial
                            ? Colors.white.withValues(alpha: 0.28)
                            : (duration == BillingDuration.sixMonths
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981)))
                        : (isTrial
                            ? const Color(0xFF3B82F6)
                            : (duration == BillingDuration.sixMonths
                                ? const Color(0xFFD97706)
                                : const Color(0xFF059669))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isSelected &&
                              duration == BillingDuration.sixMonths
                          ? Colors.black
                          : Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── FULL 7-DAY FREE TRIAL CARD ─────────────────────────────────────────────
  Widget _buildFreeTrialFullCard() {
    final limits = trialPlan['limits'] as Map<String, dynamic>;
    final maxCustomers = limits['maxCustomers'] ?? 10;
    final maxEngineers = limits['maxEngineers'] ?? 3;
    final maxStorage = limits['maxStorageGB'] ?? 2;
    final features = (trialPlan['features'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF2563EB), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ribbon Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '★  7-DAY RISK-FREE FULL ACCESS TRIAL  ★',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Name & Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '7-Day Free Trial',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E3A8A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: const Text(
                            'Zero Risk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Test drive all premium service features with zero upfront commitment.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 12),

                    // Pricing Display
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹0',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                            letterSpacing: -1,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '/ 7 days full access',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'No credit card or payment info needed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Quota Mini Grid
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuotaPill(
                            Icons.people_alt_rounded,
                            'Customers',
                            '$maxCustomers',
                            false,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: const Color(0xFFBFDBFE),
                          ),
                          _buildQuotaPill(
                            Icons.engineering_rounded,
                            'Engineers',
                            '$maxEngineers',
                            false,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: const Color(0xFFBFDBFE),
                          ),
                          _buildQuotaPill(
                            Icons.cloud_done_rounded,
                            'Storage',
                            '${maxStorage}GB',
                            false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _startFreeTrial,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor:
                              const Color(0xFF2563EB).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Start 7-Day Free Trial Now',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Features Checklist
                    const Text(
                      'What\'s Included in Free Trial:',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...List.generate(features.length, (i) {
                      final feature = features[i].toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDBEAFE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MOBILE CAROUSEL & TABS VIEW ────────────────────────────────────────────
  Widget _buildMobileCarouselView() {
    return Column(
      children: [
        // Quick Selector Tabs (Bigger, horizontally scrollable chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: List.generate(plans.length, (index) {
              final plan = plans[index];
              final isSelected = _selectedPlanIndex == index;
              final isEnterprise = plan['isEnterprise'] == true;
              final isPopular = plan['isPopular'] == true;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPlanIndex = index;
                    });
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isPopular
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF1E293B))
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (isPopular
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF0F172A))
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isPopular
                                        ? const Color(0xFFF59E0B)
                                        : Colors.black)
                                    .withValues(alpha: 0.16),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPopular)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              plan['name']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              isEnterprise
                                  ? 'Custom Plan'
                                  : '₹${plan['monthlyPrice']}/month',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? (isPopular
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF93C5FD))
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 6),

        // Carousel Slider (Comfortable 560px height for larger typography)
        SizedBox(
          height: 560,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedPlanIndex = index;
              });
            },
            itemCount: plans.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.08)).clamp(0.9, 1.0);
                  }
                  return Transform.scale(
                    scale: value,
                    child: _buildPricingCard(plans[index]),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(plans.length, (index) {
            final isSelected = _selectedPlanIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              width: isSelected ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── TABLET & DESKTOP GRIDS ─────────────────────────────────────────────────
  Widget _buildDesktopGridView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plans.map((plan) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildPricingCard(plan),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabletGridView() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPricingCard(plans[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildPricingCard(plans[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPricingCard(plans[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildPricingCard(plans[3])),
          ],
        ),
      ],
    );
  }

  // ── PRICING CARD COMPONENT ─────────────────────────────────────────────────
  Widget _buildPricingCard(Map<String, dynamic> plan) {
    final isYearly = _billingDuration == BillingDuration.yearly;
    final isSixMonths = _billingDuration == BillingDuration.sixMonths;

    final isEnterprise = plan['isEnterprise'] == true;
    final isPopular = plan['isPopular'] == true;
    final isCurrent = _isCurrentPlan(plan);

    final monthlyPrice = (plan['monthlyPrice'] as num?)?.toInt() ?? 0;
    final monthlyOriginal =
        (plan['monthlyOriginalPrice'] as num?)?.toInt() ?? 0;

    int displayPerMonth;
    int totalPrice;
    int? totalOriginal;
    String billingCycleText;

    if (isYearly) {
      totalPrice = (plan['yearlyPrice'] as num?)?.toInt() ?? 0;
      totalOriginal = (plan['yearlyOriginalPrice'] as num?)?.toInt();
      displayPerMonth = monthlyPrice == 99
          ? 83
          : (monthlyPrice == 199
              ? 165
              : (monthlyPrice == 299 ? 249 : monthlyPrice));
      billingCycleText =
          'Billed ₹$totalPrice annually (${totalOriginal != null && totalOriginal > totalPrice ? 'Save ₹${totalOriginal - totalPrice}' : ''})';
    } else if (isSixMonths) {
      totalPrice = (plan['sixMonthPrice'] as num?)?.toInt() ?? 0;
      totalOriginal = (plan['sixMonthOriginalPrice'] as num?)?.toInt();
      displayPerMonth = monthlyPrice;
      billingCycleText = 'Billed ₹$totalPrice every 6 months';
    } else {
      totalPrice = monthlyPrice;
      totalOriginal = monthlyOriginal;
      displayPerMonth = monthlyPrice;
      billingCycleText = 'Billed monthly, cancel anytime';
    }

    final limits = (plan['limits'] as Map<String, dynamic>?) ?? {};
    final maxCustomers = limits['maxCustomers'] == -1
        ? 'Unlimited'
        : '${limits['maxCustomers'] ?? 0}';
    final maxEngineers = limits['maxEngineers'] == -1
        ? 'Unlimited'
        : '${limits['maxEngineers'] ?? 0}';
    final maxStorage = limits['maxStorageGB'] == -1
        ? 'Unlimited'
        : '${limits['maxStorageGB'] ?? 0}GB';

    final planFeatures = (plan['features'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isEnterprise ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular
              ? const Color(0xFFF59E0B)
              : (isEnterprise
                  ? const Color(0xFF0284C7)
                  : (isCurrent
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFE2E8F0))),
          width: isPopular ? 2.2 : (isCurrent ? 2 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                : (isEnterprise
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.05)),
            blurRadius: isPopular ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Popular / Ribbon Header
              if (isPopular)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '★  RECOMMENDED & BEST VALUE  ★',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                )
              else if (isEnterprise)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'TAILORED FOR SCALE & LARGE TEAMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Name & Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          plan['name']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isEnterprise
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isEnterprise
                                ? const Color(0xFF1E293B)
                                : (isPopular
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isEnterprise
                                  ? const Color(0xFF334155)
                                  : (isPopular
                                      ? const Color(0xFFFCD34D)
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Text(
                            plan['badge']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isEnterprise
                                  ? const Color(0xFF38BDF8)
                                  : (isPopular
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan['tagline']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isEnterprise
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 10),

                    // Pricing Display
                    if (isEnterprise) ...[
                      const Text(
                        'Contact Us',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Custom quotation based on your organization\'s size',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹$displayPerMonth',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: isPopular
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF0F172A),
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/month',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isEnterprise
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const Spacer(),
                          if (monthlyOriginal > 0)
                            Text(
                              '₹$monthlyOriginal/mo',
                              style: const TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        billingCycleText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPopular
                              ? const Color(0xFFB45309)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Quota Mini Grid (Customers, Engineers, Storage)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isEnterprise
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isEnterprise
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuotaPill(
                            Icons.people_alt_rounded,
                            'Customers',
                            maxCustomers,
                            isEnterprise,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: isEnterprise
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          _buildQuotaPill(
                            Icons.engineering_rounded,
                            'Engineers',
                            maxEngineers,
                            isEnterprise,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: isEnterprise
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          _buildQuotaPill(
                            Icons.cloud_done_rounded,
                            'Storage',
                            maxStorage,
                            isEnterprise,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isCurrent
                            ? null
                            : () => _handlePlanAction(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrent
                              ? (isEnterprise
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))
                              : (isEnterprise
                                  ? const Color(0xFF0284C7)
                                  : (isPopular
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF0F172A))),
                          foregroundColor: isCurrent
                              ? const Color(0xFF94A3B8)
                              : Colors.white,
                          elevation: isCurrent ? 0 : 2,
                          shadowColor: isPopular
                              ? const Color(0xFFD97706).withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCurrent)
                              const Icon(Icons.check_circle_rounded, size: 16)
                            else if (isEnterprise)
                              const Icon(Icons.headset_mic_rounded, size: 16)
                            else
                              const Icon(Icons.flash_on_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isCurrent
                                  ? 'Current Active Plan'
                                  : (isEnterprise
                                      ? 'Contact Us'
                                      : 'Subscribe to ${plan['name']}'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Enterprise Quick Contact Bar (Phone & Email)
                    if (isEnterprise) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            GestureDetector(
                              onTap: _makePhoneCall,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 13,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _businessPhone,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 12,
                              color: const Color(0xFF475569),
                            ),
                            GestureDetector(
                              onTap: _sendEmail,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    size: 13,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Email Us',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Features Checklist (Increased font size & high readability)
                    Text(
                      'What\'s Included:',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isEnterprise
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(planFeatures.length, (i) {
                      final feature = planFeatures[i].toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isEnterprise
                                    ? const Color(0xFF0284C7)
                                        .withValues(alpha: 0.2)
                                    : (isPopular
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF1F5F9)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: isEnterprise
                                    ? const Color(0xFF38BDF8)
                                    : (isPopular
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isEnterprise
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaPill(
    IconData icon,
    String label,
    String value,
    bool isEnterprise,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color:
              isEnterprise ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isEnterprise ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isEnterprise
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ── TRUST & FAQ SECTION ────────────────────────────────────────────────────
  Widget _buildTrustAndFaqSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // Trust Badges Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrustItem(Icons.lock_rounded, '256-Bit SSL', 'Encrypted'),
                _buildTrustItem(
                  Icons.verified_user_rounded,
                  'ICICI Gateway',
                  'Secure Pay',
                ),
                _buildTrustItem(
                  Icons.offline_bolt_rounded,
                  'Instant Setup',
                  'Zero Wait',
                ),
                _buildTrustItem(
                  Icons.support_agent_rounded,
                  'Direct Support',
                  'Phone & Email',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Direct Enterprise Assistance Callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Have questions or custom needs?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Call us at +91 73586 77670 or email support@rookstechnologies.com',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showEnterpriseContactModal,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Contact',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F172A)),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
