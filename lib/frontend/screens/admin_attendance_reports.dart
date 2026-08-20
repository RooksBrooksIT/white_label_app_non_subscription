import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/pdf_utils.dart';

class AdminAttendanceReportsPage extends StatefulWidget {
  const AdminAttendanceReportsPage({super.key});

  @override
  _AdminAttendanceReportsPageState createState() =>
      _AdminAttendanceReportsPageState();
}

class _AdminAttendanceReportsPageState
    extends State<AdminAttendanceReportsPage> {
  String? _selectedEngineerId;
  DateTimeRange? _selectedDateRange;
  DateTime? _selectedMonth; // For month-wise filtering
  List<Map<String, dynamic>> _engineers = [];
  bool _isLoadingEngineers = true;
  final DateTime _today = DateTime.now();

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadEngineers();
  }

  Future<void> _loadEngineers() async {
    try {
      final engineersData = await AttendanceBackend.getEngineers();
      setState(() {
        _engineers = engineersData;
        _isLoadingEngineers = false;
      });
    } catch (e) {
      print('Error loading engineers: $e');
      setState(() => _isLoadingEngineers = false);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedMonth = null; // Clear month filter if date range is selected
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedEngineerId = null;
      _selectedDateRange = null;
      _selectedMonth = null;
    });
  }

  Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Attendance Reports',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeroBanner(primaryColor),
            _buildFilterSection(primaryColor),
            Expanded(child: _buildAttendanceList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeroBanner(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.04),
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
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance & Payroll Analytics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Filter, audit, and export staff attendance logs to PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryColor.withValues(alpha: 0.85),
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

  Widget _buildFilterSection(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _isLoadingEngineers
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Filter Staff Member',
                          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.person_search_rounded, color: primaryColor, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        initialValue: _selectedEngineerId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('ALL STAFF MEMBERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          ..._engineers.map((eng) {
                            return DropdownMenuItem<String>(
                              value: eng['uid'] as String,
                              child: Text(
                                (eng['username'] ?? 'Unknown').toString(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedEngineerId = val;
                          });
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: Icon(Icons.date_range_rounded, size: 16, color: primaryColor),
                  label: Text(
                    _selectedDateRange == null
                        ? 'Date Range'
                        : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'By Month',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    prefixIcon: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  initialValue: _selectedMonth?.month,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(_months[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = DateTime(DateTime.now().year, val);
                        _selectedDateRange = null; // Clear date range
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          if (_selectedEngineerId != null ||
              _selectedDateRange != null ||
              _selectedMonth != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: _clearFilters,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_off_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Clear Active Filters',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceErrorState(Object error) {
    final message = error.toString();
    final isIndexError =
        message.contains('failed-precondition') ||
        message.contains('COLLECTION_GROUP') ||
        message.contains('index');
    final indexUrl = RegExp(
      r'https://console\.firebase\.google\.com[^\s)]+',
    ).firstMatch(message)?.group(0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              isIndexError
                  ? 'Database index required'
                  : 'Unable to load attendance',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isIndexError
                  ? 'A Firestore index is missing for attendance queries. '
                        'The full error and index link are printed in the debug terminal.'
                  : 'Something went wrong while loading records. '
                        'Check the debug terminal for details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).hintColor,
                height: 1.4,
              ),
            ),
            if (indexUrl != null) ...[
              const SizedBox(height: 16),
              Text(
                'Ask your admin to create the Firestore index, or open the link from the terminal output.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    Stream<List<Map<String, dynamic>>> stream;
    if (_selectedEngineerId != null) {
      DateTime? from, to;
      if (_selectedMonth != null) {
        from = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
        to = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
      } else {
        from = _selectedDateRange?.start;
        to = _selectedDateRange?.end;
      }
      stream = AttendanceBackend.getEngineerAttendanceHistory(
        _selectedEngineerId!,
        fromDate: from,
        toDate: to,
      );
    } else {
      stream = AttendanceBackend.getAllAttendanceHistory();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          AttendanceBackend.logFirestoreError(
            'AdminAttendanceReportsPage._buildAttendanceList',
            snapshot.error!,
            snapshot.stackTrace,
          );
          return _buildAttendanceErrorState(snapshot.error!);
        }

        var list = snapshot.data ?? [];

        // Concept: Engineer is marked as present for each and everyday until marked otherwise.
        // We fill in the gaps for the selected range/month if a specific engineer is selected.
        DateTime? start, end;
        if (_selectedMonth != null) {
          start = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
          end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
        } else if (_selectedDateRange != null) {
          start = _selectedDateRange!.start;
          end = _selectedDateRange!.end;
        } else if (_selectedEngineerId == null) {
          // Only default to today if ALL ENGINEERS selected and no filter
          start = DateTime(_today.year, _today.month, _today.day);
          end = start;
        }

        // Apply date filter only if we have a date range (either selected or default)
        if (start != null && end != null) {
          list = list.where((data) {
            final date = _parseTimestamp(data['date']).toDate();
            return (date.isAfter(start!.subtract(const Duration(days: 1))) ||
                    date.isAtSameMomentAs(start)) &&
                (date.isBefore(end!.add(const Duration(days: 1))) ||
                    date.isAtSameMomentAs(end));
          }).toList();
        }

        if (_selectedEngineerId != null) {
          // Sort descending for specific engineer
          list.sort(
            (a, b) => _parseTimestamp(
              b['date'],
            ).compareTo(_parseTimestamp(a['date'])),
          );
        }

        if (list.isEmpty) {
          return const Center(child: Text('No attendance records found.'));
        }

        // Calculate summaries
        int presentCount = 0;
        int absentCount = 0;
        int leaveCount = 0;
        int otCount = 0;
        int halfDayCount = 0;
        Set<String> uniqueEngineerIds = {};

        for (var data in list) {
          final status = data['status'];
          if (status == 'Present') {
            presentCount++;
          } else if (status == 'Absent') {
            absentCount++;
          } else if (status == 'Leave') {
            leaveCount++;
          } else if (status == 'OT') {
            otCount++;
          } else if (status == 'HalfDay' || status == 'Half Day') {
            halfDayCount++;
          }

          // Track unique engineers
          final engineerId = data['engineerId'] as String?;
          if (engineerId != null) {
            uniqueEngineerIds.add(engineerId);
          }
        }

        // Determine current date to display
        String displayDate;
        if (_selectedMonth != null) {
          displayDate = DateFormat.yMMMM().format(_selectedMonth!);
        } else if (_selectedDateRange != null) {
          if (_selectedDateRange!.start.isAtSameMomentAs(
            _selectedDateRange!.end,
          )) {
            displayDate = DateFormat.yMMMd().format(_selectedDateRange!.start);
          } else {
            displayDate =
                '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}';
          }
        } else if (_selectedEngineerId == null) {
          displayDate = DateFormat.yMMMd().format(_today);
        } else {
          displayDate = 'All Dates';
        }

        return Column(
          children: [
            _buildSummaryCards(
              presentCount,
              absentCount,
              halfDayCount,
              otCount,
              uniqueEngineerIds.length,
              displayDate,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _generateProfessionalPDF(
                      list,
                      presentCount,
                      absentCount,
                      halfDayCount,
                      otCount,
                      uniqueEngineerIds.length,
                      displayDate,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final data = list[index];
                  return _buildReportItem(data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(
    int present,
    int absent,
    int halfDay,
    int ot,
    int totalEngineers,
    String displayDate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryCard('Present', present, Colors.green),
              _summaryCard('Absent', absent, Colors.red),
              _summaryCard('Half Day', halfDay, Colors.orangeAccent),
              _summaryCard('OT', ot, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricCard(
                'Total Engineers',
                totalEngineers.toString(),
                Icons.people,
                Colors.blueGrey,
              ),
              const SizedBox(width: 12),
              _metricCard(
                'Current Date',
                displayDate,
                Icons.calendar_today,
                Colors.indigo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> data) {
    final date = _parseTimestamp(data['date']).toDate();
    final status = (data['status'] ?? 'Present') as String;
    final username = (data['engineerUsername'] ?? 'Staff Member') as String;
    final remarks = (data['comment'] ?? '').toString();

    Color statusColor = const Color(0xFF10B981);
    if (status == 'Absent') statusColor = const Color(0xFFEF4444);
    if (status == 'HalfDay' || status == 'Half Day') {
      statusColor = const Color(0xFFF59E0B);
    }
    if (status == 'OT') statusColor = const Color(0xFF3B82F6);
    if (status == 'Leave') statusColor = const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'S',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM dd, yyyy (EEE)').format(date),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (remarks.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: $remarks',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF475569),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateProfessionalPDF(
    List<dynamic> list,
    int present,
    int absent,
    int halfDay,
    int ot,
    int totalEngineers,
    String displayDate,
  ) async {
    try {
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing PDF document...'),
          duration: Duration(seconds: 2),
        ),
      );

      final pdf = pw.Document();

      // Load logo
      pw.MemoryImage? logoImage;
      final logoUrl = ThemeService.instance.logoUrl;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        logoImage = await PdfUtils.fetchNetworkImage(logoUrl);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Image(logoImage, width: 80)
                      else
                        pw.Text(
                          ThemeService.instance.appName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Attendance Performance Report',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Engineer: ${_selectedEngineerId != null ? _engineers.firstWhere((e) => e['uid'] == _selectedEngineerId)['username']?.toString().toUpperCase() : "All Engineers"}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.blue900, height: 20),
            ],
          ),
          build: (context) {
            List<pw.Widget> content = [];

            // Summary Stats - First Row (Present, Absent, Half Day, OT)
            content.add(pw.SizedBox(height: 10));
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _pdfSummaryBox(
                    'Present',
                    present.toString(),
                    PdfColors.green700,
                  ),
                  _pdfSummaryBox('Absent', absent.toString(), PdfColors.red700),
                  _pdfSummaryBox(
                    'Half Day',
                    halfDay.toString(),
                    PdfColors.orange700,
                  ),
                  _pdfSummaryBox('OT', ot.toString(), PdfColors.blue700),
                ],
              ),
            );

            // Summary Stats - Second Row (Total Engineers, Current Date)
            content.add(pw.SizedBox(height: 12));
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _pdfSummaryBox(
                    'Total Engineers',
                    totalEngineers.toString(),
                    PdfColors.blueGrey700,
                    isWide: true,
                  ),
                  _pdfSummaryBox(
                    'Current Date',
                    displayDate,
                    PdfColors.indigo700,
                    isWide: true,
                  ),
                ],
              ),
            );
            content.add(pw.SizedBox(height: 24));

            if (list.isEmpty) {
              // Empty state
              content.add(
                pw.Center(
                  child: pw.Text(
                    'No attendance records found for the selected filters.',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                  ),
                ),
              );
            } else {
              // Attendance Table
              final tableData = list.map((d) {
                try {
                  final username =
                      d['engineerUsername']?.toString().toUpperCase() ?? 'N/A';

                  String dateStr = '-';
                  if (d['date'] != null) {
                    dateStr = DateFormat(
                      'dd/MM/yyyy',
                    ).format(_parseTimestamp(d['date']).toDate());
                  }

                  return [
                    dateStr,
                    username,
                    d['status']?.toString() ?? 'N/A',
                    d['comment']?.toString() ?? '-',
                  ];
                } catch (e) {
                  return ['-', 'Error', '-', '-'];
                }
              }).toList();

              content.add(
                pw.Table.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 1,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue900,
                  ),
                  cellHeight: 30,
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                  },
                  columnWidths: const {
                    0: pw.FixedColumnWidth(80),
                    1: pw.FlexColumnWidth(),
                    2: pw.FixedColumnWidth(80),
                    3: pw.FlexColumnWidth(),
                  },
                  headers: ['Date', 'Engineer Name', 'Status', 'Remarks'],
                  data: tableData,
                ),
              );
            }

            return content;
          },
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'System Generated Official Document',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Pre-calculate the bytes to ensure it's built successfully
      final bytes = await pdf.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening PDF preview...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name:
            'Attendance_Report_${_selectedEngineerId != null ? _engineers.firstWhere((e) => e['uid'] == _selectedEngineerId, orElse: () => {})['username'] ?? "Unknown" : "All"}.pdf',
      );
    } catch (e) {
      debugPrint('CRITICAL PDF ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  pw.Widget _pdfSummaryBox(
    String title,
    String value,
    PdfColor color, {
    bool isWide = false,
  }) {
    return pw.Container(
      width: isWide ? 180 : 130,
      height: 80,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isWide ? 16 : 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
            overflow: pw.TextOverflow.clip,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
