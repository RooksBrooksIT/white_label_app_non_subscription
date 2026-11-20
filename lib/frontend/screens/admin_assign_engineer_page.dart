import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
import 'package:subscription_rooks_app/frontend/screens/assign_confirmation_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';

class AssignEngineerPage extends StatefulWidget {
  final Customer customer;

  const AssignEngineerPage({super.key, required this.customer});

  @override
  _AssignEngineerPageState createState() => _AssignEngineerPageState();
}

class _AssignEngineerPageState extends State<AssignEngineerPage> {
  bool _isAssigning = false;
  bool _isEngineerSelected = true;

  // Primary Engineer Selection
  String? _selectedEngineer;
  String? _selectedEngineerId;
  String? _selectedEngineerPhone;

  // Helper Engineer Selection (Optional)
  String? _selectedHelper;
  String? _selectedHelperId;

  // Visit Scheduling Fields
  DateTime? _selectedVisitDate;
  TimeOfDay? _selectedVisitTime;
  final TextEditingController _visitNotesController = TextEditingController();

  // Helper Tab controllers
  final TextEditingController _helperReasonController = TextEditingController();
  List<Map<String, String>> addedHelpers = [];

  // Registered Engineers
  List<Map<String, dynamic>> _engineersList = [];
  bool _isLoadingEngineers = true;

