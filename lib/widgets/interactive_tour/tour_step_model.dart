import 'package:flutter/material.dart';

/// Represents a single interactive spotlight step in the guided tour.
class TourStep {
  final String id;
  final GlobalKey targetKey;
  final String category;
  final String title;
  final String description;
  final List<String>? workflowSteps;
  final int? currentWorkflowIndex;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTargetAction;
  final String? actionButtonText;
  final bool autoScroll;

  const TourStep({
    required this.id,
    required this.targetKey,
    required this.category,
    required this.title,
    required this.description,
    this.workflowSteps,
    this.currentWorkflowIndex,
    this.icon,
    this.accentColor,
    this.onTargetAction,
    this.actionButtonText,
    this.autoScroll = true,
  });
}
