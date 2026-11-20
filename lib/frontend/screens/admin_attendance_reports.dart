import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/pdf_utils.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

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
        child: ResponsiveWrapper(
          maxWidth: 960,
          child: Column(
            children: [
              _buildFilterSection(primaryColor),
              Expanded(child: _buildAttendanceList()),
            ],
          ),
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
                      leaveCount,
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
    int leave,
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

      final theme = await PdfUtils.loadReportTheme();
      final pdf = pw.Document(theme: theme);

      // Load logo
      pw.MemoryImage? logoImage;
      final logoUrl = ThemeService.instance.logoUrl;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        logoImage = await PdfUtils.fetchNetworkImage(logoUrl);
      }

      final appName = ThemeService.instance.appName;
      String engineerFilterName = 'All Engineers';
      String filenameEngPart = 'All';
      if (_selectedEngineerId != null) {
        final found = _engineers.firstWhere(
          (e) => e['uid'] == _selectedEngineerId,
          orElse: () => {},
        );
        if (found['username'] != null &&
            found['username'].toString().isNotEmpty) {
          engineerFilterName = found['username'].toString().toUpperCase();
          filenameEngPart = found['username'].toString().replaceAll(' ', '_');
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          header: (context) {
            if (context.pageNumber == 1) {
              return _buildPdfHeader(
                logoImage: logoImage,
                appName: appName,
                displayDate: displayDate,
                engineerFilter: engineerFilterName,
              );
            }
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$appName - Engineer Attendance Report',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F172A),
                    ),
                  ),
                  pw.Text(
                    displayDate,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          },
          build: (context) {
            return [
              // Summary Section
              _buildPdfSummaryRow(
                present: present,
                absent: absent,
                halfDay: halfDay,
                leave: leave,
                totalEngineers: totalEngineers,
                ot: ot,
              ),
              pw.SizedBox(height: 14),

              // Table Title & Counter Bar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ATTENDANCE LOGS',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFF1F5F9),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFE2E8F0),
                        width: 0.6,
                      ),
                    ),
                    child: pw.Text(
                      '${list.length} ${list.length == 1 ? "Record" : "Records"}',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Attendance Details Table
              _buildAttendanceTable(list),
            ];
          },
          footer: (context) => pw.Column(
            children: [
              pw.Divider(
                thickness: 0.5,
                color: const PdfColor.fromInt(0xFFCBD5E1),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$appName - Confidential Internal Report',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening PDF preview...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final cleanDate = displayDate
          .replaceAll(' ', '_')
          .replaceAll(',', '')
          .replaceAll('-', '_');
      final pdfName = 'Attendance_Report_${filenameEngPart}_$cleanDate.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: pdfName,
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

  pw.Widget _buildPdfHeader({
    required pw.MemoryImage? logoImage,
    required String appName,
    required String displayDate,
    required String engineerFilter,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    height: 36,
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Text(
                    appName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E3A8A),
                    ),
                  ),
                pw.Text(
                  'Engineer Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Attendance and performance log summary',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF64748B),
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'Period: ',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF475569),
                        ),
                      ),
                      pw.Text(
                        displayDate,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'Engineer: ',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF475569),
                        ),
                      ),
                      pw.Text(
                        engineerFilter,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromInt(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'Generated: ',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                      pw.Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(DateTime.now()),
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 1.5,
          color: const PdfColor.fromInt(0xFF2563EB),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPdfSummaryRow({
    required int present,
    required int absent,
    required int halfDay,
    required int leave,
    required int totalEngineers,
    required int ot,
  }) {
    final cards = <pw.Widget>[
      _buildPdfSummaryCard(
        label: 'Present',
        value: present.toString(),
        textColor: const PdfColor.fromInt(0xFF15803D),
        bgColor: const PdfColor.fromInt(0xFFF0FDF4),
        borderColor: const PdfColor.fromInt(0xFFBBF7D0),
      ),
      pw.SizedBox(width: 6),
      _buildPdfSummaryCard(
        label: 'Absent',
        value: absent.toString(),
        textColor: const PdfColor.fromInt(0xFFB91C1C),
        bgColor: const PdfColor.fromInt(0xFFFEF2F2),
        borderColor: const PdfColor.fromInt(0xFFFECACA),
      ),
      pw.SizedBox(width: 6),
      _buildPdfSummaryCard(
        label: 'Half Day',
        value: halfDay.toString(),
        textColor: const PdfColor.fromInt(0xFFB45309),
        bgColor: const PdfColor.fromInt(0xFFFFFBEB),
        borderColor: const PdfColor.fromInt(0xFFFDE68A),
      ),
      pw.SizedBox(width: 6),
      _buildPdfSummaryCard(
        label: 'On Leave',
        value: leave.toString(),
        textColor: const PdfColor.fromInt(0xFF1D4ED8),
        bgColor: const PdfColor.fromInt(0xFFEFF6FF),
        borderColor: const PdfColor.fromInt(0xFFBFDBFE),
      ),
      pw.SizedBox(width: 6),
      _buildPdfSummaryCard(
        label: 'Total Engineers',
        value: totalEngineers.toString(),
        textColor: const PdfColor.fromInt(0xFF0F172A),
        bgColor: const PdfColor.fromInt(0xFFF8FAFC),
        borderColor: const PdfColor.fromInt(0xFFCBD5E1),
      ),
    ];

    if (ot > 0) {
      cards.add(pw.SizedBox(width: 6));
      cards.add(
        _buildPdfSummaryCard(
          label: 'Overtime',
          value: ot.toString(),
          textColor: const PdfColor.fromInt(0xFF7C3AED),
          bgColor: const PdfColor.fromInt(0xFFFAF5FF),
          borderColor: const PdfColor.fromInt(0xFFE9D5FF),
        ),
      );
    }

    return pw.Row(children: cards);
  }

  pw.Widget _buildPdfSummaryCard({
    required String label,
    required String value,
    required PdfColor textColor,
    required PdfColor bgColor,
    required PdfColor borderColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: borderColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 6.8,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF64748B),
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildAttendanceTable(List<dynamic> list) {
    if (list.isEmpty) {
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 24),
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              'No Attendance Records Found',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF475569),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'There are no attendance records for the selected period and filter.',
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColor.fromInt(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0F172A),
        ),
        children: [
          _pdfTableHeaderCell('Date'),
          _pdfTableHeaderCell('Engineer Name'),
          _pdfTableHeaderCell('Status', align: pw.TextAlign.center),
          _pdfTableHeaderCell('Remarks'),
        ],
      ),
    ];

    for (int i = 0; i < list.length; i++) {
      final d = list[i];
      String dateStr = '-';
      if (d['date'] != null) {
        try {
          final dt = _parseTimestamp(d['date']).toDate();
          dateStr = DateFormat('dd MMM yyyy').format(dt);
        } catch (_) {
          dateStr = d['date'].toString();
        }
      }

      final username = d['engineerUsername']?.toString().toUpperCase() ?? 'N/A';
      final status = d['status']?.toString() ?? 'N/A';
      final rawComment = d['comment']?.toString();
      String remarks = '';
      if (rawComment != null) {
        final trimmed = rawComment.trim();
        if (trimmed.isNotEmpty &&
            trimmed != '-' &&
            trimmed != '—' &&
            trimmed != '–' &&
            trimmed.toLowerCase() != 'null' &&
            trimmed.toLowerCase() != 'n/a') {
          // Normalize common unicode characters for reliable PDF font rendering
          remarks = trimmed
              .replaceAll('\u2014', '-')
              .replaceAll('\u2013', '-')
              .replaceAll('\u2018', "'")
              .replaceAll('\u2019', "'")
              .replaceAll('\u201C', '"')
              .replaceAll('\u201D', '"')
              .replaceAll('\u2026', '...')
              .replaceAll('\u00A0', ' ');
        }
      }

      final isEven = i % 2 == 0;
      final rowBg = isEven
          ? const PdfColor.fromInt(0xFFFFFFFF)
          : const PdfColor.fromInt(0xFFF8FAFC);

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBg),
          children: [
            _pdfTableCell(
              child: pw.Text(
                dateStr,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColor.fromInt(0xFF334155),
                ),
              ),
            ),
            _pdfTableCell(
              child: pw.Text(
                username,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F172A),
                ),
              ),
            ),
            _pdfTableCell(
              alignment: pw.Alignment.center,
              child: _pdfStatusBadge(status),
            ),
            _pdfTableCell(
              child: remarks.isNotEmpty
                  ? pw.Text(
                      remarks,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFF475569),
                      ),
                    )
                  : pw.SizedBox(),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        bottom: const pw.BorderSide(
          color: PdfColor.fromInt(0xFFE2E8F0),
          width: 0.8,
        ),
        horizontalInside: const pw.BorderSide(
          color: PdfColor.fromInt(0xFFE2E8F0),
          width: 0.6,
        ),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(80),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FixedColumnWidth(90),
        3: pw.FlexColumnWidth(2.8),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  pw.Widget _pdfTableHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: const PdfColor.fromInt(0xFFFFFFFF),
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell({
    required pw.Widget child,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: child,
    );
  }

  pw.Widget _pdfStatusBadge(String status) {
    final clean = status.trim().toLowerCase();
    PdfColor bg;
    PdfColor text;
    PdfColor border;

    if (clean == 'present') {
      bg = const PdfColor.fromInt(0xFFDCFCE7);
      text = const PdfColor.fromInt(0xFF15803D);
      border = const PdfColor.fromInt(0xFF86EFAC);
    } else if (clean == 'absent') {
      bg = const PdfColor.fromInt(0xFFFEE2E2);
      text = const PdfColor.fromInt(0xFFB91C1C);
      border = const PdfColor.fromInt(0xFFFCA5A5);
    } else if (clean.contains('half')) {
      bg = const PdfColor.fromInt(0xFFFEF3C7);
      text = const PdfColor.fromInt(0xFFB45309);
      border = const PdfColor.fromInt(0xFFFCD34D);
    } else if (clean.contains('leave')) {
      bg = const PdfColor.fromInt(0xFFDBEAFE);
      text = const PdfColor.fromInt(0xFF1D4ED8);
      border = const PdfColor.fromInt(0xFF93C5FD);
    } else {
      bg = const PdfColor.fromInt(0xFFF1F5F9);
      text = const PdfColor.fromInt(0xFF475569);
      border = const PdfColor.fromInt(0xFFCBD5E1);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        status.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
