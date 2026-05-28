import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/frontend/screens/auth_selection_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_customerlogin_page.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'Owner',
      'label': 'Business Owner',
      'subtitle': 'Manage your organization, staff, and services.',
      'icon': Icons.business_center_rounded,
      'color': const Color(0xFF6366F1),
    },
    {
      'id': 'Worker',
      'label': 'Service Engineer',
      'subtitle': 'Access your tasks, reports, and service tickets.',
      'icon': Icons.engineering_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'id': 'Customer',
      'label': 'Customer',
      'subtitle': 'Book services, track tickets, and view history.',
      'icon': Icons.person_rounded,
      'color': const Color(0xFFF59E0B),
    },
  ];

  void _onContinue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a role to continue.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    Widget targetScreen;
    switch (_selectedRole) {
      case 'Owner':
        targetScreen = const AuthSelectionScreen();
        break;
      case 'Worker':
        targetScreen = const Engineerlogin();
        break;
      case 'Customer':
        targetScreen = const AMCLoginPage();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildDefaultLogo(ThemeData theme) {
    return Icon(
      Icons.rocket_launch_rounded,
      size: 50,
      color: theme.primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ThemeService.instance,
          builder: (context, _) {
            final logoUrl = ThemeService.instance.logoUrl;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo and Branding
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: logoUrl != null && logoUrl.isNotEmpty
                                    ? Image.network(
                                        logoUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildDefaultLogo(theme),
                                      )
                                    : _buildDefaultLogo(theme),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Welcome to ${ThemeService.instance.appName}",
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: theme.textTheme.displayLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please select your access level to begin",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Role Selection List
                        ..._roles.map((role) {
                          final isSelected = _selectedRole == role['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _RoleCard(
                              label: role['label'],
                              subtitle: role['subtitle'],
                              icon: role['icon'],
                              color: role['color'],
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedRole = role['id'];
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Footer Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            shadowColor: primaryColor.withValues(alpha: 0.4),
                          ),
                          child: Text(
                            "Continue",
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.05) : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : theme.dividerColor.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? primaryColor
                          : theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
