import 'package:flutter/material.dart';
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

class CustomerReportGenerator extends StatefulWidget {
  const CustomerReportGenerator({super.key});

  @override
  _CustomerReportGeneratorState createState() =>
      _CustomerReportGeneratorState();
}

class _CustomerReportGeneratorState extends State<CustomerReportGenerator> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? resultData;
  List<Map<String, dynamic>>? multipleResults;
  bool _loading = false;
  bool _isPdfViewing = false;
  bool _isPdfDownloading = false;
  String _debugInfo = '';

  static const Color _reportBrand = Color(0xFF0B3470);

  @override
  void initState() {
    super.initState();
  }

  // Track selected rows for multiple results
  final Map<int, bool> _selectedRows = {};
  bool _allSelected = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  Future<void> _fetchData(String input) async {
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter Customer ID, Phone, or Booking ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      resultData = null;
      multipleResults = null;
      _selectedRows.clear();
      _allSelected = false;
      _debugInfo = 'Searching for: "$input"';
    });

    try {
      print('Searching for: $input');

      // Try searching in all three fields
      final List<QuerySnapshot> snapshots = await Future.wait([
        FirestoreService.instance
            .collection('Admin_details')
            .where('id', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Admin_details')
            .where('mobileNumber', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Admin_details')
            .where('bookingId', isEqualTo: input)
            .get(),
      ]);

      if (snapshots[1].docs.isNotEmpty) {
        // Found multiple entries by mobileNumber
        multipleResults = snapshots[1].docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        // Initialize all checkboxes as unselected
        for (int i = 0; i < multipleResults!.length; i++) {
          _selectedRows[i] = false;
        }

        setState(() {
          _debugInfo =
              'Found ${multipleResults!.length} results for mobileNumber: $input';
          resultData = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${multipleResults!.length} entries for Mobile Number',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Check for id or bookingId match (only single record)
        QuerySnapshot? foundSnapshot;
        String foundInField = '';

        for (int i in [0, 2]) {
          if (snapshots[i].docs.isNotEmpty) {
            foundSnapshot = snapshots[i];
            foundInField = (i == 0) ? 'Id' : 'BookingId';
            break;
          }
        }

        if (foundSnapshot != null) {
          final data = foundSnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            resultData = data;
            multipleResults = null;
            _selectedRows.clear();
            _allSelected = false;
            // _debugInfo =
            //     'Found in field: $foundInField\nTotal fields: ${data.length}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data found successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            resultData = null;
            multipleResults = null;
            _selectedRows.clear();
            _allSelected = false;
            _debugInfo =
                'No documents found in any field\nSearched: Id, MobileNumber, BookingId';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data found for "$input"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        resultData = null;
        multipleResults = null;
        _selectedRows.clear();
        _allSelected = false;
        _debugInfo = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
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

      // Update "Select All" checkbox state
      if (multipleResults != null) {
        _allSelected = _selectedRows.values.every((isSelected) => isSelected);
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedRecords() {
    if (multipleResults != null) {
      List<Map<String, dynamic>> selected = [];
      for (int i = 0; i < multipleResults!.length; i++) {
        if (_selectedRows[i] == true) {
          selected.add(multipleResults![i]);
        }
      }
      return selected;
    } else if (resultData != null) {
      return [resultData!];
    }
    return [];
  }

  int get _selectedCount {
    return _selectedRows.values.where((isSelected) => isSelected).length;
  }

  bool get _canExportReport {
    if (resultData != null) return true;
    if (multipleResults != null && multipleResults!.isNotEmpty) {
      return _selectedCount > 0;
    }
    return false;
  }

  List<Map<String, dynamic>> get _displayRecords {
    if (multipleResults != null) {
      return multipleResults!;
    }
    if (resultData != null) {
      return [resultData!];
    }
    return [];
  }

  String _formatDisplayAmount(dynamic amount) {
    if (amount == null) return 'N/A';
    final parsed = double.tryParse(amount.toString());
    if (parsed == null) return amount.toString();
    if (parsed == parsed.roundToDouble()) {
      return '₹${parsed.toInt()}';
    }
    return '₹${parsed.toStringAsFixed(2)}';
  }

  double _totalDisplayAmount(List<Map<String, dynamic>> records) {
    var total = 0.0;
    for (final record in records) {
      total += double.tryParse(record['amount']?.toString() ?? '') ?? 0;
    }
    return total;
  }

  String _fieldValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return 'N/A';
    return text;
  }

  String _reportPdfName(List<Map<String, dynamic>> records) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String name;
    if (records.length == 1) {
      final id = _fieldValue(records.first['bookingId']);
      name = id != 'N/A' ? 'Customer_Report_$id' : 'Customer_Report_$stamp';
    } else {
      name = 'Customer_Report_${records.length}_$stamp';
    }
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  void _showPdfMessage(String message, {bool isError = false, String? openPath}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        content: Text(message),
        action: openPath != null
            ? SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(openPath),
              )
            : null,
      ),
    );
  }

  static final PdfColor _pdfBrand = PdfColor.fromInt(0xFF0B3470);
  static final PdfColor _pdfBrandLight = PdfColor.fromInt(0xFFE8EEF5);

  String _pdfFieldValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return 'N/A';
    return text;
  }

  String _pdfFormatAmount(dynamic amount) {
    if (amount == null) return 'N/A';
    final parsed = double.tryParse(amount.toString());
    if (parsed == null) return amount.toString();
    if (parsed == parsed.roundToDouble()) {
      return '₹${parsed.toInt()}';
    }
    return '₹${parsed.toStringAsFixed(2)}';
  }

  double _pdfTotalAmount(List<Map<String, dynamic>> records) {
    var total = 0.0;
    for (final record in records) {
      total += double.tryParse(record['amount']?.toString() ?? '') ?? 0;
    }
    return total;
  }

  pw.Widget _pdfPageHeader(
    pw.MemoryImage? logoImage,
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
          if (logoImage != null)
            pw.Container(
              width: 48,
              height: 48,
              margin: const pw.EdgeInsets.only(right: 14),
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
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

  pw.Widget _pdfPageFooter(pw.Context context, String appName) {
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
            'Page ${context.pageNumber} of ${context.pagesCount}',
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

  pw.Widget _pdfSectionHeading(String title) {
    return pw.Container(
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
  }

  pw.Widget _pdfDetailRow(String label, String value, {bool emphasize = false}) {
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
                fontWeight:
                    emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: emphasize ? _pdfBrand : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryBox(
    List<Map<String, dynamic>> records,
    int? totalInSearch,
  ) {
    final totalAmount = _pdfTotalAmount(records);
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
            'Report summary',
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
                child: _pdfSummaryMetric(
                  'Records in report',
                  records.length.toString(),
                ),
              ),
              pw.Expanded(
                child: _pdfSummaryMetric(
                  'Combined amount',
                  _pdfFormatAmount(totalAmount),
                ),
              ),
              if (totalInSearch != null)
                pw.Expanded(
                  child: _pdfSummaryMetric(
                    'From search results',
                    '$totalInSearch total',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryMetric(String label, String value) {
    return pw.Column(
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
  }

  pw.Widget _pdfQuickIndex(List<Map<String, dynamic>> records) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionHeading('Quick reference — find a record'),
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
                _pdfIndexCell('#', header: true),
                _pdfIndexCell('ID', header: true),
                _pdfIndexCell('Customer', header: true),
                _pdfIndexCell('Booking ID', header: true),
                _pdfIndexCell('Status', header: true),
              ],
            ),
            ...List.generate(records.length, (i) {
              final record = records[i];
              final shaded = i.isOdd;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: shaded ? PdfColors.grey100 : PdfColors.white,
                ),
                children: [
                  _pdfIndexCell('${i + 1}'),
                  _pdfIndexCell(_pdfFieldValue(record['id'])),
                  _pdfIndexCell(_pdfFieldValue(record['customerName'])),
                  _pdfIndexCell(_pdfFieldValue(record['bookingId'])),
                  _pdfIndexCell(_pdfFieldValue(record['adminStatus'])),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Full details for each record are listed in the sections below.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _pdfIndexCell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 8 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
        maxLines: 2,
      ),
    );
  }

  pw.Widget _pdfRecordCard(
    Map<String, dynamic> record,
    int index,
    int total,
  ) {
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                  _pdfFieldValue(record['adminStatus']),
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
            'Booking: ${_pdfFieldValue(record['bookingId'])}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300, height: 1),
          pw.SizedBox(height: 10),
          _pdfSectionHeading('Customer details'),
          _pdfDetailRow('Customer ID', _pdfFieldValue(record['id'])),
          _pdfDetailRow('Name', _pdfFieldValue(record['customerName'])),
          _pdfDetailRow('Mobile', _pdfFieldValue(record['mobileNumber'])),
          _pdfDetailRow('Booking ID', _pdfFieldValue(record['bookingId'])),
          pw.SizedBox(height: 6),
          _pdfSectionHeading('Device details'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfDetailRow('Brand', _pdfFieldValue(record['deviceBrand'])),
                    _pdfDetailRow('Type', _pdfFieldValue(record['deviceType'])),
                  ],
                ),
              ),
              pw.Expanded(
                child: _pdfDetailRow(
                  'Condition',
                  _pdfFieldValue(record['deviceCondition']),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _pdfSectionHeading('Service & billing'),
          _pdfDetailRow(
            'Amount',
            _pdfFormatAmount(record['amount']),
            emphasize: true,
          ),
          _pdfDetailRow('Service address', _pdfFieldValue(record['address'])),
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdfDocument(
    List<Map<String, dynamic>> selectedRecords,
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
        header: (context) => _pdfPageHeader(logoImage, appName, generatedAt),
        footer: (context) => _pdfPageFooter(context, appName),
        build: (context) {
          final sections = <pw.Widget>[
            _pdfSummaryBox(selectedRecords, multipleResults?.length),
          ];

          if (selectedRecords.length > 1) {
            sections.add(pw.SizedBox(height: 18));
            sections.add(_pdfQuickIndex(selectedRecords));
          }

          for (var i = 0; i < selectedRecords.length; i++) {
            sections.add(pw.SizedBox(height: 18));
            sections.add(
              _pdfRecordCard(selectedRecords[i], i + 1, selectedRecords.length),
            );
          }

          return sections;
        },
      ),
    );

    return pdf;
  }

  Future<void> _viewReportPdf() async {
    final selectedRecords = _getSelectedRecords();
    if (selectedRecords.isEmpty) {
      _showPdfMessage(
        'Please select at least one record to view the report',
        isError: true,
      );
      return;
    }

    setState(() => _isPdfViewing = true);
    try {
      final pdf = await _buildPdfDocument(selectedRecords);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: _reportPdfName(selectedRecords),
      );
    } catch (e) {
      if (mounted) {
        _showPdfMessage('Unable to open report: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPdfViewing = false);
    }
  }

  Future<void> _downloadReportPdf() async {
    final selectedRecords = _getSelectedRecords();
    if (selectedRecords.isEmpty) {
      _showPdfMessage(
        'Please select at least one record to download',
        isError: true,
      );
      return;
    }

    setState(() => _isPdfDownloading = true);
    try {
      final pdf = await _buildPdfDocument(selectedRecords);
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${_reportPdfName(selectedRecords)}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      _showPdfMessage(
        'Report saved to Downloads',
        openPath: file.path,
      );
    } catch (e) {
      if (mounted) {
        _showPdfMessage('Download failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPdfDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Customer Report Generator',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final hPad = isNarrow ? 12.0 : 20.0;
          return SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
                child: Column(
                  children: [
                    // Search Card
                    Card(
                      elevation: 8,
                      shadowColor: primaryColor.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).cardColor,
                              Theme.of(
                                context,
                              ).primaryColorLight.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 400
                                ? 14
                                : 20,
                            vertical: 20,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Find Customer Records',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  labelText:
                                      'Enter Customer ID, Phone, or Booking ID',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).hintColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).cardColor,
                                  prefixIcon: Icon(
                                    Icons.person_search,
                                    color: primaryColor,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                onSubmitted: (value) {
                                  _fetchData(value.trim());
                                },
                              ),
                              SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _loading
                                      ? null
                                      : () =>
                                            _fetchData(_controller.text.trim()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    shadowColor: primaryColor.withValues(alpha: 0.4),
                                  ),
                                  child: _loading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.manage_search, size: 22),
                                            SizedBox(width: 10),
                                            Text(
                                              'Search & Generate Report',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    if (_displayRecords.isNotEmpty)
                      _buildReportSection(isNarrow)
                    else if (resultData == null &&
                        (multipleResults == null || multipleResults!.isEmpty))
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportSection(bool isNarrow) {
    final exportRecords = _getSelectedRecords();
    final exportCount = exportRecords.length;
    final totalAmount = _totalDisplayAmount(exportRecords);

    return Card(
      elevation: 4,
      shadowColor: _reportBrand.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: _reportBrand,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.summarize_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Service Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        multipleResults != null
                            ? '${_displayRecords.length} records found'
                            : '1 record found',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryChip(
                    icon: Icons.description_outlined,
                    label: 'In report',
                    value: exportCount.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryChip(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Total amount',
                    value: _formatDisplayAmount(totalAmount),
                  ),
                ),
              ],
            ),
          ),
          if (multipleResults != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCount > 0
                      ? primaryColor.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedCount > 0
                        ? primaryColor.withValues(alpha: 0.35)
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 20,
                      color: _selectedCount > 0
                          ? primaryColor
                          : Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_selectedCount of ${multipleResults!.length} selected for export',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedCount > 0
                              ? primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    Text(
                      'All',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Checkbox(
                      value: _allSelected,
                      onChanged: (_) => _toggleAllSelection(),
                      activeColor: primaryColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Record details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _reportBrand,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _displayRecords.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final record = _displayRecords[index];
              final isMulti = multipleResults != null;
              final isSelected = isMulti ? (_selectedRows[index] ?? false) : true;
              return _buildRecordReportCard(
                record: record,
                index: index,
                isSelectable: isMulti,
                isSelected: isSelected,
                onSelectionChanged: isMulti
                    ? () => _toggleRowSelection(index)
                    : null,
              );
            },
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, isNarrow ? 16 : 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Export report',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (isNarrow)
                  Column(
                    children: [
                      _buildReportActionButton(
                        label: 'View PDF',
                        icon: Icons.visibility_rounded,
                        isLoading: _isPdfViewing,
                        isPrimary: true,
                        enabled: _canExportReport &&
                            !_isPdfDownloading &&
                            !_isPdfViewing,
                        onPressed: _viewReportPdf,
                      ),
                      const SizedBox(height: 10),
                      _buildReportActionButton(
                        label: 'Download PDF',
                        icon: Icons.download_rounded,
                        isLoading: _isPdfDownloading,
                        isPrimary: false,
                        enabled: _canExportReport &&
                            !_isPdfDownloading &&
                            !_isPdfViewing,
                        onPressed: _downloadReportPdf,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportActionButton(
                          label: 'View PDF',
                          icon: Icons.visibility_rounded,
                          isLoading: _isPdfViewing,
                          isPrimary: true,
                          enabled: _canExportReport &&
                              !_isPdfDownloading &&
                              !_isPdfViewing,
                          onPressed: _viewReportPdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportActionButton(
                          label: 'Download PDF',
                          icon: Icons.download_rounded,
                          isLoading: _isPdfDownloading,
                          isPrimary: false,
                          enabled: _canExportReport &&
                              !_isPdfDownloading &&
                              !_isPdfViewing,
                          onPressed: _downloadReportPdf,
                        ),
                      ),
                    ],
                  ),
                if (!_canExportReport && multipleResults != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Select one or more records above to view or download',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _reportBrand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _reportBrand.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _reportBrand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _reportBrand,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required bool isPrimary,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: enabled && !isLoading ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : _reportBrand,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'Please wait...' : label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? _reportBrand : Colors.white,
          foregroundColor: isPrimary ? Colors.white : _reportBrand,
          disabledBackgroundColor: Theme.of(context).disabledColor,
          disabledForegroundColor: Colors.white,
          elevation: isPrimary ? 2 : 0,
          side: isPrimary
              ? null
              : BorderSide(color: _reportBrand.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordReportCard({
    required Map<String, dynamic> record,
    required int index,
    required bool isSelectable,
    required bool isSelected,
    VoidCallback? onSelectionChanged,
  }) {
    final status = record['adminStatus']?.toString();
    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.04)
          : Theme.of(context).cardColor,
      elevation: isSelected ? 2 : 0,
      shadowColor: _reportBrand.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isSelectable ? onSelectionChanged : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.45)
                  : Theme.of(context).dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectable)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onSelectionChanged?.call(),
                        activeColor: primaryColor,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fieldValue(record['customerName']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _reportBrand,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Booking ${_fieldValue(record['bookingId'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
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
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildReportDetailGrid(record),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportDetailGrid(Map<String, dynamic> record) {
    Widget rowPair(Widget left, Widget right) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      );
    }

    return Column(
      children: [
        rowPair(
          _buildReportDetailTile('Customer ID', _fieldValue(record['id'])),
          _buildReportDetailTile('Mobile', _fieldValue(record['mobileNumber'])),
        ),
        const SizedBox(height: 10),
        rowPair(
          _buildReportDetailTile(
            'Device brand',
            _fieldValue(record['deviceBrand']),
          ),
          _buildReportDetailTile(
            'Device type',
            _fieldValue(record['deviceType']),
          ),
        ),
        const SizedBox(height: 10),
        rowPair(
          _buildReportDetailTile(
            'Condition',
            _fieldValue(record['deviceCondition']),
          ),
          _buildReportDetailTile(
            'Amount',
            _formatDisplayAmount(record['amount']),
            emphasize: true,
          ),
        ),
        const SizedBox(height: 10),
        _buildReportDetailTile('Address', _fieldValue(record['address'])),
      ],
    );
  }

  Widget _buildReportDetailTile(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? Colors.green.shade800 : _reportBrand,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.maxWidth < 360 ? 80.0 : 120.0;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColorLight.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: iconSize * 0.5,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'No Data Found',
                  style: TextStyle(
                    fontSize: constraints.maxWidth < 360 ? 18 : 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Try searching with Customer ID, Phone Number, or Booking ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: constraints.maxWidth < 360 ? 13 : 15,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    final normalized = status?.toLowerCase().trim() ?? '';
    if (normalized == 'assigned' ||
        normalized == 'completed' ||
        normalized == 'complete') {
      return Colors.green;
    }
    if (normalized == 'not assigned' || normalized == 'not assinged') {
      return Colors.red;
    }
    if (normalized.contains('approval')) {
      return Colors.purple;
    }
    if (normalized.contains('spare')) {
      return Colors.amber;
    }
    if (normalized.contains('observation')) {
      return Colors.cyan;
    }
    if (normalized.contains('cancel')) {
      return Colors.grey;
    }
    if (normalized == 'pending' || normalized == 'open') {
      return Colors.orange;
    }
    if (normalized == 'in progress') {
      return Colors.blue;
    }
    return Colors.blueGrey;
  }
}
