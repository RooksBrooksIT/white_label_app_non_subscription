import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class Engineershiftscreen extends StatefulWidget {
  const Engineershiftscreen({super.key});

  @override
  _EngineershiftscreenState createState() => _EngineershiftscreenState();
}

class _EngineershiftscreenState extends State<Engineershiftscreen> {
  List<Map<String, dynamic>> _engineers = [];
  String? _selectedEngineerId;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Morning';
  String _selectedStatus = 'Pending';

  bool _isLoading = false;
  final bool _isAdmin = true;

  final TextEditingController _commentController = TextEditingController();

  final List<String> _shifts = ['Morning', 'Evening', 'General'];
  final List<String> _statuses = ['Pending', 'Present', 'Absent'];

  @override
  void initState() {
    super.initState();
    _loadEngineers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadEngineers() async {
    setState(() => _isLoading = true);
    try {
      final engineers = await AttendanceBackend.getUsers();
      if (mounted) {
        setState(() {
          _engineers = engineers;
          if (engineers.isNotEmpty) {
            _selectedEngineerId = engineers.first['uid'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading engineers: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance Saved Successfully', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving attendance: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Assign Shift & Attendance',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading && _engineers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              maxWidth: kMaxContentWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSelectionSection(primaryColor),
                    const SizedBox(height: 20),
                    _buildStatusSection(primaryColor),
                    const SizedBox(height: 20),
                    _buildRealTimeView(primaryColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSelectionSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engineer & Shift Assignment',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select Engineer',
              labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            initialValue: _selectedEngineerId,
            items: _engineers.map((eng) {
              return DropdownMenuItem(
                value: eng['uid'] as String,
                child: Text(
                  eng['name'] ?? eng['email'],
                  style: GoogleFonts.inter(fontSize: 14),
                ),
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
                    decoration: InputDecoration(
                      labelText: 'Date',
                      labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Shift',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  initialValue: _selectedShift,
                  items: _shifts
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 14))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedShift = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Attendance Status",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: _statuses.map((s) {
              return ButtonSegment<String>(
                value: s,
                label: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                icon: Icon(
                  s == 'Present'
                      ? Icons.check_circle_rounded
                      : s == 'Absent'
                      ? Icons.cancel_rounded
                      : Icons.hourglass_empty_rounded,
                  size: 18,
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
            decoration: InputDecoration(
              labelText: 'Admin Notes (Optional)',
              labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      "Save Attendance Record",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeView(Color primaryColor) {
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
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                "No shift record found for selected date.",
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sensors_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Live Shift Record",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _infoRow("Current Status", data['status'] ?? 'N/A'),
              _infoRow("Shift", data['shift'] ?? 'N/A'),
              _infoRow("Assigned By", data['assignedBy'] ?? 'Unknown'),
              _infoRow(
                "Engineer Accepted",
                data['acceptedByEngineer'] == true ? "YES" : "NO",
              ),
              _infoRow(
                "Login Time",
                data['loginTime']?.toString() ?? "Not Logged In",
              ),
              _infoRow("Tickets Handled", "${data['ticketsHandled'] ?? 0}"),
              if (data['comment'] != null && data['comment'].toString().isNotEmpty)
                _infoRow("Comment", data['comment'].toString()),
            ],
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
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
