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
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';
import 'package:subscription_rooks_app/services/app_tour_service.dart';
import 'package:subscription_rooks_app/widgets/interactive_tour/tour_step_model.dart';

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
  Timer? _timer;
  int _selectedTabIndex = 0; // 0: Live Tracking, 1: Completed & Delivered

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
    // Update relative time every minute
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) setState(() {});
    });
  }

  DateTime? parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.tryParse(timestamp);
    return null;
  }

  String _getRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Posted just now';
    } else if (difference.inMinutes < 60) {
      return 'Posted ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return 'Posted ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return 'Posted ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    }
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          ThemeService.instance.appName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance
                .collection('Raised_tickets')
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

              final allDocs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data();
                final cName = (data['customerName'] ?? data['CustomerName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                final cId = (data['customerid'] ??
                        data['id'] ??
                        data['customerId'] ??
                        '')
                    .toString()
                    .trim()
                    .toLowerCase();
                final targetName = widget.customerName.trim().toLowerCase();
                final targetId = widget.customerId.trim().toLowerCase();
                return (targetName.isNotEmpty && cName == targetName) ||
                    (targetId.isNotEmpty && cId == targetId);
              }).toList();

              // Sort by createdAt descending
              allDocs.sort((a, b) {
                final tsA = parseTimestamp(a.data()['createdAt'] ??
                    a.data()['timestamp'] ??
                    a.data()['updatedAt']);
                final tsB = parseTimestamp(b.data()['createdAt'] ??
                    b.data()['timestamp'] ??
                    b.data()['updatedAt']);
                if (tsA == null && tsB == null) return 0;
                if (tsA == null) return 1;
                if (tsB == null) return -1;
                return tsB.compareTo(tsA);
              });

              // Separate Live vs Completed
              final liveTickets = allDocs.where((doc) {
                final data = doc.data();
                final engStatus = (data['engineerStatus'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final admStatus = (data['adminStatus'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final isCompleted = engStatus == 'completed' ||
                    engStatus.contains('complete') ||
                    admStatus == 'completed' ||
                    admStatus == 'delivered' ||
                    data['orderDelivered'] == true ||
                    data['isDelivered'] == true;
                final isCanceled =
                    admStatus == 'canceled' || admStatus == 'cancelled';
                return !isCompleted && !isCanceled;
              }).toList();

              final completedTickets = allDocs.where((doc) {
                final data = doc.data();
                final engStatus = (data['engineerStatus'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final admStatus = (data['adminStatus'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final isCompleted = engStatus == 'completed' ||
                    engStatus.contains('complete') ||
                    admStatus == 'completed' ||
                    admStatus == 'delivered' ||
                    data['orderDelivered'] == true ||
                    data['isDelivered'] == true;
                return isCompleted;
              }).toList();

              final displayedTickets = _selectedTabIndex == 0
                  ? liveTickets
                  : completedTickets;

              return Column(
                children: [
                  _buildHeaderDecoration(),
                  _buildSegmentSwitcher(
                    liveCount: liveTickets.length,
                    completedCount: completedTickets.length,
                  ),
                  Expanded(
                    child: displayedTickets.isEmpty
                        ? _buildEmptyState(isLive: _selectedTabIndex == 0)
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: 32,
                            ),
                            itemCount: displayedTickets.length,
                            itemBuilder: (context, index) {
                              final data = displayedTickets[index].data();
                              final documentId = displayedTickets[index].id;
                              return _buildProfessionalTicketCard(
                                  data, documentId);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          if (showBanner) _buildFloatingBanner(),
        ],
      ),
    );
  }

  Widget _buildSegmentSwitcher({
    required int liveCount,
    required int completedCount,
  }) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Live Tracking Tab
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedTabIndex == 0) return;
                setState(() => _selectedTabIndex = 0);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 16,
                      color: _selectedTabIndex == 0
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live Tracking',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTabIndex == 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _selectedTabIndex == 0
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Colors.white.withValues(alpha: 0.25)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$liveCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _selectedTabIndex == 0
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Completed Tab
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedTabIndex == 1) return;
                setState(() => _selectedTabIndex = 1);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 16,
                      color: _selectedTabIndex == 1
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTabIndex == 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _selectedTabIndex == 1
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Colors.white.withValues(alpha: 0.25)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$completedCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _selectedTabIndex == 1
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDecoration() {
    return Container(
      width: double.infinity,
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
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

  Widget _buildEmptyState({bool isLive = true}) {
    final primary = Theme.of(context).primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isLive
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLive ? Icons.check_circle_outline_rounded : Icons.verified_rounded,
                size: 50,
                color: isLive ? const Color(0xFF10B981) : primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLive ? 'No Active Service In Progress' : 'No Completed Services Yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLive
                  ? 'All your devices are healthy and operating smoothly. Need assistance with a device?'
                  : 'Once an engineer completes a service and it is delivered, your service history and ratings will be recorded here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalTicketCard(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return _ExpandableTicketCard(data: data, documentId: documentId);
  }
}

class _ExpandableTicketCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String documentId;

  const _ExpandableTicketCard({required this.data, required this.documentId});

  @override
  State<_ExpandableTicketCard> createState() => _ExpandableTicketCardState();
}

class _ExpandableTicketCardState extends State<_ExpandableTicketCard> {
  bool _isExpanded = false;
  int _selectedRating = 5;
  final TextEditingController _ratingCommentController = TextEditingController();
  bool _isSubmittingRating = false;
  bool _hasSubmittedRating = false;

  @override
  void dispose() {
    _ratingCommentController.dispose();
    super.dispose();
  }

  _StatusInfo _mapEngineerStatus(String status, {Map<String, dynamic>? data}) {
    final isDelivered = data?['orderDelivered'] == true ||
        data?['isDelivered'] == true ||
        data?['adminStatus']?.toString().toLowerCase().trim() == 'delivered' ||
        data?['customerStatus']?.toString().toLowerCase().trim() == 'delivered';
    if (isDelivered) {
      return _StatusInfo('DELIVERED', const Color(0xFF059669));
    }

    final lowerStatus = status.toLowerCase().trim();
    switch (lowerStatus) {
      case 'delivered':
        return _StatusInfo('DELIVERED', const Color(0xFF059669));
      case 'complete':
      case 'completed':
        return _StatusInfo('COMPLETED', const Color(0xFF10B981));
      case 'assigned':
        return _StatusInfo('ASSIGNED', const Color(0xFF0284C7));
      case 'in progress':
      case 'in-progress':
      case 'repairing':
        return _StatusInfo('IN PROGRESS', const Color(0xFF2563EB));
      case 'pending':
        return _StatusInfo('PENDING', const Color(0xFFD97706));
      case 'not assigned':
        return _StatusInfo('NOT ASSIGNED', const Color(0xFFDC2626));
      case 'cancelled':
      case 'canceled':
        return _StatusInfo('CANCELLED', const Color(0xFF64748B));
      default:
        if (lowerStatus.contains('approval')) {
          return _StatusInfo('PENDING APPROVAL', const Color(0xFF7C3AED));
        }
        if (lowerStatus.contains('spare')) {
          return _StatusInfo('PENDING SPARES', const Color(0xFFD97706));
        }
        if (lowerStatus.contains('observation')) {
          return _StatusInfo('UNDER OBSERVATION', const Color(0xFF0D9488));
        }
        String formatted = status.isNotEmpty
            ? status.toUpperCase()
            : 'OPEN';
        return _StatusInfo(formatted, const Color(0xFF64748B));
    }
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusTracker(Map<String, dynamic> data) {
    final primary = Theme.of(context).primaryColor;
    final adminStatus = data['adminStatus']?.toString().toLowerCase().trim() ?? '';
    final engineerStatus = data['engineerStatus']?.toString().toLowerCase().trim() ?? '';
    final customerStatus = data['customerStatus']?.toString().toLowerCase().trim() ?? '';
    final assignedEngineer = data['assignedEngineer'] ?? data['assignedEmployee'];
    final bool hasAssignedEngineer = assignedEngineer != null &&
        assignedEngineer.toString().trim().isNotEmpty &&
        assignedEngineer.toString().toLowerCase() != 'not assigned';

    final bool isDelivered = data['orderDelivered'] == true ||
        data['isDelivered'] == true ||
        adminStatus == 'delivered' ||
        customerStatus == 'delivered';

    final bool isCompleted = engineerStatus == 'completed' ||
        adminStatus == 'completed' ||
        isDelivered;

    final inProgressKeywords = [
      'in progress',
      'in-progress',
      'repairing',
      'under observation',
      'observation',
      'pending for spares',
      'pending spares',
      'pending for approval',
      'pending approval',
      'order taken',
      'order received',
    ];

    final bool isInProgress = inProgressKeywords.contains(engineerStatus) ||
        engineerStatus.contains('progress') ||
        engineerStatus.contains('observation') ||
        engineerStatus.contains('spare') ||
        engineerStatus.contains('approval') ||
        isCompleted;

    final bool isAssigned = hasAssignedEngineer ||
        adminStatus == 'assigned' ||
        engineerStatus == 'assigned' ||
        isInProgress;

    int currentStep = 0; // 0: Raised
    if (isAssigned) currentStep = 1;     // 1: Assigned
    if (isInProgress) currentStep = 2;   // 2: In Progress
    if (isCompleted) currentStep = 3;    // 3: Completed
    if (isDelivered) currentStep = 4;    // 4: Delivered

    final stepTitles = ["Raised", "Assigned", "In Progress", "Completed", "Delivered"];

    // Status Context Capsule Details
    String capsuleTitle;
    String capsuleSubtitle;
    IconData capsuleIcon;
    Color capsuleColor;

    switch (currentStep) {
      case 4:
        capsuleTitle = 'Order Delivered';
        capsuleSubtitle = 'Service completed and delivered to customer';
        capsuleIcon = Icons.check_circle_rounded;
        capsuleColor = const Color(0xFF059669);
        break;
      case 3:
        capsuleTitle = 'Service Completed';
        capsuleSubtitle = 'Work finished, awaiting delivery verification';
        capsuleIcon = Icons.task_alt_rounded;
        capsuleColor = const Color(0xFF10B981);
        break;
      case 2:
        capsuleTitle = 'Work In Progress';
        capsuleSubtitle = engineerStatus.isNotEmpty && engineerStatus != 'in progress'
            ? 'Status: ${engineerStatus.toUpperCase()}'
            : 'Technician is actively servicing your device';
        capsuleIcon = Icons.bolt_rounded;
        capsuleColor = const Color(0xFF2563EB);
        break;
      case 1:
        capsuleTitle = 'Engineer Assigned';
        capsuleSubtitle = hasAssignedEngineer
            ? 'Assigned to $assignedEngineer'
            : 'Technician allocated to your ticket';
        capsuleIcon = Icons.engineering_rounded;
        capsuleColor = const Color(0xFF0284C7);
        break;
      default:
        capsuleTitle = 'Request Raised';
        capsuleSubtitle = 'Your service request has been registered';
        capsuleIcon = Icons.receipt_long_rounded;
        capsuleColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Context Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: capsuleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(capsuleIcon, size: 16, color: capsuleColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsuleTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: capsuleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      capsuleSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: capsuleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Step ${currentStep + 1}/5',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: capsuleColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Milestone Stepper Row (Circles and Connecting Lines)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < 5; i++) ...[
                _buildMilestoneNode(i, currentStep, primary),
                if (i < 4) _buildConnectingTrack(i, currentStep, primary),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Milestone Labels Row (Fixed height container for equal baseline alignment)
          Row(
            children: [
              for (int i = 0; i < 5; i++)
                Expanded(
                  child: SizedBox(
                    height: 26,
                    child: Text(
                      stepTitles[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: i == currentStep
                            ? FontWeight.w900
                            : (i < currentStep
                                ? FontWeight.w700
                                : FontWeight.w500),
                        color: i <= currentStep
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        height: 1.15,
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

  Widget _buildMilestoneNode(int stepIndex, int currentStep, Color primary) {
    final bool isPassed = stepIndex < currentStep;
    final bool isCurrent = stepIndex == currentStep;

    if (isPassed) {
      // Completed step: solid primary bubble with crisp white check
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
      );
    } else if (isCurrent) {
      // Current active step: pulsing highlight ring
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: primary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      // Pending step: soft muted dot
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildConnectingTrack(int stepIndex, int currentStep, Color primary) {
    final bool isPassed = stepIndex < currentStep;
    return Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: isPassed ? primary : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }

  double _calculateTotalAmount(Map<String, dynamic> record) {
    double total = 0.0;
    // Add admin's amount
    if (record['amount'] != null) {
      total += (double.tryParse(record['amount'].toString()) ?? 0.0);
    }
    // Add all engineer's payments
    if (record['payments'] is List) {
      for (var payment in record['payments']) {
        if (payment is Map && payment['amount'] != null) {
          total += (double.tryParse(payment['amount'].toString()) ?? 0.0);
        }
      }
    }
    return total;
  }

  String _formatAmount(double amount) {
    return amount == amount.roundToDouble()
        ? '₹${amount.toInt()}'
        : '₹${amount.toStringAsFixed(2)}';
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
              color: Colors.amber.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
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
              color: Colors.red.withValues(alpha: 0.05),
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
                ? Colors.red.withValues(alpha: 0.05)
                : Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDanger
                  ? Colors.red.withValues(alpha: 0.1)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
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

  String _getRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Posted just now';
    } else if (difference.inMinutes < 60) {
      return 'Posted ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return 'Posted ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return 'Posted ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    }
  }

  Widget _buildRatingSection(Map<String, dynamic> data) {
    final hasRating = data['rating'] != null || _hasSubmittedRating;
    final existingRating = (data['rating'] as num?)?.toDouble() ?? _selectedRating.toDouble();
    final existingComment = (data['ratingComment'] ?? data['comment'] ?? _ratingCommentController.text).toString();
    final assignedEngineer = data['assignedEngineer']?.toString() ?? 'our technician';

    if (hasRating) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Icon(
                  index < existingRating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 14,
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                existingComment.isNotEmpty
                    ? '"$existingComment"'
                    : 'Rated $existingRating ★',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF78350F),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Rating Input Form
    const ratingLabels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent!'];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rate Your Service Experience",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "How was the service provided by $assignedEngineer?",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 Interactive Stars
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    final isSelected = starValue <= _selectedRating;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRating = starValue;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 32,
                            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  ratingLabels[_selectedRating.clamp(1, 5)],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Comments TextField
          TextField(
            controller: _ratingCommentController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add comments or feedback (optional)...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 10),

          // Submit Rating Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingRating
                  ? null
                  : () async {
                      setState(() => _isSubmittingRating = true);
                      try {
                        final ticketId = (widget.data['ticketId'] ?? widget.data['bookingId'] ?? widget.documentId).toString();
                        final customerName = (widget.data['customerName'] ?? '').toString();
                        final comment = _ratingCommentController.text.trim();
                        final ratingDocRef = FirestoreService.instance.collection('ratings').doc();

                        final ratingPayload = {
                          'id': ratingDocRef.id,
                          'ratingId': ratingDocRef.id,
                          'ticketId': ticketId,
                          'bookingId': ticketId,
                          'customerName': customerName,
                          'customerId': widget.data['customerId'] ?? widget.data['customerid'] ?? '',
                          'engineerName': widget.data['assignedEngineer'] ?? '',
                          'rating': _selectedRating,
                          'comment': comment,
                          'deviceBrand': widget.data['deviceBrand'] ?? '',
                          'deviceType': widget.data['deviceType'] ?? '',
                          'jobType': widget.data['jobType'] ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                          'timestamp': FieldValue.serverTimestamp(),
                        };

                        await ratingDocRef.set(ratingPayload);

                        final ticketUpdate = {
                          'rating': _selectedRating,
                          'ratingComment': comment,
                          'ratedAt': FieldValue.serverTimestamp(),
                        };

                        try {
                          await FirestoreService.instance
                              .collection('Raised_tickets')
                              .doc(widget.documentId)
                              .set(ticketUpdate, SetOptions(merge: true));
                        } catch (_) {}

                        try {
                          await FirestoreService.instance
                              .collection('Admin_ticket_entry')
                              .doc(widget.documentId)
                              .set(ticketUpdate, SetOptions(merge: true));
                        } catch (_) {}

                        await NotificationService.sendNotificationToFirestore(
                          audience: 'admin',
                          title: 'New Customer Rating Received',
                          body: '$customerName rated ticket #$ticketId: $_selectedRating★ ($comment)',
                          type: 'customer_rating',
                          bookingId: ticketId,
                          customerName: customerName,
                        );

                        if (mounted) {
                          setState(() {
                            _hasSubmittedRating = true;
                            _isSubmittingRating = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you! Your rating has been submitted.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSubmittingRating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = widget.data['ticketId'] ?? 'N/A';
    final jobType = widget.data['jobType'] ?? 'N/A';
    final deviceBrand = widget.data['deviceBrand'] ?? 'N/A';
    final deviceType = widget.data['deviceType'] ?? 'N/A';
    final customerName = widget.data['customerName'] ?? 'N/A';
    final mobileNumber = widget.data['mobileNumber'] ?? 'N/A';
    final issueDescription = widget.data['issueDescription'] ?? 'N/A';
    final address = widget.data['address'] ?? 'N/A';
    final assignedEngineer = widget.data['assignedEngineer'];
    final assignedTimestamp = widget.data['assignedTimestamp'] as Timestamp?;
    final paymentDetails = widget.data['paymentDetails'];
    final paymentApproved = widget.data['paymentApprovedByAdmin'] ?? false;
    final uploadedFiles = widget.data['uploadedFiles'] as List?;
    final statusHistory = widget.data['statusHistory'] as List?;
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final updatedAt = widget.data['updatedAt'] as Timestamp?;
    final rawStatus = widget.data['engineerStatus'] ?? '';
    final adminStatus =
        widget.data['adminStatus']?.toString().toLowerCase().trim() ?? '';
    final customerStatus =
        widget.data['customerStatus']?.toString().toLowerCase().trim() ?? '';
    final isCanceled = adminStatus == 'canceled' || adminStatus == 'cancelled';
    final isOrderDelivered = widget.data['orderDelivered'] == true ||
        widget.data['isDelivered'] == true ||
        adminStatus == 'delivered' ||
        customerStatus == 'delivered';
    final isCompleted = rawStatus.toString().toLowerCase().trim() == 'completed' ||
        adminStatus == 'completed' ||
        isOrderDelivered;
    final statusInfo = _mapEngineerStatus(rawStatus, data: widget.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header (always visible)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
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
                                "ID: $ticketId",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Customer: $customerName",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getRelativeTime(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(
                          isCanceled
                              ? 'CANCELED'
                              : statusInfo.label.toUpperCase(),
                          isCanceled ? Colors.red : statusInfo.color,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    // Progress Tracker (Shown in collapsed view ONLY for Live In-Progress tickets)
                    if (!isCompleted && !isCanceled) ...[
                      const SizedBox(height: 12),
                      _buildStatusTracker(widget.data),
                    ],
                    // Quick device info (always visible)
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildInfoItem(
                          Icons.devices_rounded,
                          "Device",
                          deviceBrand,
                        ),
                        const SizedBox(width: 12),
                        _buildInfoItem(
                          Icons.category_rounded,
                          "Type",
                          deviceType,
                        ),
                      ],
                    ),
                    // Customer Star Rating Section (Visible when service is completed)
                    if (isCompleted && !isCanceled) ...[
                      _buildRatingSection(widget.data),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Expanded Content
          if (_isExpanded) ...[
            const Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Color(0xFFF1F5F9),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Timeline Tracker for Completed Tickets inside Expanded View
                  if (isCompleted && !isCanceled) ...[
                    _buildStatusTracker(widget.data),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      _buildInfoItem(Icons.work_rounded, "Job", jobType),
                      const SizedBox(width: 12),
                      _buildInfoItem(
                        Icons.calendar_today_rounded,
                        "Created",
                        _formatTimestamp(createdAt),
                      ),
                    ],
                  ),
                  if (updatedAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoItem(
                          Icons.update_rounded,
                          "Updated",
                          DateFormat('dd MMM yyyy').format(updatedAt.toDate()),
                        ),
                        const SizedBox(width: 12),
                        _buildInfoItem(
                          Icons.phone_rounded,
                          "Mobile",
                          mobileNumber,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Address
                  if (address != 'N/A') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ADDRESS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Issue Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ISSUE DESCRIPTION",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          issueDescription,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (assignedEngineer != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ASSIGNED ENGINEER",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            assignedEngineer,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (paymentApproved) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PAYMENT DETAILS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Show individual payments
                          if (widget.data['payments'] is List &&
                              (widget.data['payments'] as List).isNotEmpty)
                            ...(widget.data['payments'] as List).map((payment) {
                              if (payment is Map) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        payment['paymentMethod']?.toString() ??
                                            'Payment',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _formatAmount(
                                          double.tryParse(
                                                payment['amount'].toString(),
                                              ) ??
                                              0.0,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          const SizedBox(height: 8),
                          // Show total
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total Amount",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _formatAmount(
                                    _calculateTotalAmount(widget.data),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (paymentDetails != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pending_actions_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Payment details will be available after admin approval",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (uploadedFiles != null && uploadedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "UPLOADED FILES",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9333EA),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...uploadedFiles.map((file) {
                            final fileName = file['name'] ?? 'Unknown file';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    color: Theme.of(context).primaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildDetailSection(widget.data, isCanceled),
                  if (statusHistory != null && statusHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    const Text(
                      "STATUS HISTORY",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...statusHistory.asMap().entries.map((entry) {
                      final index = entry.key;
                      final historyItem = entry.value;
                      final historyTimestamp =
                          historyItem['timestamp'] as Timestamp?;
                      final historyStatus = historyItem['status'] ?? '';
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == statusHistory.length - 1 ? 0 : 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (historyTimestamp != null)
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy, hh:mm a',
                                      ).format(historyTimestamp.toDate()),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    historyStatus,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
          // Footer (only visible when expanded)
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isCanceled &&
                      statusInfo.label == 'Completed' &&
                      (widget.data['FeedBack'] ?? '').isEmpty)
                    _buildActionIndicator(
                      "Rate Service",
                      Icons.star_border_rounded,
                      () {
                        showDialog(
                          context: context,
                          builder: (ctx) => FeedbackDialog(
                            bookingId: ticketId.toString(),
                            documentId: widget.documentId,
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
                          bookingId: ticketId.toString(),
                          documentId: widget.documentId,
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
          .collection('Raised_tickets')
          .doc(widget.documentId)
          .update({
            'Reason_cancel': _reasonController.text.trim(),
            'adminStatus': 'Canceled',
            'engineerStatus': 'Cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
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
                color: Colors.red.withValues(alpha: 0.1),
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
                      disabledBackgroundColor: Colors.red.withValues(
                        alpha: 0.3,
                      ),
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
          .collection('Raised_tickets')
          .doc(documentId)
          .update({
            'FeedBack': feedback,
            'updatedAt': FieldValue.serverTimestamp(),
          });

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
                    color: color.withValues(alpha: 0.1),
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
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
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
                color: color.withValues(alpha: 0.8),
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

  // GlobalKeys for Customer Interactive Tour
  final GlobalKey _custHeaderKey = GlobalKey();
  final GlobalKey _custWelcomeCardKey = GlobalKey();
  final GlobalKey _custAddDeviceKey = GlobalKey();
  final GlobalKey _custTrackServiceKey = GlobalKey();
  final GlobalKey _custUpdatesKey = GlobalKey();
  final GlobalKey _custSupportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> _checkAndStartCustomerTour({bool force = false}) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('hasCompletedCustomerTour') ?? false;
    if (!completed || force) {
      final steps = _buildCustomerTourSteps();
      if (mounted && steps.isNotEmpty) {
        AppTourService.instance.startTour(
          context: context,
          steps: steps,
          force: force,
          onComplete: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool('hasCompletedCustomerTour', true);
          },
        );
      }
    }
  }

  List<TourStep> _buildCustomerTourSteps() {
    final primary = Theme.of(context).primaryColor;
    return [
      TourStep(
        id: 'cust_header',
        targetKey: _custHeaderKey,
        category: '👋 Welcome Customer',
        title: 'Customer Self-Service Hub',
        description:
            'Welcome to your personal service portal! From here, you can manage your maintenance contracts, request device repairs, and track live status.',
        icon: Icons.account_circle_rounded,
        accentColor: primary,
      ),
      TourStep(
        id: 'cust_welcome_card',
        targetKey: _custWelcomeCardKey,
        category: '🏠 Account Dashboard',
        title: 'Your Account Overview',
        description:
            'Quickly access your service summary and find everything you need to keep your devices running smoothly.',
        icon: Icons.home_rounded,
        accentColor: primary,
      ),
      TourStep(
        id: 'cust_add_device',
        targetKey: _custAddDeviceKey,
        category: '➕ Raise Service Ticket',
        title: 'Raise Ticket & Book Repair',
        description:
            'Need service or maintenance? Tap "Raise Now" to select your device brand and type, enter issue details, and instantly raise a service ticket for a technician visit.',
        icon: Icons.confirmation_number_rounded,
        accentColor: primary,
        workflowSteps: const [
          '1. Select Device',
          '2. Enter Symptoms',
          '3. Submit Ticket',
          '4. Tech Dispatched',
        ],
        currentWorkflowIndex: 0,
      ),
      TourStep(
        id: 'cust_track_service',
        targetKey: _custTrackServiceKey,
        category: '📍 Live Tracking', 
        title: 'Track Active Service',
        description:
            'Track real-time progress on your open repairs. View assigned engineer name, live GPS status, repair notes, and invoice details.',
        icon: Icons.track_changes_rounded,
        accentColor: const Color(0xFF059669),
      ),
      TourStep(
        id: 'cust_updates',
        targetKey: _custUpdatesKey,
        category: '🔔 Instant Notifications',
        title: 'Real-time Updates',
        description:
            'Receive instant push notifications as soon as a technician is assigned, checks in onsite, or completes your repair.',
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFF3B82F6),
      ),
      TourStep(
        id: 'cust_support',
        targetKey: _custSupportKey,
        category: '⭐ Certified Support',
        title: 'Expert Assistance',
        description:
            'Rest assured knowing all repairs are carried out by certified field specialists with professional support anytime.',
        icon: Icons.workspace_premium_rounded,
        accentColor: const Color(0xFF8B5CF6),
      ),
    ];
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _checkAndStartCustomerTour();
        });
      });
    }
  }



  Future<void> handleLogout(BuildContext context) async {
    final primaryError = const Color(0xFFEF4444);
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryError.withValues(alpha: 0.15),
                        primaryError.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryError.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: primaryError,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Confirm Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to logout? You will need to sign in again to access your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryError,
                            elevation: 3,
                            shadowColor: primaryError.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Minimize app to home screen like Instagram without logging out
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
    final primary = Theme.of(context).primaryColor;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: primary,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 90,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primary,
              HSLColor.fromColor(primary).withLightness(0.32).toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Container(
          key: _custHeaderKey,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ThemeService.instance.logoUrl != null
                    ? CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(ThemeService.instance.logoUrl!),
                      )
                    : CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        ThemeService.instance.appName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Hello, $userName 👋",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
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
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0, top: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => _checkAndStartCustomerTour(force: true),
              tooltip: 'App Tour & Guide',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14.0, top: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
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
    final primary = Theme.of(context).primaryColor;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ResponsiveWrapper(
        maxWidth: kMaxContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Gradient Curve Banner Transition
            _buildHeaderDecoration(),

            // Welcome Section Hero Card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                key: _custWelcomeCardKey,
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 14,
                                color: primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'WELCOME BACK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'How can we help you maintain your balance today?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Main Action Cards Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      key: _custAddDeviceKey,
                      child: _buildActionCard(
                        icon: Icons.confirmation_number_rounded,
                        title: 'Raise Ticket',
                        subtitle: 'Report issue & book repair',
                        buttonLabel: 'Raise Now',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerDeviceType(
                                name: userName,
                                loggedInName: userName,
                                phoneNumber: phoneNumber,
                                customerId: customerId,
                                customerType: "amc",
                              ),
                            ),
                          );
                        },
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      key: _custTrackServiceKey,
                      child: _buildActionCard(
                        icon: Icons.track_changes_rounded,
                        title: 'Track Service',
                        subtitle: 'Manage active repair requests',
                        buttonLabel: 'Track Now',
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Additional Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      key: _custUpdatesKey,
                      child: _buildInfoCard(
                        icon: Icons.bolt_rounded,
                        title: 'Real-time Updates',
                        subtitle: 'Stay notified instantly',
                        accentColor: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      key: _custSupportKey,
                      child: _buildInfoCard(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Expert Support',
                        subtitle: 'Professionals at duty',
                        accentColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderDecoration() {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            HSLColor.fromColor(primary).withLightness(0.32).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
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
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
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
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
