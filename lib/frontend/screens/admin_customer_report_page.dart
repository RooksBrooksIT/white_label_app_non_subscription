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
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import 'dart:io';

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
  Map<String, dynamic>? amcCustomerData;
  Map<String, dynamic>? resultData;
  List<Map<String, dynamic>>? multipleResults;
  bool _loading = false;
  bool _isPdfViewing = false;
  bool _isPdfDownloading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Color get _brand => ThemeService.instance.primaryColor;
  Color get _brandLight =>
      ThemeService.instance.primaryColor.withValues(alpha: 0.1);

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
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  final Map<int, bool> _selectedRows = {};
  bool _allSelected = false;

  Color get primaryColor => _brand;

  Future<void> _fetchData(String input) async {
    final searchInput = input.trim();
    if (searchInput.isEmpty) {
      _showSnack(
        'Please enter Customer ID, Phone, or Booking ID',
        color: Colors.orange,
      );
      return;
    }

    setState(() {
      _loading = true;
      amcCustomerData = null;
      resultData = null;
      multipleResults = null;
      _selectedRows.clear();
      _allSelected = false;
    });
    _animController.reset();

    try {
      final firestore = FirestoreService.instance;

      // 1. Search AMC_user collection for Customer Profile
      Map<String, dynamic>? foundAmcUser;
      try {
        final docById = await firestore
            .collection('AMC_user')
            .doc(searchInput)
            .get();
        if (docById.exists && docById.data() != null) {
          foundAmcUser = docById.data();
        }
      } catch (_) {}

      if (foundAmcUser == null) {
        final amcSnapshots = await Future.wait([
          firestore
              .collection('AMC_user')
              .where('Id', isEqualTo: searchInput)
              .get(),
          firestore
              .collection('AMC_user')
              .where('Phone Number', isEqualTo: searchInput)
              .get(),
          firestore
              .collection('AMC_user')
              .where('email', isEqualTo: searchInput)
              .get(),
        ]);
        for (final snap in amcSnapshots) {
          if (snap.docs.isNotEmpty) {
            foundAmcUser = snap.docs.first.data();
            break;
          }
        }
      }

      // If still not found, search all AMC_user documents for matching fields
      if (foundAmcUser == null) {
        final allAmcUsers = await firestore.collection('AMC_user').get();
        final lowerInput = searchInput.toLowerCase();
        for (final doc in allAmcUsers.docs) {
          final data = doc.data();
          final id = (data['Id'] ?? '').toString().toLowerCase();
          final phone = (data['Phone Number'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final name = (data['name'] ?? '').toString().toLowerCase();

          if (id == lowerInput ||
              phone == lowerInput ||
              email == lowerInput ||
              name == lowerInput ||
              doc.id.toLowerCase() == lowerInput) {
            foundAmcUser = data;
            break;
          }
        }
      }

      amcCustomerData = foundAmcUser;

      // 2. Search Admin_ticket_entry collection for tickets
      final String amcId = (foundAmcUser?['Id'] ?? searchInput).toString();
      final String amcPhone = (foundAmcUser?['Phone Number'] ?? searchInput)
          .toString();

      final ticketSnapshots = await Future.wait([
        firestore
            .collection('Admin_ticket_entry')
            .where('id', isEqualTo: searchInput)
            .get(),
        firestore
            .collection('Admin_ticket_entry')
            .where('mobileNumber', isEqualTo: searchInput)
            .get(),
        firestore
            .collection('Admin_ticket_entry')
            .where('bookingId', isEqualTo: searchInput)
            .get(),
        if (amcId != searchInput)
          firestore
              .collection('Admin_ticket_entry')
              .where('id', isEqualTo: amcId)
              .get(),
        if (amcPhone != searchInput)
          firestore
              .collection('Admin_ticket_entry')
              .where('mobileNumber', isEqualTo: amcPhone)
              .get(),
      ]);

      final Map<String, Map<String, dynamic>> uniqueTickets = {};
      for (final snap in ticketSnapshots) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final key = data['bookingId']?.toString() ?? doc.id;
          uniqueTickets[key] = data;
        }
      }

      final ticketList = uniqueTickets.values.toList();

      if (ticketList.isNotEmpty) {
        if (ticketList.length == 1) {
          resultData = ticketList.first;
        } else {
          multipleResults = ticketList;
          for (int i = 0; i < ticketList.length; i++) {
            _selectedRows[i] = false;
          }
        }
      }

      if (foundAmcUser != null || ticketList.isNotEmpty) {
        _animController.forward();
        _showSnack(
          ticketList.isNotEmpty
              ? 'Found ${ticketList.length} ticket(s)!'
              : 'Customer record found!',
          color: Colors.green,
        );
      } else {
        _showSnack('No data found for "$searchInput"', color: Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
    } finally {
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

  String _cleanPdfText(String? input) {
    if (input == null) return '';
    var s = input.trim();
    if (s.isEmpty) return '';
    // Remove Unicode replacement character ( / \uFFFD) and broken byte artifacts
    s = s.replaceAll('\uFFFD', '');
    // Remove common control/null characters that can break PDF renderers
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    return s.trim();
  }

  String _fmt(dynamic v) {
    if (v == null) return 'N/A';
    final t = _cleanPdfText(v.toString());
    return (t.isEmpty || t.toLowerCase() == 'null' || t.toLowerCase() == 'undefined') ? 'N/A' : t;
  }

  String _fmtBrandAndType(Map<String, dynamic> r) {
    final brand = _fmt(r['deviceBrand']);
    final type = _fmt(r['deviceType']);
    if (brand == 'N/A' && type == 'N/A') return 'N/A';
    if (brand == 'N/A') return type;
    if (type == 'N/A') return brand;
    return '$brand $type';
  }

  String _extractHelperName(Map<String, dynamic> data) {
    if (data['helpers'] is List && (data['helpers'] as List).isNotEmpty) {
      final list = (data['helpers'] as List)
          .map((e) => _cleanPdfText(e.toString()))
          .where(
            (e) =>
                e.isNotEmpty &&
                e.toLowerCase() != 'null' &&
                e.toLowerCase() != 'n/a',
          )
          .toList();
      if (list.isNotEmpty) return list.join(', ');
    }
    final helperName = _cleanPdfText(
        (data['helperName'] ?? data['helper'] ?? data['Helper1'] ?? '')
            .toString());
    if (helperName.isNotEmpty &&
        helperName.toLowerCase() != 'null' &&
        helperName.toLowerCase() != 'n/a' &&
        helperName != 'Unknown Helper') {
      return helperName;
    }
    final helperRegex = RegExp(r'^Helper(\d+)$');
    final helperKeys = data.keys.where((k) => helperRegex.hasMatch(k)).toList()
      ..sort((a, b) {
        final aIdx =
            int.tryParse(helperRegex.firstMatch(a)?.group(1) ?? '0') ?? 0;
        final bIdx =
            int.tryParse(helperRegex.firstMatch(b)?.group(1) ?? '0') ?? 0;
        return aIdx.compareTo(bIdx);
      });
    final names = <String>[];
    for (final key in helperKeys) {
      final val = _cleanPdfText(data[key]?.toString() ?? '');
      if (val.isNotEmpty &&
          val.toLowerCase() != 'null' &&
          val.toLowerCase() != 'n/a' &&
          val != 'Unknown Helper') {
        names.add(val);
      }
    }
    if (names.isNotEmpty) {
      return names.join(', ');
    }
    return '';
  }

  String _fmtAmount(dynamic a) {
    if (a == null) return 'N/A';
    final s = _cleanPdfText(a.toString());
    if (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'n/a') return 'N/A';
    final clean = s.replaceAll('₹', '').replaceAll(RegExp(r'rs\.?', caseSensitive: false), '').trim();
    final p = double.tryParse(clean);
    if (p == null) return s;
    return p == p.roundToDouble()
        ? '₹${p.toInt()}'
        : '₹${p.toStringAsFixed(2)}';
  }

  double _totalAmount(List<Map<String, dynamic>> records) => records.fold(
    0.0,
    (s, r) {
      final a = r['amount'];
      if (a == null) return s;
      final str = _cleanPdfText(a.toString());
      if (str.isEmpty || str.toLowerCase() == 'null' || str.toLowerCase() == 'n/a') return s;
      final clean = str.replaceAll('₹', '').replaceAll(RegExp(r'rs\.?', caseSensitive: false), '').trim();
      final p = double.tryParse(clean);
      return s + (p ?? 0.0);
    },
  );

  String _reportPdfName(List<Map<String, dynamic>> records) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String name;
    if (records.length == 1) {
      final id = _fmt(records.first['bookingId']);
      name = id != 'N/A' ? 'Customer_Report_$id' : 'Customer_Report_$stamp';
    } else {
      name = 'Customer_Report_${records.length}_$stamp';
    }
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  // ─── PDF generation ────────────────────────────────────────────────────────

  PdfColor get _pdfBrand =>
      PdfColor.fromInt(ThemeService.instance.primaryColor.toARGB32());

  (PdfColor bg, PdfColor text) _statusBadgeColors(String? status) {
    final s = status?.toLowerCase().trim() ?? '';
    if (s.contains('complete') ||
        s.contains('deliver') ||
        s.contains('closed')) {
      return (PdfColor.fromHex('#DCFCE7'), PdfColor.fromHex('#15803D'));
    }
    if (s.contains('progress') ||
        s.contains('assign') ||
        s.contains('working')) {
      return (PdfColor.fromHex('#DBEAFE'), PdfColor.fromHex('#1D4ED8'));
    }
    if (s.contains('pending') ||
        s.contains('approval') ||
        s.contains('open') ||
        s.contains('raised') ||
        s.contains('hold')) {
      return (PdfColor.fromHex('#FEF3C7'), PdfColor.fromHex('#B45309'));
    }
    if (s.contains('cancel') || s.contains('reject') || s.contains('abort')) {
      return (PdfColor.fromHex('#FEE2E2'), PdfColor.fromHex('#B91C1C'));
    }
    if (s.contains('ready')) {
      return (PdfColor.fromHex('#F3E8FF'), PdfColor.fromHex('#7E22CE'));
    }
    return (PdfColor.fromHex('#F1F5F9'), PdfColor.fromHex('#475569'));
  }

  pw.Widget _pdfStatusBadge(
    String status, {
    double fontSize = 7.5,
    double px = 7,
    double py = 2.5,
  }) {
    final colors = _statusBadgeColors(status);
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: pw.BoxDecoration(
        color: colors.$1,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: colors.$2, width: 0.5),
      ),
      child: pw.Text(
        status.toUpperCase(),
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: colors.$2,
        ),
      ),
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    try {
      if (v is Timestamp) {
        return DateFormat('dd MMM yyyy').format(v.toDate());
      }
      if (v is DateTime) {
        return DateFormat('dd MMM yyyy').format(v);
      }
      final s = v.toString();
      final parsed = DateTime.tryParse(s);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy').format(parsed);
      }
      return s;
    } catch (_) {
      return '';
    }
  }

  String _fmtDeviceModel(Map<String, dynamic> r) {
    final type = _fmt(r['deviceType']);
    final model = _cleanPdfText(
        (r['model'] ?? r['deviceModel'] ?? r['Model'] ?? r['modelName'] ?? '')
            .toString());
    if (model.isNotEmpty &&
        model.toLowerCase() != 'null' &&
        model.toLowerCase() != 'n/a') {
      return type != 'N/A' ? '$type ($model)' : model;
    }
    return type;
  }

  String _fmtIssue(Map<String, dynamic> r) {
    final issue = _cleanPdfText(
        (r['problem'] ??
                r['reportedIssue'] ??
                r['description'] ??
                r['issue'] ??
                r['statusDescription'] ??
                '')
            .toString());
    return (issue.isNotEmpty &&
            issue.toLowerCase() != 'null' &&
            issue.toLowerCase() != 'n/a')
        ? issue
        : '';
  }

  String _fmtEngineer(Map<String, dynamic> r) {
    final eng = _cleanPdfText(
        (r['assignedEmployee'] ?? r['engineerName'] ?? r['engineer'] ?? '')
            .toString());
    return (eng.isNotEmpty &&
            eng.toLowerCase() != 'null' &&
            eng.toLowerCase() != 'n/a' &&
            eng != 'Not Assigned')
        ? eng
        : 'Not Assigned';
  }

  String _fmtNotes(Map<String, dynamic> r) {
    final notes = _cleanPdfText(
        (r['visitNotes'] ??
                r['notes'] ??
                r['adminNotes'] ??
                r['cancellationReason'] ??
                r['cancelReason'] ??
                r['Reason_cancel'] ??
                '')
            .toString());
    return (notes.isNotEmpty &&
            notes.toLowerCase() != 'null' &&
            notes.toLowerCase() != 'n/a')
        ? notes
        : '';
  }

  Future<pw.Document> _buildPdfDocument(
    List<Map<String, dynamic>> records,
  ) async {
    final theme = await PdfUtils.loadReportTheme();
    final pdf = pw.Document(theme: theme);
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (ctx) => _pdfHeader(logoImage, appName, generatedAt),
        footer: (ctx) => _pdfFooter(ctx, appName),
        build: (ctx) {
          final widgets = <pw.Widget>[_pdfSummaryBox(records)];
          if (records.length > 1) {
            widgets
              ..add(pw.SizedBox(height: 14))
              ..add(_pdfIndex(records));
          }
          for (var i = 0; i < records.length; i++) {
            widgets
              ..add(pw.SizedBox(height: 12))
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
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _pdfBrand, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 44,
              height: 44,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 38,
              height: 38,
              margin: const pw.EdgeInsets.only(right: 12),
              decoration: pw.BoxDecoration(
                color: _pdfBrand,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text(
                  (appName.isNotEmpty ? appName : 'S').trim()[0].toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER SERVICE REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfBrand,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  appName.isNotEmpty ? appName : 'ServNex Service Management',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  'SERVICE DOSSIER',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfBrand,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated: $generatedAt',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx, String appName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
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
            appName.isNotEmpty ? appName : 'ServNex',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Confidential — internal & customer record',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryBox(List<Map<String, dynamic>> records) {
    final total = _totalAmount(records);
    final completedCount = records.where((r) {
      final s = (r['adminStatus'] ?? r['status'] ?? '')
          .toString()
          .toLowerCase();
      return s.contains('complete') ||
          s.contains('deliver') ||
          s.contains('closed');
    }).length;
    final activeCount = records.length - completedCount;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _pdfStatCard(
              title: 'TOTAL RECORDS',
              value: '${records.length}',
              accentColor: _pdfBrand,
              subtext: multipleResults != null
                  ? 'of ${multipleResults!.length} searched'
                  : 'Selected for report',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _pdfStatCard(
              title: 'COMBINED AMOUNT',
              value: _fmtAmount(total),
              accentColor: PdfColor.fromHex('#0D9488'),
              subtext: 'Total billing value',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _pdfStatCard(
              title: 'COMPLETED',
              value: '$completedCount',
              accentColor: PdfColor.fromHex('#16A34A'),
              subtext: 'Closed tickets',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _pdfStatCard(
              title: 'ACTIVE / PENDING',
              value: '$activeCount',
              accentColor: PdfColor.fromHex('#D97706'),
              subtext: 'In pipeline',
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatCard({
    required String title,
    required String value,
    required PdfColor accentColor,
    String? subtext,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 8.5,
                margin: const pw.EdgeInsets.only(right: 5),
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
              ),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          if (subtext != null) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              subtext,
              style: const pw.TextStyle(
                fontSize: 6.8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _pdfIndex(List<Map<String, dynamic>> records) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 10,
                margin: const pw.EdgeInsets.only(right: 5),
                decoration: pw.BoxDecoration(
                  color: _pdfBrand,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
              ),
              pw.Text(
                'TICKET SUMMARY TABLE',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfBrand,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(1.1),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.4),
            5: const pw.FlexColumnWidth(1.3),
            6: const pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
              children: [
                _pdfTableHeaderCell('#', align: pw.TextAlign.center),
                _pdfTableHeaderCell('Cust ID'),
                _pdfTableHeaderCell('Customer Name'),
                _pdfTableHeaderCell('Booking ID'),
                _pdfTableHeaderCell('Device / Brand'),
                _pdfTableHeaderCell('Status', align: pw.TextAlign.center),
                _pdfTableHeaderCell('Amount', align: pw.TextAlign.right),
              ],
            ),
            ...List.generate(records.length, (i) {
              final r = records[i];
              final isOdd = i.isOdd;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isOdd ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
                ),
                children: [
                  _pdfTableCell('${i + 1}', align: pw.TextAlign.center),
                  _pdfTableCell(_fmt(r['id'] ?? r['customerId'])),
                  _pdfTableCell(
                    _fmt(r['customerName'] ?? r['name']),
                    isBold: true,
                  ),
                  _pdfTableCell(_fmt(r['bookingId'])),
                  _pdfTableCell(_fmtBrandAndType(r)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: pw.Center(
                      child: _pdfStatusBadge(
                        _fmt(r['adminStatus'] ?? r['status']),
                        fontSize: 6.5,
                        px: 5,
                        py: 2,
                      ),
                    ),
                  ),
                  _pdfTableCell(
                    _fmtAmount(r['amount']),
                    align: pw.TextAlign.right,
                    isBold: true,
                    color: _pdfBrand,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfTableHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5),
      child: pw.Text(
        text,
        textAlign: align,
        maxLines: 2,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
      child: pw.Row(
        children: [
          pw.Container(
            width: 2.5,
            height: 8.5,
            margin: const pw.EdgeInsets.only(right: 5),
            decoration: pw.BoxDecoration(
              color: _pdfBrand,
              borderRadius: pw.BorderRadius.circular(1),
            ),
          ),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7.8,
              fontWeight: pw.FontWeight.bold,
              color: _pdfBrand,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfKeyValueRow(
    String label,
    String value, {
    bool isHighlight = false,
    double labelWidth = 78,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.2,
                fontWeight: isHighlight
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: isHighlight ? _pdfBrand : PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCard(Map<String, dynamic> r, int index, int total) {
    final status = _fmt(r['adminStatus'] ?? r['status']);
    final createdDate = _fmtDate(r['createdAt'] ?? r['timestamp']);
    final issue = _fmtIssue(r);
    final notes = _fmtNotes(r);
    final helperName = _extractHelperName(r);
    final engineer = _fmtEngineer(r);
    final customerDecision = _cleanPdfText(r['Customer_decision']?.toString());

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Card Header Bar
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'TICKET #${_fmt(r['bookingId'])}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfBrand,
                      letterSpacing: 0.3,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Record $index of $total',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  if (createdDate.isNotEmpty) ...[
                    pw.Text(
                      ' · ',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'Created: $createdDate',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ],
              ),
              _pdfStatusBadge(status, fontSize: 7.5, px: 8, py: 3),
            ],
          ),

          pw.Container(
            height: 0.5,
            color: PdfColors.grey200,
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
          ),

          // Two-Column Details
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column: Customer & Device Details
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionTitle('Customer Information'),
                    _pdfKeyValueRow(
                      'Customer ID',
                      _fmt(r['id'] ?? r['customerId']),
                    ),
                    _pdfKeyValueRow(
                      'Name',
                      _fmt(r['customerName'] ?? r['name']),
                      isHighlight: true,
                    ),
                    _pdfKeyValueRow(
                      'Phone Number',
                      _fmt(
                        r['mobileNumber'] ?? r['Phone Number'] ?? r['phone'],
                      ),
                    ),
                    _pdfKeyValueRow('Booking ID', _fmt(r['bookingId'])),
                    pw.SizedBox(height: 6),
                    _pdfSectionTitle('Device Information'),
                    _pdfKeyValueRow('Brand', _fmt(r['deviceBrand'])),
                    _pdfKeyValueRow('Type / Model', _fmtDeviceModel(r)),
                    _pdfKeyValueRow('Condition', _fmt(r['deviceCondition'])),
                    if (issue.isNotEmpty)
                      _pdfKeyValueRow('Reported Issue', issue),
                  ],
                ),
              ),

              pw.SizedBox(width: 14),

              // Right Column: Service & Assignment
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionTitle('Service & Assignment'),
                    _pdfKeyValueRow('Assigned Eng.', engineer),
                    if (helperName.isNotEmpty)
                      _pdfKeyValueRow('Helper Eng.', helperName),
                    _pdfKeyValueRow(
                      'Billing Amount',
                      _fmtAmount(r['amount']),
                      isHighlight: true,
                    ),
                    _pdfKeyValueRow('Address', _fmt(r['address'])),
                    if (customerDecision.isNotEmpty &&
                        customerDecision.toLowerCase() != 'null' &&
                        customerDecision.toLowerCase() != 'n/a')
                      _pdfKeyValueRow('Customer Decision', customerDecision),
                  ],
                ),
              ),
            ],
          ),

          // Optional Notes / Cancellation Reason Callout
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Notes / Details: ',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      notes,
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
        title: const Text(
          'Customer Report Generator',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ResponsiveWrapper(
          maxWidth: 960,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeroBanner(),
                const SizedBox(height: 10),
                _buildSearchCard(),
                const SizedBox(height: 16),
                if (_loading) _buildLoading(),
                if (!_loading && amcCustomerData != null) ...[
                  _buildAmcCustomerHeaderCard(),
                  const SizedBox(height: 12),
                ],
                if (!_loading && _displayRecords.isNotEmpty)
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: _buildResultsSection(),
                    ),
                  ),
                if (!_loading &&
                    amcCustomerData != null &&
                    _displayRecords.isEmpty)
                  _buildNoTicketsForCustomerCard(),
                if (!_loading &&
                    amcCustomerData == null &&
                    _displayRecords.isEmpty)
                  _buildEmptyState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeroBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _brand.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.manage_search_rounded, color: _brand, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Report Generator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lookup customer history by ID, Phone, or Booking ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _brand.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH CARD ────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  color: _brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Find Customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Text(
                      'Search by ID, Phone Number or Booking ID',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter Customer ID, Phone, or Booking ID...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (v) => _fetchData(v.trim()),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
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
          const SizedBox(height: 12),
          // Quick-search chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              'Customer ID',
              'Phone Number',
              'Booking ID',
            ].map((label) => _searchChip(label)).toList(),
          ),
          const SizedBox(height: 16),
          // Search button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () {
                      _searchFocusNode.unfocus();
                      _fetchData(_controller.text.trim());
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.manage_search_rounded, size: 18),
              label: Text(
                _loading ? 'Searching Records...' : 'Search & Generate Report',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmcCustomerHeaderCard() {
    if (amcCustomerData == null) return const SizedBox.shrink();
    final name =
        (amcCustomerData!['name'] ?? amcCustomerData!['Id'] ?? 'AMC Customer')
            .toString();
    final amcId = (amcCustomerData!['Id'] ?? 'AMC Customer').toString();
    final phone = (amcCustomerData!['Phone Number'] ?? 'N/A').toString();
    final email = (amcCustomerData!['email'] ?? 'N/A').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            amcId,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Registered AMC Customer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoTicketsForCustomerCard() {
    final name =
        amcCustomerData!['name'] ?? amcCustomerData!['Id'] ?? 'Customer';
    final id = amcCustomerData!['Id'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Service Tickets Created Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Customer details for $name ($id) were loaded successfully, but no service or repair tickets have been created yet under this customer.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
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
            color: _brand.withValues(alpha: 0.06),
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
              color: _brand.withValues(alpha: 0.7),
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
          colors: [_brand, _brand.withValues(alpha: 0.8)],
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

  Widget _divider() => Container(
    width: 1,
    height: 40,
    color: Colors.white.withValues(alpha: 0.2),
  );

  Widget _buildSelectAllBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _selectedCount > 0
            ? _brand.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCount > 0
              ? _brand.withValues(alpha: 0.3)
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
                  color: _brand.withValues(alpha: 0.7),
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
              ? _brand.withValues(alpha: 0.4)
              : const Color(0xFFDDE4F0),
          width: isSelected && isSelectable ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected && isSelectable
                ? _brand.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
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
                    ? _brand.withValues(alpha: 0.04)
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
                      color: _brand.withValues(alpha: 0.1),
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
                          'Booking: ${_fmt(record['bookingId'])}',
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
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
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
                          _fmt(record['id']),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailTile(
                          'Amount',
                          _fmtAmount(record['amount']),
                          icon: Icons.currency_rupee_rounded,
                          emphasize: true,
                        ),
                      ),
                    ],
                  ),
                  if ((record['assignedEmployee'] != null &&
                          record['assignedEmployee']
                              .toString()
                              .trim()
                              .isNotEmpty &&
                          record['assignedEmployee'].toString().trim() !=
                              'Not Assigned') ||
                      _extractHelperName(record).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (record['assignedEmployee'] != null &&
                            record['assignedEmployee']
                                .toString()
                                .trim()
                                .isNotEmpty &&
                            record['assignedEmployee'].toString().trim() !=
                                'Not Assigned')
                          Expanded(
                            child: _detailTile(
                              'Assigned',
                              _fmt(record['assignedEmployee']),
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                        if ((record['assignedEmployee'] != null &&
                                record['assignedEmployee']
                                    .toString()
                                    .trim()
                                    .isNotEmpty &&
                                record['assignedEmployee'].toString().trim() !=
                                    'Not Assigned') &&
                            _extractHelperName(record).isNotEmpty)
                          const SizedBox(width: 10),
                        if (_extractHelperName(record).isNotEmpty)
                          Expanded(
                            child: _detailTile(
                              'Helper',
                              _extractHelperName(record),
                              icon: Icons.handshake_outlined,
                            ),
                          ),
                      ],
                    ),
                  ],
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
            color: _brand.withValues(alpha: 0.08),
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
                              color: _brand.withValues(alpha: 0.6),
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
                            ? _brand.withValues(alpha: 0.35)
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.feed_outlined, size: 36, color: _brand),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Records Loaded Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search by Customer ID, Phone Number\nor Booking ID to compile customer report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _tipChip(Icons.badge_outlined, 'Customer ID'),
              _tipChip(Icons.phone_outlined, 'Phone Number'),
              _tipChip(Icons.confirmation_number_outlined, 'Booking ID'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    final n = status?.toLowerCase().trim() ?? '';
    if (n == 'assigned' || n == 'completed' || n == 'complete') {
      return Colors.green;
    }
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
