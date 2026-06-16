import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:intl/intl.dart';
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
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildEngineerList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAttendance,
        label: const Text("Save Attendance"),
        icon: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
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
      padding: const EdgeInsets.all(16.0),
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

    final double screenWidth = MediaQuery.of(context).size.width;
    // Mobile screen gets smaller widths to prevent overflow; Tablet & Desktop get wider ones.
    final double colWidth = screenWidth < 600 ? 55 : 75;

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
                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
}
