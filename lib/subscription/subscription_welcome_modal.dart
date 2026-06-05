import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanDetails {
  final String name;
  final String title;
  final String message;
  final List<String> features;
  final Map<String, dynamic> limits;
  final Color color;
  final String billingCycle;
  final bool isTrial;

  PlanDetails({
    required this.name,
    required this.title,
    required this.message,
    required this.features,
    required this.limits,
    required this.color,
    required this.billingCycle,
    required this.isTrial,
  });
}

class SubscriptionWelcomeModal extends StatefulWidget {
  final PlanDetails plan;
  final VoidCallback onClose;

  const SubscriptionWelcomeModal({
    super.key,
    required this.plan,
    required this.onClose,
  });

  @override
  State<SubscriptionWelcomeModal> createState() =>
      _SubscriptionWelcomeModalState();
}

class _SubscriptionWelcomeModalState extends State<SubscriptionWelcomeModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markAsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = ThemeService.instance.databaseName;
    await prefs.setString('last_viewed_plan_$tenantId', widget.plan.name);
    await prefs.setString(
      'last_viewed_plan_timestamp_$tenantId',
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textPrimaryColor = isDarkMode ? Colors.white : Colors.black87;
    final textSecondaryColor = isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Confetti / Header
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: widget.plan.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.celebration,
                            size: 40,
                            color: widget.plan.color,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          widget.plan.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Plan Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.plan.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: widget.plan.color,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            widget.plan.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: widget.plan.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Plan Summary
                        _buildSummaryRow(
                          context,
                          'Current Plan',
                          widget.plan.name,
                          textPrimaryColor,
                          textSecondaryColor,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          context,
                          'Billing Cycle',
                          widget.plan.billingCycle,
                          textPrimaryColor,
                          textSecondaryColor,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          context,
                          'Status',
                          'Active',
                          Colors.green.shade700,
                          textSecondaryColor,
                        ),
                        const SizedBox(height: 24),

                        // Benefits Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'What you get:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...widget.plan.features.map((feature) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: widget.plan.color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),

                        // Limits Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: widget.plan.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Your Plan Limits',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildLimitItem(
                                    'Customers',
                                    widget.plan.limits['maxCustomers'] == -1
                                        ? 'Unlimited'
                                        : '${widget.plan.limits['maxCustomers'] ?? 0}',
                                    widget.plan.color,
                                  ),
                                  _buildLimitItem(
                                    'Engineers',
                                    widget.plan.limits['maxEngineers'] == -1
                                        ? 'Unlimited'
                                        : '${widget.plan.limits['maxEngineers'] ?? 0}',
                                    widget.plan.color,
                                  ),
                                  _buildLimitItem(
                                    'Storage',
                                    widget.plan.limits['maxStorageGB'] == -1
                                        ? 'Unlimited'
                                        : '${widget.plan.limits['maxStorageGB'] ?? 0}GB',
                                    widget.plan.color,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Plan Message
                        Text(
                          widget.plan.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _markAsViewed();
                                  widget.onClose();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      ThemeService.instance.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Continue to Dashboard',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLimitItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
