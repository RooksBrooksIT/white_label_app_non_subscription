import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class AssigndeliveryCustomerPage extends StatefulWidget {
  final Customer customer;

  const AssigndeliveryCustomerPage({super.key, required this.customer});

  @override
  _AssigndeliveryCustomerPageState createState() =>
      _AssigndeliveryCustomerPageState();
}

class _AssigndeliveryCustomerPageState
    extends State<AssigndeliveryCustomerPage> {
  bool _isAssigning = false;
  bool _isEngineerSelected = true;
  String? _selectedHelper;
  final TextEditingController _reasonController = TextEditingController();
  final bool _showHelperInputs = false;

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
        title: Text(
          'Assign Delivery Engineer',
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
      body: ResponsiveWrapper(
        maxWidth: kMaxContentWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isEngineerSelected = true;
                            _selectedHelper = null;
                            _reasonController.clear();
                            addedHelpers.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isEngineerSelected
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isEngineerSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Lead Engineer',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: _isEngineerSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _isEngineerSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isEngineerSelected = false;
                            _selectedHelper = null;
                            _reasonController.clear();
                            addedHelpers.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isEngineerSelected
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isEngineerSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Helper Staff',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: !_isEngineerSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !_isEngineerSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildTicketSummaryCard(primaryColor),
              const SizedBox(height: 24),
              _isEngineerSelected
                  ? _buildEngineerView(primaryColor)
                  : _buildHelperView(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketSummaryCard(Color primaryColor) {
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
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    widget.customer.customerName.isNotEmpty
                        ? widget.customer.customerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.customerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ticket #${widget.customer.ticketId}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _detailRow('Device Brand', widget.customer.deviceBrand),
          _detailRow('Device Condition', widget.customer.deviceCondition),
          _detailRow('Device Type', widget.customer.deviceType),
          if (widget.customer.issueDescription.isNotEmpty)
            _detailRow('Message', widget.customer.issueDescription),
          if (widget.customer.address.isNotEmpty)
            _detailRow('Address', widget.customer.address),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerView(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Engineer to Assign',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadAvailableDeliveryEngineers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final employees = snapshot.data ?? <Map<String, dynamic>>[];
            if (employees.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'No delivery engineers available',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                final name = (emp['name'] ?? emp['username'] ?? 'Unknown')
                    .toString();
                final phone = (emp['phone'] ?? emp['mobileNumber'] ?? '')
                    .toString();
                final email = (emp['email'] ?? '').toString();
                final specialization = (emp['specialization'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (specialization.isNotEmpty)
                              Text(
                                specialization,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            if (phone.isEmpty && email.isNotEmpty)
                              Text(
                                email,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isAssigning
                            ? null
                            : () => _assignEngineerToCustomer(name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Assign',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadAvailableDeliveryEngineers() async {
    final Set<String> seen = {};
    final List<Map<String, dynamic>> result = [];

    Future<void> pushDoc(Map<String, dynamic> raw, String source) async {
      final name =
          (raw['name'] ??
                  raw['username'] ??
                  raw['Username'] ??
                  raw['Name'] ??
                  '')
              .toString()
              .trim();
      if (name.isEmpty) return;
      final key = name.toLowerCase();
      if (!seen.add(key)) return;
      result.add({
        'name': name,
        'phone': (raw['phone'] ?? raw['Phone'] ?? raw['mobileNumber'] ?? '')
            .toString(),
        'email': (raw['email'] ?? raw['Email'] ?? '').toString(),
        'specialization':
            (raw['specialization'] ??
                    raw['Specialization'] ??
                    (source == 'EngineerLogin'
                        ? 'Service Engineer'
                        : 'Delivery Staff') ??
                    '')
                .toString(),
        'source': source,
      });
    }

    try {
      final primary = await FirestoreService.instance
          .collection('EngineerLogin')
          .orderBy('Username')
          .get();
      for (final d in primary.docs) {
        await pushDoc(d.data() as Map<String, dynamic>, 'EngineerLogin');
      }
    } catch (_) {}

    try {
      final legacy = await FirestoreService.instance
          .collection('delivery_employees')
          .get();
      for (final d in legacy.docs) {
        await pushDoc(d.data() as Map<String, dynamic>, 'delivery_employees');
      }
    } catch (_) {}

    result.sort((a, b) => a['name'].compareTo(b['name']));
    return result;
  }

  Widget _buildHelperView(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Helper to Delivery',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Helper Name or Reason',
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
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_reasonController.text.isNotEmpty) {
                  _assignEngineerToCustomer(_reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Assign Helper',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignEngineerToCustomer(String engineerName) async {
    setState(() => _isAssigning = true);
    try {
      final bookingId = widget.customer.ticketId;
      final cJobType =
          (widget.customer.jobType ?? 'Delivery').toString().trim().isEmpty
          ? 'Delivery'
          : widget.customer.jobType;
      final cId = widget.customer.customerid;
      final cName = widget.customer.customerName;
      final cMobile = widget.customer.mobileNumber;
      final cAddress = widget.customer.address;
      final cDeviceType = widget.customer.deviceType;
      final cDeviceBrand = widget.customer.deviceBrand;
      final cDeviceCondition = widget.customer.deviceCondition;
      final cMessage = widget.customer.issueDescription;
      final rawAmount = widget.customer.amount?.toString().trim() ?? '';
      final amountDouble = double.tryParse(rawAmount) ?? 0.0;
      final paymentDetailsStr = rawAmount.isEmpty ? '' : rawAmount;

      final Map<String, dynamic> payload = {
        'id': cId,
        'customerid': cId,
        'assignedEmployee': engineerName,
        'assignedEngineer': engineerName,
        'customerName': cName,
        'bookingId': bookingId,
        'ticketId': bookingId,
        'deviceType': cDeviceType,
        'deviceBrand': cDeviceBrand,
        'deviceCondition': cDeviceCondition,
        'message': cMessage,
        'description': cMessage,
        'address': cAddress,
        'notificationStatus': 'pending',
        'engineerStatus': 'Assigned',
        'adminStatus': 'Assigned',
        'customerStatus': 'Engineer Assigned',
        'JobType': cJobType,
        'jobType': cJobType,
        'categoryName': 'Delivery',
        'timestamp': FieldValue.serverTimestamp(),
        'assignedTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'mobileNumber': cMobile,
        'customerType': widget.customer.customerType,
        'DeviceName': widget.customer.deviceName,
        'Problem': widget.customer.problem,
        'customerFileUrl': widget.customer.customerFileUrl,
        'fileName': widget.customer.fileName,
        'amount': amountDouble,
        'paymentDetails': paymentDetailsStr,
      };

      await FirestoreService.instance
          .collection('Admin_details')
          .doc(bookingId)
          .set(payload, SetOptions(merge: true));

      try {
        await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .doc(bookingId)
            .set(payload, SetOptions(merge: true));
      } catch (_) {
        final found = await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .where(
              Filter.or(
                Filter('bookingId', isEqualTo: bookingId),
                Filter('ticketId', isEqualTo: bookingId),
              ),
            )
            .limit(1)
            .get();
        if (found.docs.isNotEmpty) {
          await found.docs.first.reference.set(
            payload,
            SetOptions(merge: true),
          );
        }
      }

      try {
        final raisedQuery = Filter.or(
          Filter('bookingId', isEqualTo: bookingId),
          Filter('ticketId', isEqualTo: bookingId),
        );
        final raisedMatch = await FirestoreService.instance
            .collection('Raised_tickets')
            .where(raisedQuery)
            .limit(1)
            .get();
        if (raisedMatch.docs.isNotEmpty) {
          await raisedMatch.docs.first.reference.set(
            payload,
            SetOptions(merge: true),
          );
        } else {
          final byCustomer =
              (cId?.toString().trim().isNotEmpty ?? false) ||
              cName.toString().trim().isNotEmpty;
          if (byCustomer) {
            final cIdStr = (cId ?? '').toString().trim();
            final cNameLower = cName.toString().trim().toLowerCase();
            final allRaised = await FirestoreService.instance
                .collection('Raised_tickets')
                .limit(200)
                .get();
            for (final d in allRaised.docs) {
              final m = d.data() as Map<String, dynamic>;
              final docId =
                  (m['customerid'] ?? m['id'] ?? m['customerId'] ?? '')
                      .toString()
                      .trim();
              final docName = (m['customerName'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final docTicket = (m['ticketId'] ?? m['bookingId'] ?? '')
                  .toString()
                  .trim();
              final match =
                  (cIdStr.isNotEmpty && docId == cIdStr) ||
                  (cNameLower.isNotEmpty && docName == cNameLower);
              if (match && (docTicket.isEmpty || docTicket == bookingId)) {
                await d.reference.set(payload, SetOptions(merge: true));
                break;
              }
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationdeliveryPage(
              customerName: widget.customer.customerName,
              employeeName: engineerName,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign engineer: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }
}

class ConfirmationdeliveryPage extends StatelessWidget {
  final String customerName;
  final String employeeName;

  const ConfirmationdeliveryPage({
    super.key,
    required this.customerName,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Assignment Confirmation',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Engineer Assigned!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$employeeName has been assigned for delivery to $customerName.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminDeliveryTickets(statusFilter: ''),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Back to Delivery Tickets',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
