import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_screen.dart';
import 'branding_customization_screen.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  /// Optionally pass the admin's current plan name to highlight it on the screen.
  final String? currentPlanName;

  /// When true, hides the Free Trial tab (used when admin is changing an existing plan).
  final bool hideTrial;

  /// Remaining days on the active plan (shown in the active plan card).
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

enum PlanType { freeTrial, monthly, sixMonths, yearly }

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  PlanType selectedPlanType = PlanType.monthly;
  int _selectedPlanIndex = 1; // Default: Gold (Index 1) for Paid plans
  bool _hasNavigated = false; // Prevent multiple redirects

  String? _fetchedPlanName;
  int? _fetchedRemainingDays;
  String? _fetchedBillingCycle;
  Map<String, dynamic>? _fetchedLimits;
  bool _isLoadingSubscription = true;

  // Getter for safe selectedPlanIndex access
  int get selectedPlanIndex {
    if (_selectedPlanIndex < 0 || _selectedPlanIndex >= plans.length) {
      return 1; // Default to Gold if index is invalid
    }
    return _selectedPlanIndex;
  }

  set selectedPlanIndex(int value) {
    if (value >= 0 && value < plans.length) {
      _selectedPlanIndex = value;
    } else {
      _selectedPlanIndex = 1; // Fallback to default
    }
  }

  // Plan data for Paid tiers
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Silver',
      'monthlyPrice': 1,
      'monthlyOriginalPrice': 299,
      'sixMonthPrice': 999,
      'sixMonthOriginalPrice': 1794,
      'yearlyPrice': 1990,
      'yearlyOriginalPrice': 3588,
      'subtitle': 'Best for small teams & basic usage',
      'limits': {
        'maxCustomers': 20,
        'maxEngineers': 5,
        'maxPhotosPerCustomer': 10,
        'maxPdfUploadsPerCustomer': 5,
        'maxStorageGB': 1,
      },
      'features': [
        '0-20 Customers',
        '0-5 Engineers',
        '1GB Storage',
        'Web Support',
        'Basic Dashboard',
        'Standard Email Support',
      ],
      'geoLocation': false,
      'attendance': false,
      'barcode': false,
      'reportExport': false,
      'color': const Color(0xFFE0E0E0),
    },
    {
      'name': 'Gold',
      'monthlyPrice': 2,
      'monthlyOriginalPrice': 499,
      'sixMonthPrice': 1990,
      'sixMonthOriginalPrice': 2994,
      'yearlyPrice': 3990,
      'yearlyOriginalPrice': 5988,
      'subtitle': 'Ideal for growing businesses',
      'limits': {
        'maxCustomers': 50,
        'maxEngineers': 10,
        'maxPhotosPerCustomer': 30,
        'maxPdfUploadsPerCustomer': 15,
        'maxStorageGB': 5,
      },
      'features': [
        '0-50 Customers',
        '0-10 Engineers',
        '5GB Storage',
        'Web Support',
        'Geo Location Enabled',
        'Priority Support',
      ],
      'geoLocation': true,
      'attendance': false,
      'barcode': false,
      'reportExport': true,
      'color': const Color(0xFFFFD700),
    },
    {
      'name': 'Platinum',
      'monthlyPrice': 999,
      'monthlyOriginalPrice': 1499,
      'sixMonthPrice': 4990,
      'sixMonthOriginalPrice': 8994,
      'yearlyPrice': 9990,
      'yearlyOriginalPrice': 17988,
      'subtitle': 'Best for enterprises & unlimited usage',
      'limits': {
        'maxCustomers': -1, // -1 means Unlimited
        'maxEngineers': -1,
        'maxPhotosPerCustomer': -1,
        'maxPdfUploadsPerCustomer': -1,
        'maxStorageGB': 100, // Increased for Platinum
      },
      'features': [
        'Unlimited Customers',
        'Unlimited Engineers',
        'Unlimited Photos & PDF Uploads',
        'Geo Location Enabled',
        'Attendance System',
        'Barcode System',
        '100GB Storage',
        'Report Export Available',
        'Premium Priority Support',
      ],
      'geoLocation': true,
      'attendance': true,
      'barcode': true,
      'reportExport': true,
      'color': const Color(0xFFB0BEC5),
    },
  ];

  // Data for Trial tier
  final Map<String, dynamic> trialPlan = {
    'name': '7-Day Free Trial',
    'price': 0,
    'originalPrice': 0,
    'subtitle': 'Full access to premium features for 7 days',
    'limits': {
      'maxCustomers': 50,
      'maxEngineers': 10,
      'maxPhotosPerCustomer': 30,
      'maxPdfUploadsPerCustomer': 15,
      'maxStorageGB': 5,
    },
    'features': [
      'Access to all Gold Plan features',
      'Experience Geo Location & Barcode',
      'No credit card required for trial',
      'Automatic expiration after 7 days',
      'Web support included',
    ],
    'geoLocation': true,
    'attendance': true,
    'barcode': true,
    'reportExport': true,
    'color': const Color(0xFFE3F2FD),
  };

  StreamSubscription<Map<String, dynamic>?>? _subscriptionListener;

  // Helper to get consistent appId
  String get _consistentAppId => ThemeService.instance.appName;

  @override
  void initState() {
    super.initState();

    // Auto-select current plan if provided
    if (widget.currentPlanName != null) {
      _fetchedPlanName = widget.currentPlanName;
      _fetchedRemainingDays = widget.remainingDays;
      _fetchedBillingCycle = widget.billingCycle;
      if (widget.currentPlanName!.toLowerCase().contains('trial')) {
        selectedPlanType = PlanType.freeTrial;
      } else {
        final idx = plans.indexWhere(
          (p) =>
              p['name'].toString().toLowerCase() ==
              widget.currentPlanName!.toString().toLowerCase(),
        );
        if (idx != -1) {
          selectedPlanIndex = idx;
        }
      }
    }

    _startSubscriptionListener();
    _fetchSubscriptionData();
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    super.dispose();
  }

  void _startSubscriptionListener() {
    // If the user already has an active plan and is managing it,
    // prevent the listener from auto-redirecting them back to the dashboard.
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
              // Subscription became active in real-time!
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
    // Navigate to dashboard automatically
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

        // Filter for current user's transactions
        final transactionUserId = map['userId']?.toString() ?? '';
        final currentUserId =
            user?.uid ?? widget.pendingUserData?['userId']?.toString() ?? '';

        if (transactionUserId != currentUserId) {
          continue; // Skip other users' transactions
        }

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
          } else if (isYearly) {
            _fetchedBillingCycle = 'Yearly';
          } else if (isSixMonths) {
            _fetchedBillingCycle = '6 Months';
          } else {
            _fetchedBillingCycle = 'Monthly';
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
              // Adjust for month end (e.g., March 31 + 1 year should not be April 1)
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            } else if (isSixMonths) {
              int year = startedAt.year;
              int month = startedAt.month + 6;
              // Handle year rollover
              if (month > 12) {
                year += (month - 1) ~/ 12;
                month = (month - 1) % 12 + 1;
              }
              int day = startedAt.day;
              // Adjust for month end
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            } else {
              int year = startedAt.year;
              int month = startedAt.month + 1;
              // Handle year rollover
              if (month > 12) {
                year += 1;
                month = 1;
              }
              int day = startedAt.day;
              // Adjust for month end
              day = day > DateTime(year, month + 1, 0).day
                  ? DateTime(year, month + 1, 0).day
                  : day;
              nextBilling = DateTime(year, month, day);
            }

            _fetchedRemainingDays = nextBilling
                .difference(DateTime.now())
                .inDays;
            if (_fetchedRemainingDays! < 0) _fetchedRemainingDays = 0;
          }

          if (activeData.containsKey('limits')) {
            _fetchedLimits = activeData['limits'] as Map<String, dynamic>?;
          }

          // Update selection
          if (_fetchedPlanName!.toLowerCase().contains('trial')) {
            selectedPlanType = PlanType.freeTrial;
          } else {
            final idx = plans.indexWhere(
              (p) =>
                  p['name'].toString().toLowerCase() ==
                  _fetchedPlanName.toString().toLowerCase(),
            );
            if (idx != -1) {
              selectedPlanIndex = idx;
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.white),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.blue.shade50.withValues(alpha: 0.5),
              Colors.grey.shade200,
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color.fromARGB(255, 233, 231, 231),
          body: SafeArea(
            child: _isLoadingSubscription
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Header with Glassy Effect
                      ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: Colors.white.withValues(alpha: 0.2),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'CHOOSE WHAT FITS YOU',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Choose the plan that suits your Workflow best',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (_fetchedPlanName != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            'Active: $_fetchedPlanName',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Active Plan Status Card (shown when managing existing plan)
                      if (_fetchedPlanName != null) _buildActivePlanCard(),

                      // Plan Duration Selector (Tabs)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              if (!widget.hideTrial)
                                _buildTab(PlanType.freeTrial, 'Free Trial'),
                              _buildTab(PlanType.monthly, 'Monthly'),
                              _buildTab(PlanType.sixMonths, '6 Months'),
                              _buildTab(PlanType.yearly, 'Yearly'),
                            ],
                          ),
                        ),
                      ),

                      // Main Plan Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: selectedPlanType == PlanType.freeTrial
                              ? _buildMainCard(trialPlan, isTrial: true)
                              : _buildMainCard(
                                  plans[selectedPlanIndex],
                                  isYearly: selectedPlanType == PlanType.yearly,
                                  isSixMonths:
                                      selectedPlanType == PlanType.sixMonths,
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bottom Selectors (Hidden for Trial)
                      if (selectedPlanType != PlanType.freeTrial)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(plans.length, (index) {
                              return _buildBottomSelector(index);
                            }),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Subscribe Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Builder(
                            builder: (context) {
                              final isTrialSelected =
                                  selectedPlanType == PlanType.freeTrial;
                              final currentSelectedPlan = isTrialSelected
                                  ? trialPlan
                                  : plans[selectedPlanIndex];
                              final isAlreadyCurrentPlan = _isCurrentPlan(
                                currentSelectedPlan,
                                isYearly: selectedPlanType == PlanType.yearly,
                                isSixMonths:
                                    selectedPlanType == PlanType.sixMonths,
                                isTrial: isTrialSelected,
                              );

                              return ElevatedButton(
                                onPressed: isAlreadyCurrentPlan
                                    ? null // Disable if it's already the current plan
                                    : () {
                                        if (isTrialSelected) {
                                          _handlePlanSelection(
                                            context,
                                            trialPlan,
                                            isTrial: true,
                                          );
                                        } else {
                                          _handlePlanSelection(
                                            context,
                                            plans[selectedPlanIndex],
                                            isYearly:
                                                selectedPlanType ==
                                                PlanType.yearly,
                                            isSixMonths:
                                                selectedPlanType ==
                                                PlanType.sixMonths,
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAlreadyCurrentPlan
                                      ? Colors.grey.shade300
                                      : Colors.white,
                                  foregroundColor: isAlreadyCurrentPlan
                                      ? Colors.grey.shade600
                                      : Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: isAlreadyCurrentPlan ? 0 : 4,
                                ),
                                child: Text(
                                  isAlreadyCurrentPlan
                                      ? 'Your Current Plan'
                                      : (isTrialSelected
                                            ? 'Start 7-Day Free Trial'
                                            : 'Subscribe now'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isAlreadyCurrentPlan
                                        ? Colors.grey.shade700
                                        : const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              );
                            },
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

  Widget _buildTab(PlanType type, String label) {
    final isSelected = selectedPlanType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPlanType = type;
            if (type != PlanType.freeTrial && selectedPlanIndex == -1) {
              selectedPlanIndex = 1;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(206, 255, 255, 255)
                : const Color.fromARGB(0, 192, 50, 50),
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color.fromARGB(255, 0, 0, 0)
                  : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  bool _isCurrentPlan(
    Map<String, dynamic> plan, {
    bool isYearly = false,
    bool isSixMonths = false,
    bool isTrial = false,
  }) {
    if (_fetchedPlanName == null || _fetchedBillingCycle == null) {
      return false;
    }

    // Check plan name
    if (plan['name'].toString().toLowerCase() !=
        _fetchedPlanName.toString().toLowerCase()) {
      return false;
    }

    // For trial plans, no billing cycle check needed
    if (isTrial) {
      return _fetchedPlanName!.toLowerCase().contains('trial');
    }

    // Calculate billing cycle string for current selection
    String selectedCycle;
    if (isYearly) {
      selectedCycle = 'Yearly';
    } else if (isSixMonths) {
      selectedCycle = '6 Months';
    } else {
      selectedCycle = 'Monthly';
    }

    // Check if billing cycles match
    return selectedCycle == _fetchedBillingCycle;
  }

  Widget _buildMainCard(
    Map<String, dynamic> plan, {
    bool isYearly = false,
    bool isSixMonths = false,
    bool isTrial = false,
  }) {
    final price = isTrial
        ? plan['price']
        : (isYearly
              ? plan['yearlyPrice']
              : (isSixMonths ? plan['sixMonthPrice'] : plan['monthlyPrice']));
    final originalPrice = isTrial
        ? plan['originalPrice']
        : (isYearly
              ? plan['yearlyOriginalPrice']
              : (isSixMonths
                    ? plan['sixMonthOriginalPrice']
                    : plan['monthlyOriginalPrice']));
    final durationLabel = isTrial
        ? '/7 Days'
        : (isYearly ? '/Year' : (isSixMonths ? '/6 Months' : '/Month'));
    final isCurrentPlan = _isCurrentPlan(
      plan,
      isYearly: isYearly,
      isSixMonths: isSixMonths,
      isTrial: isTrial,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentPlan
              ? Colors.blue.shade300
              : Colors.grey.withValues(alpha: 0.2),
          width: isCurrentPlan ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentPlan
                ? Colors.blue.shade100
                : const Color.fromARGB(255, 235, 235, 235),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentPlan)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓  Your Current Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              Text(
                plan['name'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (originalPrice != null && originalPrice > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '₹$originalPrice',
                      style: const TextStyle(
                        fontSize: 20,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                durationLabel,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                isTrial
                    ? 'No credit card required'
                    : 'Applicable for ${isYearly ? 'annual' : (isSixMonths ? '6-month' : 'monthly')} billing',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Text(
                plan['subtitle'],
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plan['features'].length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 20,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            plan['features'][index],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlanCard() {
    final planName =
        _fetchedPlanName ?? widget.currentPlanName ?? 'Active Plan';
    final days = _fetchedRemainingDays ?? widget.remainingDays;
    final cycle = _fetchedBillingCycle ?? widget.billingCycle ?? 'Monthly';
    final isExpiringSoon = days != null && days <= 7;
    final cardColor = isExpiringSoon
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE8F5E9);
    final borderColor = isExpiringSoon
        ? Colors.orange.shade300
        : Colors.green.shade300;
    final accentColor = isExpiringSoon
        ? Colors.orange.shade700
        : Colors.green.shade700;

    // Find limits from fetched limits or static config
    Map<String, dynamic> activeLimits = _fetchedLimits ?? {};
    if (activeLimits.isEmpty) {
      if (planName.toLowerCase().contains('trial')) {
        activeLimits = trialPlan['limits'];
      } else {
        final found = plans.firstWhere(
          (p) => p['name'].toString().toLowerCase() == planName.toLowerCase(),
          orElse: () => {},
        );
        if (found.isNotEmpty) activeLimits = found['limits'];
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpiringSoon
                        ? Icons.warning_rounded
                        : Icons.verified_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              planName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cycle,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        days != null
                            ? (isExpiringSoon
                                  ? '⚠ Expires in $days day${days == 1 ? '' : 's'} — renew soon!'
                                  : '$days day${days == 1 ? '' : 's'} remaining on your plan')
                            : 'Active subscription',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor.withValues(alpha: 0.85),
                          fontWeight: isExpiringSoon
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLimitIndicator(
                      Icons.people,
                      'Customers',
                      customers,
                      accentColor,
                    ),
                    const SizedBox(width: 16),
                    _buildLimitIndicator(
                      Icons.engineering,
                      'Engineers',
                      engineers,
                      accentColor,
                    ),
                    const SizedBox(width: 16),
                    _buildLimitIndicator(
                      Icons.cloud,
                      'Storage',
                      storage,
                      accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitIndicator(
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: accentColor.withValues(alpha: 0.9),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: accentColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSelector(int index) {
    final plan = plans[index];
    final isSelected = selectedPlanIndex == index;
    final isYearly = selectedPlanType == PlanType.yearly;
    final isSixMonths = selectedPlanType == PlanType.sixMonths;

    final price = isYearly
        ? plan['yearlyPrice']
        : (isSixMonths ? plan['sixMonthPrice'] : plan['monthlyPrice']);
    final isCurrentPlan = _isCurrentPlan(
      plan,
      isYearly: isYearly,
      isSixMonths: isSixMonths,
      isTrial: false,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlanIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.26,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : isCurrentPlan
                ? Colors.blue.shade300
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentPlan)
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              plan['name'],
              style: TextStyle(
                fontSize: 10,
                color: isCurrentPlan
                    ? Colors.blue.shade700
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '₹$price',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              isYearly ? '/Year' : (isSixMonths ? '/6 Months' : '/Month'),
              style: const TextStyle(fontSize: 8, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final user = AuthStateService.instance.currentUser;
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          ThemeService.instance.databaseName;

      if (user == null) {
        return; // Allow new users to start trial
      }

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You have already used your free trial. Please select a paid plan.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          throw Exception('Trial already used');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void _handlePlanSelection(
    BuildContext context,
    Map<String, dynamic> selectedPlan, {
    bool isYearly = false,
    bool isSixMonths = false,
    bool isTrial = false,
  }) async {
    final price =
        ((isTrial
                    ? selectedPlan['price']
                    : (isYearly
                          ? selectedPlan['yearlyPrice']
                          : (isSixMonths
                                ? selectedPlan['sixMonthPrice']
                                : selectedPlan['monthlyPrice'])))
                as num?)
            ?.toInt() ??
        0;
    final originalPrice =
        ((isTrial
                    ? selectedPlan['originalPrice']
                    : (isYearly
                          ? selectedPlan['yearlyOriginalPrice']
                          : (isSixMonths
                                ? selectedPlan['sixMonthOriginalPrice']
                                : selectedPlan['monthlyOriginalPrice'])))
                as num?)
            ?.toInt();

    if (isTrial) {
      // Check trial eligibility first
      try {
        await _checkTrialEligibility();
      } catch (e) {
        return; // Trial already used, error shown to user
      }

      // Bypass Payment and Go directly to Customization
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrandingCustomizationScreen(
              planName: selectedPlan['name'],
              price: price,
              originalPrice: originalPrice,
              isYearly: isYearly,
              isSixMonths: isSixMonths,
              paymentMethod: 'Free Trial',
              transactionId: 'trial_${DateTime.now().millisecondsSinceEpoch}',
              limits: selectedPlan['limits'],
              geoLocation: selectedPlan['geoLocation'],
              attendance: selectedPlan['attendance'],
              barcode: selectedPlan['barcode'],
              reportExport: selectedPlan['reportExport'],
              pendingUserData: widget.pendingUserData,
            ),
          ),
        );
      }
      return;
    }

    // Direct navigation to Payment Screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            planName: selectedPlan['name'],
            price: price,
            originalPrice: originalPrice,
            isYearly: isYearly,
            isSixMonths: isSixMonths,
            // Correctly distinguish new users from existing users.
            // New users have pendingUserData because their Auth/Firestore records aren't created yet.
            isFirstTimeRegistration: widget.pendingUserData != null,
            limits: selectedPlan['limits'],
            geoLocation: selectedPlan['geoLocation'],
            attendance: selectedPlan['attendance'],
            barcode: selectedPlan['barcode'],
            reportExport: selectedPlan['reportExport'],
            pendingUserData: widget.pendingUserData,
            hasActiveSubscription: widget.currentPlanName != null && widget.currentPlanName!.isNotEmpty,
            currentActivePlanName: widget.currentPlanName,
            activePlanExpiryDate: widget.remainingDays != null ? DateTime.now().add(Duration(days: widget.remainingDays!)) : null,
          ),
        ),
      );
    }
  }
}
