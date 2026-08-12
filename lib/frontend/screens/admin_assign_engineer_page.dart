import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
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
  String? _selectedHelper;
  final TextEditingController _reasonController = TextEditingController();

  List<Map<String, String>> addedHelpers = [];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assign Engineers & Helpers',
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
      body: SingleChildScrollView(
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
                          _selectedHelper = null;
                          _reasonController.clear();
                          addedHelpers.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isEngineerSelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isEngineerSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.25),
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
                              color: _isEngineerSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Engineer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _isEngineerSelected ? Colors.white : const Color(0xFF64748B),
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
                          _reasonController.clear();
                          addedHelpers.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isEngineerSelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_isEngineerSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.25),
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
                              color: !_isEngineerSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Helper',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: !_isEngineerSelected ? Colors.white : const Color(0xFF64748B),
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
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Booking ID: #${widget.customer.bookingId}',
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

          // 2-Column Grid Alignment details
          _buildDetailRow('Device Type', widget.customer.deviceType),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow('Device Brand', widget.customer.deviceBrand),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow('Condition', widget.customer.deviceCondition),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          _buildDetailRow('Contact Number', widget.customer.mobileNumber.isNotEmpty ? widget.customer.mobileNumber : 'N/A'),
          if (widget.customer.message.isNotEmpty) ...[
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            _buildDetailRow('Issue Message', widget.customer.message),
          ],

          const SizedBox(height: 14),

          // Full Address Box
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
                        'FULL ADDRESS',
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

          const SizedBox(height: 24),

          // Assign Engineer Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAssigning ? null : () => _showEmployeeSelection(context),
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
                  : const Icon(Icons.person_add_rounded, size: 20, color: Colors.white),
              label: _isAssigning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Assign Engineer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
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
          return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final assignedEmployee = data['assignedEmployee'] as String? ?? '';

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
                  ? _buildDetailRow('Assigned Engineer', assignedEmployee, isHighlight: true)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Device Brand', widget.customer.deviceBrand),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow('Condition', widget.customer.deviceCondition),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow('Device Type', widget.customer.deviceType),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildDetailRow('Message', widget.customer.message),
                      ],
                    ),

              const SizedBox(height: 20),
              const Text(
                'Select Helper',
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
                  if (engineerSnapshot.connectionState == ConnectionState.waiting) {
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        final username = data['Username'] ?? '';
                        return DropdownMenuItem<String>(
                          value: username,
                          child: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                controller: _reasonController,
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
                    if ((_selectedHelper != null && _selectedHelper!.isNotEmpty) &&
                        _reasonController.text.trim().isNotEmpty) {
                      setState(() {
                        addedHelpers.add({
                          'helperName': _selectedHelper!,
                          'reason': _reasonController.text.trim(),
                        });
                        _selectedHelper = null;
                        _reasonController.clear();
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a helper and enter a reason'),
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
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
                        child: Icon(Icons.group_rounded, color: primaryColor, size: 18),
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
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
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
                          final match = RegExp(r'^Helper(\d+)$').firstMatch(key);
                          if (match != null) {
                            final index = int.tryParse(match.group(1) ?? '') ?? 0;
                            if (index > maxIndex) maxIndex = index;
                          }
                        });

                        Map<String, dynamic> fieldsToUpdate = {};

                        for (int i = 0; i < addedHelpers.length; i++) {
                          final index = maxIndex + i + 1;
                          fieldsToUpdate['Helper$index'] = addedHelpers[i]['helperName'] ?? '';
                          fieldsToUpdate['Helper${index}_Reason'] = addedHelpers[i]['reason'] ?? '';
                        }

                        await docRef.set(fieldsToUpdate, SetOptions(merge: true));

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
                          SnackBar(content: Text('Error saving helpers: $e'), backgroundColor: Colors.red),
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

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
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
              color: isHighlight ? Theme.of(context).primaryColor : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showEmployeeSelection(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.badge_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Engineer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: FutureBuilder<QuerySnapshot>(
                  future: FirestoreService.instance.collection('EngineerLogin').get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No engineers found.'));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        if (data is Map<String, dynamic>) {
                          final username = data['Username'] ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () async {
                              Navigator.pop(context);
                              await _assignEngineerToCustomer(username);
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignEngineerToCustomer(String engineerName) async {
    setState(() => _isAssigning = true);
    try {
      final assignedTimestamp = DateTime.now();

      await FirestoreService.instance
          .collection('Admin_ticket_entry')
          .doc(widget.customer.bookingId)
          .set({
        'id': widget.customer.customerid,
        'assignedEmployee': engineerName.trim(),
        'customerName': widget.customer.customerName,
        'bookingId': widget.customer.bookingId,
        'deviceType': widget.customer.deviceType,
        'deviceBrand': widget.customer.deviceBrand,
        'deviceCondition': widget.customer.deviceCondition,
        'message': widget.customer.message,
        'address': widget.customer.address,
        'notificationStatus': 'pending',
        'engineerStatus': 'Assigned',
        'timestamp': FieldValue.serverTimestamp(),
        'AssignedTimestamp': assignedTimestamp,
        'mobileNumber': widget.customer.mobileNumber,
      }, SetOptions(merge: true));

      await NotificationService.sendNotificationToFirestore(
        audience: 'engineer',
        engineerName: engineerName,
        type: 'new_assignment',
        bookingId: widget.customer.bookingId,
        body: 'You have been assigned a new task: ${widget.customer.bookingId}',
        customerName: widget.customer.customerName,
        additionalData: {'processed': false, 'status': 'pending'},
        title: 'New Task Assigned',
      );

      if (mounted) {
        setState(() => _isAssigning = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              customerName: widget.customer.customerName,
              employeeName: engineerName,
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
}
