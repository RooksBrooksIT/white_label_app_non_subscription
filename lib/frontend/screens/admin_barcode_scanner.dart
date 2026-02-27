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
  String? scannedCode;
  bool _isScanning = true;
  FirestoreService? _firestore;
  MobileScannerController? _scannerController;

  // Form controllers
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

  final _formKey = GlobalKey<FormState>();

  // Color scheme
  // final Color _deepBlue = const Color(0xFF0B3470);
  // final Color _lightBlue = const Color(0xFF4B6A93);
  // final Color _accentColor = const Color(0xFF5D8AA8);

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
      debugPrint('Firestore initialization error: $e');
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

  Future<String> _getNextDocumentId() async {
    if (_firestore == null) {
      _initializeFirestore();
      if (_firestore == null) {
        return 'BSD${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    try {
      final snapshot = await _firestore!
          .collection('Barcode_Scanning_Details')
          .orderBy('documentId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'BSD001';
      }

      final lastDoc = snapshot.docs.first;
      final lastId = lastDoc['documentId'] as String;
      final number = int.parse(lastId.replaceAll('BSD', ''));
      return 'BSD${(number + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error getting next document ID: $e');
      return 'BSD${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _saveToFirestore() async {
    if (_firestore == null) {
      _initializeFirestore();
      if (_firestore == null) {
        _showSnackBar('Database not ready. Please try again.', Colors.red);
        return;
      }
    }

    try {
      if (_formKey.currentState?.validate() != true) {
        return;
      }

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
            "userlog": "Admin",
          });

      if (!mounted) return;

      _showSnackBar(
        'Product saved successfully with ID: $documentId',
        Colors.green,
      );
      _resetForm();
    } catch (e) {
      debugPrint('Firestore error: $e');
      _showSnackBar('Error saving product: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
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

  Future<void> _selectWarrantyStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _warrantyStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _warrantyStartDate) {
      setState(() {
        _warrantyStartDate = picked;
      });
    }
  }

  Future<void> _selectWarrantyEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _warrantyEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _warrantyEndDate) {
      setState(() {
        _warrantyEndDate = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar with Glass Effect
            SliverAppBar(
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              pinned: true,
              floating: true,
              centerTitle: true,
              title: Text(
                'Barcode Scanner',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              iconTheme: IconThemeData(
                color: Theme.of(context).iconTheme.color,
              ),
              actions: [
                if (scannedCode != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: _resetForm,
                      tooltip: 'Scan New Code',
                    ),
                  ),
              ],
            ),

            // Main Content
            SliverList(
              delegate: SliverChildListDelegate([
                // Scanner Section
                _buildScannerSection(),

                // Form Section or Empty State
                if (scannedCode != null)
                  Form(key: _formKey, child: _buildProductForm())
                else
                  _buildEmptyState(),

                // Add some bottom padding
                const SizedBox(height: 30),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 300, // Fixed height for scanner
          child: _isScanning
              ? Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (!_isScanning) return;

                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          final String? code = barcode.rawValue;
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
                    // Scanner overlay with glass effect
                    // Scanner overlay with glass effect - removed solid container that was blocking camera feed
                    Center(
                      child: Container(
                        width: 250,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: ScannerBorderPainter(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            'Scanned: $scannedCode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
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

  Widget _buildEmptyState() {
    return Container(
      height: 300, // Fixed height for empty state
      margin: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                'Scan a barcode to register product',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isScanning = true;
                  });
                  _scannerController?.start();
                },
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Start Scanning',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scanned Barcode Display with Glass Effect
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scanned Barcode:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          scannedCode!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Product Information
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Product Information'),
                  const SizedBox(height: 20),
                  _buildGlassTextField(
                    controller: _productNameController,
                    label: 'Product Name *',
                    icon: Icons.shopping_bag,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _brandNameController,
                    label: 'Brand Name *',
                    icon: Icons.branding_watermark,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _serialNumberController,
                    label: 'Serial Number',
                    icon: Icons.confirmation_number,
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _modelNumberController,
                    label: 'Model Number',
                    icon: Icons.model_training,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassDateField(
                          date: _warrantyStartDate,
                          label: 'Warranty Start',
                          onTap: _selectWarrantyStartDate,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildGlassDateField(
                          date: _warrantyEndDate,
                          label: 'Warranty End',
                          onTap: _selectWarrantyEndDate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Customer Information
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Customer Information'),
                  const SizedBox(height: 20),
                  _buildGlassTextField(
                    controller: _customerNameController,
                    label: 'Customer Name *',
                    icon: Icons.person,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _customerIdController,
                    label: 'Customer ID',
                    icon: Icons.badge,
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _customerPhoneController,
                    label: 'Customer Phone',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null; // input is valid
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildGlassButton(
                  onPressed: _resetForm,
                  text: 'Cancel',
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildGlassButton(
                  onPressed: _saveToFirestore,
                  text: 'Save Product',
                  isPrimary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).hintColor),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Theme.of(context).hintColor),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDateField({
    required DateTime? date,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: Theme.of(context).hintColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _formatDate(date),
              style: TextStyle(
                color: date == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String text,
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? Theme.of(context).primaryColor
            : Theme.of(context).cardColor,
        side: isPrimary
            ? null
            : BorderSide(color: Theme.of(context).dividerColor),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: isPrimary ? 2 : 0,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: isPrimary
              ? Colors.white
              : Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ScannerBorderPainter extends CustomPainter {
  final Color color;
  ScannerBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      // Will rely on theme usage where Painter is instantiated or defaults to blue if no context
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    const cornerLength = 20.0;

    // Top left corner
    path.moveTo(0, cornerLength);
    path.lineTo(0, 0);
    path.lineTo(cornerLength, 0);

    // Top right corner
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerLength);

    // Bottom right corner
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom left corner
    path.moveTo(cornerLength, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
