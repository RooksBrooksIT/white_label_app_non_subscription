import 'dart:io';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class EngineerOfficePayQRScreen extends StatefulWidget {
  const EngineerOfficePayQRScreen({super.key});

  /// Helper to also show this as a modal dialog if needed
  static Future<void> showAsModal(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: EngineerOfficePayQRScreen(),
      ),
    );
  }

  @override
  State<EngineerOfficePayQRScreen> createState() =>
      _EngineerOfficePayQRScreenState();
}

class _EngineerOfficePayQRScreenState extends State<EngineerOfficePayQRScreen> {
  File? _cachedFile;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Check if image is already cached in memory
    final memoryFile = StorageService.memoryCachedQRFile;
    if (memoryFile != null &&
        memoryFile.existsSync() &&
        memoryFile.lengthSync() > 0) {
      _cachedFile = memoryFile;
      _isLoading = false;
    } else {
      _isLoading = true;
    }

    _loadQRCode(forceRefresh: false);
  }

  Future<void> _loadQRCode({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isRefreshing = true);
    }

    final file = await StorageService.instance.getCachedQRCodeFile(
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
      if (file != null && file.existsSync() && file.lengthSync() > 0) {
        _cachedFile = file;
      }
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    PaintingBinding.instance.imageCache.clear();
    await _loadQRCode(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF1E293B),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Office Pay QR Scanner',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh QR',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isRefreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Color(0xFF1E293B),
                    ),
            ),
            onPressed: _isRefreshing ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  // Main Payment QR Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card Header with Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.qr_code_2_rounded,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Office Payment QR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Official payment code for customer billing',
                                    style: TextStyle(
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

                        const SizedBox(height: 18),

                        // Official Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF16A34A),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Official Office Collection QR',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // QR Code Display Area:
                        // 1. If cached file exists: Display immediately without any spinner!
                        // 2. If loading for the first time without cache: Show spinner.
                        // 3. If no QR available: Show empty state.
                        _buildQRContent(primaryColor),

                        const SizedBox(height: 24),

                        // Guidance Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF475569),
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ask the customer to scan this QR code with any UPI, banking, or payment scanner to remit payment directly to the office.',
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Display-Only static notice
                  const Center(
                    child: Text(
                      'Display Only • Managed by Office Administrator',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRContent(Color primaryColor) {
    // 1. Immediately show cached image if available
    if (_cachedFile != null &&
        _cachedFile!.existsSync() &&
        _cachedFile!.lengthSync() > 0) {
      return Column(
        children: [
          GestureDetector(
            onTap: () => _openZoomDialog(context, _cachedFile!),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _cachedFile!,
                  height: 240,
                  width: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 240,
                    width: 240,
                    color: const Color(0xFFF8FAFC),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openZoomDialog(context, _cachedFile!),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap QR to enlarge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 2. Loading state: ONLY shown when there is NO cached image and fetching for first time
    if (_isLoading) {
      return Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 14),
              const Text(
                'Loading QR code...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Empty state: No QR uploaded by admin
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_rounded,
              size: 38,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No QR Code Available',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The office payment QR code has not been uploaded yet.\nPlease contact your administrator to upload the QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _loadQRCode(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Check Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(
                color: primaryColor.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openZoomDialog(BuildContext context, File qrFile) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan Office Pay QR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.5,
                      child: Image.file(
                        qrFile,
                        height: 320,
                        width: 320,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pinch to zoom if required',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
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
}
