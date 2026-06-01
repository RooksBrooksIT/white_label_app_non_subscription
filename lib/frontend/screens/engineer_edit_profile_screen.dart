import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';

class EngineerEditProfileScreen extends StatefulWidget {
  final String engineerName;

  const EngineerEditProfileScreen({super.key, required this.engineerName});

  @override
  State<EngineerEditProfileScreen> createState() =>
      _EngineerEditProfileScreenState();
}

class _EngineerEditProfileScreenState
    extends State<EngineerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _docId;
  String? _tenantId;
  Map<String, dynamic> _originalData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tenantId = prefs.getString('tenantId') ?? ThemeService.instance.databaseName;

      final query = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: _tenantId)
          .where('Username', isEqualTo: widget.engineerName)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Profile not found in database.', isError: true);
        }
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      _docId = doc.id;
      _originalData = data;

      _nameController.text = data['Username'] ?? '';
      _emailController.text = data['Email'] ?? '';
      _phoneController.text = data['Phone'] ?? '';
      _specializationController.text = data['Specialization'] ?? '';
      _addressController.text = data['Address'] ?? '';

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load profile: $e', isError: true);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_docId == null) {
      _showSnackBar('Cannot save: document ID not found.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'Email': _emailController.text.trim(),
        'Phone': _phoneController.text.trim(),
        'Specialization': _specializationController.text.trim(),
        'Address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.instance
          .collection('EngineerLogin', tenantId: _tenantId)
          .doc(_docId)
          .update(updates);

      if (mounted) {
        _showSnackBar('Profile updated successfully!', isError: false);
        Navigator.pop(context, true); // return true = refreshed
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save profile: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? ProfessionalTheme.error : ProfessionalTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalTheme.background(context),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: ProfessionalTheme.primary(context),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Profile picture placeholder
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ProfessionalTheme.primary(context),
                                width: 3,
                              ),
                              boxShadow: ProfessionalTheme.elevatedShadow,
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor:
                                  ProfessionalTheme.primaryExtraLight(context),
                              child: Text(
                                (widget.engineerName.isNotEmpty
                                        ? widget.engineerName[0]
                                        : 'E')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: ProfessionalTheme.primary(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        widget.engineerName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: ProfessionalTheme.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Fields ──────────────────────────────────────────
                    _sectionLabel('Personal Details'),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_rounded,
                      readOnly: true, // Username is the document ID — not editable
                      hint: 'Username (read-only)',
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_rounded,
                      hint: 'engineer@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                            .hasMatch(v)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _phoneController,
                      label: 'Mobile Number',
                      icon: Icons.phone_rounded,
                      hint: '10-digit mobile number',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Phone is required';
                        if (v.length != 10) return 'Must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('Professional Details'),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _specializationController,
                      label: 'Specialization',
                      icon: Icons.architecture_rounded,
                      hint: 'e.g. AC Repair, Plumbing, Electrical',
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Specialization is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.place_rounded,
                      hint: 'Your home / service address',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfessionalTheme.primary(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: ProfessionalTheme.textSecondary(context),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ProfessionalTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          readOnly: readOnly,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: readOnly
                ? ProfessionalTheme.textSecondary(context)
                : ProfessionalTheme.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: Icon(
              icon,
              color: readOnly
                  ? ProfessionalTheme.textTertiary(context)
                  : ProfessionalTheme.primary(context),
              size: 20,
            ),
            filled: true,
            fillColor: readOnly
                ? ProfessionalTheme.borderLight(context).withValues(alpha: 0.5)
                : ProfessionalTheme.surface(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ProfessionalTheme.borderLight(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ProfessionalTheme.borderLight(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: ProfessionalTheme.primary(context),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ProfessionalTheme.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
