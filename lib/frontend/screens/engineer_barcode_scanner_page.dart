import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String userName;

  const BarcodeScannerScreen({super.key, required this.userName});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String? scannedCode;
  bool _isScanning = true;

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

  // Color scheme
  // Color scheme
  // final Color _deepBlue = const Color(0xFF0B3470);
  // final Color _lightBlue = const Color(0xFF4B6A93);
  // final Color _accentColor = const Color(0xFF5D8AA8);

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _scannerController = MobileScannerController();
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
    try {
      final snapshot = await FirestoreService.instance
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
      print('Error getting next document ID: $e');
      return 'BSD${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _saveToFirestore() async {
    if (_productNameController.text.isEmpty ||
        _brandNameController.text.isEmpty ||
        _customerNameController.text.isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    try {
      final documentId = await _getNextDocumentId();

      await FirestoreService.instance
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
            "userlog": widget.userName, // This will now work correctly
          });

      _showSnackBar(
        'Product saved successfully with ID: $documentId',
        Colors.green,
      );
      _resetForm();
    } catch (e) {
      print('Firestore error: $e');
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
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              floating: true,
              expandedHeight: 100,
              flexibleSpace: _buildGlassAppBar(),
              iconTheme: IconThemeData(
                color: Theme.of(context).iconTheme.color,
              ),
            ),

            // Main Content
            SliverList(
              delegate: SliverChildListDelegate([
                // Scanner Section
                _buildScannerSection(),

                // Form Section or Empty State
                if (scannedCode != null)
                  _buildProductForm()
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

  Widget _buildGlassAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Barcode Scanner',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
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
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.8,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    // Scanning frame
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
                        child: CustomPaint(painter: ScannerBorderPainter()),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
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
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            'Scanned: $scannedCode',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
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
                color: Theme.of(
                  context,
                ).cardColor, // BoxShape.circle not visible on white without color
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.transparent),
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
                icon: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  'Start Scanning',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shadowColor: Colors.transparent,
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
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanned Barcode:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          scannedCode!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
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
                  ),
                  const SizedBox(height: 15),
                  _buildGlassTextField(
                    controller: _brandNameController,
                    label: 'Brand Name *',
                    icon: Icons.branding_watermark,
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
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            icon,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
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
              color: Theme.of(context).textTheme.bodyMedium?.color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _formatDate(date),
              style: TextStyle(
                color: date == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          foregroundColor: isPrimary
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).primaryColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: isPrimary
              ? null
              : BorderSide(color: Theme.of(context).primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class ScannerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
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
