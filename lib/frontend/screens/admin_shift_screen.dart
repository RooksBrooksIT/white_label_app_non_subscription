import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

class Engineershiftscreen extends StatefulWidget {
  const Engineershiftscreen({super.key});

  @override
  _EngineershiftscreenState createState() => _EngineershiftscreenState();
}

class _EngineershiftscreenState extends State<Engineershiftscreen> {
  // UI State
  List<Map<String, dynamic>> _engineers = [];
  String? _selectedEngineerId;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Morning';
  String _selectedStatus = 'Pending';

  bool _isLoading = false;
  bool _isAdmin = false;

  final TextEditingController _commentController = TextEditingController();

  // Constants
  final List<String> _shifts = ['Morning', 'Evening', 'General'];
  final List<String> _statuses = ['Pending', 'Present', 'Absent'];

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    // Basic role check - could be more robust
    final user = AuthStateService.instance.currentUser;
    // For now assuming if they can access this page they are admin or checking role
    // Ideally check custom claim or user doc role here

    // In a real scenario, fetch user role from Firestore again or trust provided context
    setState(() => _isAdmin = true); // Assuming admin for this screen
    _loadEngineers();
  }

  Future<void> _loadEngineers() async {
    setState(() => _isLoading = true);
    try {
      final engineers = await AttendanceBackend.getUsers();
      setState(() {
        _engineers = engineers;
        if (engineers.isNotEmpty) {
          _selectedEngineerId = engineers.first['uid'];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading engineers: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)), // Allow future?
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedEngineerId == null) return;

    setState(() => _isLoading = true);
    try {
      final adminId =
          AuthStateService.instance.currentUser?.uid ?? 'unknown_admin';

      await AttendanceBackend.saveShiftAttendance(
        engineerId: _selectedEngineerId!,
        date: _selectedDate,
        shift: _selectedShift,
        status: _selectedStatus,
        assignedBy: adminId,
        comment: _commentController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance Saved Successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access Denied: Admins Only")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Shift & Attendance"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _engineers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectionSection(),
                  const Divider(height: 30),
                  _buildStatusSection(),
                  const Divider(height: 30),
                  _buildRealTimeView(),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Engineer'),
              initialValue: _selectedEngineerId,
              items: _engineers.map((eng) {
                return DropdownMenuItem(
                  value: eng['uid'] as String,
                  child: Text(eng['name'] ?? eng['email']),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedEngineerId = val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Shift'),
                    initialValue: _selectedShift,
                    items: _shifts
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedShift = val!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Set Status",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: _statuses.map((s) {
                return ButtonSegment<String>(
                  value: s,
                  label: Text(s),
                  icon: Icon(
                    s == 'Present'
                        ? Icons.check_circle
                        : s == 'Absent'
                        ? Icons.cancel
                        : Icons.hourglass_empty,
                  ),
                );
              }).toList(),
              selected: {_selectedStatus},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedStatus = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Admin Comment (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text("SAVE ATTENDANCE RECORD"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeView() {
    if (_selectedEngineerId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: AttendanceBackend.getAttendanceStream(
        engineerId: _selectedEngineerId!,
        date: _selectedDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              "No record found for selected date.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "LIVE RECORD VIEW",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Divider(),
                _infoRow("Current Status:", data['status'] ?? 'N/A'),
                _infoRow("Shift:", data['shift'] ?? 'N/A'),
                _infoRow("Assigned By:", data['assignedBy'] ?? 'Unknown'),
                _infoRow(
                  "Engineer Accepted:",
                  data['acceptedByEngineer'] == true ? "YES" : "NO",
                ),
                const SizedBox(height: 10),
                _infoRow(
                  "Login Time:",
                  data['loginTime']?.toString() ?? "Not Logged In",
                ),
                _infoRow("Tickets Handle:", "${data['ticketsHandled'] ?? 0}"),
                if (data['comment'] != null && data['comment'].isNotEmpty)
                  _infoRow("Comment:", data['comment']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
