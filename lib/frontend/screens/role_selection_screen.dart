import 'package:flutter/material.dart';
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
    {'id': 'Owner', 'label': 'Owner', 'icon': Icons.business_center_rounded},
    {'id': 'Worker', 'label': 'Worker', 'icon': Icons.engineering_rounded},
    {'id': 'Customer', 'label': 'Customer', 'icon': Icons.person_rounded},
  ];

  void _onContinue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role to continue.'),
          backgroundColor: Colors.black,
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

    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header section with Dynamic Logo support
                ListenableBuilder(
                  listenable: ThemeService.instance,
                  builder: (context, _) {
                    if (ThemeService.instance.logoUrl != null) {
                      return Image.network(
                        ThemeService.instance.logoUrl!,
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.account_circle, size: 80),
                      );
                    }
                    return Icon(
                      Icons.account_circle_outlined,
                      size: 80,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "Select Your Role",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Choose how you would like to proceed with the platform.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: theme.hintColor),
                ),
                const SizedBox(height: 48),

                // Role Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _roles.map((role) {
                    final isSelected = _selectedRole == role['id'];
                    return _RoleItem(
                      label: role['label'],
                      icon: role['icon'],
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedRole = role['id'];
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 60),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor : theme.dividerColor,
                width: 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(
              icon,
              size: 36,
              color: isSelected
                  ? Colors.white
                  : theme.iconTheme.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? primaryColor : theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
