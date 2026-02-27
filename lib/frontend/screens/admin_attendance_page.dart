import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';

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

        records.add({
          'engineerId': uid,
          'status': status,
          if (comment != null) 'comment': comment,
        });
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
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          ElevatedButton(
            onPressed: _selectAllPresent,
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

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final engineer = filtered[index];
        final uid = engineer['uid'];
        final status = _attendanceStatus[uid] ?? 'Present';

        return ListTile(
          title: Text(engineer['username'] ?? 'Unknown'),
          subtitle: Text(status),
          trailing: _buildStatusSelector(uid, status),
        );
      },
    );
  }

  Widget _buildStatusSelector(String uid, String currentStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusButton(uid, 'Present', Colors.green, currentStatus == 'Present'),
        _statusButton(uid, 'Absent', Colors.red, currentStatus == 'Absent'),
        _statusButton(uid, 'OT', Colors.blue, currentStatus == 'OT'),
        _statusButton(
          uid,
          'HalfDay',
          Colors.orange,
          currentStatus == 'HalfDay',
        ),
      ],
    );
  }

  Widget _statusButton(
    String uid,
    String status,
    Color color,
    bool isSelected,
  ) {
    return IconButton(
      icon: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? color : Colors.grey,
      ),
      onPressed: () {
        setState(() {
          _attendanceStatus[uid] = status;
        });
      },
    );
  }
}
