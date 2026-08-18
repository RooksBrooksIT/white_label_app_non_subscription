import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/app_update_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _rippleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Snappy entrance animation (0.9s)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
    ));

    _slideAnimation = Tween<double>(
      begin: 18.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    ));

    // 2. Continuous subtle breathing / ripple animation
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _entranceController.forward();
    _handleInitialLaunch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logoUrl = ThemeService.instance.logoUrl;
    if (logoUrl != null &&
        logoUrl.isNotEmpty &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))) {
      precacheImage(NetworkImage(logoUrl), context).catchError((_) {});
    }
  }

  Future<void> _handleInitialLaunch() async {
    Widget target = const RoleSelectionScreen();

    try {
      // Execute initial screen determination, background checks, and minimum 2.0s delay in parallel
      final results = await Future.wait([
        // Task 1: Determine initial screen with a 2.5s safety timeout
        AuthStateService.instance.getInitialScreen().timeout(
          const Duration(milliseconds: 2500),
          onTimeout: () => const RoleSelectionScreen(),
        ),
        // Task 2: Background checks (permissions & update check)
        _performBackgroundChecks(),
        // Task 3: Minimum visual display duration (2000ms) for a perfect 2-3s splash
        Future.delayed(const Duration(milliseconds: 2000)),
      ]);

      target = results[0] as Widget;
    } catch (e) {
      debugPrint('SplashScreen initialization error: $e');
      target = await AuthStateService.instance.getInitialScreen().catchError(
        (_) => const RoleSelectionScreen(),
      );
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _performBackgroundChecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

      if (isFirstLaunch) {
        await _requestPermissions().timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () {},
        );
        await prefs.setBool('is_first_launch', false);
      }

      if (mounted) {
        await AppUpdateService.instance.checkForUpdate(context).timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () {},
        );
      }
    } catch (e) {
      debugPrint('SplashScreen background checks: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // 1. Notification Permission
    await Permission.notification.request();

    // 2. Location Permission
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Error requesting location permission in splash: $e');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;
    final primary = theme.primaryColor;
    final size = MediaQuery.sizeOf(context);
    final logoSize = (size.width * 0.34).clamp(125.0, 170.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16), // Deep premium obsidian slate
        body: Stack(
          children: [
            // ── Background Ambient Radial Flare ──
            Positioned(
              top: size.height * 0.22,
              left: (size.width - size.width * 1.1) / 2,
              child: AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final scale = 1.0 + (_rippleController.value * 0.12);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: size.width * 1.1,
                      height: size.width * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            primary.withValues(alpha: 0.38),
                            primary.withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top-left subtle ambient orb
            Positioned(
              top: -size.width * 0.2,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Center Brand Showcase ──
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Concentric Animated Ripple Rings around Logo
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple Ring 1
                        AnimatedBuilder(
                          animation: _rippleController,
                          builder: (context, child) {
                            final progress = _rippleController.value;
                            return Container(
                              width: logoSize + 55 + (progress * 25),
                              height: logoSize + 55 + (progress * 25),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withValues(
                                    alpha: (1.0 - progress) * 0.35,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),

                        // Ripple Ring 2 (Offset)
                        AnimatedBuilder(
                          animation: _rippleController,
                          builder: (context, child) {
                            final progress = (_rippleController.value + 0.5) % 1.0;
                            return Container(
                              width: logoSize + 30 + (progress * 30),
                              height: logoSize + 30 + (progress * 30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: (1.0 - progress) * 0.22,
                                  ),
                                  width: 1.2,
                                ),
                              ),
                            );
                          },
                        ),

                        // Frosted Logo Badge
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFF1F5F9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.45),
                                    blurRadius: 36,
                                    spreadRadius: 6,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.15),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: ClipOval(
                                  child: _buildInstantLogoWidget(
                                    theme.logoUrl,
                                    primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 38),

                    // App Title with Slide & Fade Transition
                    AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text(
                            theme.appName,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Text(
                              'SERVICE MANAGEMENT SUITE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Modern Glowing Gradient Progress Line
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: 90,
                        height: 3.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              AnimatedBuilder(
                                animation: _rippleController,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment(
                                      -1.5 + (_rippleController.value * 3.0),
                                      0.0,
                                    ),
                                    child: Container(
                                      width: 40,
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            primary,
                                            Colors.white,
                                            primary,
                                            Colors.transparent,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(alpha: 0.8),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Secure Cloud Badge ──
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Secure Enterprise Cloud Platform',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.50),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Multi-format instant logo loader supporting Base64, Asset, File, and Network with zero-latency fallback
  Widget _buildInstantLogoWidget(String? logoUrl, Color primaryColor) {
    if (logoUrl == null || logoUrl.trim().isEmpty) {
      return _buildDefaultLogo();
    }

    final trimmed = logoUrl.trim();

    // 1. Check if it is a Base64 data URL (e.g. data:image/png;base64,...)
    if (trimmed.startsWith('data:image') || trimmed.contains(';base64,')) {
      try {
        final base64String = trimmed.split('base64,').last.trim();
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
        );
      } catch (_) {
        // continue to next formats
      }
    }

    // 2. Check if it is a local asset path
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
      );
    }

    // 3. Check if it is a local file path
    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) {
      try {
        final cleanPath = trimmed.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
          );
        }
      } catch (_) {}
    }

    // 4. Check if it is a raw Base64 string (without data:image prefix)
    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        trimmed.length > 60 &&
        !trimmed.contains(' ')) {
      try {
        final bytes = base64Decode(trimmed);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
        );
      } catch (_) {}
    }

    // 5. Network URL with instant fallback overlay & gapless playback
    return Image.network(
      trimmed,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // While fetching network bytes, render default logo immediately with zero white void
        return _buildDefaultLogo();
      },
      errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
    );
  }

  Widget _buildDefaultLogo() {
    return Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (c, e, s) => Icon(
          Icons.rocket_launch_rounded,
          size: 48,
          color: ThemeService.instance.primaryColor,
        ),
      ),
    );
  }
}
