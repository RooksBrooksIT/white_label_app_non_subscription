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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildAttendanceList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                          labelText: 'Select Engineer',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        initialValue: _selectedEngineerId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('ALL ENGINEERS'),
                          ),
                          ..._engineers.map((eng) {
                            return DropdownMenuItem<String>(
                              value: eng['uid'] as String,
                              child: Text(
                                (eng['username'] ?? 'Unknown')
                                    .toString()
                                    .toUpperCase(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _selectedDateRange == null
                        ? 'Date Range'
                        : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'By Month',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  initialValue: _selectedMonth?.month,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(_months[index]),
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
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All Filters'),
              ),
            ),
        ],
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var list = snapshot.data ?? [];

        // Concept: Engineer is marked as present for each and everyday until marked otherwise.
        // We fill in the gaps for the selected range/month if a specific engineer is selected.
        if (_selectedEngineerId != null) {
          // Sort descending
          list.sort(
            (a, b) =>
                (b['date'] as Timestamp).compareTo(a['date'] as Timestamp),
          );
        } else if (_selectedEngineerId == null) {
          // If "All Engineers" is selected, just filter the existing list by date
          DateTime? start, end;
          if (_selectedMonth != null) {
            start = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
            end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
          } else if (_selectedDateRange != null) {
            start = _selectedDateRange!.start;
            end = _selectedDateRange!.end;
          }

          if (start != null && end != null) {
            list = list.where((data) {
              final date = _parseTimestamp(data['date']).toDate();
              return (date.isAfter(start!.subtract(const Duration(days: 1))) ||
                      date.isAtSameMomentAs(start)) &&
                  (date.isBefore(end!.add(const Duration(days: 1))) ||
                      date.isAtSameMomentAs(end));
            }).toList();
          }
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
        }

        int totalDays = list.length;
        double attendancePercentage = totalDays > 0
            ? ((presentCount + otCount + (halfDayCount * 0.5)) / totalDays) *
                  100
            : 0.0;

        return Column(
          children: [
            _buildSummaryCards(
              presentCount,
              absentCount,
              leaveCount,
              otCount,
              halfDayCount,
              totalDays,
              attendancePercentage,
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
                      leaveCount,
                      otCount,
                      halfDayCount,
                      totalDays,
                      attendancePercentage,
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
    int leave,
    int ot,
    int halfDay,
    int total,
    double percentage,
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
                'Total Days',
                total.toString(),
                Icons.event_note,
                Colors.blueGrey,
              ),
              const SizedBox(width: 12),
              _metricCard(
                'Attendance %',
                '${percentage.toStringAsFixed(1)}%',
                Icons.analytics,
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(bottom: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> data) {
    final date = _parseTimestamp(data['date']).toDate();
    final status = data['status'] as String;
    final username = data['engineerUsername'] as String;
    // Strictly use 'comment' as that is where data is saved.
    final remarks = data['comment'] ?? '';

    Color statusColor = Colors.green;
    if (status == 'Absent') statusColor = Colors.red;
    if (status == 'Leave') statusColor = Colors.orange;
    if (status == 'OT') statusColor = Colors.blue;
    if (status == 'HalfDay' || status == 'Half Day') {
      statusColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              username.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          username.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy (EEE)').format(date),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: $remarks',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateProfessionalPDF(
    List<dynamic> list,
    int present,
    int absent,
    int leave,
    int ot,
    int halfDay,
    int total,
    double percentage,
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
          pageFormat: PdfPageFormat.a4,
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
            return [
              // Summary Stats
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
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
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfSummaryBox(
                    'Total Days',
                    total.toString(),
                    PdfColors.blueGrey700,
                  ),
                  _pdfSummaryBox(
                    'Attendance %',
                    '${percentage.toStringAsFixed(1)}%',
                    PdfColors.indigo700,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Attendance Table
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                },
                headers: ['Engineer Name', 'Date', 'Status', 'Remarks'],
                data: list.map((d) {
                  try {
                    final username =
                        d['engineerUsername']?.toString().toUpperCase() ??
                        'N/A';

                    String dateStr = '-';
                    if (d['date'] != null && d['date'] is Timestamp) {
                      dateStr = DateFormat(
                        'dd/MM/yyyy',
                      ).format((d['date'] as Timestamp).toDate());
                    }

                    return [
                      username,
                      dateStr,
                      d['status']?.toString() ?? 'N/A',
                      d['comment']?.toString() ?? '-',
                    ];
                  } catch (e) {
                    return ['Error', '-', '-', '-'];
                  }
                }).toList(),
              ),
            ];
          },
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
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

  pw.Widget _pdfSummaryBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
