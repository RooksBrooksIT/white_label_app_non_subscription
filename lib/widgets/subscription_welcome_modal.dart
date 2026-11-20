import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

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
    if (lowerName.contains('silver')) return const Color(0xFF64748B); // Slate Silver
    if (lowerName.contains('gold')) return const Color(0xFFF59E0B); // Amber Gold
    if (lowerName.contains('platinum')) return const Color(0xFF6366F1); // Indigo Platinum
    if (lowerName.contains('trial')) return const Color(0xFF0EA5E9); // Sky Blue Trial
    return const Color(0xFF0F172A); // Default Slate
  }

  List<Color> _getPlanGradient(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
    if (lowerName.contains('gold')) {
      return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    }
    if (lowerName.contains('platinum')) {
      return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
    }
    if (lowerName.contains('trial')) {
      return [const Color(0xFF0EA5E9), const Color(0xFF0284C7)];
    }
    return [const Color(0xFF1E293B), const Color(0xFF0F172A)];
  }

  // Get plan summary message
  String _getPlanMessage(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return 'Ideal for small teams and core service dispatch workflows.';
    }
    if (lowerName.contains('gold')) {
      return 'Tailored for growing teams needing geo-tracking and report exports.';
    }
    if (lowerName.contains('platinum')) {
      return 'Unrestricted enterprise scale with full feature access.';
    }
    if (lowerName.contains('trial')) {
      return 'Explore all premium features free for your 7-day trial period.';
    }
    return 'Your subscription is now active and ready to use.';
  }

  // Get plan benefits
  List<String> _getPlanBenefits(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return [
        'Up to 20 Customers',
        'Up to 5 Engineers',
        '1GB Cloud Storage',
        'Web Support Portal',
        'Standard Email Support',
        'Basic Operations Dashboard',
      ];
    }
    if (lowerName.contains('gold')) {
      return [
        'Up to 50 Customers',
        'Up to 10 Engineers',
        '5GB Cloud Storage',
        'Live Geo-Location Enabled',
        'Detailed Report Exporting',
        'Priority Technical Support',
      ];
    }
    if (lowerName.contains('platinum')) {
      return [
        'Unlimited Customers & Engineers',
        '100GB Cloud Storage',
        'GPS Geo-Location Tracking',
        'Automated Attendance System',
        'Barcode / QR Code Management',
        'Full Report Export & Analytics',
        '24/7 Dedicated Priority Support',
      ];
    }
    return [
      'Access to All Gold Features',
      'Live Geo-Location Tracking',
      'Engineer Attendance Management',
      'Barcode Scanning & Search',
      '50 Customers & 10 Engineers',
      '5GB Cloud Storage Included',
    ];
  }

  // Get plan limits details
  Map<String, String> _getPlanLimits(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('silver')) {
      return {
        'Customers': '20 Allowed',
        'Engineers': '5 Allowed',
        'Storage': '1 GB',
      };
    }
    if (lowerName.contains('gold')) {
      return {
        'Customers': '50 Allowed',
        'Engineers': '10 Allowed',
        'Storage': '5 GB',
      };
    }
    if (lowerName.contains('platinum')) {
      return {
        'Customers': 'Unlimited',
        'Engineers': 'Unlimited',
        'Storage': '100 GB',
      };
    }
    return {
      'Customers': '50 Allowed',
      'Engineers': '10 Allowed',
      'Storage': '5 GB',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = ThemeService.instance.primaryColor;

    final planColor = _getPlanColor(planName);
    final planGradient = _getPlanGradient(planName);
    final message = _getPlanMessage(planName);
    final benefits = _getPlanBenefits(planName);
    final limits = _getPlanLimits(planName);

    final isTrial = planName.toLowerCase().contains('trial');
    final formattedPlanName = isTrial ? '7-Day Free Trial' : '$planName Plan';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Gradient Accent Strip
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: planGradient,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Celebratory Icon Badge
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: planColor.withValues(alpha: 0.1),
                              ),
                            ),
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: planGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: planColor.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Title
                        Text(
                          'Congratulations!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        Text(
                          'Welcome to the $formattedPlanName',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Plan Tier Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: planGradient,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: planColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            planName.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Status & Billing Dual Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Billing Cycle',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            billingCycle,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Status',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Active',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Capacity & Limits Metrics Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Plan Limits & Capacity',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: limits.entries.map((entry) {
                                  return Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            entry.key,
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.value,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // What's Included Title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "What's Included",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Benefits List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: benefits.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 13,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    benefits[index],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Plan Subtitle / Message
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 22),

                        // High-Contrast Primary CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: primaryColor.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue to Dashboard',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Secondary Details Link
                        TextButton(
                          onPressed: onViewDetails,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'View Subscription Details',
                            style: GoogleFonts.inter(
                              fontSize: 13,
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
}