  // Existing ticket data / Cancellation check
  bool _isTicketCancelled = false;
  String _cancellationReason = '';
  Map<String, dynamic>? _existingTicketData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _visitNotesController.dispose();
    _helperReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Fetch Engineers list
      final snapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .get();
      final engineers = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final username = (data['Username'] ?? '').toString().trim();
        final isActive =
            data['isActive'] != false && data['status'] != 'inactive';
        if (username.isNotEmpty && isActive) {
          engineers.add({
            'id': doc.id,
            'username': username,
            'phone':
                (data['Phone'] ??
                        data['phone'] ??
                        data['mobileNumber'] ??
                        data['Mobile'] ??
                        '')
                    .toString()
                    .trim(),
            'specialization':
                (data['Specialization'] ?? data['specialization'] ?? '')
                    .toString()
                    .trim(),
          });
        }
      }

      // 2. Fetch existing ticket data to pre-populate or check cancellation
      final ticketDoc = await FirestoreService.instance
          .collection('Admin_ticket_entry')
          .doc(widget.customer.bookingId)
          .get();

      Map<String, dynamic>? ticketData;
      if (ticketDoc.exists && ticketDoc.data() != null) {
        ticketData = ticketDoc.data()!;
      } else {
        // Fallback to Raised_tickets
        final raisedDoc = await FirestoreService.instance
            .collection('Raised_tickets')
            .doc(widget.customer.bookingId)
            .get();
        if (raisedDoc.exists && raisedDoc.data() != null) {
          ticketData = raisedDoc.data()!;
        }
      }

      bool isCancelled = false;
      String cancelReason = '';

      if (ticketData != null) {
        final status = (ticketData['status'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final adminStatus = (ticketData['adminStatus'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final engineerStatus = (ticketData['engineerStatus'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        if (status == 'cancelled' ||
            status == 'canceled' ||
            adminStatus == 'cancelled' ||
            adminStatus == 'canceled' ||
            engineerStatus == 'cancelled' ||
            engineerStatus == 'canceled') {
          isCancelled = true;
          cancelReason =
              (ticketData['cancellationReason'] ??
                      ticketData['cancellation_reason'] ??
                      ticketData['cancelReason'] ??
                      'This ticket was cancelled by administration.')
                  .toString();
        }
      }

      if (mounted) {
        setState(() {
          _engineersList = engineers;
          _isLoadingEngineers = false;
          _existingTicketData = ticketData;
          _isTicketCancelled = isCancelled;
          _cancellationReason = cancelReason;

          // Pre-populate if existing assignment & schedule exists
          if (ticketData != null && !isCancelled) {
            final assignedEmp =
                (ticketData['assignedEmployee'] ??
                        ticketData['assignedEngineer'] ??
                        '')
                    .toString()
                    .trim();
            if (assignedEmp.isNotEmpty &&
                assignedEmp.toLowerCase() != 'not assigned') {
              _selectedEngineer = assignedEmp;
              final matched = engineers.firstWhere(
                (e) =>
                    e['username'].toString().toLowerCase() ==
                    assignedEmp.toLowerCase(),
                orElse: () => {},
              );
              if (matched.isNotEmpty) {
                _selectedEngineerId = matched['id'];
                _selectedEngineerPhone = matched['phone'];
              }
            }

            final hName =
                (ticketData['helperName'] ??
                        ticketData['helper'] ??
                        ticketData['Helper1'] ??
                        '')
                    .toString()
                    .trim();
            if (hName.isNotEmpty) {
              _selectedHelper = hName;
              final matchedH = engineers.firstWhere(
                (e) =>
                    e['username'].toString().toLowerCase() ==
                    hName.toLowerCase(),
                orElse: () => {},
              );
              if (matchedH.isNotEmpty) {
                _selectedHelperId = matchedH['id'];
              }
            }

            final vDateStr = (ticketData['expectedVisitDate'] ?? '')
                .toString()
                .trim();
            if (vDateStr.isNotEmpty) {
              try {
                _selectedVisitDate = DateFormat('dd MMMM yyyy').parse(vDateStr);
              } catch (_) {
                try {
                  _selectedVisitDate = DateTime.tryParse(vDateStr);
                } catch (_) {}
              }
            }

            final vTimeStr = (ticketData['expectedVisitTime'] ?? '')
                .toString()
                .trim();
            if (vTimeStr.isNotEmpty) {
              _selectedVisitTime = _parseTimeOfDay(vTimeStr);
            }

            final notes = (ticketData['visitNotes'] ?? '').toString().trim();
            if (notes.isNotEmpty) {
              _visitNotesController.text = notes;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEngineers = false);
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim();
      final format = DateFormat('h:mm a');
      final dt = format.parse(clean);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      try {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0].trim());
          int minute = int.parse(parts[1].split(' ')[0].trim());
          if (timeStr.toLowerCase().contains('pm') && hour < 12) hour += 12;
          if (timeStr.toLowerCase().contains('am') && hour == 12) hour = 0;
          return TimeOfDay(hour: hour, minute: minute);
        }
      } catch (_) {}
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text(
          'Assign Engineer & Schedule Visit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: ResponsiveWrapper(
        maxWidth: 960,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Segmented Toggle Bar (Engineer vs Helper)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isEngineerSelected = true;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isEngineerSelected
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isEngineerSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.badge_rounded,
                                size: 18,
                                color: _isEngineerSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Assign & Schedule',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _isEngineerSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isEngineerSelected = false;
                            _selectedHelper = null;
                            _helperReasonController.clear();
                            addedHelpers.clear();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isEngineerSelected
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isEngineerSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_add_rounded,
                                size: 18,
                                color: !_isEngineerSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manage Helpers',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: !_isEngineerSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
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

              const SizedBox(height: 20),

              _isEngineerSelected ? _buildEngineerView() : _buildHelperView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerView() {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancelled Notice Banner
          if (_isTicketCancelled) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ticket is Cancelled',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This ticket was cancelled by administration ($_cancellationReason). It is in a terminal read-only state and cannot be assigned or scheduled.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB91C1C),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Header Customer Profile Avatar
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.customer.customerName.isNotEmpty
                          ? widget.customer.customerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.customer.customerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ticket ID: #${widget.customer.bookingId}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),

          // Customer details
          _buildDetailRow('Device Type', widget.customer.deviceType),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow('Device Brand', widget.customer.deviceBrand),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow('Condition', widget.customer.deviceCondition),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow(
            'Contact Number',
            widget.customer.mobileNumber.isNotEmpty
                ? widget.customer.mobileNumber
                : 'N/A',
          ),
          if (widget.customer.message.isNotEmpty) ...[
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildDetailRow('Issue Message', widget.customer.message),
          ],

          const SizedBox(height: 14),

          // Address Box
          if (widget.customer.address.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      const Text(
                        'SERVICE ADDRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.customer.address,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_isTicketCancelled) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0), thickness: 1.5),
            const SizedBox(height: 16),

            // Form Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_ind_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ENGINEER & VISIT SCHEDULING',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Primary Engineer (Mandatory)
            const Text(
              'Primary Engineer *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            _isLoadingEngineers
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedEngineer,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(
                        Icons.badge_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    hint: const Text('Select Primary Engineer (Mandatory)'),
                    items: _engineersList.map((engineer) {
                      final name = engineer['username'] as String;
                      final spec = engineer['specialization'] as String;
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(
                          spec.isNotEmpty ? '$name ($spec)' : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedEngineer = val;
                        if (val != null) {
                          final match = _engineersList.firstWhere(
                            (e) => e['username'] == val,
                            orElse: () => {},
                          );
                          _selectedEngineerId = match['id'] as String?;
                          _selectedEngineerPhone = match['phone'] as String?;
                          // If same as helper, clear helper
                          if (_selectedHelper != null &&
                              _selectedHelper == val) {
                            _selectedHelper = null;
                            _selectedHelperId = null;
                          }
                        } else {
                          _selectedEngineerId = null;
                          _selectedEngineerPhone = null;
                        }
                      });
                    },
                  ),

            const SizedBox(height: 16),

            // 2. Helper Engineer (Optional)
            const Text(
              'Helper Engineer (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedHelper,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              hint: const Text('None / Optional Helper'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'None / No Helper',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ..._engineersList
                    .where((e) => e['username'] != _selectedEngineer)
                    .map((engineer) {
                      final name = engineer['username'] as String;
                      final spec = engineer['specialization'] as String;
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(
                          spec.isNotEmpty ? '$name ($spec)' : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedHelper = val;
                  if (val != null) {
                    final match = _engineersList.firstWhere(
                      (e) => e['username'] == val,
                      orElse: () => {},
                    );
                    _selectedHelperId = match['id'] as String?;
                  } else {
                    _selectedHelperId = null;
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            // 3. Expected Visit Date & Time (Mandatory)
            Row(
              children: [
                // Date Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expected Visit Date *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _pickVisitDate(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedVisitDate != null
                                  ? primaryColor
                                  : const Color(0xFFE2E8F0),
                              width: _selectedVisitDate != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedVisitDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_selectedVisitDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedVisitDate != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedVisitDate != null
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Time Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expected Visit Time *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _pickVisitTime(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedVisitTime != null
                                  ? primaryColor
                                  : const Color(0xFFE2E8F0),
                              width: _selectedVisitTime != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedVisitTime != null
                                      ? _formatTimeOfDay(_selectedVisitTime!)
                                      : 'Select Time',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedVisitTime != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedVisitTime != null
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. Visit Notes (Optional)
            const Text(
              'Visit Notes (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _visitNotesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Customer requested morning service.',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Button: Review & Assign
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAssigning ? null : _handleReviewAndAssign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: _isAssigning
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.event_available_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                label: _isAssigning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Review & Confirm Assignment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickVisitDate(BuildContext context) async {
    final now = DateTime.now();
    final initial =
        _selectedVisitDate != null &&
            _selectedVisitDate!.isAfter(now.subtract(const Duration(days: 1)))
        ? _selectedVisitDate!
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select Expected Visit Date',
    );

    if (picked != null) {
      setState(() {
        _selectedVisitDate = picked;
      });
    }
  }

  Future<void> _pickVisitTime(BuildContext context) async {
    final initial = _selectedVisitTime ?? const TimeOfDay(hour: 10, minute: 30);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Select Expected Visit Time',
    );

    if (picked != null) {
      setState(() {
        _selectedVisitTime = picked;
      });
    }
  }

  void _handleReviewAndAssign() {
    if (_isTicketCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot assign or schedule a cancelled ticket.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEngineer == null || _selectedEngineer!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Primary Engineer.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedVisitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Expected Visit Date.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedVisitTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Expected Visit Time.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _showAssignmentReviewDialog();
  }

  void _showAssignmentReviewDialog() {
    final primaryColor = Theme.of(context).primaryColor;
    final dateStr = DateFormat('dd MMMM yyyy').format(_selectedVisitDate!);
    final timeStr = _formatTimeOfDay(_selectedVisitTime!);
    final notes = _visitNotesController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fact_check_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Review Assignment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please confirm the engineer assignment and customer visit schedule details below:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildReviewRow(
                      'Ticket ID',
                      '#${widget.customer.bookingId}',
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildReviewRow('Customer', widget.customer.customerName),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildReviewRow(
                      'Primary Engineer',
                      _selectedEngineer!,
                      isHighlight: true,
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildReviewRow(
                      'Helper Engineer',
                      _selectedHelper ?? 'None',
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildReviewRow('Expected Visit Date', dateStr),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildReviewRow('Expected Visit Time', timeStr),
                    if (notes.isNotEmpty) ...[
                      const Divider(color: Color(0xFFE2E8F0), height: 16),
                      _buildReviewRow('Visit Notes', notes),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmAssignmentAndSchedule();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm & Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight
                  ? const Color(0xFF0984E3)
                  : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAssignmentAndSchedule() async {
    setState(() => _isAssigning = true);
    try {
      final bookingId = widget.customer.bookingId;
      final assignedTimestamp = DateTime.now();
      final dateStr = DateFormat('dd MMMM yyyy').format(_selectedVisitDate!);
      final timeStr = _formatTimeOfDay(_selectedVisitTime!);
      final notes = _visitNotesController.text.trim();

      // Combined Timestamp in Asia/Kolkata timezone context
      final visitDateTime = DateTime(
        _selectedVisitDate!.year,
        _selectedVisitDate!.month,
        _selectedVisitDate!.day,
        _selectedVisitTime!.hour,
        _selectedVisitTime!.minute,
      );
      final expectedVisitAt = Timestamp.fromDate(visitDateTime);

      // Verify cancellation one more time against server
      final docRef = FirestoreService.instance
          .collection('Admin_ticket_entry')
          .doc(bookingId);
      final freshSnap = await docRef.get();
      final freshData = freshSnap.data() ?? {};

      final status = (freshData['status'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final adminStatus = (freshData['adminStatus'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (status == 'cancelled' ||
          status == 'canceled' ||
          adminStatus == 'cancelled' ||
          adminStatus == 'canceled') {
        throw Exception(
          'This ticket has been cancelled and cannot be assigned or scheduled.',
        );
      }

      final prevPrimary =
          (freshData['assignedEmployee'] ?? freshData['assignedEngineer'] ?? '')
              .toString()
              .trim();
      final prevHelper = (freshData['helperName'] ?? freshData['helper'] ?? '')
          .toString()
          .trim();
      final prevDate = (freshData['expectedVisitDate'] ?? '').toString().trim();
      final prevTime = (freshData['expectedVisitTime'] ?? '').toString().trim();

      final bool isPrimaryReassigned =
          prevPrimary.isNotEmpty &&
          prevPrimary.toLowerCase() !=
              _selectedEngineer!.trim().toLowerCase() &&
          prevPrimary.toLowerCase() != 'not assigned';

      final bool isRescheduled =
          prevDate.isNotEmpty && (prevDate != dateStr || prevTime != timeStr);

      final primaryName = _selectedEngineer!.trim();
      final helperName =
          (_selectedHelper != null && _selectedHelper!.trim().isNotEmpty)
          ? _selectedHelper!.trim()
          : '';

      final assignedUsers = <String>{primaryName};
      if (helperName.isNotEmpty) {
        assignedUsers.add(helperName);
      }

      final updateData = {
        'id': widget.customer.customerid,
        'customerId': widget.customer.customerid,
        'customerName': widget.customer.customerName,
        'bookingId': bookingId,
        'ticketId': bookingId,
        'deviceType': widget.customer.deviceType,
        'deviceBrand': widget.customer.deviceBrand,
        'deviceCondition': widget.customer.deviceCondition,
        'message': widget.customer.message,
        'address': widget.customer.address,
        'mobileNumber': widget.customer.mobileNumber,
        'adminStatus': 'Assigned',
        'engineerStatus': 'Assigned',
        'assignedEmployee': primaryName,
        'assignedEngineer': primaryName,
        'assignedEngineerId': _selectedEngineerId ?? primaryName,
        'assignedEngineerPhone': _selectedEngineerPhone ?? '',
        'expectedVisitDate': dateStr,
        'expectedVisitTime': timeStr,
        'expectedVisitAt': expectedVisitAt,
        'visitNotes': notes,
        'assignedAt': FieldValue.serverTimestamp(),
        'AssignedTimestamp': assignedTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
        'assignedUsers': assignedUsers.toList(),
        'assignmentNotificationStatus': {
          'lastNotifiedPrimary': primaryName,
          'lastNotifiedHelper': helperName,
          'lastNotifiedVisitDate': dateStr,
          'lastNotifiedVisitTime': timeStr,
          'lastNotifiedAt': FieldValue.serverTimestamp(),
        },
      };

      if (helperName.isNotEmpty) {
        updateData['helper'] = helperName;
        updateData['helperName'] = helperName;
        updateData['helperId'] = _selectedHelperId ?? helperName;
        updateData['Helper1'] = helperName;
        updateData['helpers'] = [helperName];
      } else {
        updateData['helper'] = '';
        updateData['helperName'] = '';
        updateData['helperId'] = '';
        updateData['Helper1'] = '';
        updateData['helpers'] = [];
      }

      // Save to Admin_ticket_entry
      await docRef.set(updateData, SetOptions(merge: true));

      // Save to Raised_tickets
      try {
        await FirestoreService.instance
            .collection('Raised_tickets')
            .doc(bookingId)
            .set(updateData, SetOptions(merge: true));
      } catch (_) {}

      // 1. Dispatch Customer Notification
      final customerTitle = isRescheduled
          ? 'Service Visit Rescheduled'
          : 'Engineer Assigned – Service Visit Scheduled';
      final customerBody = isRescheduled
          ? 'Your service visit for ticket $bookingId has been rescheduled to $dateStr at $timeStr.'
          : 'Your ticket $bookingId has been assigned to Engineer $primaryName. Expected visit: $dateStr at $timeStr.';

      await NotificationService.sendNotificationToFirestore(
        audience: 'customer',
        customerId: widget.customer.customerid,
        bookingId: bookingId,
        title: customerTitle,
        body: customerBody,
        type: isRescheduled ? 'visit_rescheduled' : 'visit_scheduled',
        customerName: widget.customer.customerName,
        engineerName: primaryName,
        additionalData: {
          'expectedVisitDate': dateStr,
          'expectedVisitTime': timeStr,
          'visitNotes': notes,
          'primaryEngineer': primaryName,
          'primaryEngineerPhone': _selectedEngineerPhone ?? '',
          'helperEngineer': helperName,
        },
      );

      // 2. Dispatch Primary Engineer Notification
      final primaryTitle = isRescheduled
          ? 'Service Visit Rescheduled'
          : 'New Service Ticket Assigned';
      final primaryBody =
          'Ticket $bookingId has been assigned to you. Expected customer visit: $dateStr at $timeStr.';

      await NotificationService.sendNotificationToFirestore(
        audience: 'engineer',
        engineerName: primaryName,
        bookingId: bookingId,
        title: primaryTitle,
        body: primaryBody,
        type: 'new_assignment',
        customerId: widget.customer.customerid,
        customerName: widget.customer.customerName,
        additionalData: {
          'processed': false,
          'status': 'pending',
          'expectedVisitDate': dateStr,
          'expectedVisitTime': timeStr,
          'visitNotes': notes,
        },
      );

      // 3. Dispatch Helper Engineer Notification (if assigned)
      if (helperName.isNotEmpty) {
        final helperTitle = isRescheduled
            ? 'Helper Visit Rescheduled'
            : 'New Helper Assignment';
        final helperBody =
            'You have been assigned as a helper for ticket $bookingId. Expected customer visit: $dateStr at $timeStr. Primary Engineer: $primaryName.';

        await NotificationService.sendNotificationToFirestore(
          audience: 'engineer',
          engineerName: helperName,
          bookingId: bookingId,
          title: helperTitle,
          body: helperBody,
          type: 'new_assignment',
          customerId: widget.customer.customerid,
          customerName: widget.customer.customerName,
          additionalData: {
            'processed': false,
            'status': 'pending',
            'role': 'helper',
            'isHelper': true,
            'expectedVisitDate': dateStr,
            'expectedVisitTime': timeStr,
            'visitNotes': notes,
            'primaryEngineer': primaryName,
          },
        );
      }

      // 4. Notify previous engineer if re-assigned
      if (isPrimaryReassigned) {
        await NotificationService.sendNotificationToFirestore(
          audience: 'engineer',
          engineerName: prevPrimary,
          bookingId: bookingId,
          title: 'Ticket Reassigned',
          body:
              'Ticket $bookingId has been reassigned to another engineer ($primaryName).',
          type: 'ticket_reassigned',
          customerId: widget.customer.customerid,
          customerName: widget.customer.customerName,
        );
      }

      if (mounted) {
        setState(() => _isAssigning = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              customerName: widget.customer.customerName,
              employeeName: primaryName,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning engineer: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHelperView() {
    final primaryColor = Theme.of(context).primaryColor;

    return FutureBuilder<DocumentSnapshot>(
      future: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .doc(widget.customer.bookingId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final assignedEmployee = data['assignedEmployee'] as String? ?? '';
        final vDate = (data['expectedVisitDate'] ?? '').toString();
        final vTime = (data['expectedVisitTime'] ?? '').toString();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              assignedEmployee.isNotEmpty
                  ? _buildDetailRow(
                      'Assigned Engineer',
                      assignedEmployee,
                      isHighlight: true,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Device Brand',
                          widget.customer.deviceBrand,
                        ),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow(
                          'Condition',
                          widget.customer.deviceCondition,
                        ),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow(
                          'Device Type',
                          widget.customer.deviceType,
                        ),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow('Message', widget.customer.message),
                      ],
                    ),
              if (vDate.isNotEmpty && vTime.isNotEmpty) ...[
                const Divider(color: Color(0xFFF1F5F9), height: 16),
                _buildDetailRow(
                  'Scheduled Visit',
                  '$vDate at $vTime',
                  isHighlight: true,
                ),
              ],

              const SizedBox(height: 20),
              const Text(
                'Select Additional Helper',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.instance
                    .collection('EngineerLogin')
                    .snapshots(),
                builder: (context, engineerSnapshot) {
                  if (engineerSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (engineerSnapshot.hasError) {
                    return Text('Error: ${engineerSnapshot.error}');
                  }
                  final engineerDocs = engineerSnapshot.data?.docs ?? [];
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    initialValue: _selectedHelper,
                    hint: const Text('Choose a Helper'),
                    items: engineerDocs.map((doc) {
                      final data = doc.data();
                      if (data is Map<String, dynamic>) {
                        final username = (data['Username'] ?? '').toString();
                        return DropdownMenuItem<String>(
                          value: username,
                          child: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      return const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Unknown'),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedHelper = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _helperReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Helper',
                  alignLabelWithHint: true,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if ((_selectedHelper != null &&
                            _selectedHelper!.isNotEmpty) &&
                        _helperReasonController.text.trim().isNotEmpty) {
                      setState(() {
                        addedHelpers.add({
                          'helperName': _selectedHelper!,
                          'reason': _helperReasonController.text.trim(),
                        });
                        _selectedHelper = null;
                        _helperReasonController.clear();
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select a helper and enter a reason',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0984E3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Add Helper to List',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...addedHelpers.map((helper) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.group_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              helper['helperName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reason: ${helper['reason']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            addedHelpers.remove(helper);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              if (addedHelpers.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final docRef = FirestoreService.instance
                            .collection('Admin_ticket_entry')
                            .doc(widget.customer.bookingId);
                        final snapshot = await docRef.get();

                        final existingData = snapshot.data() ?? {};

                        int maxIndex = 0;
                        existingData.forEach((key, value) {
                          final match = RegExp(
                            r'^Helper(\d+)$',
                          ).firstMatch(key);
                          if (match != null) {
                            final index =
                                int.tryParse(match.group(1) ?? '') ?? 0;
                            if (index > maxIndex) maxIndex = index;
                          }
                        });

                        Map<String, dynamic> fieldsToUpdate = {};

                        final existingHelpers = <String>{};
                        if (existingData['helpers'] is List) {
                          existingHelpers.addAll(
                            (existingData['helpers'] as List).map(
                              (e) => e.toString().trim(),
                            ),
                          );
                        }
                        if (existingData['helperName'] != null &&
                            existingData['helperName']
                                .toString()
                                .trim()
                                .isNotEmpty) {
                          existingHelpers.add(
                            existingData['helperName'].toString().trim(),
                          );
                        }

                        for (int i = 0; i < addedHelpers.length; i++) {
                          final index = maxIndex + i + 1;
                          final hName = (addedHelpers[i]['helperName'] ?? '')
                              .trim();
                          final hReason = (addedHelpers[i]['reason'] ?? '')
                              .trim();
                          fieldsToUpdate['Helper$index'] = hName;
                          fieldsToUpdate['Helper${index}_Reason'] = hReason;
                          if (hName.isNotEmpty) {
                            existingHelpers.add(hName);
                          }
                        }

                        if (addedHelpers.isNotEmpty) {
                          final firstHelper = addedHelpers.first;
                          if ((existingData['helperName'] ?? '')
                              .toString()
                              .trim()
                              .isEmpty) {
                            fieldsToUpdate['helper'] =
                                firstHelper['helperName'] ?? '';
                            fieldsToUpdate['helperName'] =
                                firstHelper['helperName'] ?? '';
                            fieldsToUpdate['helperReason'] =
                                firstHelper['reason'] ?? '';
                          }
                          fieldsToUpdate['helpers'] = existingHelpers.toList();

                          final assignedUsers = <String>{
                            if ((existingData['assignedEmployee'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              existingData['assignedEmployee']
                                  .toString()
                                  .trim(),
                            if ((existingData['assignedEngineer'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              existingData['assignedEngineer']
                                  .toString()
                                  .trim(),
                            ...existingHelpers,
                          }.toList();
                          fieldsToUpdate['assignedUsers'] = assignedUsers;
                        }

                        await docRef.set(
                          fieldsToUpdate,
                          SetOptions(merge: true),
                        );

                        try {
                          await FirestoreService.instance
                              .collection('Raised_tickets')
                              .doc(widget.customer.bookingId)
                              .set(fieldsToUpdate, SetOptions(merge: true));
                        } catch (_) {}

                        // Send helper assignment notification
                        final scheduledVisitText =
                            (vDate.isNotEmpty && vTime.isNotEmpty)
                            ? ' Expected customer visit: $vDate at $vTime.'
                            : '';

                        for (final helper in addedHelpers) {
                          final hName = (helper['helperName'] ?? '').trim();
                          if (hName.isNotEmpty) {
                            await NotificationService.sendNotificationToFirestore(
                              audience: 'engineer',
                              engineerName: hName,
                              type: 'new_assignment',
                              bookingId: widget.customer.bookingId,
                              body:
                                  'You have been assigned as a helper for ticket ${widget.customer.bookingId}.$scheduledVisitText Primary Engineer: $assignedEmployee.',
                              customerName: widget.customer.customerName,
                              customerId: widget.customer.customerid,
                              additionalData: {
                                'processed': false,
                                'status': 'pending',
                                'role': 'helper',
                                'isHelper': true,
                                'helperReason': helper['reason'] ?? '',
                                'expectedVisitDate': vDate,
                                'expectedVisitTime': vTime,
                                'primaryEngineer': assignedEmployee,
                              },
                              title: 'New Helper Assignment',
                            );
                          }
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Helpers added successfully'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );

                        setState(() {
                          addedHelpers.clear();
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving helpers: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Submit Helpers',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
                  ? Theme.of(context).primaryColor
                  : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
