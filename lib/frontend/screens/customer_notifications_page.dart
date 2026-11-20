import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/models/notification_model.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_feedback_screen.dart';

class CustomerNotificationsPage extends StatelessWidget {
  final String customerId;
  final String customerName;

  const CustomerNotificationsPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

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
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : InkWell(
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
        maxWidth: 720.0,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationService.instance.getCustomerNotificationsStream(
            tenantId,
            customerId: customerId,
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
                    id: data['id'] ?? '',
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
              return _buildEmptyState(context);
            }

            final unreadCount = notifications.where((n) => !n.seen).length;

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: notifications.length + (unreadCount > 0 ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (unreadCount > 0 && index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _markAllAsRead(context, tenantId),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(60, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Mark all read',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final actualIndex = unreadCount > 0 ? index - 1 : index;
                final notification = notifications[actualIndex];
                return _buildNotificationCard(
                  context,
                  notification,
                  tenantId,
                  primaryColor,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 54,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see your service updates and important alerts here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
    String tenantId,
    Color primaryColor,
  ) {
    final typeInfo = _resolveTypeInfo(notification.type, primaryColor);
    final isUnread = !notification.seen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 1. Mark as read
          if (isUnread) {
            NotificationService.instance.markNotificationAsRead(
              tenantId,
              notification.id,
            );
          }

          // 2. Navigate to relevant ticket or feedback screen if bookingId exists
          if (notification.bookingId != null &&
              notification.bookingId!.trim().isNotEmpty) {
            final bId = notification.bookingId!.trim();
            final notifType = (notification.type ?? '').toLowerCase().trim();

            if (notifType == 'ticket_completed_feedback') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerFeedbackScreen(
                    ticketId: bId,
                    customerId: customerId,
                    customerName: customerName,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AMCTrackMyService(
                    customerName: customerName,
                    customerId: customerId,
                    initialBookingId: bId,
                  ),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread
                ? primaryColor.withValues(alpha: 0.03)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? primaryColor.withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? primaryColor.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeInfo.icon, color: typeInfo.color, size: 22),
              ),
              const SizedBox(width: 14),

              // Title, Body, Timestamp
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
                              fontSize: 15,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        if (notification.bookingId != null &&
                            notification.bookingId!.trim().isNotEmpty) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#${notification.bookingId}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),
                              ],
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
        ),
      ),
    );
  }

  _NotificationTypeInfo _resolveTypeInfo(String? type, Color primaryColor) {
    final t = (type ?? '').toLowerCase().trim();

    if (t == 'ticket_created' || t == 'new_ticket') {
      return _NotificationTypeInfo(
        icon: Icons.confirmation_number_outlined,
        color: const Color(0xFF2563EB), // Blue
      );
    }
    if (t == 'ticket_assigned' || t == 'engineer_assigned') {
      return _NotificationTypeInfo(
        icon: Icons.engineering_outlined,
        color: const Color(0xFF0D9488), // Teal
      );
    }
    if (t == 'visit_scheduled') {
      return _NotificationTypeInfo(
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF059669), // Green
      );
    }
    if (t == 'visit_rescheduled') {
      return _NotificationTypeInfo(
        icon: Icons.edit_calendar_outlined,
        color: const Color(0xFFD97706), // Amber
      );
    }
    if (t == 'status_update' || t == 'ticket_updated') {
      return _NotificationTypeInfo(
        icon: Icons.sync_rounded,
        color: const Color(0xFF0284C7), // Light Blue
      );
    }
    if (t == 'ticket_cancelled' || t.contains('cancel')) {
      return _NotificationTypeInfo(
        icon: Icons.cancel_outlined,
        color: const Color(0xFFDC2626), // Red
      );
    }
    if (t == 'service_in_progress' || t.contains('progress')) {
      return _NotificationTypeInfo(
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFF3B82F6), // Blue
      );
    }
    if (t == 'ready_for_delivery' || t.contains('ready')) {
      return _NotificationTypeInfo(
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF0D9488), // Teal
      );
    }
    if (t == 'service_delivered' || t == 'delivered') {
      return _NotificationTypeInfo(
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF10B981), // Emerald
      );
    }
    if (t == 'ticket_completed_feedback' || t == 'feedback' || t == 'rating') {
      return _NotificationTypeInfo(
        icon: Icons.star_rate_rounded,
        color: const Color(0xFFD97706), // Amber
      );
    }
    if (t == 'service_completed' || t == 'completed') {
      return _NotificationTypeInfo(
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A), // Emerald
      );
    }
    if (t == 'payment' || t == 'invoice' || t == 'payment_update') {
      return _NotificationTypeInfo(
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF7C3AED), // Purple
      );
    }
    if (t == 'reminder' || t == 'amc_reminder' || t == 'service_reminder') {
      return _NotificationTypeInfo(
        icon: Icons.alarm_rounded,
        color: const Color(0xFFEA580C), // Orange
      );
    }

    return _NotificationTypeInfo(
      icon: Icons.notifications_none_rounded,
      color: primaryColor,
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1 && now.day == dt.day) {
      return 'Today, ${DateFormat('hh:mm a').format(dt)}';
    } else if (difference.inDays < 2) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }
  }

  void _markAllAsRead(BuildContext context, String tenantId) async {
    await NotificationService.instance.markAllCustomerNotificationsAsRead(
      tenantId,
      customerId: customerId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _NotificationTypeInfo {
  final IconData icon;
  final Color color;

  _NotificationTypeInfo({required this.icon, required this.color});
}
