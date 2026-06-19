import 'dart:ui';
import 'package:flutter/material.dart';

class SubscriptionWelcomeModal extends StatelessWidget {
  final String planName;
  final String billingCycle;
  final String status;
  final VoidCallback onContinue;
  final VoidCallback onViewDetails;

  const SubscriptionWelcomeModal({
    super.key,
    required this.planName,
    required this.billingCycle,
    required this.status,
    required this.onContinue,
    required this.onViewDetails,
  });

  // Helper to resolve plan color dynamically
  Color _getPlanColor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) return const Color(0xFF9E9E9E); // Silver
    if (lowerName.contains('gold')) return const Color(0xFFFFD700); // Gold
    if (lowerName.contains('platinum')) return const Color(0xFF607D8B); // Platinum / Steel Blue
    if (lowerName.contains('trial')) return const Color(0xFF2196F3); // Free Trial Blue
    return const Color(0xFF6C5CE7); // Default premium purple
  }

  // Get plan summary message
  String _getPlanMessage(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return 'Perfect for small teams and basic operations.';
    }
    if (lowerName.contains('gold')) {
      return 'Ideal for growing businesses requiring advanced tracking and reporting.';
    }
    if (lowerName.contains('platinum')) {
      return 'You now have access to all premium platform features.';
    }
    if (lowerName.contains('trial')) {
      return 'Explore all premium features free for 7 days.';
    }
    return 'Thank you for subscribing to our premium features!';
  }

  // Get plan benefits
  List<String> _getPlanBenefits(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return [
        'Up to 20 Customers',
        'Up to 5 Engineers',
        '1GB Storage',
        'Web Support',
        'Basic Dashboard',
        'Standard Email Support',
      ];
    }
    if (lowerName.contains('gold')) {
      return [
        'Up to 50 Customers',
        'Up to 10 Engineers',
        '5GB Storage',
        'Geo Location Enabled',
        'Report Export Available',
        'Priority Support',
      ];
    }
    if (lowerName.contains('platinum')) {
      return [
        'Unlimited Customers',
        'Unlimited Engineers',
        'Unlimited Photos & PDFs',
        'Geo Location Enabled',
        'Attendance System',
        'Barcode System',
        'Report Export',
        '100GB Storage',
        'Premium Priority Support',
      ];
    }
    // Trial plan benefits
    return [
      'Access to all Gold Features',
      'Geo Location Enabled',
      'Attendance Enabled',
      'Barcode Enabled',
      'Report Export Available',
      '50 Customers',
      '10 Engineers',
      '5GB Storage',
    ];
  }

  // Get plan limits details
  Map<String, String> _getPlanLimits(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return {
        'Customers': '20 Allowed',
        'Engineers': '5 Allowed',
        'Storage': '1 GB Capacity',
      };
    }
    if (lowerName.contains('gold')) {
      return {
        'Customers': '50 Allowed',
        'Engineers': '10 Allowed',
        'Storage': '5 GB Capacity',
      };
    }
    if (lowerName.contains('platinum')) {
      return {
        'Customers': 'Unlimited',
        'Engineers': 'Unlimited',
        'Storage': '100 GB Capacity',
      };
    }
    // Trial limits
    return {
      'Customers': '50 Allowed',
      'Engineers': '10 Allowed',
      'Storage': '5 GB Capacity',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final planColor = _getPlanColor(planName);
    final message = _getPlanMessage(planName);
    final benefits = _getPlanBenefits(planName);
    final limits = _getPlanLimits(planName);

    final titlePrefix = planName.toLowerCase().contains('trial')
        ? 'Welcome to Your 7-Day Free Trial'
        : 'Welcome to the $planName Plan';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900]!.withOpacity(0.9) : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Accent Gradient
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [planColor.withOpacity(0.6), planColor, planColor.withOpacity(0.8)],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      children: [
                        // 🎉 Congratulations Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '🎉',
                              style: TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Congratulations!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: planColor,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title with Plan Name
                        Text(
                          titlePrefix,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Plan Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: planColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: planColor.withOpacity(0.4), width: 1.5),
                          ),
                          child: Text(
                            planName.toUpperCase(),
                            style: TextStyle(
                              color: planColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Plan Summary Block
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850]!.withOpacity(0.5) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                context,
                                'Billing Cycle',
                                billingCycle,
                                Icons.calendar_today_rounded,
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                              ),
                              _buildSummaryItem(
                                context,
                                'Status',
                                status,
                                Icons.verified_user_rounded,
                                valueColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Benefits Section Title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'What\'s Included',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Benefits list
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: benefits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    benefits[index],
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Usage Limits Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [Colors.grey[850]!, Colors.grey[900]!]
                                  : [Colors.blue.shade50.withOpacity(0.5), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: planColor.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speed_rounded, color: planColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Plan Limits & Capacity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: limits.entries.map((entry) {
                                  return Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.value,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Additional Message / Subtitle
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Action Buttons
                        ElevatedButton(
                          onPressed: onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: planColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: planColor.withOpacity(0.5),
                          ),
                          child: const Text(
                            'Continue to Dashboard',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: onViewDetails,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'View Subscription Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
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
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
