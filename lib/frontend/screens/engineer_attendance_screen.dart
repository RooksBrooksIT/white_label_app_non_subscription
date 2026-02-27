import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

class EngineerAttendanceScreen extends StatefulWidget {
  const EngineerAttendanceScreen({super.key});

  @override
  _EngineerAttendanceScreenState createState() =>
      _EngineerAttendanceScreenState();
}

class _EngineerAttendanceScreenState extends State<EngineerAttendanceScreen> {
  late String _engineerId;
  final DateTime _today = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Get current engineer ID from AuthStateService
    final user = AuthStateService.instance.currentUser;
    if (user != null) {
      _engineerId = user.uid;
    } else {
      // Handle case where user is not logged in properly or ID missing
      // For now, defaulting to placeholder or popping
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error: Not Logged In')));
        Navigator.pop(context);
      });
      _engineerId = '';
    }
  }

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    try {
      await AttendanceBackend.markAttendancePresent(
        engineerId: _engineerId,
        date: _today,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift Accepted Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting shift: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAbsent() async {
    final reasonController = TextEditingController();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Absent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for your absence:'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Reason (Required)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason is required')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (shouldSubmit == true) {
      setState(() => _isLoading = true);
      try {
        await AttendanceBackend.markAttendanceAbsent(
          engineerId: _engineerId,
          date: _today,
          reason: reasonController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked Absent Successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking absent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getTodayAttendanceWithNames() async {
    try {
      // Get all daily attendance for today
      final attendance = await AttendanceBackend.getDailyAttendance(_today);

      // Get all engineers to map IDs to names
      final engineers = await AttendanceBackend.getEngineers();
      final engineerMap = {for (var e in engineers) e['uid']: e['username']};

      // Add engineer names to attendance records
      return attendance.map((record) {
        final engineerId = record['engineerId'] as String?;
        return {
          ...record,
          'engineerName': engineerMap[engineerId] ?? 'Unknown Engineer',
        };
      }).toList();
    } catch (e) {
      print('Error fetching today attendance: $e');
      return [];
    }
  }

  void _showTeamAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Team Attendance",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(_today),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),

                // Table Content
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getTodayAttendanceWithNames(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final allAttendance = snapshot.data ?? [];

                      if (allAttendance.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No attendance records for today',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final presentCount = allAttendance
                          .where((a) => a['status'] == 'Present')
                          .length;
                      final absentCount = allAttendance
                          .where((a) => a['status'] == 'Absent')
                          .length;

                      return Column(
                        children: [
                          // Summary Cards
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    color: Colors.green.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$presentCount',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const Text(
                                            'Present',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Card(
                                    color: Colors.red.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$absentCount',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const Text(
                                            'Absent',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Data Table
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey.shade200,
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Engineer Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Shift',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: allAttendance.map((engineer) {
                                    final status =
                                        engineer['status'] ?? 'Pending';
                                    final isPresent = status == 'Present';
                                    final isAbsent = status == 'Absent';

                                    Color statusColor = Colors.orange;
                                    if (isPresent) statusColor = Colors.green;
                                    if (isAbsent) statusColor = Colors.red;

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: statusColor,
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                engineer['engineerName'] ??
                                                    'Unknown',
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(engineer['shift'] ?? 'N/A'),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_engineerId.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt),
            tooltip: 'View Team Attendance',
            onPressed: () => _showTeamAttendanceDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AttendanceBackend.getAttendanceStream(
          engineerId: _engineerId,
          date: _today,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No shift assigned for today',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data()!;
          final status = data['status'] ?? 'Pending';
          final shift = data['shift'] ?? 'N/A';
          final assignedBy = data['assignedBy'] ?? 'Admin';
          final comment = data['comment'] ?? '';

          Color statusColor = Colors.orange;
          if (status == 'Present') statusColor = Colors.green;
          if (status == 'Absent') statusColor = Colors.red;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date Header
                  Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(_today),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Shift Details Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow('Shift', shift, icon: Icons.schedule),
                          const Divider(),
                          _buildDetailRow(
                            'Assigned By',
                            assignedBy == 'unknown_admin'
                                ? 'System'
                                : 'Admin', // Simple fallback
                            icon: Icons.person_outline,
                          ),
                          const Divider(),
                          _buildDetailRow(
                            'Status',
                            status,
                            icon: Icons.info_outline,
                            valueColor: statusColor,
                            isBold: true,
                          ),
                          if (comment.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(
                              'Comment',
                              comment,
                              icon: Icons.comment_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  if (status == 'Pending') ...[
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleAccept,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Accept Shift'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleAbsent,
                              icon: const Icon(Icons.cancel),
                              label: const Text('Mark Absent'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    // Status already set message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status == 'Present'
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status == 'Present'
                                ? 'You have accepted this shift'
                                : 'You have marked absent',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
          ],
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
