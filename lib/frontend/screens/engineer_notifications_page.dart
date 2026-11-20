import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/models/notification_model.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';

class EngineerNotificationsPage extends StatefulWidget {
  final String engineerName;
  final String? engineerId;
  final String? userEmail;

  const EngineerNotificationsPage({
    super.key,
    required this.engineerName,
    this.engineerId,
    this.userEmail,
  });

  @override
  State<EngineerNotificationsPage> createState() =>
      _EngineerNotificationsPageState();
}

class _EngineerNotificationsPageState extends State<EngineerNotificationsPage> {
  String? _loadingTicketId;

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
            onPressed: () => _markAllAsRead(tenantId),
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
          stream: NotificationService.instance.getEngineerNotificationsStream(
            tenantId,
            engineerName: widget.engineerName,
            engineerId: widget.engineerId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading notifications: ${snapshot.error}',
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
                    bookingId: data['bookingId'] ?? data['ticketId'],
                    customerName: data['customerName'],
                    audience: data['audience'],
                  ),
                )
                .toList();

            if (notifications.isEmpty) {
              return _buildEmptyState(context);
            }

            final unreadCount = notifications.where((n) => !n.seen).length;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount:
                  unreadCount > 0
                      ? notifications.length + 1
                      : notifications.length,
              itemBuilder: (context, index) {
                if (unreadCount > 0 && index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                          onPressed: () => _markAllAsRead(tenantId),
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
                LucideIcons.bellOff,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see all your task assignments, updates, and messages here.',
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
    final isOpeningThis = _loadingTicketId == notification.bookingId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? primaryColor.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isUnread
                  ? primaryColor.withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isUnread
                    ? primaryColor.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(notification, tenantId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon Badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: typeInfo.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        typeInfo.icon,
                        size: 18,
                        color: typeInfo.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Type Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeInfo.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeInfo.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: typeInfo.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (notification.bookingId != null &&
                        notification.bookingId!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '#${notification.bookingId}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Timestamp
                    Text(
                      _formatDate(notification.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  notification.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Body
                Text(
                  notification.body,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                // Bottom Meta: Customer Info & Tap action prompt
                if ((notification.customerName != null &&
                        notification.customerName!.isNotEmpty) ||
                    (notification.bookingId != null &&
                        notification.bookingId!.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (notification.customerName != null &&
                          notification.customerName!.isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.user,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  notification.customerName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (notification.bookingId != null &&
                          notification.bookingId!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOpeningThis)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            Text(
                              'View Ticket',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: primaryColor,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
    NotificationModel notification,
    String tenantId,
  ) async {
    // 1. Mark notification as read
    if (!notification.seen) {
      await NotificationService.instance.markNotificationAsRead(
        tenantId,
        notification.id,
      );
    }

    // 2. Navigate to relevant ticket if bookingId exists
    final bookingId = notification.bookingId?.trim() ?? '';
    if (bookingId.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _loadingTicketId = bookingId;
    });

    try {
      // Check Admin_ticket_entry first
      var doc =
          await FirestoreService.instance
              .collection('Admin_ticket_entry')
              .doc(bookingId)
              .get();

      // Fallback to Admin_details if not in Admin_ticket_entry
      if (!doc.exists) {
        doc =
            await FirestoreService.instance
                .collection('Admin_details')
                .doc(bookingId)
                .get();
      }

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final booking = AdminDetails.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => TicketDetailScreen(
                  booking: booking,
                  userName: widget.engineerName,
                  userId: widget.engineerId ?? '',
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ticket #$bookingId details are no longer available.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: const Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ticket: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTicketId = null;
        });
      }
    }
  }

  void _markAllAsRead(String tenantId) async {
    await NotificationService.instance.markAllEngineerNotificationsAsRead(
      tenantId,
      engineerName: widget.engineerName,
      engineerId: widget.engineerId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'All notifications marked as read',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  _TypeInfo _resolveTypeInfo(String? type, Color primaryColor) {
    switch (type) {
      case 'new_assignment':
        return _TypeInfo(
          label: 'ASSIGNMENT',
          icon: LucideIcons.clipboardList,
          color: const Color(0xFF2563EB),
          backgroundColor: const Color(0xFFEFF6FF),
        );
      case 'ticket_cancelled':
        return _TypeInfo(
          label: 'CANCELLED',
          icon: LucideIcons.calendarX,
          color: const Color(0xFFEF4444),
          backgroundColor: const Color(0xFFFEF2F2),
        );
      case 'visit_scheduled':
        return _TypeInfo(
          label: 'SCHEDULED VISIT',
          icon: LucideIcons.calendarClock,
          color: const Color(0xFF8B5CF6),
          backgroundColor: const Color(0xFFF5F3FF),
        );
      case 'helper_assigned':
        return _TypeInfo(
          label: 'HELPER ASSIGNED',
          icon: LucideIcons.users,
          color: const Color(0xFF0D9488),
          backgroundColor: const Color(0xFFF0FDFA),
        );
      case 'status_update':
      case 'engineer_status_update':
        return _TypeInfo(
          label: 'UPDATE',
          icon: LucideIcons.refreshCw,
          color: const Color(0xFF0284C7),
          backgroundColor: const Color(0xFFF0F9FF),
        );
      case 'customer_rating':
      case 'ticket_completed_feedback':
        return _TypeInfo(
          label: 'FEEDBACK',
          icon: LucideIcons.star,
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFFFFFBEB),
        );
      default:
        return _TypeInfo(
          label: 'NOTIFICATION',
          icon: LucideIcons.bell,
          color: primaryColor,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
        );
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays == 0 && now.day == dt.day) {
      return DateFormat('hh:mm a').format(dt);
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
    } else if (now.year == dt.year) {
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } else {
      return DateFormat('dd MMM yyyy').format(dt);
    }
  }
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  _TypeInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}
