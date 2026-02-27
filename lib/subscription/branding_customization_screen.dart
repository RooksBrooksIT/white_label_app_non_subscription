import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandingCustomizationScreen extends StatefulWidget {
  final String? planName;
  final bool? isYearly;
  final bool? isSixMonths;
  final int? price;
  final int? originalPrice;
  final String? paymentMethod;
  final String? transactionId;
  final bool isEditMode;

  // New fields for plan limits and features
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;

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
  });

  @override
  State<BrandingCustomizationScreen> createState() =>
      _BrandingCustomizationScreenState();
}

class _BrandingCustomizationScreenState
    extends State<BrandingCustomizationScreen> {
  // Branding State
  Color _primaryColor = Colors.deepPurple;
  Color _secondaryColor = Colors.amber;
  Color _backgroundColor = Colors.white; // Fixed to white as per requirements
  File? _logoFile;
  String? _existingLogoUrl;
  final bool _useDarkMode = false; // Fixed to false as per requirements

  String _selectedFont = 'Roboto';
  final TextEditingController _appNameController = TextEditingController(
    text: 'My Awesome App',
  );

  // Preset Themes - Modern color combinations
  final List<Map<String, Color>> _presetThemes = [
    // Modern Blues
    {
      'primary': const Color(0xFF2563EB),
      'secondary': const Color(0xFF7C3AED),
    }, // Electric Blue to Purple
    {
      'primary': const Color(0xFF0891B2),
      'secondary': const Color(0xFF2D6A4F),
    }, // Cyan to Green
    {
      'primary': const Color(0xFF7C3AED),
      'secondary': const Color(0xFFDB2777),
    }, // Purple to Pink
    {
      'primary': const Color(0xFFDC2626),
      'secondary': const Color(0xFFF59E0B),
    }, // Red to Amber
    {
      'primary': const Color(0xFF059669),
      'secondary': const Color(0xFF10B981),
    }, // Emerald
    {
      'primary': const Color(0xFF9333EA),
      'secondary': const Color(0xFFF472B6),
    }, // Purple to Pink
    // Warm Tones
    {
      'primary': const Color(0xFFEA580C),
      'secondary': const Color(0xFFFBBF24),
    }, // Orange to Yellow
    {
      'primary': const Color(0xFF1E40AF),
      'secondary': const Color(0xFF3B82F6),
    }, // Navy to Blue
    {
      'primary': const Color(0xFFBE185D),
      'secondary': const Color(0xFFEC4899),
    }, // Rose to Pink
    {
      'primary': const Color(0xFF4F46E5),
      'secondary': const Color(0xFF818CF8),
    }, // Indigo
    {
      'primary': const Color(0xFFB45309),
      'secondary': const Color(0xFFF59E0B),
    }, // Amber
    {
      'primary': const Color(0xFF065F46),
      'secondary': const Color(0xFF34D399),
    }, // Dark Green to Light Green
    // Professional Tones
    {
      'primary': const Color(0xFF1F2937),
      'secondary': const Color(0xFF4B5563),
    }, // Gray Scale
    {
      'primary': const Color(0xFF8B5CF6),
      'secondary': const Color(0xFFC4B5FD),
    }, // Violet
    {
      'primary': const Color(0xFFB91C1C),
      'secondary': const Color(0xFFFCA5A5),
    }, // Red
  ];

  int _selectedThemeIndex = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize with current values from ThemeService
    final theme = ThemeService.instance;
    _primaryColor = theme.primaryColor;
    _secondaryColor = theme.secondaryColor;
    _backgroundColor = Colors.white; // Requirement: Fixed to white
    _selectedFont = theme.fontFamily;
    _appNameController.text = theme.appName;

    // Pre-fill existing logo URL in edit mode
    if (widget.isEditMode && theme.logoUrl != null) {
      _existingLogoUrl = theme.logoUrl;
    }

    // Try to find if current colors match a preset
    _selectedThemeIndex = _presetThemes.length; // Default to Custom
    for (int i = 0; i < _presetThemes.length; i++) {
      if (_presetThemes[i]['primary']?.toARGB32() == _primaryColor.toARGB32() &&
          _presetThemes[i]['secondary']?.toARGB32() ==
              _secondaryColor.toARGB32()) {
        _selectedThemeIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _logoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Handle permission errors, etc.
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  void _showColorPicker(String type) {
    Color currentColor;
    if (type == 'primary') {
      currentColor = _primaryColor;
    } else if (type == 'secondary') {
      currentColor = _secondaryColor;
    } else {
      currentColor = _backgroundColor;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick ${type[0].toUpperCase()}${type.substring(1)} Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (type == 'primary') {
                  _primaryColor = color;
                } else if (type == 'secondary') {
                  _secondaryColor = color;
                } else {
                  _backgroundColor = color;
                }

                if (type != 'background') {
                  // When manually picking primary/secondary, set to Custom mode
                  _selectedThemeIndex = _presetThemes.length;
                }
              });
            },
            labelTypes: const [ColorLabelType.hsl],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeService.instance.defaultTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.blue.shade50.withValues(alpha: 0.5),
              Colors.grey.shade200,
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              widget.isEditMode ? 'Edit Branding' : 'Customize Branding',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: Colors.black,
            elevation: 0,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildAppInfoSection(),
                      const SizedBox(height: 32),
                      _buildLogoUploadSection(),
                      const SizedBox(height: 32),
                      _buildColorThemeSection(), // Redesigned section
                      const SizedBox(height: 32),
                      _buildVisualSettingsSection(),
                      const SizedBox(height: 48),
                      _buildPreviewSection(),
                      const SizedBox(height: 48),
                      _buildContinueButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note, color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _appNameController,
              decoration: InputDecoration(
                hintText: 'Enter your app name',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.app_registration, color: _primaryColor),
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild for preview
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brand Your App',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Make the app truly yours. Upload your logo and choose your brand colors.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoUploadSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image, color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Company Logo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_logoFile!, fit: BoxFit.contain),
                      )
                    : _existingLogoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _existingLogoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildUploadPlaceholder(),
                        ),
                      )
                    : _buildUploadPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 12),
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
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    );
  }

  // REDESIGNED THEME COLOR SECTION - More Professional
  Widget _buildColorThemeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.palette, color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Theme Colors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Preset Themes with modern design
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
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

                  // Theme Circles Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemCount: _presetThemes.length + 1, // +1 for Custom
                    itemBuilder: (context, index) {
                      final isCustom = index == _presetThemes.length;
                      final isSelected = _selectedThemeIndex == index;

                      if (isCustom) {
                        return _buildCustomThemeCircle(isSelected);
                      }

                      return _buildModernThemeCircle(
                        index,
                        _presetThemes[index]['primary']!,
                        _presetThemes[index]['secondary']!,
                        isSelected,
                      );
                    },
                  ),
                ],
              ),
            ),

            if (_selectedThemeIndex == _presetThemes.length) ...[
              const SizedBox(height: 20),

              // Custom Colors Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Colors',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
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
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern Theme Circle Design
  Widget _buildModernThemeCircle(
    int index,
    Color primary,
    Color secondary,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedThemeIndex = index;
          _primaryColor = primary;
          _secondaryColor = secondary;
        });
      },
      child: Stack(
        children: [
          Container(
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
                        color: primary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(Icons.check, color: primary, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  // Modern Custom Theme Circle
  Widget _buildCustomThemeCircle(bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedThemeIndex = _presetThemes.length;
        });
      },
      child: Stack(
        children: [
          Container(
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
                        color: _primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.color_lens, color: Colors.white, size: 18),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(Icons.check, color: _primaryColor, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  // Modern Color Button
  Widget _buildModernColorButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.text_format,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Typography',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.font_download,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Font Family',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFont,
                      underline: Container(),
                      icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
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
                                    style: GoogleFonts.getFont(f, fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedFont = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
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
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
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
          child: Container(
            width: 280,
            height: 500,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade300, width: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                children: [
                  // Mock Status Bar
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
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
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 16,
                          color: _backgroundColor.computeLuminance() < 0.5
                              ? Colors.white70
                              : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.wifi,
                          size: 16,
                          color: _backgroundColor.computeLuminance() < 0.5
                              ? Colors.white70
                              : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.battery_full,
                          size: 16,
                          color: _backgroundColor.computeLuminance() < 0.5
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  // Mock App Bar
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _logoFile != null
                            ? Image.file(
                                _logoFile!,
                                height: 30,
                                width: 30,
                                fit: BoxFit.contain,
                              )
                            : _existingLogoUrl != null
                            ? Image.network(
                                _existingLogoUrl!,
                                height: 30,
                                width: 30,
                                fit: BoxFit.contain,
                              )
                            : Container(
                                width: 30,
                                height: 30,
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
                        const SizedBox(width: 8),
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
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.notifications_none,
                          color: _backgroundColor.computeLuminance() < 0.5
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_primaryColor, _secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Feature Card',
                                style: const TextStyle(
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
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _secondaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.person,
                                    color: _secondaryColor,
                                  ),
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
                                            _backgroundColor
                                                    .computeLuminance() <
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
                                            _backgroundColor
                                                    .computeLuminance() <
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
                  // Mock Tab Bar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(17),
                        bottomRight: Radius.circular(17),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  // Mock Bottom Navigation
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(Icons.home, color: _primaryColor),
                        Icon(Icons.search, color: Colors.grey.shade400),
                        Icon(
                          Icons.favorite_border,
                          color: Colors.grey.shade400,
                        ),
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
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () async {
          // Show loading dialog
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
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          );

          try {
            // Prepare branding data
            final brandingData = {
              'appName': _appNameController.text,
              'primaryColor': _primaryColor.toARGB32(),
              'secondaryColor': _secondaryColor.toARGB32(),
              'backgroundColor': _backgroundColor.toARGB32(),
              'useDarkMode': _useDarkMode,
              'fontFamily': _selectedFont,
              'databaseName': ThemeService.instance.databaseName,
            };

            // Use real auth uid if available
            final uid =
                AuthStateService.instance.currentUser?.uid ?? 'demo-user';

            debugPrint(
              'BrandingCustomizationScreen: uid=$uid, appName=${_appNameController.text}',
            );
            debugPrint(
              'BrandingCustomizationScreen: logoFile=${_logoFile?.path}',
            );

            // Upload logo if a new file was picked
            if (_logoFile != null) {
              debugPrint(
                'BrandingCustomizationScreen: Starting logo upload...',
              );
              final logoUrl = await StorageService.instance.uploadLogo(
                userId: uid,
                file: _logoFile!,
              );
              if (logoUrl != null) {
                brandingData['logoUrl'] = logoUrl;
              }
            } else if (_existingLogoUrl != null) {
              // Keep existing logo URL if no new file was picked
              brandingData['logoUrl'] = _existingLogoUrl!;
            }

            if (widget.isEditMode) {
              // --- Edit Mode: Only update branding data ---

              // Save to App-Specific Collection
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                brandingData: brandingData,
              );

              // Update App Theme
              ThemeService.instance.updateTheme(
                primary: _primaryColor,
                secondary: _secondaryColor,
                backgroundColor: _backgroundColor,
                isDarkMode: _useDarkMode,
                fontFamily: _selectedFont,
                appName: _appNameController.text,
                databaseName: ThemeService.instance.databaseName,
                logoUrl: brandingData['logoUrl'] as String?,
              );

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );

              // Use pushReplacement to force a full rebuild of the dashboard
              // with the updated branding colors and app name
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const admindashboard()),
              );
            } else {
              // --- First-time Setup Mode ---

              // Generate Referral Code
              final referralCode = _generateReferralCode();
              brandingData['referralCode'] = referralCode;

              // 1. Save to App-Specific Collection ('data' as stable ID)
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                brandingData: brandingData,
              );

              // 2. Save Referral Code Mapping
              await FirestoreService.instance.saveReferralCode(
                code: referralCode,
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                adminUid: uid,
              );

              // 3. Save Full Subscription with Branding (linked to user)
              await FirestoreService.instance.upsertSubscription(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                planName: widget.planName!,
                isYearly: widget.isYearly!,
                isSixMonths: widget.isSixMonths ?? false,
                price: widget.price!,
                originalPrice: widget.originalPrice,
                paymentMethod: widget.paymentMethod!,
                brandingData: brandingData,
                limits: widget.limits,
                geoLocation: widget.geoLocation,
                attendance: widget.attendance,
                barcode: widget.barcode,
                reportExport: widget.reportExport,
              );

              // 4. Update Global User Directory (Link Admin to this App)
              await FirestoreService.instance.saveUserDirectory(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                role: 'admin',
                appName: _appNameController.text,
              );

              // 5. Activate the user after successful subscription
              await FirestoreService.instance.setUserActiveStatus(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                active: true,
              );

              // Update App Theme
              ThemeService.instance.updateTheme(
                primary: _primaryColor,
                secondary: _secondaryColor,
                backgroundColor: _backgroundColor,
                isDarkMode: _useDarkMode,
                fontFamily: _selectedFont,
                appName: _appNameController.text,
                databaseName: ThemeService.instance.databaseName,
                logoUrl: brandingData['logoUrl'] as String?,
              );

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              // Show Success Dialog with Referral Code
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
                          borderRadius: BorderRadius.circular(8),
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
                      child: Text(
                        'Let\'s Go',
                        style: TextStyle(color: _primaryColor),
                      ),
                    ),
                  ],
                ),
              );

              if (!mounted) return;
              // Navigate directly to Admin Dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const admindashboard()),
                (route) => false,
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving preferences: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          widget.isEditMode ? 'Update Profile' : 'Complete Setup',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class ThemeCirclePainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color tertiary;

  ThemeCirclePainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Draw Top Half (Primary)
    paint.color = primary;
    canvas.drawArc(rect, -3.14159, 3.14159, true, paint);

    // 2. Draw Bottom Left (Secondary)
    paint.color = secondary;
    canvas.drawArc(
      rect,
      1.5708,
      1.5708,
      true,
      paint,
    ); // 90 to 180 degrees ? Wait.
    // Arc starts from positive X axis (0).
    // Top half is -PI to 0. (from left to right top)
    // Actually, drawArc(rect, startAngle, sweepAngle, useCenter, paint)
    // -PI is 180 deg (left). sweep PI (180). This draws Top Half. Correct.

    // Bottom Left:
    // Angle from PI (180 or -180) to PI/2 (90).
    // Let's use 0 to PI (bottom half).
    // Bottom Left is 90 deg to 180 deg?
    // 0 is Right. PI/2 is Bottom. PI is Left.
    // So Bottom Left is from PI/2 to PI.
    // Bottom Right is from 0 to PI/2.

    // Bottom Left Implementation:
    paint.color = secondary;
    canvas.drawArc(rect, 1.5708, 1.5708, true, paint); // PI/2 to PI?
    // sweep 1.57 is 90 deg. Start at 1.57 (90 deg). YES.

    // 3. Draw Bottom Right (Tertiary/Grey)
    paint.color = tertiary;
    canvas.drawArc(rect, 0, 1.5708, true, paint); // 0 to 90 deg.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
