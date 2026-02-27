import 'package:flutter/material.dart';
import 'dart:ui';
import 'payment_screen.dart';
import 'branding_customization_screen.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  /// Optionally pass the admin's current plan name to highlight it on the screen.
  final String? currentPlanName;

  /// When true, hides the Free Trial tab (used when admin is changing an existing plan).
  final bool hideTrial;

  const SubscriptionPlansScreen({
    super.key,
    this.currentPlanName,
    this.hideTrial = false,
  });

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

enum PlanType { freeTrial, monthly, sixMonths, yearly }

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  PlanType selectedPlanType = PlanType.monthly;
  int selectedPlanIndex = 1; // Default: Gold (Index 1) for Paid plans

  // Plan data for Paid tiers
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Silver Plan',
      'monthlyPrice': 199,
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
      'name': 'Gold Plan',
      'monthlyPrice': 399,
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
      'name': 'Platinum Plan',
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
    'attendance': false,
    'barcode': false,
    'reportExport': true,
    'color': const Color(0xFFE3F2FD),
  };

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
            child: Column(
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
                                if (widget.currentPlanName != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Active: ${widget.currentPlanName}',
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
                            isSixMonths: selectedPlanType == PlanType.sixMonths,
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
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedPlanType == PlanType.freeTrial) {
                          _handlePlanSelection(
                            context,
                            trialPlan,
                            isTrial: true,
                          );
                        } else {
                          _handlePlanSelection(
                            context,
                            plans[selectedPlanIndex],
                            isYearly: selectedPlanType == PlanType.yearly,
                            isSixMonths: selectedPlanType == PlanType.sixMonths,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        selectedPlanType == PlanType.freeTrial
                            ? 'Start 7-Day Free Trial'
                            : 'Subscribe now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
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
    final isCurrentPlan =
        widget.currentPlanName != null &&
        plan['name'] == widget.currentPlanName;

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
        child: Column(
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
            Expanded(
              child: ListView.builder(
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
            ),
          ],
        ),
      ),
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
    final isCurrentPlan =
        widget.currentPlanName != null &&
        plan['name'] == widget.currentPlanName;

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

  void _handlePlanSelection(
    BuildContext context,
    Map<String, dynamic> selectedPlan, {
    bool isYearly = false,
    bool isSixMonths = false,
    bool isTrial = false,
  }) {
    final price = isTrial
        ? selectedPlan['price']
        : (isYearly
              ? selectedPlan['yearlyPrice']
              : (isSixMonths
                    ? selectedPlan['sixMonthPrice']
                    : selectedPlan['monthlyPrice']));
    final originalPrice = isTrial
        ? selectedPlan['originalPrice']
        : (isYearly
              ? selectedPlan['yearlyOriginalPrice']
              : (isSixMonths
                    ? selectedPlan['sixMonthOriginalPrice']
                    : selectedPlan['monthlyOriginalPrice']));

    if (isTrial) {
      // Bypass Payment and Go directly to Customization
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
          ),
        ),
      );
      return;
    }

    // Navigate to Payment Screen for Paid Plans
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          planName: selectedPlan['name'],
          price: price,
          originalPrice: originalPrice,
          isYearly: isYearly,
          isSixMonths: isSixMonths,
          isFirstTimeRegistration: widget.currentPlanName == null,
          limits: selectedPlan['limits'],
          geoLocation: selectedPlan['geoLocation'],
          attendance: selectedPlan['attendance'],
          barcode: selectedPlan['barcode'],
          reportExport: selectedPlan['reportExport'],
        ),
      ),
    );
  }
}
