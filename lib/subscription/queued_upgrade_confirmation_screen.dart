/// Flutter Screen: Queued Upgrade Confirmation
/// File: lib/subscription/queued_upgrade_confirmation_screen.dart
///
/// Shown after a successful payment where the user chose to queue the upgrade.
/// Displays current plan, queued plan, and scheduled activation date.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';

class QueuedUpgradeConfirmationScreen extends StatelessWidget {
  /// The name of the newly purchased (queued) plan.
  final String newPlanName;

  /// The name of the currently active plan.
  final String currentPlanName;

  /// The date when the queued plan will auto-activate (= active plan expiry).
  final DateTime? scheduledActivationDate;

  /// Amount paid for the queued plan.
  final int amountPaid;

  /// Transaction ID of the queued payment.
  final String transactionId;

  /// Billing cycle flag.
  final bool isYearly;
  final bool isSixMonths;

  const QueuedUpgradeConfirmationScreen({
    super.key,
    required this.newPlanName,
    required this.currentPlanName,
    required this.amountPaid,
    required this.transactionId,
    this.scheduledActivationDate,
    this.isYearly = false,
    this.isSixMonths = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedActivation = scheduledActivationDate != null
        ? DateFormat('d MMM yyyy').format(scheduledActivationDate!)
        : 'After current plan expires';

    final billingCycle =
        isYearly ? 'Yearly' : (isSixMonths ? '6 Months' : 'Monthly');

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.blueAccent,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ── Queued Icon ──────────────────────────────────────────────
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF00B894)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Title ────────────────────────────────────────────────────
                const Text(
                  'UPGRADE QUEUED!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your $newPlanName plan is ready and waiting.\nIt will activate automatically on $formattedActivation.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // ── Timeline Card ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PLAN TIMELINE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Current plan row
                      _buildTimelineRow(
                        icon: Icons.verified_rounded,
                        iconColor: Colors.green,
                        label: 'Currently Active',
                        value: currentPlanName,
                        badge: 'ACTIVE',
                        badgeColor: Colors.green,
                      ),

                      // Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 56),
                            Column(
                              children: [
                                Container(
                                  width: 2,
                                  height: 16,
                                  color: Colors.grey.shade300,
                                ),
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                                Container(
                                  width: 2,
                                  height: 16,
                                  color: Colors.grey.shade300,
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Expires $formattedActivation',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Queued plan row
                      _buildTimelineRow(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFF6C5CE7),
                        label: 'Queued Upgrade',
                        value: newPlanName,
                        badge: 'QUEUED',
                        badgeColor: const Color(0xFF6C5CE7),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Payment Details ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PAYMENT DETAILS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('STATUS', 'Success', valueColor: Colors.green),
                      _buildDetailRow('TRANSACTION ID', transactionId),
                      _buildDetailRow('AMOUNT PAID', '₹ $amountPaid'),
                      _buildDetailRow('PLAN', '$newPlanName Plan'),
                      _buildDetailRow('BILLING CYCLE', billingCycle),
                      _buildDetailRow('ACTIVATES ON', formattedActivation,
                          valueColor: const Color(0xFF6C5CE7)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Info Banner ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your $currentPlanName plan continues uninterrupted. '
                          'The $newPlanName plan will activate automatically on '
                          '$formattedActivation. You can view or manage this in '
                          'the Manage Subscription section of your account.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A3F99),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Go to Dashboard Button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const admindashboard(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'GO TO DASHBOARD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String badge,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
