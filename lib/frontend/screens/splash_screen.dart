import 'dart:async';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final Widget target = await AuthStateService.instance.getInitialScreen();

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;

    return Scaffold(
      backgroundColor: theme.primaryColor, // Solid orange background
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.primaryColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// LOGO SECTION (Exact Image Style)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white, // Outer white ring
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6), // White ring thickness
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300, // Thin grey border
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child:
                            theme.logoUrl != null && theme.logoUrl!.isNotEmpty
                            ? Image.network(
                                theme.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultLogo(),
                              )
                            : _buildDefaultLogo(),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              /// APP NAME
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  theme.appName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// SMALL LINE BELOW NAME
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.rocket_launch_rounded,
        size: 50,
        color: ThemeService.instance.primaryColor,
      ),
    );
  }
}
