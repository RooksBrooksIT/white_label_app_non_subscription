import 'package:flutter/material.dart';
import 'subscription_plans_screen.dart';

/// SubscriptionPage - modern SaaS Subscription Screen
class SubscriptionPage extends StatelessWidget {
  final String? currentPlanName;
  final bool hideTrial;
  final int? remainingDays;
  final String? billingCycle;
  final Map<String, dynamic>? pendingUserData;

  const SubscriptionPage({
    super.key,
    this.currentPlanName,
    this.hideTrial = false,
    this.remainingDays,
    this.billingCycle,
    this.pendingUserData,
  });

  @override
  Widget build(BuildContext context) {
    return SubscriptionPlansScreen(
      currentPlanName: currentPlanName,
      hideTrial: hideTrial,
      remainingDays: remainingDays,
      billingCycle: billingCycle,
      pendingUserData: pendingUserData,
    );
  }
}

