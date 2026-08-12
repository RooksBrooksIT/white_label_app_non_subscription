import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminBarcodeScanner extends StatefulWidget {
  const AdminBarcodeScanner({super.key});

  @override
  State<AdminBarcodeScanner> createState() => _AdminBarcodeScannerState();
}

class _AdminBarcodeScannerState extends State<AdminBarcodeScanner> {
  // ── Theme helpers ──────────────────────────────
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;

  // ── State ──────────────────────────────────────
  String? scannedCode;
  bool _isScanning = true;
  FirestoreService? _firestore;
  MobileScannerController? _scannerController;

  // ── Form ───────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _modelNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();

  DateTime? _warrantyStartDate;
  DateTime? _warrantyEndDate;

  // ── Init / Dispose ─────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeDates();
    _scannerController = MobileScannerController();
    _initializeFirestore();
  }

  void _initializeFirestore() {
    try {
      _firestore = FirestoreService.instance;
    } catch (e) {
      debugPrint('Firestore init error: $e');
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _productNameController.dispose();
    _brandNameController.dispose();
    _serialNumberController.dispose();
    _modelNumberController.dispose();
    _customerNameController.dispose();
    _customerIdController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _initializeDates() {
    final now = DateTime.now();
    _warrantyStartDate = now;
    _warrantyEndDate = DateTime(now.year + 1, now.month, now.day);
  }

  // ── Firestore helpers ──────────────────────────
  Future<String> _getNextDocumentId() async {
    _firestore ??= FirestoreService.instance;
    try {
      final snapshot = await _firestore!
          .collection('Barcode_Scanning_Details')
          .orderBy('documentId', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return 'BSD001';
      final lastId = snapshot.docs.first['documentId'] as String;
      final number = int.parse(lastId.replaceAll('BSD', ''));
      return 'BSD${(number + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      return 'BSD${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _saveToFirestore() async {
    _firestore ??= FirestoreService.instance;
    if (_formKey.currentState?.validate() != true) return;
    try {
      final documentId = await _getNextDocumentId();
      await _firestore!
          .collection('Barcode_Scanning_Details')
          .doc(documentId)
          .set({
        'documentId': documentId,
        'barcode': scannedCode,
        'productName': _productNameController.text.trim(),
        'brandName': _brandNameController.text.trim(),
        'currentDate': DateTime.now(),
        'serialNumber': _serialNumberController.text.trim(),
        'modelNumber': _modelNumberController.text.trim(),
        'warrantyStartDate': _warrantyStartDate,
        'warrantyEndDate': _warrantyEndDate,
        'customerName': _customerNameController.text.trim(),
        'customerId': _customerIdController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'userlog': 'Admin',
      });
      if (!mounted) return;
      _showSnackBar('Saved successfully — ID: $documentId', Colors.green);
      _resetForm();
    } catch (e) {
      _showSnackBar('Error saving: $e', errorColor);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _resetForm() {
    setState(() {
      scannedCode = null;
      _isScanning = true;
    });
    _productNameController.clear();
    _brandNameController.clear();
    _serialNumberController.clear();
    _modelNumberController.clear();
    _customerNameController.clear();
    _customerIdController.clear();
    _customerPhoneController.clear();
    _initializeDates();
    _scannerController?.start();
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initial =
        isStart ? (_warrantyStartDate ?? DateTime.now()) : (_warrantyEndDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _warrantyStartDate = picked;
        } else {
          _warrantyEndDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // ── AppBar (dashboard style) ───────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          if (scannedCode != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _resetForm,
                icon: Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
                label: Text('Rescan',
                    style: TextStyle(
                        color: primaryColor, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Scanner / Success view ─────────────
            _buildScannerCard(),
            const SizedBox(height: 16),

            // ── If no code yet: idle hint ──────────
            if (scannedCode == null) _buildIdleHint(),

            // ── If scanned: registration form ─────
            if (scannedCode != null) ...[
              _buildBarcodeResultCard(),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSection(
                      icon: Icons.inventory_2_rounded,
                      title: 'Product Information',
                      children: [
                        _field(_productNameController, 'Product Name',
                            Icons.shopping_bag_rounded,
                            required: true),
                        _field(_brandNameController, 'Brand Name',
                            Icons.branding_watermark_rounded,
                            required: true),
                        _field(_serialNumberController, 'Serial Number',
                            Icons.confirmation_number_rounded),
                        _field(_modelNumberController, 'Model Number',
                            Icons.model_training_rounded),
                        // Warranty dates
                        Row(
                          children: [
                            Expanded(
                              child: _dateField(
                                label: 'Warranty Start',
                                date: _warrantyStartDate,
                                onTap: () => _selectDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dateField(
                                label: 'Warranty End',
                                date: _warrantyEndDate,
                                onTap: () => _selectDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.person_rounded,
                      title: 'Customer Information',
                      children: [
                        _field(_customerNameController, 'Customer Name',
                            Icons.person_rounded,
                            required: true),
                        _field(_customerIdController, 'Customer ID',
                            Icons.badge_rounded),
                        _field(_customerPhoneController, 'Customer Phone',
                            Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Phone number required';
                              }
                              if (v.length != 10) {
                                return 'Must be exactly 10 digits';
                              }
                              return null;
                            }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ── Action buttons ─────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetForm,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveToFirestore,
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Save Product',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Scanner camera card ──────────────────────
  Widget _buildScannerCard() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _isScanning
          ? Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (!_isScanning) return;
                    for (final barcode in capture.barcodes) {
                      final code = barcode.rawValue;
                      if (code != null && scannedCode == null) {
                        setState(() {
                          scannedCode = code;
                          _isScanning = false;
                        });
                        _scannerController?.stop();
                        break;
                      }
                    }
                  },
                ),
                // Corner border overlay
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 140,
                    child: CustomPaint(
                      painter: ScannerBorderPainter(color: primaryColor),
                    ),
                  ),
                ),
                // Scanning label
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Point camera at barcode',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : // Scanned success view
          Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Barcode Detected!',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scannedCode ?? '',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Idle hint (no barcode yet) ───────────────
  Widget _buildIdleHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.qr_code_scanner_rounded,
                color: primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan a Barcode',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Align the barcode inside the camera frame above',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Scanned code result chip ─────────────────
  Widget _buildBarcodeResultCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_rounded, color: primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanned Barcode',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor.withValues(alpha: 0.8),
                      letterSpacing: 0.5),
                ),
                Text(
                  scannedCode!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  // ── Section card ─────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            // Fields spaced
            ...children
                .expand((w) => [w, const SizedBox(height: 12)])
                .toList()
              ..removeLast(),
          ],
        ),
      ),
    );
  }

  // ── Text field ───────────────────────────────
  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A)),
      validator: validator ??
          (required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon,
            color: primaryColor.withValues(alpha: 0.7), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Date picker field ────────────────────────
  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: primaryColor.withValues(alpha: 0.7), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryColor),
                  ),
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
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

// ── Corner-bracket scanner overlay painter ────
class ScannerBorderPainter extends CustomPainter {
  final Color color;
  ScannerBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;

    void corner(Offset o, Offset a, Offset b) {
      canvas.drawLine(o + a, o, paint);
      canvas.drawLine(o, o + b, paint);
    }

    corner(Offset.zero, const Offset(0, len), const Offset(len, 0));
    corner(Offset(size.width, 0), const Offset(-len, 0),
        const Offset(0, len));
    corner(Offset(0, size.height), const Offset(0, -len),
        const Offset(len, 0));
    corner(Offset(size.width, size.height), const Offset(-len, 0),
        const Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
