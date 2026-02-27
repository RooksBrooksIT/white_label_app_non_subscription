import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/subscription/welcome_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/unified_login_screen.dart';

class AuthSelectionScreen extends StatefulWidget {
  const AuthSelectionScreen({super.key});

  @override
  State<AuthSelectionScreen> createState() => _AuthSelectionScreenState();
}

class _AuthSelectionScreenState extends State<AuthSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoPosition;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Initial logo zoom and fade in
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Logo moves up
    _logoPosition =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.25)).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 0.8, curve: Curves.easeInOutExpo),
          ),
        );

    // Content fade and slide up
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Logo Animation
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.of(context).size.height * _logoPosition.value.dy,
                  ),
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ThemeService.instance.logoUrl != null
                            ? Image.network(
                                ThemeService.instance.logoUrl!,
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                      'assets/images/logo.png',
                                      width: 110,
                                      height: 110,
                                      fit: BoxFit.contain,
                                    ),
                              )
                            : Image.asset(
                                'assets/images/logo.png',
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Main Content (Buttons and Text)
          SafeArea(
            child: FadeTransition(
              opacity: _contentOpacity,
              child: SlideTransition(
                position: _contentSlide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      // Text Section
                      Text(
                        ThemeService.instance.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Elevating your experience with\n${ThemeService.instance.appName}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(flex: 3),

                      // Action Buttons
                      Column(
                        children: [
                          _buildButton(
                            label: 'Log In',
                            color: Colors.black,
                            textColor: Colors.black,
                            isOutlined: true,
                            onPressed: () =>
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UnifiedLoginScreen(),
                                    // const WelcomeScreen(),
                                  ),
                                ).then(
                                  (_) => setState(() {}),
                                ), // Refresh state after returning
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Conditional Log In Button
                      // Opacity(
                      //   opacity: AuthStateService.instance.isRegistered
                      //       ? 1.0
                      //       : 0.5,
                      //   child: _buildButton(
                      //     label: 'Log In',
                      //     color: Theme.of(context).primaryColor,
                      //     textColor: Colors.white,
                      //     onPressed: AuthStateService.instance.isRegistered
                      //         ? () => Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (_) => const UnifiedLoginScreen(),
                      //             ),
                      //           )
                      //         : () {
                      //             ScaffoldMessenger.of(context).showSnackBar(
                      //               const SnackBar(
                      //                 content: Text(
                      //                   'Please register first to enable login.',
                      //                 ),
                      //               ),
                      //             );
                      //           },
                      //   ),
                      // ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                            ),
                            child: Text(
                              "Register",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: isOutlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: Colors.grey[300]!, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: textColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
