import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _engineers = [];

  // State maps
  Map<String, String> _attendanceStatus =
      {}; // uid -> status ('Present', 'Absent', 'OT', 'HalfDay')
  Map<String, String> _absentReasons = {}; // uid -> reason

  String _searchQuery = '';
  bool _isLoading = true;
  final String _selectedShift = 'General';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final engineers = await AttendanceBackend.getEngineers();
      final attendanceRecords = await AttendanceBackend.getDailyAttendance(
        _selectedDate,
      );

      final statusMap = <String, String>{};
      final reasonMap = <String, String>{};

      for (var record in attendanceRecords) {
        final uid = record['engineerId'];
        final status = record['status'];
        if (uid != null && status != null) {
          statusMap[uid] = status;
          if (status == 'Absent' || status == 'HalfDay') {
            reasonMap[uid] = record['comment'] ?? '';
          }
        }
      }

      if (mounted) {
        setState(() {
          _engineers = engineers;
          _attendanceStatus = statusMap;
          _absentReasons = reasonMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> records = [];

      for (var engineer in _engineers) {
        final uid = engineer['uid'];
        final status = _attendanceStatus[uid] ?? 'Present';
        final comment = (status == 'Absent' || status == 'HalfDay')
            ? (_absentReasons[uid] ?? '')
            : null;

        records.add({'engineerId': uid, 'status': status, 'comment': comment});
      }

      await AttendanceBackend.batchSaveAttendance(
        records: records,
        date: _selectedDate,
        shift: _selectedShift,
        assignedBy: 'Admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAllPresent() {
    setState(() {
      for (var eng in _engineers) {
        _attendanceStatus[eng['uid']] = 'Present';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Attendance'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAttendanceReportsPage(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isWeb
              ? _buildWebLayout()
              : ResponsiveWrapper(
                  maxWidth: kMaxContentWidth,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(child: _buildEngineerList()),
                    ],
                  ),
                ),
      floatingActionButton: isWeb
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveAttendance,
              label: const Text("Save Attendance"),
              icon: const Icon(Icons.save),
            ),
    );
  }

  Widget _buildHeader() {
    final bool isMobile = context.isMobile;
    // Desktop/tablet will use larger layout automatically

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: 16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by engineer name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12.0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectAllPresent,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text("All Present"),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Tablet/Desktop Header
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: 16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by engineer name...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _selectAllPresent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              child: const Text("All Present"),
            ),
          ],
        ),
      );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Widget _buildEngineerList() {
    final filtered = _engineers.where((e) {
      final name = (e['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No engineers found"));
    }

    final double colWidth = context.isMobile ? 55 : 75;

    return Column(
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Engineer Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              _buildStatusHeader(colWidth),
            ],
          ),
        ),
        // Divider
        const Divider(height: 1),
        // Engineer List
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final engineer = filtered[index];
              final uid = engineer['uid'];
              final status = _attendanceStatus[uid] ?? 'Present';

              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                ),
                padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            engineer['username'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status == 'HalfDay' ? 'Half Day' : status,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusSelector(uid, status, colWidth),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(double colWidth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerLabel('Present', colWidth),
        _headerLabel('Absent', colWidth),
        _headerLabel('Half Day', colWidth),
        _headerLabel('OT', colWidth),
      ],
    );
  }

  Widget _headerLabel(String text, double colWidth) {
    return SizedBox(
      width: colWidth,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: colWidth < 60 ? 9.5 : 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildStatusSelector(String uid, String currentStatus, double colWidth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusButton(uid, 'Present', Colors.green, currentStatus == 'Present', colWidth),
        _statusButton(uid, 'Absent', Colors.red, currentStatus == 'Absent', colWidth),
        _statusButton(uid, 'HalfDay', Colors.orange, currentStatus == 'HalfDay', colWidth),
        _statusButton(uid, 'OT', Colors.blue, currentStatus == 'OT', colWidth),
      ],
    );
  }

  Widget _statusButton(
    String uid,
    String status,
    Color color,
    bool isSelected,
    double colWidth,
  ) {
    return SizedBox(
      width: colWidth,
      height: 48,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: isSelected ? color : Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _attendanceStatus[uid] = status;
          });
        },
      ),
    );
  }
  // --- Web Specific Layout Methods ---

  Widget _buildWebLayout() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ResponsiveWrapper(
            maxWidth: 1200.0,
            child: Column(
              children: [
                _buildWebHeader(),
                Expanded(child: _buildWebDataTable()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search engineers...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 24),
          OutlinedButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _selectAllPresent,
            icon: const Icon(Icons.done_all),
            label: const Text("Mark All Present"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _saveAttendance,
            icon: const Icon(Icons.save),
            label: const Text("Save Attendance"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDataTable() {
    final filtered = _engineers.where((e) {
      final name = (e['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No engineers found", style: TextStyle(fontSize: 18)));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 24),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                dataRowMinHeight: 70,
                dataRowMaxHeight: 70,
                columns: const [
                  DataColumn(label: Text('Engineer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  DataColumn(label: Text('Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ],
                rows: filtered.map((engineer) {
                  final uid = engineer['uid'];
                  final status = _attendanceStatus[uid] ?? 'Present';
                  return DataRow(
                    cells: [
                      DataCell(Text(engineer['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      DataCell(_buildWebStatusSelector(uid, status)),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            width: 300,
                            child: TextFormField(
                              initialValue: _absentReasons[uid] ?? '',
                              onChanged: (val) {
                                _absentReasons[uid] = val;
                              },
                              decoration: InputDecoration(
                                hintText: 'Add remarks...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                      )
                    ]
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebStatusSelector(String uid, String currentStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _webStatusChip(uid, 'Present', Colors.green, currentStatus == 'Present'),
        const SizedBox(width: 8),
        _webStatusChip(uid, 'Absent', Colors.red, currentStatus == 'Absent'),
        const SizedBox(width: 8),
        _webStatusChip(uid, 'HalfDay', Colors.orange, currentStatus == 'HalfDay'),
        const SizedBox(width: 8),
        _webStatusChip(uid, 'OT', Colors.blue, currentStatus == 'OT'),
      ],
    );
  }

  Widget _webStatusChip(String uid, String status, Color color, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceStatus[uid] = status;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status == 'HalfDay' ? 'Half Day' : status,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
