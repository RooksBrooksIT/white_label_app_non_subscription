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

  // Attendance state maps
  Map<String, String> _attendanceStatus = {}; // uid -> status ('Present', 'Absent', 'HalfDay', 'OT', 'Leave')
  Map<String, String> _attendanceComments = {}; // uid -> reason / notes
  Map<String, String> _attendanceCheckIn = {}; // uid -> '09:05 AM'
  Map<String, String> _attendanceCheckOut = {}; // uid -> '06:10 PM'

  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Present', 'Absent', 'HalfDay', 'OT', 'Leave'
  bool _isLoading = true;
  bool _isSaving = false;
  final String _selectedShift = 'General';

  late TabController _tabController;

  // History tab state filters
  String? _historySelectedEngineer;
  final String _historyStatusFilter = 'All';

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
      final commentMap = <String, String>{};
      final checkInMap = <String, String>{};
      final checkOutMap = <String, String>{};

      for (var record in attendanceRecords) {
        final uid = record['engineerId'];
        final status = record['status'];
        if (uid != null && status != null) {
          statusMap[uid] = status;
          if (record['comment'] != null && (record['comment'] as String).isNotEmpty) {
            commentMap[uid] = record['comment'];
          }
          if (record['checkInTime'] != null) {
            checkInMap[uid] = record['checkInTime'].toString();
          }
          if (record['checkOutTime'] != null) {
            checkOutMap[uid] = record['checkOutTime'].toString();
          }
        }
      }

      if (mounted) {
        setState(() {
          _engineers = engineers;
          _attendanceStatus = statusMap;
          _attendanceComments = commentMap;
          _attendanceCheckIn = checkInMap;
          _attendanceCheckOut = checkOutMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendance data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> records = [];

      for (var engineer in _engineers) {
        final uid = engineer['uid'];
        final status = _attendanceStatus[uid] ?? 'Present';
        final comment = _attendanceComments[uid] ?? '';

        records.add({
          'engineerId': uid,
          'status': status,
          'comment': comment,
          'checkInTime': _attendanceCheckIn[uid] ?? '09:00 AM',
          'checkOutTime': _attendanceCheckOut[uid] ?? '06:00 PM',
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
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("Attendance saved successfully!"),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving attendance: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmMarkAllPresent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('Mark All Present?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'This will set all ${_engineers.length} staff members to "Present" for ${DateFormat('dd MMMM yyyy').format(_selectedDate)}. You can still make individual adjustments afterwards.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                for (var eng in _engineers) {
                  _attendanceStatus[eng['uid']] = 'Present';
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All staff marked as Present.'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm All Present'),
          ),
        ],
      ),
    );
  }

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _loadData();
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  // Calculated operational counts
  int get _countTotal => _engineers.length;
  int get _countPresent => _engineers.where((e) => (_attendanceStatus[e['uid']] ?? 'Present') == 'Present').length;
  int get _countAbsent => _engineers.where((e) => (_attendanceStatus[e['uid']] ?? 'Present') == 'Absent').length;
  int get _countHalfDay => _engineers.where((e) {
    final s = _attendanceStatus[e['uid']] ?? 'Present';
    return s == 'HalfDay' || s == 'OT';
  }).length;
  int get _countLeave => _engineers.where((e) => (_attendanceStatus[e['uid']] ?? 'Present') == 'Leave').length;

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
          'Attendance Workspace',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAttendanceReportsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded, size: 18),
              label: const Text(
                'Reports',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopDomainBanner(primaryColor),
            _buildDateNavigatorBar(primaryColor),
            _buildSummaryKpiCards(),
            _buildWorkspaceTabs(primaryColor),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayAttendanceTab(primaryColor),
                  _buildAttendanceHistoryTab(primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP DOMAIN HERO BANNER
  // ===========================================================================
  Widget _buildTopDomainBanner(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                Icons.fact_check_rounded,
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
                    'Attendance Management System',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monitor staff presence, hours, and daily attendance logs',
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

  // ===========================================================================
  // DATE NAVIGATOR BAR
  // ===========================================================================
  Widget _buildDateNavigatorBar(Color primaryColor) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 22),
              color: const Color(0xFF0F172A),
              onPressed: () => _changeDate(-1),
              tooltip: 'Previous Day',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 15, color: primaryColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B), size: 20),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isToday)
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDate = DateTime.now());
                      _loadData();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  color: const Color(0xFF0F172A),
                  onPressed: isToday ? null : () => _changeDate(1),
                  tooltip: 'Next Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // OPERATIONAL KPI CARDS
  // ===========================================================================
  Widget _buildSummaryKpiCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildKpiCard('Total Staff', '$_countTotal', Icons.people_alt_rounded, const Color(0xFF64748B)),
            const SizedBox(width: 8),
            _buildKpiCard('Present', '$_countPresent', Icons.check_circle_rounded, const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _buildKpiCard('Half Day / OT', '$_countHalfDay', Icons.access_time_filled_rounded, const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _buildKpiCard('Absent', '$_countAbsent', Icons.cancel_rounded, const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            _buildKpiCard('On Leave', '$_countLeave', Icons.beach_access_rounded, const Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WORKSPACE TAB SEGMENT CONTROL
  // ===========================================================================
  Widget _buildWorkspaceTabs(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: primaryColor,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'Today\'s Attendance'),
          Tab(text: 'History Log'),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TODAY'S ATTENDANCE INLINE WORKSPACE
  // ===========================================================================
  Widget _buildTodayAttendanceTab(Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredEngineers = _engineers.where((eng) {
      final name = (eng['username'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      final status = _attendanceStatus[eng['uid']] ?? 'Present';

      if (_statusFilter == 'All') return matchesSearch;
      if (_statusFilter == 'Present') return matchesSearch && status == 'Present';
      if (_statusFilter == 'Absent') return matchesSearch && status == 'Absent';
      if (_statusFilter == 'HalfDay') return matchesSearch && status == 'HalfDay';
      if (_statusFilter == 'OT') return matchesSearch && status == 'OT';
      if (_statusFilter == 'Leave') return matchesSearch && status == 'Leave';
      return matchesSearch;
    }).toList();

    return Column(
      children: [
        // Controls Row: Search + Status Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search staff member...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _confirmMarkAllPresent,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF059669),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),

        // Quick Filter Status Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', _statusFilter == 'All', primaryColor),
                const SizedBox(width: 6),
                _buildStatusChip('Present', _statusFilter == 'Present', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildStatusChip('Absent', _statusFilter == 'Absent', const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _buildStatusChip('HalfDay', _statusFilter == 'HalfDay', const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _buildStatusChip('OT', _statusFilter == 'OT', const Color(0xFF3B82F6)),
                const SizedBox(width: 6),
                _buildStatusChip('Leave', _statusFilter == 'Leave', const Color(0xFF8B5CF6)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Staff Attendance List Cards
        Expanded(
          child: filteredEngineers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredEngineers.length,
                  itemBuilder: (context, index) {
                    final engineer = filteredEngineers[index];
                    final uid = engineer['uid'];
                    final username = engineer['username'] ?? 'Unknown Staff';
                    final currentStatus = _attendanceStatus[uid] ?? 'Present';
                    final comment = _attendanceComments[uid] ?? '';

                    return _buildStaffAttendanceCard(
                      uid: uid,
                      username: username,
                      email: engineer['email'] ?? '',
                      currentStatus: currentStatus,
                      comment: comment,
                      primaryColor: primaryColor,
                    );
                  },
                ),
        ),

        // Sticky Bottom Save Bar
        _buildStickySaveBar(primaryColor),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, Color activeColor) {
    return ChoiceChip(
      label: Text(
        label == 'HalfDay' ? 'Half Day' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = label),
      selectedColor: activeColor,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? activeColor : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildStaffAttendanceCard({
    required String uid,
    required String username,
    required String email,
    required String currentStatus,
    required String comment,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Staff Name + Remarks Trigger
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  comment.isNotEmpty ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: comment.isNotEmpty ? primaryColor : const Color(0xFF94A3B8),
                ),
                onPressed: () => _openRemarksModal(uid, username, comment),
                tooltip: 'Add Remarks',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status Selector Segmented Controls
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusOptionPill(uid, 'Present', '✓ Present', const Color(0xFF10B981), currentStatus == 'Present'),
                const SizedBox(width: 6),
                _buildStatusOptionPill(uid, 'Absent', '✕ Absent', const Color(0xFFEF4444), currentStatus == 'Absent'),
                const SizedBox(width: 6),
                _buildStatusOptionPill(uid, 'HalfDay', '⏰ Half Day', const Color(0xFFF59E0B), currentStatus == 'HalfDay'),
                const SizedBox(width: 6),
                _buildStatusOptionPill(uid, 'OT', '⚡ OT', const Color(0xFF3B82F6), currentStatus == 'OT'),
                const SizedBox(width: 6),
                _buildStatusOptionPill(uid, 'Leave', '🏖 Leave', const Color(0xFF8B5CF6), currentStatus == 'Leave'),
              ],
            ),
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Notes: $comment',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusOptionPill(String uid, String status, String label, Color activeColor, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceStatus[uid] = status;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStickySaveBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveAttendance,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded, size: 20),
          label: Text(
            _isSaving ? 'Saving Attendance...' : 'Save Attendance Records',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  void _openRemarksModal(String uid, String username, String initialComment) {
    final controller = TextEditingController(text: initialComment);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remarks for $username',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason or attendance remarks...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _attendanceComments[uid] = controller.text.trim();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Remarks', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: ATTENDANCE HISTORY LOG STREAM
  // ===========================================================================
  Widget _buildAttendanceHistoryTab(Color primaryColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AttendanceBackend.getAllAttendanceHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading history: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        var historyList = snapshot.data ?? [];

        // Apply History Filters
        if (_historySelectedEngineer != null && _historySelectedEngineer!.isNotEmpty) {
          historyList = historyList.where((h) => h['engineerId'] == _historySelectedEngineer).toList();
        }
        if (_historyStatusFilter != 'All') {
          historyList = historyList.where((h) => h['status'] == _historyStatusFilter).toList();
        }

        if (historyList.isEmpty) {
          return _buildEmptyState(message: 'No historical attendance records found');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: historyList.length,
          itemBuilder: (context, index) {
            final record = historyList[index];
            final status = record['status'] ?? 'Present';
            final dateStr = record['date'] ?? '';
            final username = record['engineerUsername'] ?? 'Staff Member';
            final comment = record['comment'] ?? '';

            Color statusColor;
            if (status == 'Present') {
              statusColor = const Color(0xFF10B981);
            } else if (status == 'Absent') {
              statusColor = const Color(0xFFEF4444);
            } else if (status == 'HalfDay') {
              statusColor = const Color(0xFFF59E0B);
            } else if (status == 'OT') {
              statusColor = const Color(0xFF3B82F6);
            } else {
              statusColor = const Color(0xFF8B5CF6);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      status == 'Present'
                          ? Icons.check_circle_rounded
                          : status == 'Absent'
                          ? Icons.cancel_rounded
                          : Icons.access_time_filled_rounded,
                      color: statusColor,
                      size: 20,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            if (comment.toString().isNotEmpty) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.info_outline, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  comment,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================

  Widget _buildEmptyState({String message = 'No attendance records for this date'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a status or use "All Present" to initialize attendance.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
