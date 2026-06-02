import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/models/notification_model.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantId = ThemeService.instance.databaseName;
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Mark all as read',
            onPressed: () => _markAllAsRead(context, tenantId),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.instance.getAdminNotificationsStream(
          tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isSeen = notification.seen;
              final formattedDate = DateFormat(
                'MMM d, h:mm a',
              ).format(notification.timestamp);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isSeen
                      ? null
                      : Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isSeen
                        ? Colors.grey[200]
                        : primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      _getIconForType(notification.type),
                      color: isSeen ? Colors.grey[600] : primaryColor,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isSeen ? FontWeight.normal : FontWeight.bold,
                      fontSize: 16,
                      color: isSeen ? Colors.grey[800] : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: !isSeen
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () =>
                      _handleNotificationTap(context, tenantId, notification),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'ticket_assigned':
      case 'new_assignment':
        return Icons.assignment_turned_in;
      case 'ticket_update':
      case 'status_update':
        return Icons.update;
      case 'new_ticket':
        return Icons.add_alert_rounded;
      case 'ticket_acknowledged':
        return Icons.fact_check_rounded;
      case 'ticket_canceled':
        return Icons.cancel_presentation_rounded;
      case 'monthly_status':
        return Icons.calendar_today;
      case 'subscription_expiry':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications;
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
      // Navigate to the tickets overview with a filter or search
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
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }
}
