import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/models/notification_model.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantId = ThemeService.instance.databaseName;
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Mark all as read',
            onPressed: () => _markAllAsRead(context, tenantId),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: kMaxContentWidth,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationService.instance.getAdminNotificationsStream(
            tenantId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              );
            }

            final rawNotifications = snapshot.data ?? [];
            final notifications = rawNotifications
                .map(
                  (data) => NotificationModel(
                    id: data['id'],
                    title: data['title'] ?? 'No Title',
                    body: data['body'] ?? 'No Content',
                    timestamp:
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    seen: data['seen'] ?? false,
                    type: data['type'],
                    bookingId: data['bookingId'],
                    customerName: data['customerName'],
                    audience: data['audience'],
                  ),
                )
                .toList();

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are completely caught up!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isSeen = notification.seen;
                final formattedDate = DateFormat(
                  'MMM d, h:mm a',
                ).format(notification.timestamp);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSeen
                          ? const Color(0xFFE2E8F0)
                          : primaryColor.withValues(alpha: 0.35),
                      width: isSeen ? 1.2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _handleNotificationTap(
                        context,
                        tenantId,
                        notification,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSeen
                                    ? const Color(0xFFF1F5F9)
                                    : primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _getIconForType(notification.type),
                                color: isSeen
                                    ? const Color(0xFF64748B)
                                    : primaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: isSeen
                                                ? FontWeight.w600
                                                : FontWeight.w700,
                                            fontSize: 14.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (!isSeen)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.body,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'ticket_assigned':
      case 'new_assignment':
        return Icons.assignment_turned_in_rounded;
      case 'ticket_update':
      case 'status_update':
        return Icons.update_rounded;
      case 'new_ticket':
        return Icons.add_alert_rounded;
      case 'ticket_acknowledged':
        return Icons.fact_check_rounded;
      case 'ticket_canceled':
        return Icons.cancel_presentation_rounded;
      case 'monthly_status':
        return Icons.calendar_today_rounded;
      case 'subscription_expiry':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    String tenantId,
    NotificationModel notification,
  ) {
    if (!notification.seen) {
      NotificationService.instance.markNotificationAsRead(
        tenantId,
        notification.id,
      );
    }

    final bookingId = notification.bookingId;
    if (bookingId != null && bookingId.toString().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AdminPage_CusDetails(statusFilter: "", searchQuery: bookingId),
        ),
      );
    }
  }

  void _markAllAsRead(BuildContext context, String tenantId) {
    NotificationService.instance.markAllNotificationsAsRead(tenantId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'All notifications marked as read',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
