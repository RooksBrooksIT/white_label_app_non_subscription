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
  Color _backgroundColor = Colors.white;
  File? _logoFile;
  String? _existingLogoUrl;
  final bool _useDarkMode = false;

  String _selectedFont = 'Roboto';
  final TextEditingController _appNameController = TextEditingController(
    text: 'My Awesome App',
  );

  final List<Map<String, Color>> _presetThemes = [
    {'primary': const Color(0xFF2563EB), 'secondary': const Color(0xFF7C3AED)},
    {'primary': const Color(0xFF0891B2), 'secondary': const Color(0xFF2D6A4F)},
    {'primary': const Color(0xFF7C3AED), 'secondary': const Color(0xFFDB2777)},
    {'primary': const Color(0xFFDC2626), 'secondary': const Color(0xFFF59E0B)},
    {'primary': const Color(0xFF059669), 'secondary': const Color(0xFF10B981)},
    {'primary': const Color(0xFF9333EA), 'secondary': const Color(0xFFF472B6)},
    {'primary': const Color(0xFFEA580C), 'secondary': const Color(0xFFFBBF24)},
    {'primary': const Color(0xFF1E40AF), 'secondary': const Color(0xFF3B82F6)},
    {'primary': const Color(0xFFBE185D), 'secondary': const Color(0xFFEC4899)},
    {'primary': const Color(0xFF4F46E5), 'secondary': const Color(0xFF818CF8)},
    {'primary': const Color(0xFFB45309), 'secondary': const Color(0xFFF59E0B)},
    {'primary': const Color(0xFF065F46), 'secondary': const Color(0xFF34D399)},
    {'primary': const Color(0xFF1F2937), 'secondary': const Color(0xFF4B5563)},
    {'primary': const Color(0xFF8B5CF6), 'secondary': const Color(0xFFC4B5FD)},
    {'primary': const Color(0xFFB91C1C), 'secondary': const Color(0xFFFCA5A5)},
  ];

  int _selectedThemeIndex = 0;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final theme = ThemeService.instance;
    _primaryColor = theme.primaryColor;
    _secondaryColor = theme.secondaryColor;
    _backgroundColor = Colors.white;
    _selectedFont = theme.fontFamily;
    _appNameController.text = theme.appName;

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
        title: Text(
          'Pick ${type[0].toUpperCase()}${type.substring(1)} Color',
          style: const TextStyle(fontWeight: FontWeight.w600),
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
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final double horizontalPadding = isTablet ? 32.0 : 20.0;

    return Theme(
      data: ThemeService.instance.defaultTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            widget.isEditMode ? 'Edit Branding' : 'Customize Branding',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey.shade50,
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildAppInfoSection(),
                    const SizedBox(height: 24),
                    _buildLogoUploadSection(),
                    const SizedBox(height: 24),
                    _buildColorThemeSection(isTablet),
                    const SizedBox(height: 24),
                    _buildVisualSettingsSection(),
                    const SizedBox(height: 32),
                    _buildPreviewSection(isTablet),
                    const SizedBox(height: 40),
                    _buildContinueButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand Your App',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 400 ? 34 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Make the app truly yours. Upload your logo and choose your brand colors.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoSection() {
    return _ModernCard(
      icon: Icons.edit_note,
      color: _primaryColor,
      title: 'App Information',
      child: TextField(
        controller: _appNameController,
        decoration: InputDecoration(
          hintText: 'Enter your app name',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          prefixIcon: Icon(Icons.app_registration, color: _primaryColor),
        ),
      ),
    );
  }

  Widget _buildLogoUploadSection() {
    return _ModernCard(
      icon: Icons.image,
      color: _primaryColor,
      title: 'Company Logo',
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingLogo ? null : _pickLogo,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: _isUploadingLogo
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : (_logoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(_logoFile!, fit: BoxFit.contain),
                        )
                      : _existingLogoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            _existingLogoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildUploadPlaceholder(),
                          ),
                        )
                      : _buildUploadPlaceholder()),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pickLogo,
            icon: Icon(Icons.cloud_upload, size: 18, color: _primaryColor),
            label: Text(
              _logoFile != null || _existingLogoUrl != null
                  ? 'Change Logo'
                  : 'Upload Logo',
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cloud_upload_outlined, size: 32, color: _primaryColor),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to upload logo',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PNG, JPG up to 5MB',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildColorThemeSection(bool isTablet) {
    final crossAxisCount = isTablet
        ? (MediaQuery.of(context).size.width > 800 ? 8 : 6)
        : (MediaQuery.of(context).size.width > 380 ? 5 : 4);

    return _ModernCard(
      icon: Icons.palette,
      color: _primaryColor,
      title: 'Theme Colors',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preset Color Schemes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${_selectedThemeIndex < _presetThemes.length ? _selectedThemeIndex + 1 : 'Custom'}/${_presetThemes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _presetThemes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _presetThemes.length) {
                      return _buildCustomThemeCircle();
                    }
                    return _buildModernThemeCircle(
                      index,
                      _presetThemes[index]['primary']!,
                      _presetThemes[index]['secondary']!,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_selectedThemeIndex == _presetThemes.length) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernColorButton(
                      'Primary',
                      _primaryColor,
                      () => _showColorPicker('primary'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernColorButton(
                      'Secondary',
                      _secondaryColor,
                      () => _showColorPicker('secondary'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernThemeCircle(int index, Color primary, Color secondary) {
    final isSelected = _selectedThemeIndex == index;
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedThemeIndex = index;
            _primaryColor = primary;
            _secondaryColor = secondary;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, secondary],
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Icon(Icons.check, color: primary, size: 18),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomThemeCircle() {
    final isSelected = _selectedThemeIndex == _presetThemes.length;
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedThemeIndex = _presetThemes.length;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, _secondaryColor],
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.color_lens,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernColorButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualSettingsSection() {
    return _ModernCard(
      icon: Icons.text_format,
      color: _primaryColor,
      title: 'Typography',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.font_download, color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Font Family',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedFont,
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                style: const TextStyle(color: Colors.black87),
                items:
                    [
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
                          style: GoogleFonts.getFont(f, fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFont = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(bool isTablet) {
    final previewWidth = isTablet ? 360.0 : 280.0;
    final previewHeight = isTablet ? 600.0 : 500.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.preview, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Live Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: previewWidth,
            height: previewHeight,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.grey.shade300, width: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: _backgroundColor,
                    child: Row(
                      children: [
                        Text(
                          '9:41',
                          style: TextStyle(
                            color: _backgroundColor.computeLuminance() < 0.5
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.signal_cellular_alt,
                            size: 14,
                            color: _backgroundColor.computeLuminance() < 0.5
                                ? Colors.white70
                                : Colors.black54),
                        const SizedBox(width: 4),
                        Icon(Icons.wifi,
                            size: 14,
                            color: _backgroundColor.computeLuminance() < 0.5
                                ? Colors.white70
                                : Colors.black54),
                        const SizedBox(width: 4),
                        Icon(Icons.battery_full,
                            size: 14,
                            color: _backgroundColor.computeLuminance() < 0.5
                                ? Colors.white70
                                : Colors.black54),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: _backgroundColor,
                    child: Row(
                      children: [
                        _logoFile != null
                            ? Image.file(_logoFile!, height: 32, width: 32)
                            : _existingLogoUrl != null
                            ? Image.network(_existingLogoUrl!,
                                height: 32, width: 32)
                            : Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _appNameController.text.isNotEmpty
                                        ? _appNameController.text[0]
                                            .toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _appNameController.text.isEmpty
                                ? 'App Name'
                                : _appNameController.text,
                            style: GoogleFonts.getFont(
                              _selectedFont,
                              color: _backgroundColor.computeLuminance() < 0.5
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.notifications_none,
                            color: _backgroundColor.computeLuminance() < 0.5
                                ? Colors.white70
                                : Colors.black54),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 90,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_primaryColor, _secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Feature Card',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _secondaryColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(Icons.person, color: _secondaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'John Doe',
                                      style: GoogleFonts.getFont(
                                        _selectedFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _backgroundColor.computeLuminance() <
                                                    0.5
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Premium Member',
                                      style: GoogleFonts.getFont(
                                        _selectedFont,
                                        fontSize: 12,
                                        color:
                                            _backgroundColor.computeLuminance() <
                                                    0.5
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 50,
                    color: _backgroundColor,
                  ),
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(Icons.home, color: _primaryColor),
                        Icon(Icons.search, color: Colors.grey.shade400),
                        Icon(Icons.favorite_border, color: Colors.grey.shade400),
                        Icon(Icons.person_outline, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _generateReferralCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isEditMode
                        ? 'Updating profile...'
                        : 'Finalizing subscription...',
                  ),
                ],
              ),
            ),
          );

          try {
            final brandingData = {
              'appName': _appNameController.text,
              'primaryColor': _primaryColor.toARGB32(),
              'secondaryColor': _secondaryColor.toARGB32(),
              'backgroundColor': _backgroundColor.toARGB32(),
              'useDarkMode': _useDarkMode,
              'fontFamily': _selectedFont,
              'databaseName': ThemeService.instance.databaseName,
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
                    ..remove('role')
                    ..remove('tenantId');

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

            final tenantId = ThemeService.instance.databaseName;

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
                appName: _appNameController.text,
                databaseName: tenantId,
                logoUrl: brandingData['logoUrl'] as String?,
              );

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('branding_completed', true);

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile updated successfully!'),
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
                appName: _appNameController.text,
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
                  appName: _appNameController.text,
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
                  title: const Text('Setup Complete!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your application is ready. Share this referral code with your customers so they can register:',
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
                      const SizedBox(height: 16),
                      const Text(
                        'You can verify this later in your dashboard.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Let\'s Go', style: TextStyle(color: _primaryColor)),
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
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          widget.isEditMode ? 'Update Profile' : 'Complete Setup',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class CustomLogoCropperScreen extends StatefulWidget {
  final File imageFile;
  final Color primaryColor;

  const CustomLogoCropperScreen({
    Key? key,
    required this.imageFile,
    required this.primaryColor,
  }) : super(key: key);

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
                  onPressed: _isSaving ? null : () async {
                    setState(() => _isSaving = true);
                    try {
                      final img = await controller.croppedBitmap();
                      final data = await img.toByteData(format: ImageByteFormat.png);
                      final bytes = data!.buffer.asUint8List();
                      final tempDir = Directory.systemTemp;
                      final file = await File('${tempDir.path}/cropped_logo_${DateTime.now().millisecondsSinceEpoch}.png').create();
                      await file.writeAsBytes(bytes);
                      if (!mounted) return;
                      Navigator.pop(context, file);
                    } catch (e) {
                      debugPrint('Crop error: $e');
                      if (mounted) Navigator.pop(context, null);
                    }
                  },
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _ModernCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}