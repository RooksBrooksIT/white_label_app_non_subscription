import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/pdf_utils.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class CustomerReportGenerator extends StatefulWidget {
  const CustomerReportGenerator({super.key});

  @override
  _CustomerReportGeneratorState createState() =>
      _CustomerReportGeneratorState();
}

class _CustomerReportGeneratorState extends State<CustomerReportGenerator>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Map<String, dynamic>? resultData;
  List<Map<String, dynamic>>? multipleResults;
  bool _loading = false;
  bool _isPdfViewing = false;
  bool _isPdfDownloading = false;
  StreamSubscription? _ticketsSubscription;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Color get _brand => ThemeService.instance.primaryColor;
  Color get _brandLight => ThemeService.instance.primaryColor.withOpacity(0.1);
  Color get _accent => ThemeService.instance.secondaryColor;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    // Load all tickets initially with realtime updates
    _listenToAllTickets();
  }

  @override
  void dispose() {
    _ticketsSubscription?.cancel();
    _animController.dispose();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _listenToAllTickets() {
    setState(() {
      _loading = true;
    });
    _ticketsSubscription = FirestoreService.instance
        .collection('Raised_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              multipleResults = snapshot.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();
              resultData = null;
              _selectedRows.clear();
              _allSelected = false;
              _loading = false;
              if (multipleResults!.isNotEmpty) {
                _animController.forward();
              }
            });
          },
          onError: (error) {
            _showSnack('Error loading tickets: $error', color: Colors.red);
            setState(() {
              _loading = false;
            });
          },
        );
  }

  final Map<int, bool> _selectedRows = {};
  bool _allSelected = false;

  Color get primaryColor => _brand;

  Future<void> _fetchData(String input) async {
    if (input.isEmpty) {
      // If search is cleared, re-listen to all tickets
      _listenToAllTickets();
      return;
    }

    // Cancel the realtime subscription before searching
    _ticketsSubscription?.cancel();
    _ticketsSubscription = null;

    setState(() {
      _loading = true;
      resultData = null;
      multipleResults = null;
      _selectedRows.clear();
      _allSelected = false;
    });
    _animController.reset();

    try {
      final List<QuerySnapshot> snapshots = await Future.wait([
        FirestoreService.instance
            .collection('Raised_tickets')
            .where('customerId', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Raised_tickets')
            .where('mobileNumber', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Raised_tickets')
            .where('ticketId', isEqualTo: input)
            .get(),
      ]);

      // Combine all unique results
      final allDocs = <DocumentSnapshot>{};
      for (var snapshot in snapshots) {
        allDocs.addAll(snapshot.docs);
      }

      if (allDocs.isNotEmpty) {
        multipleResults =
            allDocs.map((doc) => doc.data() as Map<String, dynamic>).toList()
              ..sort((a, b) {
                final aTime = a['createdAt'] as Timestamp?;
                final bTime = b['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });
        for (int i = 0; i < multipleResults!.length; i++) {
          _selectedRows[i] = false;
        }
        setState(() {
          _loading = false;
        });
        _animController.forward();
        _showSnack(
          'Found ${multipleResults!.length} matching entries',
          color: Colors.green,
        );
      } else {
        setState(() {
          _loading = false;
        });
        _showSnack('No data found for "$input"', color: Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {Color color = Colors.blueGrey}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _toggleAllSelection() {
    setState(() {
      _allSelected = !_allSelected;
      if (multipleResults != null) {
        for (int i = 0; i < multipleResults!.length; i++) {
          _selectedRows[i] = _allSelected;
        }
      }
    });
  }

  void _toggleRowSelection(int index) {
    setState(() {
      _selectedRows[index] = !(_selectedRows[index] ?? false);
      if (multipleResults != null) {
        _allSelected = _selectedRows.values.every((v) => v);
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedRecords() {
    if (multipleResults != null) {
      return [
        for (int i = 0; i < multipleResults!.length; i++)
          if (_selectedRows[i] == true) multipleResults![i],
      ];
    } else if (resultData != null) {
      return [resultData!];
    }
    return [];
  }

  int get _selectedCount => _selectedRows.values.where((v) => v).length;

  bool get _canExportReport {
    if (resultData != null) return true;
    return multipleResults != null && _selectedCount > 0;
  }

  List<Map<String, dynamic>> get _displayRecords {
    if (multipleResults != null) return multipleResults!;
    if (resultData != null) return [resultData!];
    return [];
  }

  String _fmt(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? 'N/A' : t;
  }

  String _fmtAmount(dynamic a) {
    if (a == null) return 'N/A';
    final p = double.tryParse(a.toString());
    if (p == null) return a.toString();
    return p == p.roundToDouble()
        ? '₹${p.toInt()}'
        : '₹${p.toStringAsFixed(2)}';
  }

  double _calculateTotalAmount(Map<String, dynamic> record) {
    double total = 0.0;
    // First check if payments array exists
    if (record['payments'] is List) {
      for (var payment in record['payments']) {
        if (payment is Map && payment['amount'] != null) {
          total += (double.tryParse(payment['amount'].toString()) ?? 0.0);
        }
      }
    }
    // Fallback to paymentDetails if no payments array
    if (total == 0 && record['paymentDetails'] != null) {
      total += (double.tryParse(record['paymentDetails'].toString()) ?? 0.0);
    }
    // Also fallback to amount field for compatibility
    if (total == 0 && record['amount'] != null) {
      total += (double.tryParse(record['amount'].toString()) ?? 0.0);
    }
    return total;
  }

  double _totalAmount(List<Map<String, dynamic>> records) =>
      records.fold(0.0, (s, r) => s + _calculateTotalAmount(r));

  String _reportPdfName(List<Map<String, dynamic>> records) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String name;
    if (records.length == 1) {
      final id = _fmt(records.first['ticketId']);
      name = id != 'N/A' ? 'Customer_Report_$id' : 'Customer_Report_$stamp';
    } else {
      name = 'Customer_Report_${records.length}_$stamp';
    }
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  // ─── PDF generation ────────────────────────────────────────────────────────

  PdfColor get _pdfBrand =>
      PdfColor.fromInt(ThemeService.instance.primaryColor.value);
  PdfColor get _pdfBrandLight => PdfColor.fromInt(
    ThemeService.instance.primaryColor.withOpacity(0.1).value,
  );

  Future<pw.Document> _buildPdfDocument(
    List<Map<String, dynamic>> records,
  ) async {
    final pdf = pw.Document();
    final appName = ThemeService.instance.appName;
    final generatedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    pw.MemoryImage? logoImage;
    final logoUrl = ThemeService.instance.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      logoImage = await PdfUtils.fetchNetworkImage(logoUrl);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (ctx) => _pdfHeader(logoImage, appName, generatedAt),
        footer: (ctx) => _pdfFooter(ctx, appName),
        build: (ctx) {
          final widgets = <pw.Widget>[_pdfSummaryBox(records)];
          if (records.length > 1) {
            widgets
              ..add(pw.SizedBox(height: 18))
              ..add(_pdfIndex(records));
          }
          for (var i = 0; i < records.length; i++) {
            widgets
              ..add(pw.SizedBox(height: 18))
              ..add(_pdfCard(records[i], i + 1, records.length));
          }
          return widgets;
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfHeader(
    pw.MemoryImage? logo,
    String appName,
    String generatedAt,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 48,
              height: 48,
              margin: const pw.EdgeInsets.only(right: 14),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER SERVICE REPORT',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfBrand,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  appName,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generated: $generatedAt',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _pdfBrand,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'INTERNAL',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx, String appName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            appName,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Confidential — internal use only',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryBox(List<Map<String, dynamic>> records) {
    final total = _totalAmount(records);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _pdfBrandLight,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _pdfBrand, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Report Summary',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _pdfBrand,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _pdfMetric('Records', records.length.toString()),
              ),
              pw.Expanded(
                child: _pdfMetric('Combined Amount', _fmtAmount(total)),
              ),
              if (multipleResults != null)
                pw.Expanded(
                  child: _pdfMetric(
                    'From Search',
                    '${multipleResults!.length} total',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfMetric(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _pdfBrand,
        ),
      ),
    ],
  );

  pw.Widget _pdfIndex(List<Map<String, dynamic>> records) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfHeading('Quick Reference'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _pdfBrand),
              children: [
                '#',
                'Customer ID',
                'Customer',
                'Ticket ID',
                'Status',
              ].map((h) => _pdfCell(h, header: true)).toList(),
            ),
            ...List.generate(records.length, (i) {
              final r = records[i];
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isOdd ? PdfColors.grey100 : PdfColors.white,
                ),
                children: [
                  _pdfCell('${i + 1}'),
                  _pdfCell(_fmt(r['customerId'])),
                  _pdfCell(_fmt(r['customerName'])),
                  _pdfCell(_fmt(r['ticketId'])),
                  _pdfCell(_fmt(r['adminStatus'])),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfHeading(String title) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color: _pdfBrandLight,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _pdfBrand,
      ),
    ),
  );

  pw.Widget _pdfCell(String text, {bool header = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    child: pw.Text(
      text,
      maxLines: 2,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: header ? PdfColors.white : PdfColors.black,
      ),
    ),
  );

  pw.Widget _pdfDetailRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 118,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: emphasize
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: emphasize ? _pdfBrand : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCard(Map<String, dynamic> r, int index, int total) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Record $index of $total',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfBrand,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _pdfBrand,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  _fmt(r['adminStatus']),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Ticket: ${_fmt(r['ticketId'])}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300, height: 1),
          pw.SizedBox(height: 10),
          _pdfHeading('Customer Details'),
          _pdfDetailRow('Customer ID', _fmt(r['customerId'])),
          _pdfDetailRow('Name', _fmt(r['customerName'])),
          _pdfDetailRow('Mobile', _fmt(r['mobileNumber'])),
          _pdfDetailRow('Ticket ID', _fmt(r['ticketId'])),
          pw.SizedBox(height: 6),
          _pdfHeading('Device Details'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfDetailRow('Brand', _fmt(r['deviceBrand'])),
                    _pdfDetailRow('Type', _fmt(r['deviceType'])),
                  ],
                ),
              ),
              pw.Expanded(
                child: _pdfDetailRow('Condition', _fmt(r['deviceCondition'])),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _pdfHeading('Service & Billing'),
          // Show individual payments
          if (r['payments'] is List && (r['payments'] as List).isNotEmpty)
            ...(r['payments'] as List).asMap().entries.map((entry) {
              final payment = entry.value;
              return _pdfDetailRow(
                payment['paymentMethod'] ?? 'Payment ${entry.key + 1}',
                _fmtAmount(payment['amount']),
              );
            }),
          _pdfDetailRow(
            'Total Amount',
            _fmtAmount(_calculateTotalAmount(r)),
            emphasize: true,
          ),
          _pdfDetailRow('Address', _fmt(r['address'])),
        ],
      ),
    );
  }

  Future<void> _viewReportPdf() async {
    final records = _getSelectedRecords();
    if (records.isEmpty) {
      _showSnack('Select at least one record', color: Colors.orange);
      return;
    }
    setState(() => _isPdfViewing = true);
    try {
      final pdf = await _buildPdfDocument(records);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (fmt) async => pdf.save(),
        name: _reportPdfName(records),
      );
    } catch (e) {
      if (mounted) _showSnack('Unable to open PDF: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPdfViewing = false);
    }
  }

  Future<void> _downloadReportPdf() async {
    final records = _getSelectedRecords();
    if (records.isEmpty) {
      _showSnack('Select at least one record', color: Colors.orange);
      return;
    }
    setState(() => _isPdfDownloading = true);
    try {
      final pdf = await _buildPdfDocument(records);
      if (kIsWeb) {
        // Web: Use Printing package to download
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: '${_reportPdfName(records)}.pdf',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Mobile/Desktop: Use path_provider and open_file
        final dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${_reportPdfName(records)}.pdf');
        await file.writeAsBytes(await pdf.save());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF saved to Downloads'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Download failed: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPdfDownloading = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Customer Report Generator',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ResponsiveWrapper(
          maxWidth: 1200.0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchCard(),
                    const SizedBox(height: 20),
                    if (_loading) _buildLoading(),
                    if (!_loading && _displayRecords.isNotEmpty)
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildResultsSection(),
                        ),
                      ),
                    if (!_loading &&
                        resultData == null &&
                        (multipleResults == null || multipleResults!.isEmpty))
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── SEARCH CARD ────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  color: _brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Customer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _brand,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Text(
                    'Search by Customer ID, Phone or Ticket ID',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A9BB8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Search field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE4F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _searchFocusNode,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _brand,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter Customer ID, Phone, or Ticket ID',
                      hintStyle: TextStyle(
                        color: Color(0xFFADB9CC),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Color(0xFF8A9BB8),
                        size: 20,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                    ),
                    onSubmitted: (v) => _fetchData(v.trim()),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8A9BB8),
                      size: 20,
                    ),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        resultData = null;
                        multipleResults = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Quick-search chips
          Wrap(
            spacing: 8,
            children: [
              'Customer ID',
              'Phone Number',
              'Ticket ID',
            ].map((label) => _searchChip(label)).toList(),
          ),
          const SizedBox(height: 18),
          // Search button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      _searchFocusNode.unfocus();
                      _fetchData(_controller.text.trim());
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.manage_search_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Search & Generate Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _brandLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: _brand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── LOADING ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _brand, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Searching records…',
            style: TextStyle(
              color: _brand.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESULTS SECTION ────────────────────────────────────────────────────────

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats bar
        _buildStatsBar(),
        const SizedBox(height: 14),

        // Select-all bar (multi results only)
        if (multipleResults != null) ...[
          _buildSelectAllBar(),
          const SizedBox(height: 14),
        ],

        // Record cards
        ...List.generate(_displayRecords.length, (i) {
          final record = _displayRecords[i];
          final isMulti = multipleResults != null;
          final isSelected = isMulti ? (_selectedRows[i] ?? false) : true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecordCard(
              record: record,
              index: i,
              isSelectable: isMulti,
              isSelected: isSelected,
              onTap: isMulti ? () => _toggleRowSelection(i) : null,
            ),
          );
        }),

        const SizedBox(height: 4),

        // Export panel
        _buildExportPanel(),
      ],
    );
  }

  Widget _buildStatsBar() {
    final selected = _getSelectedRecords();
    final total = _totalAmount(selected);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_brand, _brand.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _statItem(
            icon: Icons.folder_open_rounded,
            label: 'Found',
            value: '${_displayRecords.length}',
          ),
          _divider(),
          _statItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Selected',
            value: multipleResults != null ? '$_selectedCount' : '1',
          ),
          _divider(),
          _statItem(
            icon: Icons.currency_rupee_rounded,
            label: 'Total',
            value: _fmtAmount(total),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2));

  Widget _buildSelectAllBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _selectedCount > 0 ? _brand.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCount > 0
              ? _brand.withOpacity(0.3)
              : const Color(0xFFDDE4F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 18,
            color: _selectedCount > 0 ? _brand : const Color(0xFF8A9BB8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedCount > 0
                  ? '$_selectedCount of ${multipleResults!.length} selected for PDF export'
                  : 'Select records to export',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _selectedCount > 0 ? _brand : const Color(0xFF8A9BB8),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _brand.withOpacity(0.7),
                ),
              ),
              Checkbox(
                value: _allSelected,
                onChanged: (_) => _toggleAllSelection(),
                activeColor: _brand,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── RECORD CARD ────────────────────────────────────────────────────────────

  Widget _buildRecordCard({
    required Map<String, dynamic> record,
    required int index,
    required bool isSelectable,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final status = record['adminStatus']?.toString();
    final statusColor = _getStatusColor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected && isSelectable
              ? _brand.withOpacity(0.4)
              : const Color(0xFFDDE4F0),
          width: isSelected && isSelectable ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected && isSelectable
                ? _brand.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Card header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: isSelected && isSelectable
                    ? _brand.withOpacity(0.04)
                    : const Color(0xFFF8FAFD),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (isSelectable) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap?.call(),
                        activeColor: _brand,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        (_fmt(record['customerName']).isNotEmpty &&
                                _fmt(record['customerName']) != 'N/A')
                            ? _fmt(record['customerName'])[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: _brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fmt(record['customerName']),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _brand,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ticket: ${_fmt(record['ticketId'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9BB8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status ?? 'N/A',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details grid
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          'Customer ID',
                          _fmt(record['customerId']),
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailTile(
                          'Mobile',
                          _fmt(record['mobileNumber']),
                          icon: Icons.phone_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          'Device Brand',
                          _fmt(record['deviceBrand']),
                          icon: Icons.devices_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailTile(
                          'Device Type',
                          _fmt(record['deviceType']),
                          icon: Icons.phone_android_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          'Condition',
                          _fmt(record['deviceCondition']),
                          icon: Icons.info_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  // Show individual payments
                  if (record['payments'] is List &&
                      (record['payments'] as List).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...(record['payments'] as List).asMap().entries.map((
                      entry,
                    ) {
                      final payment = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _detailTile(
                          payment['paymentMethod'] ??
                              'Payment ${entry.key + 1}',
                          _fmtAmount(payment['amount']),
                          icon: Icons.receipt_long_outlined,
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 10),
                  _detailTile(
                    'Total Amount',
                    _fmtAmount(_calculateTotalAmount(record)),
                    icon: Icons.currency_rupee_rounded,
                    emphasize: true,
                  ),
                  const SizedBox(height: 10),
                  _detailTile(
                    'Service Address',
                    _fmt(record['address']),
                    icon: Icons.location_on_outlined,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(
    String label,
    String value, {
    required IconData icon,
    bool emphasize = false,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8A9BB8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A9BB8),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    color: emphasize ? Colors.green.shade700 : _brand,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── EXPORT PANEL ────────────────────────────────────────────────────────────

  Widget _buildExportPanel() {
    final canExport = _canExportReport;
    final exportCount = _getSelectedRecords().length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export PDF Report',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _brand,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        canExport
                            ? '$exportCount record${exportCount != 1 ? 's' : ''} ready to export'
                            : 'Select records above to export',
                        style: TextStyle(
                          fontSize: 12,
                          color: canExport
                              ? Colors.green.shade600
                              : const Color(0xFF8A9BB8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canExport)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // View PDF - primary
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: canExport && !_isPdfViewing && !_isPdfDownloading
                        ? _viewReportPdf
                        : null,
                    icon: _isPdfViewing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.visibility_rounded, size: 20),
                    label: Text(
                      _isPdfViewing ? 'Opening…' : 'View PDF Report',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFDDE4F0),
                      disabledForegroundColor: const Color(0xFF8A9BB8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Download PDF - secondary
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: canExport && !_isPdfViewing && !_isPdfDownloading
                        ? _downloadReportPdf
                        : null,
                    icon: _isPdfDownloading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _brand.withOpacity(0.6),
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _isPdfDownloading ? 'Saving…' : 'Download PDF',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brand,
                      disabledForegroundColor: const Color(0xFF8A9BB8),
                      side: BorderSide(
                        color: canExport
                            ? _brand.withOpacity(0.35)
                            : const Color(0xFFDDE4F0),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (!canExport && multipleResults != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: const Color(0xFF8A9BB8),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Tap a record above to select it for export',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A9BB8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _brandLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.assignment_outlined, size: 40, color: _brand),
          ),
          const SizedBox(height: 20),
          Text(
            'No Records Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _brand,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search by Customer ID, Phone Number\nor Ticket ID to generate a report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8A9BB8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _tipChip(Icons.badge_outlined, 'Customer ID'),
              _tipChip(Icons.phone_outlined, 'Phone Number'),
              _tipChip(Icons.confirmation_number_outlined, 'Ticket ID'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _brandLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _brand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    final n = status?.toLowerCase().trim() ?? '';
    if (n == 'assigned' || n == 'completed' || n == 'complete')
      return Colors.green;
    if (n == 'not assigned' || n == 'not assinged') return Colors.red;
    if (n.contains('approval')) return Colors.purple;
    if (n.contains('spare')) return Colors.amber.shade800;
    if (n.contains('observation')) return Colors.cyan.shade700;
    if (n.contains('cancel')) return Colors.grey;
    if (n == 'pending' || n == 'open') return Colors.orange;
    if (n == 'in progress') return Colors.blue;
    return Colors.blueGrey;
  }
}
