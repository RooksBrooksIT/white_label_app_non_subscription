import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EngineerBarcodeIdentifierScreen extends StatefulWidget {
  final String scannedBarcode;
  final String userName;

  const EngineerBarcodeIdentifierScreen({
    super.key,
    required this.scannedBarcode,
    required this.userName,
  });

  @override
  State<EngineerBarcodeIdentifierScreen> createState() =>
      _EngineerBarcodeIdentifierScreenState();
}

class _EngineerBarcodeIdentifierScreenState
    extends State<EngineerBarcodeIdentifierScreen> {
  bool _isLoading = false;
  DocumentSnapshot? _productDocument;
  String _errorMessage = '';
  String? _scannedBarcode;
  bool _scannerActive = true;

  // Color scheme
  // final Color _deepBlue = const Color(0xFF0B3470);
  // final Color _lightBlue = const Color(0xFF4B6A93);

  @override
  void initState() {
    super.initState();
    _scannedBarcode = widget.scannedBarcode;
    // If barcode is provided initially, fetch data
    if (_scannedBarcode != null && _scannedBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchProductData(_scannedBarcode!);
      });
    }
  }

  void _onBarcodeDetected(String barcode) async {
    await _fetchProductData(barcode);
  }

  Future<void> _fetchProductData(String barcode) async {
    setState(() {
      _scannerActive = false;
      _isLoading = true;
      _errorMessage = '';
      _scannedBarcode = barcode;
    });

    try {
      final querySnapshot = await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _productDocument = querySnapshot.docs.first;
        });

        // Log the engineer activity
        await _logEngineerActivity(barcode, 'SCAN', true);
      } else {
        setState(() {
          _productDocument = null;
        });
        // Log failed scan attempt
        await _logEngineerActivity(barcode, 'SCAN', false);
        _showProductNotFoundAlert();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching product data: $e';
      });
      // Log error activity
      await _logEngineerActivity(barcode, 'SCAN_ERROR', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logEngineerActivity(
    String barcode,
    String action,
    bool success,
  ) async {
    try {
      await FirestoreService.instance.collection('EngineerActivityLogs').add({
        'engineerName': widget.userName,
        'barcode': barcode,
        'action': action,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'productDocumentId': _productDocument?.id,
        'productName': _productDocument?.get('productName') ?? 'Unknown',
        'deviceInfo': {
          'platform': 'Flutter Web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      print('Error logging activity: $e');
      // Don't show error to user for logging failures
    }
  }

  Future<void> _logRefreshActivity() async {
    if (_scannedBarcode != null && _productDocument != null) {
      await _logEngineerActivity(_scannedBarcode!, 'REFRESH', true);
    }
  }

  void _showProductNotFoundAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Product Not Found'),
            content: Text(
              'No product found for barcode: ${_scannedBarcode ?? ''}',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _scannerActive = true;
                    _scannedBarcode = null;
                  });
                },
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          );
        },
      );
    });
  }

  void _navigateBackToScanner() {
    setState(() {
      _scannerActive = true;
      _scannedBarcode = null;
      _productDocument = null;
      _errorMessage = '';
    });
  }

  // Helper method to get field value with null safety
  dynamic _getFieldValue(String fieldName) {
    return _productDocument?.get(fieldName) ?? 'N/A';
  }

  // Format timestamp fields
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  // Format date fields
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is Timestamp) {
        return _formatTimestamp(date);
      } else if (date is String) {
        return date;
      }
      return date.toString();
    } catch (e) {
      return 'N/A';
    }
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
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              floating: true,
              expandedHeight: 120,
              flexibleSpace: _buildGlassAppBar(),
              iconTheme: IconThemeData(
                color: Theme.of(context).iconTheme.color,
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                // Engineer Info Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logged in as:',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.userName,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_scannerActive)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      height: 350,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            'Scan Product Barcode',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.titleLarge?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: MobileScanner(
                              onDetect: (capture) {
                                final barcode = capture.barcodes.first.rawValue;
                                if (barcode != null && _scannerActive) {
                                  _onBarcodeDetected(barcode);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isLoading) _buildLoadingState(),
                if (!_isLoading && _errorMessage.isNotEmpty) _buildErrorState(),
                if (!_isLoading && _productDocument != null)
                  _buildProductDetails(),
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
          'Product Details',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: _navigateBackToScanner,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              if (_scannedBarcode != null) {
                _fetchProductData(_scannedBarcode!);
              }
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
              ),
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Searching for product: ${_scannedBarcode ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Engineer: ${widget.userName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
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

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Engineer: ${widget.userName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 20),
              _buildGlassButton(
                onPressed: () {
                  if (_scannedBarcode != null) {
                    _fetchProductData(_scannedBarcode!);
                  }
                },
                text: 'Retry',
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    final data = _productDocument!.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scanned Barcode Display
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
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        Text(
                          _scannedBarcode ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Document ID: ${_getFieldValue('documentId')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Engineer: ${widget.userName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
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
                  _buildDetailRow(
                    icon: Icons.shopping_bag,
                    label: 'Product Name',
                    value: _getFieldValue('productName').toString(),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.branding_watermark,
                    label: 'Brand Name',
                    value: _getFieldValue('brandName').toString(),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.confirmation_number,
                    label: 'Serial Number',
                    value: _getFieldValue('serialNumber').toString(),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.model_training,
                    label: 'Model Number',
                    value: _getFieldValue('modelNumber').toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Warranty Information
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Warranty Information'),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Warranty Start Date',
                    value: _formatDate(_getFieldValue('warrantyStartDate')),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Warranty End Date',
                    value: _formatDate(_getFieldValue('warrantyEndDate')),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.schedule,
                    label: 'Warranty Status',
                    value: _getWarrantyStatus(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Customer Information
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Customer Information'),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'Customer Id',
                    value: _getFieldValue('customerId').toString(),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.person_outline,
                    label: 'Customer Name',
                    value: _getFieldValue('customerName').toString(),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.phone,
                    label: 'Customer Phone Number',
                    value: _getFieldValue('customerPhone').toString(),
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
                  onPressed: _navigateBackToScanner,
                  text: 'Scan Another',
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildGlassButton(
                  onPressed: () {
                    if (_scannedBarcode != null) {
                      _fetchProductData(_scannedBarcode!);
                      _logRefreshActivity();
                    }
                  },
                  text: 'Refresh',
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).textTheme.bodyMedium?.color,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color:
                      valueColor ??
                      Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getWarrantyStatus() {
    final endDate = _getFieldValue('warrantyEndDate');
    if (endDate == null || endDate == 'N/A') return 'Unknown';

    try {
      DateTime? warrantyEnd;
      if (endDate is Timestamp) {
        warrantyEnd = endDate.toDate();
      } else if (endDate is String && endDate != 'N/A') {
        warrantyEnd = DateTime.parse(endDate);
      }

      if (warrantyEnd != null) {
        final now = DateTime.now();
        if (warrantyEnd.isAfter(now)) {
          final difference = warrantyEnd.difference(now);
          final daysLeft = difference.inDays;
          if (daysLeft > 30) {
            return 'Active ($daysLeft days left)';
          } else {
            return 'Expiring Soon ($daysLeft days left)';
          }
        } else {
          return 'Expired';
        }
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
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
        color: Theme.of(context).textTheme.titleLarge?.color,
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
