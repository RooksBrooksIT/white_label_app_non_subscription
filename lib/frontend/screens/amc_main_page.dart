import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_createtickets_devicetype.dart';
import 'package:flutter/services.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AMCTrackMyService extends StatefulWidget {
  final String customerName;
  final String customerId;
  const AMCTrackMyService({
    super.key,
    required this.customerName,
    required this.customerId,
  });

  @override
  State<AMCTrackMyService> createState() => _AMCTrackMyServiceState();
}

class _AMCTrackMyServiceState extends State<AMCTrackMyService> {
  // Banner state
  bool showBanner = false;
  String bannerMessage = '';
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      NotificationService.instance.registerToken(
        role: 'customer',
        userId: widget.customerId,
        email: user.email ?? '',
      );
    }
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = FirestoreService.instance
        .collection('notifications')
        .where('customerId', isEqualTo: widget.customerId)
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Update';
              final body = data['body'] ?? 'Your ticket has been updated.';

              if (mounted) {
                setState(() {
                  showBanner = true;
                  bannerMessage = body;
                });

                // Show a local push notification for immediate feedback
                NotificationService.instance.showNotification(
                  title: title,
                  body: body,
                );

                // Mark notification as seen so it doesn't trigger again
                change.doc.reference.update({'seen': true});
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 224, 224),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        ),
        title: Text(
          ThemeService.instance.appName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.notifications_none_rounded),
        //     tooltip: 'Test Notification',
        //     onPressed: () {
        //       NotificationService.instance.showNotification(
        //         title: 'Test Notification',
        //         body:
        //             'This is a test notification from the customer dashboard.',
        //       );
        //     },
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeaderDecoration(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.instance
                      .collection('Admin_details')
                      .where('id', isEqualTo: widget.customerId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Lottie.asset(
                          'assets/loading_animation.json',
                          width: 100,
                          repeat: true,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }
                    final tickets = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 32,
                      ),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final data = tickets[index].data();
                        final documentId = tickets[index].id;
                        return _buildProfessionalTicketCard(data, documentId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (showBanner) _buildFloatingBanner(),
        ],
      ),
    );
  }

  Widget _buildHeaderDecoration() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    );
  }

  Widget _buildFloatingBanner() {
    return Positioned(
      top: 20,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 400),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * -20),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => setState(() => showBanner = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Please try again later',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/empty_box.json', height: 200, repeat: true),
          const SizedBox(height: 24),
          const Text(
            'No Active Tickets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your service requests will appear here',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTicketCard(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final bookingId = data['bookingId'] ?? 'N/A';
    final customerId = data['id'] ?? 'Not Assigned';
    final jobType = data['JobType'] ?? 'N/A';
    final deviceBrand = data['deviceBrand'] ?? 'N/A';
    final amount = data['amount']?.toString() ?? '0';
    final timestamp = data['timestamp'] as Timestamp?;
    final rawStatus = data['engineerStatus'] ?? '';
    final adminStatus = data['adminStatus']?.toString().toLowerCase() ?? '';
    final isCanceled = adminStatus == 'canceled' || adminStatus == 'cancelled';
    final statusInfo = _mapEngineerStatus(rawStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ID: $bookingId",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Job: $jobType • ID: $customerId",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(
                  isCanceled ? 'CANCELED' : statusInfo.label.toUpperCase(),
                  isCanceled ? Colors.red : statusInfo.color,
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Color(0xFFF1F5F9),
          ),

          // Progress Tracker
          if (!isCanceled) _buildStatusTracker(rawStatus),

          // Main Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.devices_rounded,
                      "Device",
                      deviceBrand,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoItem(
                      Icons.calendar_today_rounded,
                      "Date",
                      _formatTimestamp(timestamp),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailSection(data, isCanceled),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ESTIMATED BILL",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      "₹$amount",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isCanceled
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                if (!isCanceled &&
                    statusInfo.label == 'Completed' &&
                    (data['FeedBack'] ?? '').isEmpty)
                  _buildActionIndicator(
                    "Rate Service",
                    Icons.star_border_rounded,
                    () {
                      showDialog(
                        context: context,
                        builder: (ctx) => FeedbackDialog(
                          bookingId: bookingId.toString(),
                          documentId: documentId,
                        ),
                      );
                    },
                  )
                else if (!isCanceled &&
                    statusInfo.label != 'Completed' &&
                    statusInfo.label != 'In Progress')
                  _buildActionIndicator("Cancel", Icons.close_rounded, () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CancelTicketDialog(
                        bookingId: bookingId.toString(),
                        documentId: documentId,
                      ),
                    );
                  }, isDanger: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusTracker(String currentStatus) {
    final status = currentStatus.toLowerCase().trim();
    int currentStep = 0;
    if (status == 'assigned') {
      currentStep = 1;
    } else if (status == 'in progress')
      currentStep = 2;
    else if (status == 'completed')
      currentStep = 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Row(
        children: [
          _buildStep(0, "Raised", currentStep >= 0),
          _buildStepLine(currentStep >= 1),
          _buildStep(1, "Assigned", currentStep >= 1),
          _buildStepLine(currentStep >= 2),
          _buildStep(2, "Repairing", currentStep >= 2),
          _buildStepLine(currentStep >= 3),
          _buildStep(3, "Done", currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).primaryColor
                  : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: isActive
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive
          ? Theme.of(context).primaryColor
          : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(Map<String, dynamic> data, bool isCanceled) {
    final condition = data['deviceCondition'] ?? 'N/A';
    final desc = data['description'] ?? '';
    final feedback = data['FeedBack'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (condition != 'N/A') ...[
          const Text(
            "ISSUE REPORTED",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            condition,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ],
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "ENGINEER NOTES",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.1)),
            ),
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
        if (feedback.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildStatusBadge("FEEDBACK: $feedback", Colors.blueGrey),
        ],
        if (isCanceled && data['Reason_cancel'] != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Reason: ${data['Reason_cancel']}",
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionIndicator(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDanger
                ? Colors.red.withOpacity(0.05)
                : Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDanger
                  ? Colors.red.withOpacity(0.1)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDanger ? Colors.red : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDanger ? Colors.red : Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusInfo _mapEngineerStatus(String status) {
    final lowerStatus = status.toLowerCase().trim();
    switch (lowerStatus) {
      case 'complete':
      case 'completed':
        return _StatusInfo('Completed', Colors.green.shade600);
      case 'assigned':
        return _StatusInfo('Assigned', Colors.green.shade600);
      case 'in progress':
        return _StatusInfo('In Progress', Colors.blue.shade600);
      case 'pending':
        return _StatusInfo('Pending', Colors.orange.shade700);
      case 'not assigned':
        return _StatusInfo('Not Assigned', Colors.red.shade700);
      case 'cancelled':
      case 'canceled':
        return _StatusInfo('Cancelled', Colors.grey.shade600);
      default:
        // Check for specific substrings if exact match fails
        if (lowerStatus.contains('approval')) {
          return _StatusInfo('Pending Approval', Colors.purple.shade600);
        }
        if (lowerStatus.contains('spare')) {
          return _StatusInfo('Pending Spares', Colors.amber.shade700);
        }
        if (lowerStatus.contains('observation')) {
          return _StatusInfo('Observation', Colors.cyan.shade600);
        }

        // Capitalize first letter if it's unknown
        String formatted = status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1)
            : 'Unknown';
        return _StatusInfo(formatted, Colors.grey.shade500);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo(this.label, this.color);
}

class CancelTicketDialog extends StatefulWidget {
  final String bookingId;
  final String documentId;

  const CancelTicketDialog({
    super.key,
    required this.bookingId,
    required this.documentId,
  });

  @override
  State<CancelTicketDialog> createState() => _CancelTicketDialogState();
}

class _CancelTicketDialogState extends State<CancelTicketDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _cancelTicket(BuildContext context) async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter reason for cancellation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.documentId)
          .update({
            'Reason_cancel': _reasonController.text.trim(),
            'adminStatus': 'Canceled',
            'engineerStatus': 'Cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

      // Close the dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancellation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 24,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Cancel Booking",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "#${widget.bookingId}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please let us know the reason for cancellation to help us improve.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter reason here...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _reasonController.text.trim().isEmpty || _isSubmitting
                        ? null
                        : () => _cancelTicket(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.red.withOpacity(0.3),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirm Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackDialog extends StatelessWidget {
  final String bookingId;
  final String documentId;

  const FeedbackDialog({
    super.key,
    required this.bookingId,
    required this.documentId,
  });

  Future<void> _submitFeedback(BuildContext context, String feedback) async {
    try {
      await FirestoreService.instance
          .collection('Admin_details')
          .doc(documentId)
          .update({'FeedBack': feedback});

      // Close the feedback dialog
      Navigator.of(context).pop();

      // Show confirmation dialog based on feedback type
      _showConfirmationDialog(context, feedback);
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(BuildContext context, String feedback) {
    String message;
    IconData icon;
    Color color;

    switch (feedback) {
      case "Good":
        message =
            "Thank you for your positive feedback! We're thrilled to hear you had a great experience.";
        icon = Icons.star_rounded;
        color = Colors.green;
        break;
      case "Ok":
        message =
            "Thank you for your feedback. We appreciate your input and will work to improve our service.";
        icon = Icons.sentiment_satisfied_rounded;
        color = Colors.orange;
        break;
      case "Not Satisfied":
        message =
            "We sincerely apologize. Our team will contact you shortly to address your concerns.";
        icon = Icons.sentiment_very_dissatisfied_rounded;
        color = Colors.red;
        break;
      default:
        message = "Thank you for your feedback!";
        icon = Icons.thumb_up_rounded;
        color = Colors.blue;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 24,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: color),
                ),
                const SizedBox(height: 24),
                Text(
                  "Received!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 24,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "How was your experience?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Booking #$bookingId",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),

            // Horizontal row of circular feedback buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFeedbackOption(
                  context,
                  emoji: '😞',
                  label: "Poor",
                  color: Colors.red,
                  onTap: () => _submitFeedback(context, "Not Satisfied"),
                ),
                _buildFeedbackOption(
                  context,
                  emoji: '😐',
                  label: "Okay",
                  color: Colors.orange,
                  onTap: () => _submitFeedback(context, "Ok"),
                ),
                _buildFeedbackOption(
                  context,
                  emoji: '😊',
                  label: "Good",
                  color: Colors.green,
                  onTap: () => _submitFeedback(context, "Good"),
                ),
              ],
            ),

            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Maybe Later",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackOption(
    BuildContext context, {
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AMCCustomerMainPage extends StatefulWidget {
  const AMCCustomerMainPage({super.key});

  @override
  State<AMCCustomerMainPage> createState() => _AMCCustomerMainPageState();
}

class _AMCCustomerMainPageState extends State<AMCCustomerMainPage> {
  String? userEmail;
  String userName = 'Guest';
  String customerId = '';
  String phoneNumber = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final tenantIdFromPrefs =
          prefs.getString('tenantId') ?? prefs.getString('databaseName');

      setState(() {
        userEmail = email;
      });

      // Sync branding even if user data is still loading or if email is null
      if (tenantIdFromPrefs != null) {
        await FirestoreService.instance.syncBranding(tenantIdFromPrefs);
      }

      if (email != null) {
        final query = await FirestoreService.instance
            .collection('AMC_user', tenantId: tenantIdFromPrefs)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final userData = query.docs.first.data();
          setState(() {
            userName = userData['name'] ?? 'Guest';
            customerId = userData['Id'] ?? '';
            phoneNumber =
                (userData['Phone Number'] ?? userData['phonenumber'])
                    ?.toString() ??
                '';
          });

          // Register FCM token for the customer
          await NotificationService.instance.registerToken(
            role: 'customer',
            userId: customerId,
            email: userEmail!,
          );
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async {
            SystemNavigator.pop();
            return true;
          },
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.exit_to_app, color: Theme.of(context).primaryColor),
                const SizedBox(width: 10),
                Text(
                  "Exit App",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Are you sure you want to exit the app?",
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Exit",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
    return false;
  }

  Future<void> handleLogout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(
              "Logout",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(fontSize: 16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        await AuthStateService.instance.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 223, 224, 224),
        appBar: _buildAppBar(),
        body: isLoading
            ? Center(
                child: Lottie.asset(
                  'assets/loading_animation.json',
                  width: 100,
                  repeat: true,
                ),
              )
            : _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 90,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            if (ThemeService.instance.logoUrl != null)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage: NetworkImage(ThemeService.instance.logoUrl!),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ThemeService.instance.appName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    "Hello, $userName",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => handleLogout(context),
              tooltip: 'Logout',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Decoration (matching Track My Service style)
          _buildHeaderDecoration(),

          // Welcome Section
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor.withOpacity(0.6),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How can we help you maintain your balance today?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const SizedBox(height: 32),

          // Main Action Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.add_rounded,
                    title: 'Add Device',
                    subtitle: 'Create new requests',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDeviceType(
                            name: userName,
                            loggedInName: userName,
                            phoneNumber: phoneNumber,
                            customerId: customerId,
                          ),
                        ),
                      );
                    },
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.track_changes_rounded,
                    title: 'Track Service',
                    subtitle: 'Manage active requests',
                    onTap: userName != 'Guest'
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AMCTrackMyService(
                                  customerName: userName,
                                  customerId: customerId,
                                ),
                              ),
                            );
                          }
                        : null,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Additional Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.bolt_rounded,
                    title: 'Real-time Updates',
                    subtitle: 'Stay notified instantly',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Expert Support',
                    subtitle: 'Professionals at duty',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderDecoration() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      "Explore",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: color, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
