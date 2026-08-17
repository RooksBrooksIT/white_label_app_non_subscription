import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeIdentifierScreen extends StatefulWidget {
  const BarcodeIdentifierScreen(
      {super.key, required String scannedBarcode});

  @override
  State<BarcodeIdentifierScreen> createState() =>
      _BarcodeIdentifierScreenState();
}

class _BarcodeIdentifierScreenState extends State<BarcodeIdentifierScreen> {
  // ── Theme helpers ────────────────────────────
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;

  // ── State ────────────────────────────────────
  bool _isLoading = false;
  DocumentSnapshot? _productDocument;
  String _errorMessage = '';
  String? _scannedBarcode;
  bool _scannerActive = true;

  // ── Barcode detect ───────────────────────────
  void _onBarcodeDetected(String barcode) async {
    setState(() {
      _scannerActive = false;
      _isLoading = true;
      _errorMessage = '';
      _scannedBarcode = barcode;
    });
    try {
      final snap = await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() => _productDocument = snap.docs.first);
      } else {
        setState(() => _productDocument = null);
        _showNotFoundAlert();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching product data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNotFoundAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Product Not Found',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
              'No product found for barcode:\n${_scannedBarcode ?? ''}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _reset();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _reset() => setState(() {
        _scannerActive = true;
        _scannedBarcode = null;
        _productDocument = null;
        _errorMessage = '';
      });

  dynamic _get(String field) => _productDocument?.get(field) ?? 'N/A';

  String _fmtDate(dynamic d) {
    if (d == null) return 'N/A';
    try {
      if (d is Timestamp) {
        final dt = d.toDate();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
      return d.toString();
    } catch (_) {
      return 'N/A';
    }
  }

  String _warrantyStatus() {
    final end = _get('warrantyEndDate');
    if (end == null || end == 'N/A') return 'Unknown';
    try {
      DateTime? dt;
      if (end is Timestamp) dt = end.toDate();
      if (dt == null) return 'Unknown';
      final now = DateTime.now();
      if (dt.isAfter(now)) {
        final days = dt.difference(now).inDays;
        return days > 30
            ? 'Active ($days days left)'
            : 'Expiring Soon ($days days left)';
      }
      return 'Expired';
    } catch (_) {
      return 'Unknown';
    }
  }

  Color _warrantyColor() {
    final status = _warrantyStatus();
    if (status.startsWith('Active')) return Colors.green;
    if (status.startsWith('Expiring')) return Colors.orange;
    if (status == 'Expired') return errorColor;
    return const Color(0xFF64748B);
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // ── AppBar ─────────────────────────────
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
          'Barcode Identity',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          if (_scannedBarcode != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.refresh_rounded,
                    size: 18, color: primaryColor),
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
            // ── Camera scanner ──────────────
            if (_scannerActive) _buildScannerCard(),

            // ── Loading ─────────────────────
            if (_isLoading) _buildLoadingState(),

            // ── Error ───────────────────────
            if (!_isLoading && _errorMessage.isNotEmpty) _buildErrorState(),

            // ── Results ─────────────────────
            if (!_isLoading && _productDocument != null) ...[
              _buildBarcodeChip(),
              const SizedBox(height: 14),
              _buildSection(
                icon: Icons.inventory_2_rounded,
                title: 'Product Information',
                rows: [
                  _row(Icons.shopping_bag_rounded, 'Product Name',
                      _get('productName').toString()),
                  _row(Icons.branding_watermark_rounded, 'Brand Name',
                      _get('brandName').toString()),
                  _row(Icons.confirmation_number_rounded, 'Serial Number',
                      _get('serialNumber').toString()),
                  _row(Icons.model_training_rounded, 'Model Number',
                      _get('modelNumber').toString()),
                ],
              ),
              const SizedBox(height: 14),
              _buildSection(
                icon: Icons.shield_rounded,
                title: 'Warranty Information',
                rows: [
                  _row(Icons.calendar_today_rounded, 'Start Date',
                      _fmtDate(_get('warrantyStartDate'))),
                  _row(Icons.event_rounded, 'End Date',
                      _fmtDate(_get('warrantyEndDate'))),
                  _statusRow(),
                ],
              ),
              const SizedBox(height: 14),
              _buildSection(
                icon: Icons.person_rounded,
                title: 'Customer Information',
                rows: [
                  _row(Icons.badge_rounded, 'Customer ID',
                      _get('customerId').toString()),
                  _row(Icons.person_rounded, 'Customer Name',
                      _get('customerName').toString()),
                  _row(Icons.phone_rounded, 'Phone Number',
                      _get('customerPhone').toString()),
                ],
              ),
              const SizedBox(height: 22),
              // ── Action buttons ──────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          size: 18),
                      label: const Text('Scan Another',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scannedBarcode != null
                          ? () => _onBarcodeDetected(_scannedBarcode!)
                          : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
          ],
        ),
      ),
    );
  }

  // ── Camera card ──────────────────────────────
  Widget _buildScannerCard() {
    return Container(
      height: 280,
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code != null && _scannerActive) {
                _onBarcodeDetected(code);
              }
            },
          ),
          // Corner-bracket overlay
          Center(
            child: SizedBox(
              width: 220,
              height: 140,
              child: CustomPaint(
                painter: _CornerPainter(color: primaryColor),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 14,
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
                  'Align barcode inside the frame',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ──────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
          const SizedBox(height: 16),
          Text(
            'Searching for product…',
            style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────
  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: errorColor, size: 40),
          const SizedBox(height: 10),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: errorColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _scannedBarcode != null
                ? () => _onBarcodeDetected(_scannedBarcode!)
                : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barcode chip ─────────────────────────────
  Widget _buildBarcodeChip() {
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
                Text(_scannedBarcode ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                if (_get('documentId') != 'N/A')
                  Text(
                    'Doc ID: ${_get('documentId')}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 20),
        ],
      ),
    );
  }

  // ── Info section card ────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> rows,
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2)),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 4),
            ...rows
                .expand((w) => [w, const Divider(color: Color(0xFFF8FAFC))])
                .toList()
              ..removeLast(),
          ],
        ),
      ),
    );
  }

  // ── Detail row ───────────────────────────────
  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: primaryColor.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Warranty status row (coloured) ───────────
  Widget _statusRow() {
    final status = _warrantyStatus();
    final color = _warrantyColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Warranty Status',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.4)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corner-bracket painter ───────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;

    void c(Offset o, Offset a, Offset b) {
      canvas.drawLine(o + a, o, p);
      canvas.drawLine(o, o + b, p);
    }

    c(Offset.zero, const Offset(0, len), const Offset(len, 0));
    c(Offset(size.width, 0), const Offset(-len, 0), const Offset(0, len));
    c(Offset(0, size.height), const Offset(0, -len), const Offset(len, 0));
    c(Offset(size.width, size.height), const Offset(-len, 0),
        const Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
