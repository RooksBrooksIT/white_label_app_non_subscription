import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrandingCustomizationScreen extends StatefulWidget {
  final String? planName;
  final bool? isYearly;
  final bool? isSixMonths;
  final int? price;
  final int? originalPrice;
  final String? paymentMethod;
  final String? transactionId;
  final bool isEditMode;
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;
  final Map<String, dynamic>? pendingUserData;

  const BrandingCustomizationScreen({
    super.key,
    this.planName,
    this.isYearly,
    this.isSixMonths = false,
    this.price,
    this.originalPrice,
    this.paymentMethod,
    this.transactionId,
    this.isEditMode = false,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
    this.pendingUserData,
  });

  @override
  State<BrandingCustomizationScreen> createState() =>
      _BrandingCustomizationScreenState();
}

class _BrandingCustomizationScreenState
    extends State<BrandingCustomizationScreen>
    with SingleTickerProviderStateMixin {
  bool get _hasValidSubscriptionPayload {
    final plan = widget.planName?.trim() ?? '';
    final method = widget.paymentMethod?.trim() ?? '';
    return plan.isNotEmpty && widget.price != null && method.isNotEmpty;
  }

  // Branding State
  Color _primaryColor = Colors.deepPurple;
  Color _secondaryColor = Colors.amber;
  final Color _backgroundColor = Colors.white;
  File? _logoFile;
  String? _existingLogoUrl;
  final bool _useDarkMode = false;

  String _selectedFont = 'Roboto';
  final TextEditingController _appNameController = TextEditingController(
    text: 'ServNex',
  );

  final List<Map<String, Color>> _presetThemes = [
    {'primary': const Color(0xFFC62828), 'secondary': const Color(0xFFFF7070)},
    {'primary': const Color(0xFF2563EB), 'secondary': const Color(0xFF7C3AED)},
    {'primary': const Color(0xFF0891B2), 'secondary': const Color(0xFF2D6A4F)},
    {'primary': const Color(0xFF7C3AED), 'secondary': const Color(0xFFDB2777)},
    {'primary': const Color(0xFF059669), 'secondary': const Color(0xFF10B981)},
    {'primary': const Color(0xFFEA580C), 'secondary': const Color(0xFFFBBF24)},
    {'primary': const Color(0xFF1E40AF), 'secondary': const Color(0xFF3B82F6)},
    {'primary': const Color(0xFFBE185D), 'secondary': const Color(0xFFEC4899)},
    {'primary': const Color(0xFF4F46E5), 'secondary': const Color(0xFF818CF8)},
    {'primary': const Color(0xFF1F2937), 'secondary': const Color(0xFF4B5563)},
  ];

  int _selectedThemeIndex = 0;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  bool _isUploadingLogo = false;
  bool _isSavingData = false;

  @override
  void initState() {
    super.initState();
    final theme = ThemeService.instance;
    _primaryColor = theme.primaryColor;
    _secondaryColor = theme.secondaryColor;
    _selectedFont = theme.fontFamily;
    if (theme.appName.isNotEmpty) {
      _appNameController.text = theme.appName;
    }

    if (widget.isEditMode && theme.logoUrl != null) {
      _existingLogoUrl = theme.logoUrl;
    }

    _selectedThemeIndex = _presetThemes.length;
    for (int i = 0; i < _presetThemes.length; i++) {
      if (_presetThemes[i]['primary']?.toARGB32() == _primaryColor.toARGB32() &&
          _presetThemes[i]['secondary']?.toARGB32() ==
              _secondaryColor.toARGB32()) {
        _selectedThemeIndex = i;
        break;
      }
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        setState(() => _isUploadingLogo = true);

        final File? croppedFile = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomLogoCropperScreen(
              imageFile: File(pickedFile.path),
              primaryColor: _primaryColor,
            ),
          ),
        );

        if (croppedFile != null) {
          setState(() {
            _logoFile = croppedFile;
            _existingLogoUrl = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  void _showColorPicker(String type) {
    Color currentColor = type == 'primary' ? _primaryColor : _secondaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Pick ${type[0].toUpperCase()}${type.substring(1)} Color',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (type == 'primary') {
                  _primaryColor = color;
                } else {
                  _secondaryColor = color;
                }
                _selectedThemeIndex = _presetThemes.length;
              });
            },
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
            paletteType: PaletteType.hueWheel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _generateReferralCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _handleSaveBranding() async {
    if (_isSavingData) return;
    setState(() => _isSavingData = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isEditMode
                    ? 'Updating Brand Identity...'
                    : 'Saving Brand Settings...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final tenantId =
          widget.pendingUserData?['tenantId'] ??
          (ThemeService.instance.databaseName.isNotEmpty
              ? ThemeService.instance.databaseName
              : 'global_user_directory');

      final brandingData = {
        'appName': _appNameController.text.trim(),
        'primaryColor': _primaryColor.toARGB32(),
        'secondaryColor': _secondaryColor.toARGB32(),
        'backgroundColor': _backgroundColor.toARGB32(),
        'useDarkMode': _useDarkMode,
        'fontFamily': _selectedFont,
        'databaseName': tenantId,
      };

      String? uid = AuthStateService.instance.currentUser?.uid;

      if (widget.pendingUserData != null && uid == null) {
        final name = widget.pendingUserData!['name'] as String;
        final email = widget.pendingUserData!['email'] as String;
        final password = widget.pendingUserData!['password'] as String;
        final role = widget.pendingUserData!['role'] as String;

        final additionalData =
            Map<String, dynamic>.from(widget.pendingUserData!)
              ..remove('name')
              ..remove('email')
              ..remove('password')
              ..remove('role');

        final result = await AuthStateService.instance.registerUser(
          name: name,
          email: email,
          password: password,
          role: role,
          additionalData: additionalData.isNotEmpty ? additionalData : null,
        );
        if (result['success']) {
          uid = result['uid'];
        } else {
          throw Exception(result['message'] ?? 'Failed to create account');
        }
      }

      uid ??= AuthStateService.instance.currentUser?.uid ?? 'demo-user';

      if (_logoFile != null) {
        final logoUrl = await StorageService.instance.uploadLogo(
          userId: uid,
          file: _logoFile!,
        );
        if (logoUrl != null) brandingData['logoUrl'] = logoUrl;
      } else if (_existingLogoUrl != null) {
        brandingData['logoUrl'] = _existingLogoUrl!;
      }

      if (widget.isEditMode) {
        await FirestoreService.instance.saveAppBranding(
          tenantId: tenantId,
          appId: 'data',
          brandingData: brandingData,
        );

        ThemeService.instance.updateTheme(
          primary: _primaryColor,
          secondary: _secondaryColor,
          backgroundColor: _backgroundColor,
          isDarkMode: _useDarkMode,
          fontFamily: _selectedFont,
          appName: _appNameController.text.trim(),
          databaseName: tenantId,
          logoUrl: brandingData['logoUrl'] as String?,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('branding_completed', true);

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Brand settings updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryColor,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const admindashboard()),
        );
      } else {
        await FirestoreService.instance.saveAppBranding(
          tenantId: tenantId,
          appId: 'data',
          brandingData: brandingData,
        );

        ThemeService.instance.updateTheme(
          primary: _primaryColor,
          secondary: _secondaryColor,
          backgroundColor: _backgroundColor,
          isDarkMode: _useDarkMode,
          fontFamily: _selectedFont,
          appName: _appNameController.text.trim(),
          databaseName: tenantId,
          logoUrl: brandingData['logoUrl'] as String?,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('branding_completed', true);

        final referralCode = _generateReferralCode();
        brandingData['referralCode'] = referralCode;

        try {
          await FirestoreService.instance.saveReferralCode(
            code: referralCode,
            tenantId: tenantId,
            appId: 'data',
            adminUid: uid,
          );
        } catch (e) {
          debugPrint('Referral save failed: $e');
        }

        try {
          if (_hasValidSubscriptionPayload) {
            await FirestoreService.instance.upsertSubscription(
              uid: uid,
              tenantId: tenantId,
              appId: 'data',
              planName: widget.planName!.trim(),
              isYearly: widget.isYearly ?? false,
              isSixMonths: widget.isSixMonths ?? false,
              price: widget.price!,
              originalPrice: widget.originalPrice,
              paymentMethod: widget.paymentMethod!.trim(),
              status: 'active',
              gstNumber: widget.pendingUserData?['gstNumber'],
              brandingData: brandingData,
              limits: widget.limits,
              geoLocation: widget.geoLocation,
              attendance: widget.attendance,
              barcode: widget.barcode,
              reportExport: widget.reportExport,
            );
          }
        } catch (e) {
          debugPrint('Subscription upsert failed: $e');
        }

        try {
          await FirestoreService.instance.saveUserDirectory(
            uid: uid,
            tenantId: tenantId,
            role: 'admin',
            appName: _appNameController.text.trim(),
          );
        } catch (e) {
          debugPrint('User directory save failed: $e');
        }

        try {
          await FirestoreService.instance.setUserActiveStatus(
            uid: uid,
            tenantId: tenantId,
            active: true,
          );
        } catch (e) {
          debugPrint('Set active status failed: $e');
        }

        if (!mounted) return;
        Navigator.pop(context);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Setup Complete!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your application brand is live. Share this referral code with your customers:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    referralCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go to Dashboard', style: TextStyle(color: _primaryColor)),
              ),
            ],
          ),
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const admindashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('ERROR: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving branding: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600;
    final double horizontalPadding = isDesktop ? 40.0 : (isTablet ? 28.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildWorkspaceAppBar(isDesktop),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Breadcrumb & Header Title
                _buildWorkspaceTitleHeader(isDesktop),
                const SizedBox(height: 24),

                // Brand Overview Hero Banner
                _buildBrandOverviewHeroCard(),
                const SizedBox(height: 24),

                // Main Content Workspace Layout (2-Column on Desktop/Tablet, 1-Column on Mobile)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Brand Identity & Logo Management
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildAppInformationCard(),
                            const SizedBox(height: 24),
                            _buildCompanyLogoCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right Column: Appearance Colors, Typography & Live Preview
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildThemeColorsCard(isTablet),
                            const SizedBox(height: 24),
                            _buildTypographyCard(),
                            const SizedBox(height: 24),
                            _buildLiveApplicationPreview(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildAppInformationCard(),
                      const SizedBox(height: 20),
                      _buildCompanyLogoCard(),
                      const SizedBox(height: 20),
                      _buildThemeColorsCard(isTablet),
                      const SizedBox(height: 20),
                      _buildTypographyCard(),
                      const SizedBox(height: 20),
                      _buildLiveApplicationPreview(),
                      const SizedBox(height: 28),
                      _buildMobileStickySaveButton(),
                    ],
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // APP BAR & HEADER SECTION
  // ==========================================

  PreferredSizeWidget _buildWorkspaceAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Branding',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: ElevatedButton.icon(
            onPressed: _isSavingData ? null : _handleSaveBranding,
            icon: _isSavingData
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: Text(
              widget.isEditMode ? 'Save Changes' : 'Complete Setup',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              elevation: 2,
              shadowColor: _primaryColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceTitleHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.dashboard_outlined, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            const Text(
              'Admin Dashboard',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            const Text(
              'Brand Management',
              style: TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Brand Management Center',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Customize how your application looks, feels, and represents your company identity.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BRAND OVERVIEW HERO CARD
  // ==========================================

  Widget _buildBrandOverviewHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor,
            _secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.25),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'LIVE BRAND PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Logo Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _logoFile != null
                      ? Image.file(_logoFile!, fit: BoxFit.cover)
                      : (_existingLogoUrl != null
                          ? Image.network(
                              _existingLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.business_rounded,
                                color: _primaryColor,
                                size: 32,
                              ),
                            )
                          : Icon(
                              Icons.business_rounded,
                              color: _primaryColor,
                              size: 32,
                            )),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appNameController.text.isEmpty
                          ? 'ServNex'
                          : _appNameController.text,
                      style: GoogleFonts.getFont(
                        _selectedFont,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Service Management Workspace • Font: $_selectedFont',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary Color',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${_primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secondary Color',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _secondaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${_secondaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BRAND IDENTITY (APP INFORMATION) CARD
  // ==========================================

  Widget _buildAppInformationCard() {
    return _ModernWorkspaceCard(
      badgeIcon: Icons.app_shortcut_rounded,
      badgeColor: _primaryColor,
      title: 'Brand Identity',
      subtitle: 'App Information • Define your application\'s public name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appNameController,
            onChanged: (val) => setState(() {}),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter application name (e.g. ServNex)',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              prefixIcon: Icon(Icons.apps_rounded, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPANY LOGO MANAGEMENT CARD
  // ==========================================

  Widget _buildCompanyLogoCard() {
    final hasLogo = _logoFile != null || _existingLogoUrl != null;

    return _ModernWorkspaceCard(
      badgeIcon: Icons.image_rounded,
      badgeColor: const Color(0xFF0984E3),
      title: 'Company Logo',
      subtitle: 'Logo Management • Your logo appears across mobile & web apps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isUploadingLogo
                      ? Center(child: CircularProgressIndicator(color: _primaryColor))
                      : (hasLogo
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: _logoFile != null
                                  ? Image.file(_logoFile!, fit: BoxFit.contain)
                                  : Image.network(_existingLogoUrl!, fit: BoxFit.contain),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF94A3B8)),
                                SizedBox(height: 6),
                                Text(
                                  'No Logo Set',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                              ],
                            )),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isUploadingLogo ? null : _pickLogo,
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                  label: Text(
                    hasLogo ? 'Change Company Logo' : 'Upload New Logo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Recommended: PNG, JPG or SVG format up to 5MB (Square Aspect Ratio)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // APPEARANCE & THEME COLORS CARD
  // ==========================================

  Widget _buildThemeColorsCard(bool isTablet) {
    final crossAxisCount = isTablet ? 5 : 5;

    return _ModernWorkspaceCard(
      badgeIcon: Icons.palette_rounded,
      badgeColor: const Color(0xFF7C3AED),
      title: 'Appearance',
      subtitle: 'Theme Colors • Define the visual language of your application',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color Cards Grid (Primary & Secondary)
          Row(
            children: [
              Expanded(
                child: _buildIndividualColorCard(
                  title: 'Primary Color',
                  color: _primaryColor,
                  onTap: () => _showColorPicker('primary'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIndividualColorCard(
                  title: 'Secondary Color',
                  color: _secondaryColor,
                  onTap: () => _showColorPicker('secondary'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preset Color Schemes Grid
          const Text(
            'Preset Color Schemes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _presetThemes.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedThemeIndex == index;
              final primary = _presetThemes[index]['primary']!;
              final secondary = _presetThemes[index]['secondary']!;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedThemeIndex = index;
                    _primaryColor = primary;
                    _secondaryColor = secondary;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, secondary],
                    ),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 20))
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Live Brand Palette Bar
          const Text(
            'Brand Palette Bar',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 28,
                    color: _primaryColor,
                    child: const Center(
                      child: Text('Primary', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 28,
                    color: _secondaryColor,
                    child: const Center(
                      child: Text('Secondary', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 28,
                    color: const Color(0xFFF8FAFC),
                    child: const Center(
                      child: Text('Surface', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualColorCard({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final hexCode = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hexCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.color_lens_rounded, size: 20, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TYPOGRAPHY CARD
  // ==========================================

  Widget _buildTypographyCard() {
    return _ModernWorkspaceCard(
      badgeIcon: Icons.font_download_rounded,
      badgeColor: const Color(0xFF00B894),
      title: 'Typography',
      subtitle: 'Font Family • Choose typeface for your brand interface',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.text_fields_rounded, color: _primaryColor, size: 22),
            const SizedBox(width: 12),
            const Text(
              'Font Family',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _selectedFont,
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor),
              style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
              items: [
                'Roboto',
                'Lato',
                'Montserrat',
                'Playfair Display',
                'Merriweather',
                'Oswald',
                'Fira Code',
                'Dancing Script',
              ]
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f,
                        style: GoogleFonts.getFont(f, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFont = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LIVE APPLICATION PREVIEW (MOBILE MOCKUP)
  // ==========================================

  Widget _buildLiveApplicationPreview() {
    final appName = _appNameController.text.isEmpty ? 'ServNex' : _appNameController.text;

    return _ModernWorkspaceCard(
      badgeIcon: Icons.visibility_rounded,
      badgeColor: const Color(0xFFE17055),
      title: 'Live Application Preview',
      subtitle: 'Real-time UI preview updating as you change branding',
      child: Center(
        child: Container(
          width: 300,
          height: 480,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFF0F172A), width: 8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                // Top Status Bar
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white,
                  child: Row(
                    children: const [
                      Text('9:41', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      Spacer(),
                      Icon(Icons.wifi, size: 12),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full, size: 12),
                    ],
                  ),
                ),

                // App Mockup Header Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _logoFile != null
                          ? ClipOval(child: Image.file(_logoFile!, width: 28, height: 28, fit: BoxFit.cover))
                          : (_existingLogoUrl != null
                              ? ClipOval(child: Image.network(_existingLogoUrl!, width: 28, height: 28, fit: BoxFit.cover))
                              : CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _primaryColor,
                                  child: Text(appName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                )),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appName,
                          style: GoogleFonts.getFont(
                            _selectedFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF64748B)),
                    ],
                  ),
                ),

                // Mockup Body Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Feature Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primaryColor, _secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: _primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Welcome Back 👋', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              SizedBox(height: 2),
                              Text('Service Management', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('+ Create Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sample Item Tile
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _secondaryColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.confirmation_number_rounded, color: _secondaryColor, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ticket #1042', style: GoogleFonts.getFont(_selectedFont, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const Text('Ticket Management', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mockup Bottom Nav Bar
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Icon(Icons.home_rounded, color: _primaryColor, size: 20),
                      const Icon(Icons.assignment_rounded, color: Color(0xFF94A3B8), size: 20),
                      const Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStickySaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSavingData ? null : _handleSaveBranding,
        icon: _isSavingData
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        label: Text(
          widget.isEditMode ? 'Save Brand Changes' : 'Complete Setup',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: _primaryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// WORKSPACE CARD CONTAINER
// ==========================================

class _ModernWorkspaceCard extends StatelessWidget {
  final IconData badgeIcon;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _ModernWorkspaceCard({
    required this.badgeIcon,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(badgeIcon, color: badgeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LOGO CROPPER SCREEN (PRESERVED 100%)
// ==========================================

class CustomLogoCropperScreen extends StatefulWidget {
  final File imageFile;
  final Color primaryColor;

  const CustomLogoCropperScreen({
    super.key,
    required this.imageFile,
    required this.primaryColor,
  });

  @override
  State<CustomLogoCropperScreen> createState() => _CustomLogoCropperScreenState();
}

class _CustomLogoCropperScreenState extends State<CustomLogoCropperScreen> {
  final controller = CropController(
    aspectRatio: 1.0,
    defaultCrop: const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95),
  );

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crop Logo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: CropImage(
              controller: controller,
              image: Image.file(widget.imageFile),
              paddingSize: 25.0,
              alwaysMove: true,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            final img = await controller.croppedBitmap();
                            final data = await img.toByteData(format: ImageByteFormat.png);
                            final bytes = data!.buffer.asUint8List();
                            final tempDir = Directory.systemTemp;
                            final file = await File('${tempDir.path}/cropped_logo_${DateTime.now().millisecondsSinceEpoch}.png').create();
                            await file.writeAsBytes(bytes);
                            if (!context.mounted) return;
                            Navigator.of(context).pop(file);
                          } catch (e) {
                            debugPrint('Crop error: $e');
                            if (!context.mounted) return;
                            Navigator.of(context).pop(null);
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Logo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}