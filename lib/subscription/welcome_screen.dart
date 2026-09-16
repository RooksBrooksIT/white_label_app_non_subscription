import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/subscription/subscription_plans_screen.dart';
import 'package:subscription_rooks_app/subscription/terms_and_conditions_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/app_main_page.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1;

  // Form keys and controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final String _selectedRole = 'admin';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasGST = false;

  late final AnimationController _transitionController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutCubic,
      ),
    );
    _transitionController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _gstNumberController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? linkedAppName;
    if (_selectedRole != 'admin') {
      final code = _referralCodeController.text.trim();
      if (code.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a referral code.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(code);
      if (referralData == null) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid Referral Code.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      linkedAppName = referralData['appId'] ?? 'data';
    }

    final phone = _phoneController.text.trim();
    final gstValue = _hasGST
        ? _gstNumberController.text.trim().toUpperCase()
        : '';
    final Map<String, dynamic> extraData = {
      if (phone.isNotEmpty) 'phone': phone,
      'linkedAppName': linkedAppName,
      if (linkedAppName != null)
        'referralCode': _referralCodeController.text.trim(),
      if (_hasGST && gstValue.isNotEmpty) 'gstNumber': gstValue,
    };

    if (_selectedRole == 'admin') {
      final tenantId = FirestoreService.generateTenantId(
        _nameController.text.trim(),
      );
      final extraDataWithTenant = {
        'tenantId': tenantId,
        ...extraData,
      };

      // For Admins: Defer registration until after payment
      final result = await AuthStateService.instance.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        additionalData: extraDataWithTenant,
        deferAuth: true,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result['success']) {
        final pendingUserData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'role': _selectedRole,
          'tenantId': tenantId,
          ...extraData,
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubscriptionPlansScreen(pendingUserData: pendingUserData),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to save account details',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    // For non-admins: Register immediately
    final result = await AuthStateService.instance.registerUser(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
      additionalData: extraData.isNotEmpty ? extraData : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      if (_selectedRole == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppMainPage()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Registration failed',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _changeStep(int newStep) {
    if (newStep == _currentStep) return;
    setState(() {
      _transitionController.reset();
      _currentStep = newStep;
      _transitionController.forward();
    });
  }

  void _handleBackNavigation() {
    if (_currentStep == 2) {
      _changeStep(1);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TermsAndConditionsScreen(
              isPreRegistration: true,
              isFirstTimeRegistration: false,
            ),
          ),
        );
      }
    }
  }

  Widget _buildLogo(ThemeData theme, bool isDark) {
    final logoUrl = ThemeService.instance.logoUrl;
    final primaryColor = theme.primaryColor;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackAssetLogo(primaryColor),
            )
          : _buildFallbackAssetLogo(primaryColor),
    );
  }

  Widget _buildFallbackAssetLogo(Color primaryColor) {
    return Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.business_center_rounded,
              size: 34,
              color: primaryColor,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: ResponsiveWrapper(
            maxWidth: kMaxContentWidth,
            child: Column(
              children: [
                // Modern Minimalist Header with Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      InkWell(
                        onTap: _handleBackNavigation,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),

                    const SizedBox(width: 14),

                    // Modern Stepper Tabs
                    Expanded(
                      child: Row(
                        children: [
                          _buildStepPill(
                            step: 1,
                            title: "Overview",
                            isActive: _currentStep == 1,
                            isCompleted: _currentStep > 1,
                            primaryColor: primaryColor,
                            isDark: isDark,
                            onTap: () => _changeStep(1),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 8),
                          _buildStepPill(
                            step: 2,
                            title: "Register",
                            isActive: _currentStep == 2,
                            isCompleted: false,
                            primaryColor: primaryColor,
                            isDark: isDark,
                            onTap: () => _changeStep(2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Step Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _currentStep == 1
                          ? _buildStep1Overview(theme, isDark, primaryColor)
                          : _buildStep2Register(theme, isDark, primaryColor),
                    ),
                  ),
                ),
              ),

              // Fixed Bottom Action Dock
              _buildBottomActionDock(isDark, primaryColor),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStepPill({
    required int step,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.08)
                  : (isDark ? Colors.transparent : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? primaryColor.withValues(alpha: 0.25)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? primaryColor
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Text(
                            '$step',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? (isDark ? Colors.white : primaryColor)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Overview(ThemeData theme, bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Branding
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLogo(theme, isDark),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Enterprise Cloud",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Main Title
        Text(
          'Platform Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Discover how ServNex simplifies service operations, streamlines dispatch, and scales your business.',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 24),

        // Modern Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ready for Modern Service Delivery',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Our all-in-one platform scales with your business while delivering a white-labeled, premium customer brand experience.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.55,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              // Value micro badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMicroBadge(
                    icon: Icons.bolt_rounded,
                    label: "Real-time Dispatch",
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  _buildMicroBadge(
                    icon: Icons.shield_outlined,
                    label: "Multi-Tenant Cloud",
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  _buildMicroBadge(
                    icon: Icons.branding_watermark_outlined,
                    label: "100% White-Label",
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Section Title
        Text(
          'Core Capabilities',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),

        // Core Capability Cards
        _buildCapabilityCard(
          icon: Icons.layers_outlined,
          title: 'Unified Service Delivery',
          description: 'Manage AMC contracts, maintenance tickets, engineer assignments, and invoicing through one cohesive system.',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 12),
        _buildCapabilityCard(
          icon: Icons.smartphone_rounded,
          title: 'Branded Client & Customer App',
          description: 'Offer your customers their own dedicated mobile app to raise service requests, track jobs, and view service history.',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 12),
        _buildCapabilityCard(
          icon: Icons.insights_rounded,
          title: 'Real-Time Operational Analytics',
          description: 'Monitor field engineers, track GPS attendance, analyze resolution times, and export comprehensive audit reports.',
          isDark: isDark,
          primaryColor: primaryColor,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMicroBadge({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Register(ThemeData theme, bool isDark, Color primaryColor) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Create Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your organization details below to set up your master workspace.',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 22),

          // Admin Role Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Master Administrator Workspace',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You will have full control over branding, plans, and team access.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_selectedRole != 'admin') ...[
            const SizedBox(height: 18),
            _buildModernInput(
              label: 'Referral Code',
              controller: _referralCodeController,
              icon: Icons.vpn_key_outlined,
              hintText: 'Enter referral code',
              isDark: isDark,
              primaryColor: primaryColor,
              validator: (v) => v!.isEmpty ? 'Referral code is required' : null,
            ),
          ],

          const SizedBox(height: 22),

          // Form Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Organization / Name
                _buildModernInput(
                  label: 'Organization / Full Name',
                  controller: _nameController,
                  icon: Icons.domain_rounded,
                  hintText: 'e.g. Apex Technical Services',
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) => v!.trim().isEmpty ? 'Please enter organization or full name' : null,
                ),

                const SizedBox(height: 18),

                // Corporate Email
                _buildModernInput(
                  label: 'Corporate Email',
                  controller: _emailController,
                  icon: Icons.alternate_email_rounded,
                  hintText: 'admin@company.com',
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter corporate email';
                    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email address';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Phone Number
                _buildModernInput(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  hintText: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter phone number';
                    if (v.trim().length != 10) return 'Phone number must be exactly 10 digits';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Password
                _buildModernInput(
                  label: 'Password',
                  controller: _passwordController,
                  icon: Icons.lock_outline_rounded,
                  hintText: 'Minimum 6 characters',
                  obscureText: _obscurePassword,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 19,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Confirm Password
                _buildModernInput(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  icon: Icons.lock_reset_rounded,
                  hintText: 'Re-enter your password',
                  obscureText: _obscureConfirmPassword,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 19,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // GST Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _hasGST = !_hasGST),
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _hasGST ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _hasGST
                                      ? primaryColor
                                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  width: 1.8,
                                ),
                              ),
                              child: _hasGST
                                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'My organization has a registered GSTIN',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasGST) ...[
                        const SizedBox(height: 14),
                        _buildModernInput(
                          label: 'GST Number (GSTIN)',
                          controller: _gstNumberController,
                          icon: Icons.receipt_long_outlined,
                          hintText: 'e.g. 29ABCDE1234F1Z5',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[^\dA-Za-z]')),
                            LengthLimitingTextInputFormatter(15),
                          ],
                          isDark: isDark,
                          primaryColor: primaryColor,
                          validator: (v) {
                            if (!_hasGST) return null;
                            if (v == null || v.trim().isEmpty) return 'GST number is required';
                            final trimmedValue = v.trim().toUpperCase();
                            final gstRegExp = RegExp(
                              r'^([0-2][0-9]|3[0-8])[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                            );
                            if (!gstRegExp.hasMatch(trimmedValue)) {
                              return 'Please enter a valid GSTIN format';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModernInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required bool isDark,
    required Color primaryColor,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryColor,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionDock(bool isDark, Color primaryColor) {
    final isStep1 = _currentStep == 1;
    final label = isStep1 ? 'Continue to Registration' : 'Create Organization Workspace';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (isStep1) {
                        _changeStep(2);
                      } else {
                        _handleRegister();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: primaryColor.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Text(
                isStep1
                    ? "Step 1 of 2 • Platform Architecture"
                    : "Step 2 of 2 • Secure Workspace Setup",
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
