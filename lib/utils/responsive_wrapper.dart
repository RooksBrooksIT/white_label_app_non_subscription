import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ─── Breakpoints ─────────────────────────────────────────────────────────────
const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1024.0;
const double kMaxContentWidth = 960.0;
const double kMaxFormWidth = 480.0;
const double kMaxCardWidth = 560.0;
const double kMaxWebContainerWidth = 1100.0;

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
      child: SizedBox(
        width: double.infinity,
        child: child,
      ),
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

// ─── WebResponsiveLayoutWrapper ───────────────────────────────────────────────
/// Centers the application screen content horizontally with equal margins on web.
/// Prevents the layout from stretching across ultra-wide desktop monitors while
/// preserving 100% responsive fluid behavior on smaller windows and mobile devices.
class WebResponsiveLayoutWrapper extends StatelessWidget {
  const WebResponsiveLayoutWrapper({
    super.key,
    required this.child,
    this.maxWidth = kMaxWebContainerWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Clean neutral canvas background for web browser side gutters
    final canvasBg = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // If the browser window is narrower than maxWidth, display full width seamlessly
        if (screenWidth <= maxWidth) {
          return child;
        }

        final containerWidth = maxWidth;
        final mediaQuery = MediaQuery.of(context);

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: canvasBg,
          child: Center(
            child: Container(
              width: containerWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: ClipRect(
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    size: Size(containerWidth, mediaQuery.size.height),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
