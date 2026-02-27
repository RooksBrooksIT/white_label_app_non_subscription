import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeIdentifierScreen extends StatefulWidget {
  const BarcodeIdentifierScreen({super.key, required String scannedBarcode});

  @override
  State<BarcodeIdentifierScreen> createState() =>
      _BarcodeIdentifierScreenState();
}

class _BarcodeIdentifierScreenState extends State<BarcodeIdentifierScreen> {
  bool _isLoading = false;
  DocumentSnapshot? _productDocument;
  String _errorMessage = '';
  String? _scannedBarcode;
  bool _scannerActive = true;

  void _onBarcodeDetected(String barcode) async {
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
      } else {
        setState(() {
          _productDocument = null;
        });
        _showProductNotFoundAlert();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching product data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Theme.of(context).cardColor,
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
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.95),
              Theme.of(context).primaryColor.withOpacity(0.7),
              Theme.of(context).primaryColor.withOpacity(0.95),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              floating: true,
              expandedHeight: 100,
              flexibleSpace: _buildGlassAppBar(),
              iconTheme: IconThemeData(
                color: Colors.white, // This will make the back icon white
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                if (_scannerActive)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      height: 350,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            'Scan Product Barcode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: MobileScanner(
                              onDetect: (capture) {
                                final barcode = capture.barcodes.first.rawValue;
                                if (barcode != null) {
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _navigateBackToScanner,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              if (_scannedBarcode != null) {
                _onBarcodeDetected(_scannedBarcode!);
              }
            },
            tooltip: 'Refresh',
          ),
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
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                'Searching for product: ${_scannedBarcode ?? ''}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
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
              const Icon(Icons.error_outline, color: Colors.white, size: 50),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildGlassButton(
                onPressed: () {
                  if (_scannedBarcode != null) {
                    _onBarcodeDetected(_scannedBarcode!);
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
                          _scannedBarcode ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Document ID: ${_getFieldValue('documentId')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
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

          // Warranty Information
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Customer Information'),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Customer Id',
                    value: _formatDate(_getFieldValue('customerId')),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Customer Name',
                    value: _formatDate(_getFieldValue('customerName')),
                  ),
                  const SizedBox(height: 15),
                  _buildDetailRow(
                    icon: Icons.schedule,
                    label: 'Customer Phone Number',
                    value: _formatDate(_getFieldValue('customerPhone')),
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
                      _onBarcodeDetected(_scannedBarcode!);
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

  // Removed unused _getAdditionalFields

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
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

  // Removed unused _getWarrantyStatusColor

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String text,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(isPrimary ? 0.3 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Colors.transparent
              : Colors.white.withOpacity(0.1),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: isPrimary ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Removed unused _getAdditionalFields
