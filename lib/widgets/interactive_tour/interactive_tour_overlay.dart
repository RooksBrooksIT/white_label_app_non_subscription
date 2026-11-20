import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/app_tour_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/widgets/interactive_tour/tour_step_model.dart';

class InteractiveTourOverlay extends StatefulWidget {
  final AppTourService service;

  const InteractiveTourOverlay({
    super.key,
    required this.service,
  });

  @override
  State<InteractiveTourOverlay> createState() => _InteractiveTourOverlayState();
}

class _InteractiveTourOverlayState extends State<InteractiveTourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    widget.service.addListener(_onServiceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateAndScrollTarget();
    });
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      _locateAndScrollTarget();
    }
  }

  Future<void> _locateAndScrollTarget() async {
    final step = widget.service.currentStep;
    if (step == null) return;

    final targetContext = step.targetKey.currentContext;
    if (targetContext != null && targetContext.mounted) {
      if (step.autoScroll) {
        try {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: 0.35,
          );
        } catch (_) {}
      }

      if (!mounted || !targetContext.mounted) return;
      final renderBox = targetContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        setState(() {
          _targetRect = position & size;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _targetRect = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.service.currentStep;
    if (step == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final primaryColor = step.accentColor ?? ThemeService.instance.primaryColor;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Spotlight Canvas Cutout with Touch Blocker to prevent unwanted clicks underneath
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // Blocks underlying touches
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SpotlightPainter(
                      targetRect: _targetRect,
                      pulseProgress: _pulseController.value,
                      accentColor: primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),

          // Tap gesture on cutout to interact/advance
          if (_targetRect != null)
            Positioned(
              left: math.max(0.0, _targetRect!.left - 10),
              top: math.max(0.0, _targetRect!.top - 10),
              width: _targetRect!.width + 20,
              height: _targetRect!.height + 20,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (step.onTargetAction != null) {
                    step.onTargetAction!();
                  } else {
                    widget.service.nextStep();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // Floating Smart Information Card
          _buildFloatingInfoCard(
            context: context,
            step: step,
            screenSize: screenSize,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingInfoCard({
    required BuildContext context,
    required TourStep step,
    required Size screenSize,
    required Color primaryColor,
  }) {
    final currentIndex = widget.service.currentStepIndex + 1;
    final totalSteps = widget.service.totalSteps;
    final isLastStep = currentIndex == totalSteps;

    // Calculate smart vertical position
    double? top;
    double? bottom;

    final target = _targetRect;
    final padding = MediaQuery.of(context).padding;

    if (target != null) {
      final targetMidY = target.top + (target.height / 2);
      final screenHeight = screenSize.height;

      // If target is in the top 55% of the screen, show card BELOW it
      if (targetMidY < screenHeight * 0.55) {
        top = target.bottom + 16;
        if (top + 280 > screenHeight - padding.bottom) {
          top = null;
          bottom = 16 + padding.bottom;
        }
      } else {
        // If target is in the bottom half, show card ABOVE it
        bottom = (screenHeight - target.top) + 16;
        if (bottom + 280 > screenHeight - padding.top) {
          bottom = null;
          top = 16 + padding.top;
        }
      }
    } else {
      // Centered fallback
      top = (screenSize.height / 2) - 130;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Container(
              key: ValueKey(step.id),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Step Badge & Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              step.icon ?? Icons.explore_rounded,
                              size: 13,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              step.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$currentIndex of $totalSteps',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Skip Icon Button
                      InkWell(
                        onTap: () => widget.service.dismissTour(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Title
                  Text(
                    step.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    step.description,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.45,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  // Visual Mini Workflow Diagram (if provided)
                  if (step.workflowSteps != null &&
                      step.workflowSteps!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildVisualWorkflowDiagram(
                      workflowSteps: step.workflowSteps!,
                      activeIndex: step.currentWorkflowIndex ?? 0,
                      primaryColor: primaryColor,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Footer Controls
                  Row(
                    children: [
                      // Back Button
                      if (widget.service.currentStepIndex > 0) ...[
                        OutlinedButton(
                          onPressed: () => widget.service.previousStep(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left_rounded, size: 18),
                              Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        TextButton(
                          onPressed: () => widget.service.dismissTour(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'Skip Tour',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Custom Target Action Button (Optional)
                      if (step.actionButtonText != null &&
                          step.onTargetAction != null) ...[
                        OutlinedButton(
                          onPressed: step.onTargetAction,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            step.actionButtonText!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Next / Finish Button
                      ElevatedButton(
                        onPressed: () => widget.service.nextStep(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLastStep ? 'Finish' : 'Next',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isLastStep
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              size: 18,
                            ),
                          ],
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
  }

  /// Renders a horizontal/wrapped visual flowchart diagram of workflow milestones.
  Widget _buildVisualWorkflowDiagram({
    required List<String> workflowSteps,
    required int activeIndex,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 13, color: primaryColor),
              const SizedBox(width: 5),
              Text(
                'WORKFLOW LIFECYCLE',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < workflowSteps.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: i == activeIndex
                          ? primaryColor
                          : (i < activeIndex
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i == activeIndex
                            ? primaryColor
                            : (i < activeIndex
                                ? primaryColor.withValues(alpha: 0.4)
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      workflowSteps[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: i == activeIndex
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: i == activeIndex
                            ? Colors.white
                            : (i < activeIndex
                                ? primaryColor
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  if (i < workflowSteps.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: i < activeIndex
                            ? primaryColor
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates the darkened overlay and cuts out a squircle spotlight.
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseProgress;
  final Color accentColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.pulseProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color(0xCC090D16)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      return;
    }

    // Expand target rect slightly for padding
    const padding = 8.0;
    final expandedRect = Rect.fromLTRB(
      math.max(0.0, targetRect!.left - padding),
      math.max(0.0, targetRect!.top - padding),
      math.min(size.width, targetRect!.right + padding),
      math.min(size.height, targetRect!.bottom + padding),
    );

    final rrect = RRect.fromRectAndRadius(
      expandedRect,
      const Radius.circular(20),
    );

    // Cutout path
    final screenPath = Path()..addRect(Offset.zero & size);
    final targetPath = Path()..addRRect(rrect);
    final cutoutPath = Path.combine(
      PathOperation.difference,
      screenPath,
      targetPath,
    );

    canvas.drawPath(cutoutPath, backgroundPaint);

    // Pulsing glowing border
    final pulseScale = 1.0 + (pulseProgress * 0.04);
    final pulseAlpha = (1.0 - pulseProgress) * 0.65;

    final glowBorderPaint = Paint()
      ..color = accentColor.withValues(alpha: pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * pulseScale;

    canvas.drawRRect(rrect, glowBorderPaint);

    // Inner sharp border
    final sharpBorderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(rrect, sharpBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.accentColor != accentColor;
  }
}
