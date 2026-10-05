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
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Reports',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterSection(primaryColor),
            Expanded(child: _buildAttendanceList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _isLoadingEngineers
                    ? const SizedBox(
                        height: 42,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Staff Member',
                          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: primaryColor, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        initialValue: _selectedEngineerId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Staff Members',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          ..._engineers.map((eng) {
                            return DropdownMenuItem<String>(
                              value: eng['uid'] as String,
                              child: Text(
                                (eng['username'] ?? 'Unknown').toString(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: Icon(
                      Icons.date_range_outlined,
                      size: 16,
                      color: _selectedDateRange != null ? primaryColor : const Color(0xFF64748B),
                    ),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Date Range'
                          : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedDateRange != null ? FontWeight.w600 : FontWeight.w500,
                        color: _selectedDateRange != null ? primaryColor : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: _selectedDateRange != null ? primaryColor : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'By Month',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    prefixIcon: Icon(
                      Icons.calendar_month_outlined,
                      color: _selectedMonth != null ? primaryColor : const Color(0xFF64748B),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _selectedMonth != null ? primaryColor : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  initialValue: _selectedMonth?.month,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        _months[index],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
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
              _selectedMonth != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _clearFilters,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Clear Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 44, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No attendance records found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${list.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _generateProfessionalPDF(
                      list,
                      presentCount,
                      absentCount,
                      halfDayCount,
                      otCount,
                      uniqueEngineerIds.length,
                      displayDate,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: Color(0xFFDC2626)),
                    label: const Text(
                      'Export PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  const Text(
                    'Staff: ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$totalEngineers',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Text(
                    displayDate,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            children: [
              _summaryStatItem('Present', present, const Color(0xFF16A34A)),
              _summaryStatDivider(),
              _summaryStatItem('Absent', absent, const Color(0xFFDC2626)),
              _summaryStatDivider(),
              _summaryStatItem('Half Day', halfDay, const Color(0xFFD97706)),
              _summaryStatDivider(),
              _summaryStatItem('OT', ot, const Color(0xFF2563EB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStatDivider() {
    return Container(
      width: 1,
      height: 26,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _summaryStatItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> data) {
    final date = _parseTimestamp(data['date']).toDate();
    final status = (data['status'] ?? 'Present') as String;
    final username = (data['engineerUsername'] ?? 'Staff Member') as String;
    final remarks = (data['comment'] ?? '').toString();

    Color statusColor = const Color(0xFF16A34A);
    if (status == 'Absent') statusColor = const Color(0xFFDC2626);
    if (status == 'HalfDay' || status == 'Half Day') {
      statusColor = const Color(0xFFD97706);
    }
    if (status == 'OT') statusColor = const Color(0xFF2563EB);
    if (status == 'Leave') statusColor = const Color(0xFF7C3AED);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'S',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy (EEE)').format(date),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Note: $remarks',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
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
