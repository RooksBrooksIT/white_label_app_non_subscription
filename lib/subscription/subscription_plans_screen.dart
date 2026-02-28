import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
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

enum PlanType { freeTrial, enterprise }

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  PlanType selectedPlanType = PlanType.freeTrial;
  int selectedPlanIndex = 0;

  // Data for Trial tier
  final Map<String, dynamic> trialPlan = {
    'name': '30-Day Free Trial',
    'price': 0,
    'originalPrice': 0,
    'subtitle': 'Full access to premium features for 30 days',
    'limits': {
      'maxCustomers': -1,
      'maxEngineers': -1,
      'maxPhotosPerCustomer': -1,
      'maxPdfUploadsPerCustomer': -1,
      'maxStorageGB': 100,
    },
    'features': [
      'Unlimited Customers',
      'Unlimited Engineers',
      '100GB Storage',
      'Web Support',
      'Geo Location Enabled',
      'Priority Support',
    ],
    'geoLocation': true,
    'attendance': true,
    'barcode': true,
    'reportExport': true,
    'color': const Color(0xFFE3F2FD),
  };

  final Map<String, dynamic> enterprisePlan = {
    'name': 'Enterprise Mode',
    'subtitle': 'Custom solutions for your large-scale business',
    'contact': {
      'email': 'info@rookstechnologies.com',
      'whatsapp': '+91 8925633099',
      'phone': '+91 8925633099',
    },
    'features': [
      'Dedicated Account Manager',
      'Custom Feature Development',
      'On-premise Deployment Options',
      '24/7 Premium Support',
      'SLA Guarantees',
    ],
    'color': const Color(0xFFF3E5F5),
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
                        _buildTab(PlanType.enterprise, 'Enterprise'),
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
                        : _buildEnterpriseCard(enterprisePlan),
                  ),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 20),

                const SizedBox(height: 20),

                // Subscribe Button
                if (selectedPlanType == PlanType.freeTrial)
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
                          _handlePlanSelection(
                            context,
                            trialPlan,
                            isTrial: true,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Start One-Month Free Trial',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Text(
                      'Contact us to enable Enterprise Mode',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
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
    final durationLabel = '/30 Days';
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

  Widget _buildEnterpriseCard(Map<String, dynamic> plan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 235, 235, 235),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              plan['name'],
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              plan['subtitle'],
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildContactItem(
              Icons.email,
              'Email',
              plan['contact']['email'],
              onTap: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: plan['contact']['email'],
                );
                await launchUrl(emailLaunchUri);
              },
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              Icons.chat,
              'WhatsApp',
              plan['contact']['whatsapp'],
              onTap: () async {
                final String phone = plan['contact']['whatsapp']
                    .replaceAll(RegExp(r'\s+'), '')
                    .replaceAll('+', '');
                final Uri whatsappUri = Uri.parse("https://wa.me/$phone");
                if (await canLaunchUrl(whatsappUri)) {
                  await launchUrl(
                    whatsappUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              Icons.phone,
              'Phone',
              plan['contact']['phone'],
              onTap: () async {
                final Uri phoneUri = Uri(
                  scheme: 'tel',
                  path: plan['contact']['phone'],
                );
                await launchUrl(phoneUri);
              },
            ),
            const SizedBox(height: 30),
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
                          Icons.star,
                          size: 20,
                          color: Colors.deepPurple,
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

  Widget _buildContactItem(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
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
    final price = selectedPlan['price'] ?? 0;
    final originalPrice = selectedPlan['originalPrice'] ?? 0;

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
  }
}
