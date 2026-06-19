import 'package:flutter/material.dart';

// ─── Breakpoints ─────────────────────────────────────────────────────────────
const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1024.0;
const double kMaxContentWidth = 960.0;
const double kMaxFormWidth = 480.0;
const double kMaxCardWidth = 560.0;

// ─── BuildContext Extension ───────────────────────────────────────────────────
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isMobile => screenWidth < kMobileBreakpoint;
  bool get isTablet =>
      screenWidth >= kMobileBreakpoint && screenWidth < kTabletBreakpoint;
  bool get isDesktop => screenWidth >= kTabletBreakpoint;

  /// Horizontal padding: 16 mobile, 24 tablet, 48 desktop
  double get responsiveHPadding {
    if (isDesktop) return 48.0;
    if (isTablet) return 32.0;
    return 16.0;
  }

  /// Safe horizontal padding for form containers
  double get formHPadding {
    if (isDesktop) return 24.0;
    if (isTablet) return 24.0;
    return 24.0;
  }
}

// ─── ResponsiveWrapper ────────────────────────────────────────────────────────
/// Centers [child] and constrains its width to [maxWidth].
/// Perfect for dashboard content, list views, and any scrollable body.
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Align(alignment: alignment, child: content);
  }
}

// ─── ResponsiveFormWrapper ────────────────────────────────────────────────────
/// Centers a form card and constrains its width.
/// Wraps in a [Center] so it looks like a modal card on wide screens.
class ResponsiveFormWrapper extends StatelessWidget {
  const ResponsiveFormWrapper({
    super.key,
    required this.child,
    this.maxWidth = kMaxFormWidth,
    this.horizontalPadding = 24.0,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

// ─── Responsive Horizontal Padding helper ────────────────────────────────────
/// Returns [EdgeInsets.symmetric] horizontal padding adapted to screen size.
EdgeInsets responsivePadding(BuildContext context, {double vertical = 0}) {
  return EdgeInsets.symmetric(
    horizontal: context.responsiveHPadding,
    vertical: vertical,
  );
}

// ─── Responsive Font Size ─────────────────────────────────────────────────────
/// Returns a font size that scales slightly on larger screens.
double responsiveFontSize(
  BuildContext context, {
  required double mobile,
  double? tablet,
  double? desktop,
}) {
  if (context.isDesktop) return desktop ?? (mobile * 1.1);
  if (context.isTablet) return tablet ?? (mobile * 1.05);
  return mobile;
}
