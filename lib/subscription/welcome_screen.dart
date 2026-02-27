import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/subscription/subscription_plans_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/app_main_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _currentStep = 1; // Flow starts at Step 1 (Platform Overview)

  // Form keys and controllers for Step 2
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController(); // For customers
  final String _selectedRole = 'admin';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Role is fixed to Administration as per requirements

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? linkedAppName;

    // Referral Code Validation for Non-Admins
    if (_selectedRole != 'admin') {
      final code = _referralCodeController.text.trim();
      if (code.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a referral code.')),
        );
        return;
      }

      final referralData = await FirestoreService.instance
          .validateGlobalReferralCode(code);
      if (referralData == null) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid Referral Code.')));
        return;
      }
      linkedAppName = referralData['appId'] ?? 'data';
    }

    final phone = _phoneController.text.trim();
    final Map<String, dynamic> extraData = {
      if (phone.isNotEmpty) 'phone': phone,
      if (linkedAppName != null) 'linkedAppName': linkedAppName,
      if (linkedAppName != null)
        'referralCode': _referralCodeController.text.trim(),
    };

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
      // Determine Navigation
      if (_selectedRole == 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Now choose your plan.'),
          ),
        );
        // Admin -> Subscription Flow
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
        );
      } else {
        // Customer/User -> Main App (Skip Subscription)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Welcome.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppMainPage()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _buildStepIndicator(),
        centerTitle: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCTA(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep == 1)
                _buildStep1Content()
              else
                _buildStep2Content(),
              const SizedBox(height: 120), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepDot(1),
          Container(height: 2, width: 24, color: Colors.grey[300]),
          _stepDot(2),
        ],
      ),
    );
  }

  Widget _stepDot(int step) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.black
            : (isCompleted ? Colors.green : Colors.transparent),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.black : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey[500],
                ),
              ),
      ),
    );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Platform Overview',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Discover how our Service Management Platform can transform your business delivery.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        _buildHeroCard(),
        const SizedBox(height: 40),
        Text(
          'Key Capabilities',
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildFeatureCard(
          icon: Icons.auto_awesome_mosaic_rounded,
          title: 'Unified Delivery',
          description:
              'Manage technical and maintenance services through one cohesive system.',
        ),
        _buildFeatureCard(
          icon: Icons.smartphone_rounded,
          title: 'Client Application',
          description:
              'Custom branded mobile apps for your customers to raise requests.',
        ),
        _buildFeatureCard(
          icon: Icons.dashboard_customize_rounded,
          title: 'Full Operational Control',
          description:
              'Assigned tickets, engineer tracking, and resolution analytics.',
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 2: Registration',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your details below to create your organization account.',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          // Role Selection
          const Text(
            'Primary Role',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.black,
                ),
                const SizedBox(width: 12),
                Text(
                  'Administration',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          if (_selectedRole != 'admin') ...[
            const SizedBox(height: 24),
            _buildFormTextField(
              label: 'Referral Code',
              controller: _referralCodeController,
              icon: Icons.vpn_key_outlined,
              validator: (v) => v!.isEmpty ? 'Referral code is required' : null,
            ),
          ],

          const SizedBox(height: 32),

          _buildFormTextField(
            label: 'Organization / Full Name',
            controller: _nameController,
            icon: Icons.person_outline,
            validator: (v) => v!.isEmpty ? 'Enter name' : null,
          ),
          const SizedBox(height: 24),
          _buildFormTextField(
            label: 'Corporate Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v!.isEmpty || !v.contains('@') ? 'Enter valid email' : null,
          ),
          const SizedBox(height: 24),
          _buildFormTextField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter phone number';
              if (v.length != 10) {
                return 'Phone number must be exactly 10 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildFormTextField(
            label: 'Secure Password',
            controller: _passwordController,
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) =>
                v!.length < 6 ? 'Password must be 6+ characters' : null,
          ),
          const SizedBox(height: 24),
          _buildFormTextField(
            label: 'Confirm Password',
            controller: _confirmPasswordController,
            icon: Icons.lock_reset_outlined,
            obscureText: _obscurePassword,
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black87),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Ready for Modern Service Delivery',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our platform is designed to scale with your business while maintaining a premium brand experience.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withAlpha(179),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCTA() {
    String label = _currentStep == 1
        ? 'Continue to Account Setup'
        : 'Create My Account';
    IconData icon = _currentStep == 1
        ? Icons.arrow_forward_rounded
        : Icons.check_circle_outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_currentStep == 1) {
                    setState(() => _currentStep = 2);
                  } else {
                    _handleRegister();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else ...[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
