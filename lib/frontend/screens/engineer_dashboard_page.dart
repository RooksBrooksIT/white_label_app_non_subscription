import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_barcode_identifier.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_barcode_scanner_page.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:subscription_rooks_app/services/location_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ProfessionalTheme {
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color primaryDark(BuildContext context) =>
      Theme.of(context).primaryColor;
  static Color primaryLight(BuildContext context) =>
      Theme.of(context).primaryColor.withOpacity(0.8);
  static Color primaryExtraLight(BuildContext context) =>
      Theme.of(context).primaryColor.withOpacity(0.1);

  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) => Theme.of(context).cardColor;
  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).cardColor;

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static Color info(BuildContext context) => Theme.of(context).primaryColor;
  static const Color infoLight = Color(0xFFCFFAFE);

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A);
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B);
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).hintColor;
  static Color textInverse(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static Color borderLight(BuildContext context) =>
      Theme.of(context).dividerColor.withOpacity(0.5);
  static Color borderMedium(BuildContext context) =>
      Theme.of(context).dividerColor;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  // Utility for section headers
  static TextStyle sectionHeader(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textSecondary(context),
    letterSpacing: 0.5,
  );

  // Utility for card decoration
  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
    color: surface(context),
    borderRadius: BorderRadius.circular(16),
    boxShadow: cardShadow,
    border: Border.all(color: borderLight(context)),
  );
}

// Professional Animations
class ProfessionalAnimations {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  static Curve easeInOut = Curves.easeInOut;
  static Curve elasticOut = Curves.elasticOut;
}

// AdminDetails Model
class AdminDetails {
  final String docId;
  final String bookingId;
  final String customerName;
  final String deviceBrand;
  final String deviceType;
  final String deviceCondition;
  final String address;
  final String mobileNumber;
  final String customerId;

  String selectedStatus;
  String description;
  String amount;
  List<String> imageUrls;
  String paymentType;
  final String adminStatus;
  final String customerDecision;
  final Timestamp? assignedTimestamp;
  final Timestamp? completedAt;
  final String id;
  final String assignedDate;
  final double? lat;
  final double? lng;
  AdminDetails({
    required this.docId,
    required this.bookingId,
    required this.customerName,
    required this.deviceBrand,
    required this.deviceType,
    required this.deviceCondition,
    required this.address,
    required this.mobileNumber,
    required this.customerId,
    required this.selectedStatus,
    required this.description,
    required this.amount,
    this.imageUrls = const [],
    this.paymentType = '',
    required this.adminStatus,
    required this.customerDecision,
    this.assignedTimestamp,
    this.completedAt,

    this.id = '',
    this.lat,
    this.lng,
  }) : assignedDate = assignedTimestamp != null
           ? '${assignedTimestamp.toDate().day}/${assignedTimestamp.toDate().month}/${assignedTimestamp.toDate().year}'
           : 'Not assigned';
  String get assignedDateTimeFormatted {
    if (assignedTimestamp == null) return 'Not assigned';

    final date = assignedTimestamp!.toDate();
    final formatter = DateFormat('MMMM d, yyyy \'at\' h:mm:ss a');
    return formatter.format(date);
  }

  factory AdminDetails.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return AdminDetails(
      docId: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerName: data['customerName'] ?? '',
      deviceBrand: data['deviceBrand'] ?? '',
      deviceType: data['deviceType'] ?? '',
      deviceCondition: data['deviceCondition'] ?? '',
      address: data['address'] ?? '',
      mobileNumber: data['mobileNumber'] ?? '',
      customerId: data['id']?.toString() ?? '',
      selectedStatus: data['engineerStatus'] ?? data['adminStatus'] ?? '',
      description: data['description'] ?? '',
      amount: data['amount']?.toString() ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      paymentType: data['PaymentType'] ?? '',
      adminStatus: data['adminStatus'] ?? '',
      customerDecision: data['Customer_decision'] ?? '',
      assignedTimestamp: data['AssignedTimestamp'],
      completedAt: data['completedAt'],
      id: data['id'] ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
    );
  }

  bool get isCanceled {
    return adminStatus.toLowerCase() == 'canceled' ||
        customerDecision.toLowerCase() == 'canceled';
  }

  String get cancellationMessage {
    if (adminStatus.toLowerCase() == 'canceled') {
      return 'This ticket was canceled by admin';
    } else if (customerDecision.toLowerCase() == 'canceled') {
      return 'This ticket was canceled by customer: $customerName';
    }
    return '';
  }

  // Calculate days since assignment
  int get daysSinceAssignment {
    if (assignedTimestamp == null) return 0;

    final assignedDate = assignedTimestamp!.toDate();
    final now = DateTime.now();

    // Calculate difference in days
    final difference = now.difference(assignedDate);
    return difference.inDays;
  }

  // Calculate days it took to complete
  int? get daysToComplete {
    if (assignedTimestamp == null) return null;

    final assignedDate = assignedTimestamp!.toDate();
    final endDate = completedAt?.toDate() ?? DateTime.now();

    // Calculate difference in days
    final difference = endDate.difference(assignedDate);
    return difference.inDays;
  }

  // Get display text for days
  String get daysDisplayText {
    if (selectedStatus.toLowerCase() == 'completed' && daysToComplete != null) {
      return 'Completed in $daysToComplete ${daysToComplete == 1 ? 'day' : 'days'}';
    } else {
      return '$daysSinceAssignment ${daysSinceAssignment == 1 ? 'day' : 'days'} since assignment';
    }
  }

  // Get the completion message with days
  String get completionMessage {
    if (selectedStatus.toLowerCase() == 'completed' && daysToComplete != null) {
      return 'This job took $daysToComplete ${daysToComplete == 1 ? 'day' : 'days'} to complete';
    }
    return '';
  }
}

// Professional Loading Spinner
class ProfessionalLoadingSpinner extends StatelessWidget {
  const ProfessionalLoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ProfessionalTheme.primary(context).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                ProfessionalTheme.primary(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading assignments...',
            style: TextStyle(
              fontSize: 16,
              color: ProfessionalTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Professional Empty State
class ProfessionalEmptyState extends StatelessWidget {
  const ProfessionalEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: ProfessionalTheme.surface(context),
                shape: BoxShape.circle,
                boxShadow: ProfessionalTheme.cardShadow,
                border: Border.all(
                  color: ProfessionalTheme.borderLight(context),
                ),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: ProfessionalTheme.textTertiary(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Assigned Bookings',
              style: TextStyle(
                fontSize: 20,
                color: ProfessionalTheme.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'New assignments from admin will appear here automatically',
              style: TextStyle(
                fontSize: 14,
                color: ProfessionalTheme.textSecondary(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Professional Navigation Drawer
class ProfessionalNavigationDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final String currentSection;
  final Function(String) onSectionChange;

  const ProfessionalNavigationDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.currentSection,
    required this.onSectionChange,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ProfessionalTheme.surface(context),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: ProfessionalTheme.primary(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              // Line 390
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirestoreService.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .get(),
                  builder: (context, snapshot) {
                    String? photoUrl;
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      photoUrl = data?['photoUrl'] ?? data?['profileImage'];
                    }
                    // Fallback to Auth photoURL if Firestore doesn't have it
                    photoUrl ??= FirebaseAuth.instance.currentUser?.photoURL;

                    return CircleAvatar(
                      radius: 32,
                      backgroundColor: ProfessionalTheme.textInverse(
                        context,
                      ).withOpacity(0.2),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Icon(
                              Icons.engineering,
                              size: 32,
                              color: ProfessionalTheme.textInverse(context),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalTheme.textInverse(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: ProfessionalTheme.textInverse(
                      context,
                    ).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    isSelected: currentSection == 'dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      onSectionChange('dashboard');
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.assignment_turned_in,
                    title: 'Completed Tickets',
                    isSelected: currentSection == 'completed',
                    onTap: () {
                      Navigator.pop(context);
                      onSectionChange('completed');
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.qr_code_scanner,
                    title: 'Barcode Scanner',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BarcodeScannerScreen(userName: userName),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.qr_code_2_rounded,
                    title: 'Barcode Identifier',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EngineerBarcodeIdentifierScreen(
                            scannedBarcode: '',
                            userName: userName,
                          ),
                        ),
                      );
                    },
                  ),
                  // _buildMenuItem(
                  //   context: context,
                  //   icon: Icons.qr_code_2_rounded,
                  //   title: 'Engineer Attendance',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => EngineerAttendanceScreen(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  const Spacer(),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.logout,
                    title: 'Logout',
                    isLogout: true,
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isSelected = false,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? ProfessionalTheme.primary(context).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout
              ? ProfessionalTheme.error
              : (isSelected
                    ? ProfessionalTheme.primary(context)
                    : ProfessionalTheme.textSecondary(context)),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isLogout
                ? ProfessionalTheme.error
                : ProfessionalTheme.textPrimary(context),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.circle,
                size: 8,
                color: ProfessionalTheme.primary(context),
              )
            : null,
        onTap: onTap,
        dense: true,
      ),
    );
  }
}

// Enhanced Professional Engineer Page
class EngineerPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  final Map<String, dynamic>? notificationData;

  const EngineerPage({
    super.key,
    required this.userEmail,
    required this.userName,
    this.notificationData,
  });

  @override
  _EngineerPageState createState() => _EngineerPageState();
}

class _EngineerPageState extends State<EngineerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add this new state variable
  String _currentSection = 'dashboard'; // 'dashboard' or 'completed'

  // Firestore subscription for incoming notifications targeted to this engineer
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;

  // FCM message subscription
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  // Optimization variables
  Timer? _searchDebounceTimer;
  List<AdminDetails> _allBookings = [];
  List<AdminDetails> _filteredBookings = [];
  bool _isOnline = true; // Default to true as they just logged in
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    NotificationService.instance.registerToken(
      role: 'engineer',
      userId: widget.userName,
      email: widget.userEmail,
    );

    _handleInitialNotification();
    _listenToNotifications();
    _setupFCMListeners();
    _fetchInitialOnlineStatus();
  }

  Future<void> _fetchInitialOnlineStatus() async {
    final tenantId = await SharedPreferences.getInstance().then(
      (p) => p.getString('tenantId'),
    );
    if (tenantId != null) {
      final doc = await FirestoreService.instance
          .collection('EngineerLogin', tenantId: tenantId)
          .where('Username', isEqualTo: widget.userName)
          .get();

      if (doc.docs.isNotEmpty && mounted) {
        setState(() {
          _isOnline = doc.docs.first.data()['isOnline'] ?? false;
        });
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final tenantId = await SharedPreferences.getInstance().then(
      (p) => p.getString('tenantId'),
    );
    if (tenantId != null) {
      setState(() => _isOnline = value);

      // Start/Stop location tracking based on online status
      if (value) {
        await LocationService.instance.startTracking(widget.userName);
      } else {
        await LocationService.instance.stopTracking(widget.userName);
      }

      await FirestoreService.instance.updateEngineerStatus(
        tenantId: tenantId,
        username: widget.userName,
        isOnline: value,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _notificationSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  void _listenToNotifications() {
    try {
      final query = FirestoreService.instance
          .collection('notifications')
          .where('engineerName', isEqualTo: widget.userName)
          .where('audience', isEqualTo: 'engineer')
          .where('processed', isEqualTo: false)
          .snapshots();

      _notificationSubscription = query.listen(
        (snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;

              final docId = change.doc.id;
              final bookingId = data['bookingId']?.toString() ?? '';
              if (bookingId.isNotEmpty) {
                _checkTicketStatusAndNotify(bookingId, data, docId);
              }
            }
          }
        },
        onError: (e) {
          print('Notifications listener error: $e');
        },
      );
    } catch (e) {
      print('Error starting notifications listener: $e');
    }
  }

  Future<void> _checkTicketStatusAndNotify(
    String bookingId,
    Map<String, dynamic> data,
    String docId,
  ) async {
    try {
      final doc = await FirestoreService.instance
          .collection('Admin_details')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        final ticketData = doc.data();
        final engineerStatus = ticketData?['engineerStatus'] ?? '';

        // Only show notification if status is "Assigned" (not "Completed")
        if (engineerStatus == 'Assigned') {
          // Show dialog with bookingId and customerName (uses existing helper)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNotificationDialog({
              'type': data['type'] ?? 'notification',
              'bookingId': bookingId,
              'body': data['body'] ?? '',
            });
          });

          // Optionally mark as processed to avoid re-processing (non-blocking)
          try {
            FirestoreService.instance
                .collection('notifications')
                .doc(docId)
                .update({'processed': true});
          } catch (e) {
            // ignore
          }
        }
      }
    } catch (e) {
      print('Error checking ticket status: $e');
    }
  }

  void _setupFCMListeners() {
    // Listen for foreground messages
    _fcmSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      print('Received FCM message: ${message.messageId}');
      if (message.data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNotificationDialog({
            'type': message.data['type'] ?? 'notification',
            'customerName': message.data['customerName'] ?? '',
            'bookingId': message.data['bookingId'] ?? '',
            'body': message.notification?.body ?? '',
          });
        });
      }
    });

    // Handle when app is opened from terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });

    // Handle when app is opened from background state via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle navigation or actions based on notification type
    if (data['type'] == 'new_assignment') {
      // Could navigate to specific booking or refresh the list
      print('Notification tapped for assignment: ${data['bookingId']}');
    }
  }

  void _handleInitialNotification() {
    if (widget.notificationData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationDialog(widget.notificationData!);
      });
    }
  }

  void _showNotificationDialog(Map<String, dynamic> data) async {
    NotificationService.instance.showNotification(
      title: data['type'] == 'new_assignment'
          ? 'New Assignment'
          : 'Notification',
      body: data['type'] == 'new_assignment'
          ? 'You have been assigned a new task (ID: ${data['bookingId']})'
          : data['body'] ?? 'You have a new notification',
      data: data.map((key, value) => MapEntry(key, value.toString())),
    );

    // Show dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primary(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: ProfessionalTheme.primary(context),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['type'] == 'new_assignment'
                    ? 'New Assignment'
                    : 'Notification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              if (data['type'] == 'new_assignment') ...[
                // const SizedBox(height: 8, width: 8),
                // _buildNotificationItem('Customer', data['customerName']),
                // const SizedBox(height: 8),
                _buildNotificationItem('Booking ID', data['bookingId']),
              ],
              if (data['body'] != null) ...[
                const SizedBox(height: 8),
                _buildNotificationItem('Message', data['body']),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProfessionalTheme.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Got It',
                    style: TextStyle(
                      color: ProfessionalTheme.textInverse(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProfessionalTheme.surfaceElevated(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ProfessionalTheme.borderLight(context)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ProfessionalTheme.textSecondary(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: ProfessionalTheme.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ProfessionalTheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout,
                  color: ProfessionalTheme.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ProfessionalTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: ProfessionalTheme.borderMedium(context),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: ProfessionalTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _performLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: ProfessionalTheme.textInverse(context),
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
    );
  }

  void _performLogout() async {
    await LocationService.instance.stopTracking(widget.userName);
    if (mounted) {
      Navigator.pop(context);
    }
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getString('tenantId');
    if (tenantId != null) {
      await FirestoreService.instance.updateEngineerStatus(
        tenantId: tenantId,
        username: widget.userName,
        isOnline: false,
      );
    }

    await prefs.remove('engineerEmail');
    await prefs.remove('engineerName');
    await AuthStateService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ProfessionalTheme.background(context),
      endDrawer: ProfessionalNavigationDrawer(
        userName: widget.userName,
        userEmail: widget.userEmail,
        onLogout: _showLogoutConfirmation,
        currentSection: _currentSection,
        onSectionChange: (section) {
          setState(() {
            _currentSection = section;
          });
        },
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              expandedHeight: 140,
              collapsedHeight: 64,
              floating: true,
              pinned: true,
              backgroundColor: ProfessionalTheme.primary(context),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: AnimatedOpacity(
                  duration: ProfessionalAnimations.quick,
                  opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                  child: Text(
                    _currentSection == 'completed'
                        ? 'Completed Tickets'
                        : 'Engineer Dashboard',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ProfessionalTheme.primary(context),
                            ProfessionalTheme.primaryDark(context),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 20,
                      right: 20,
                      child: Row(
                        children: [
                          if (ThemeService.instance.logoUrl != null)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(
                                  ThemeService.instance.logoUrl!,
                                ),
                              ),
                            ),
                          if (ThemeService.instance.logoUrl != null)
                            const SizedBox(width: 12),
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
                                const SizedBox(height: 2),
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
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
                  ],
                ),
              ),
              actions: [
                // Online/Offline Toggle
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOnline
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          size: 16,
                          color: _isOnline
                              ? Colors.greenAccent
                              : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: Switch(
                              value: _isOnline,
                              onChanged: _toggleOnlineStatus,
                              activeThumbColor: Colors.greenAccent,
                              activeTrackColor: Colors.white24,
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: Colors.white12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8, left: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ),
              ],
            ),
          ];
        },
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_details')
          .where('assignedEmployee', isEqualTo: widget.userName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const ProfessionalLoadingSpinner();
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          _isLoading = false;
          return _buildEmptyState();
        }

        // Process data based on current section
        if (_isLoading ||
            snapshot.data!.docs.length != _allBookings.length ||
            _hasDataChanged(snapshot.data!.docs)) {
          // Get all bookings assigned to this engineer
          var allBookings = snapshot.data!.docs
              .map((doc) => AdminDetails.fromFirestore(doc))
              .toList();

          // Filter based on current section
          if (_currentSection == 'completed') {
            _allBookings = allBookings
                .where(
                  (booking) =>
                      booking.selectedStatus.toLowerCase() == 'completed',
                )
                .toList();
          } else {
            // Dashboard shows all non-completed tickets
            _allBookings = allBookings
                .where(
                  (booking) =>
                      booking.selectedStatus.toLowerCase() != 'completed',
                )
                .toList();
          }

          _allBookings.sort((a, b) => b.bookingId.compareTo(a.bookingId));
          _applyFilters();
          _isLoading = false;
        }

        return Column(
          children: [
            // Search and Filter Section (only show in dashboard)
            if (_currentSection == 'dashboard') ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildStatusFilterChips(),
                  ],
                ),
              ),
            ] else ...[
              // Completed Tickets Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ProfessionalTheme.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ProfessionalTheme.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in,
                        color: ProfessionalTheme.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed Tickets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ProfessionalTheme.success,
                              ),
                            ),
                            Text(
                              'View all successfully completed service tickets',
                              style: TextStyle(
                                fontSize: 12,
                                color: ProfessionalTheme.success.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Results Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredBookings.length} ${_filteredBookings.length == 1 ? 'ticket' : 'tickets'} ${_currentSection == 'completed' ? 'completed' : 'assigned'}',
                    style: TextStyle(
                      color: ProfessionalTheme.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Bookings List
            Expanded(child: _buildSearchResults()),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_currentSection == 'completed') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: ProfessionalTheme.surface(context),
                  shape: BoxShape.circle,
                  boxShadow: ProfessionalTheme.cardShadow,
                  border: Border.all(
                    color: ProfessionalTheme.borderLight(context),
                  ),
                ),
                child: Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: ProfessionalTheme.textTertiary(context),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Completed Tickets',
                style: TextStyle(
                  fontSize: 20,
                  color: ProfessionalTheme.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Completed service tickets will appear here automatically',
                style: TextStyle(
                  fontSize: 14,
                  color: ProfessionalTheme.textSecondary(context),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      return const ProfessionalEmptyState();
    }
  }

  bool _hasDataChanged(List<DocumentSnapshot> newDocs) {
    if (_allBookings.length != newDocs.length) return true;

    for (int i = 0; i < newDocs.length; i++) {
      final newData = newDocs[i].data() as Map<String, dynamic>;
      final oldBooking = _allBookings[i];

      if (newData['bookingId'] != oldBooking.bookingId ||
          newData['engineerStatus'] != oldBooking.selectedStatus) {
        return true;
      }
    }

    return false;
  }

  Widget _buildSearchResults() {
    if (_filteredBookings.isEmpty) {
      if (_searchQuery.isNotEmpty || _statusFilter != null) {
        return _buildNoResults();
      }
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBookings.length,
      itemBuilder: (context, index) {
        var booking = _filteredBookings[index];
        TextEditingController descriptionController = TextEditingController(
          text: booking.description,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProfessionalBookingCard(
            key: ValueKey(booking.bookingId),
            booking: booking,
            descriptionController: descriptionController,
            index: index,
            userName: widget.userName,
            isCompletedSection: _currentSection == 'completed',
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: ProfessionalTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: ProfessionalTheme.textPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search by Booking ID or Customer...',
          hintStyle: TextStyle(
            color: ProfessionalTheme.textTertiary(context),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: ProfessionalTheme.primary(context),
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: ProfessionalTheme.textTertiary(context),
                    size: 20,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Start new timer
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
          _applyFilters();
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (_allBookings.isEmpty) return;

    _filteredBookings = _allBookings.where((b) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          b.bookingId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == null || _statusFilter!.isEmpty
          ? true
          : b.selectedStatus == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _buildStatusFilterChips() {
    final statuses = [
      'Assigned', // Add this new status
      'Pending for Approval',
      'Pending for Spares',
      'Under Observation',
      'Delivered',
      // 'Completed', // Remove this as requested
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final isSelected = _statusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_shortenStatus(status)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _statusFilter = selected ? status : null;
                  _applyFilters();
                });
              },
              backgroundColor: ProfessionalTheme.surface(context),
              selectedColor: ProfessionalTheme.primary(
                context,
              ).withOpacity(0.1),
              checkmarkColor: ProfessionalTheme.primary(context),
              labelStyle: TextStyle(
                color: isSelected
                    ? ProfessionalTheme.primary(context)
                    : ProfessionalTheme.textSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? ProfessionalTheme.primary(context)
                      : ProfessionalTheme.borderLight(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: ProfessionalTheme.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              color: ProfessionalTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: TextStyle(color: ProfessionalTheme.textTertiary(context)),
          ),
        ],
      ),
    );
  }

  String _shortenStatus(String status) {
    const shortMap = {
      'Pending for Approval': 'Pending',
      'Pending for Spares': 'Spares',
      'Under Observation': 'Observation',
      'Assigned': 'Assigned',
    };
    return shortMap[status] ?? status;
  }
}

// Professional Booking Card
class ProfessionalBookingCard extends StatefulWidget {
  final AdminDetails booking;
  final TextEditingController descriptionController;
  final int index;
  final String userName;
  final bool isCompletedSection;

  const ProfessionalBookingCard({
    super.key,
    required this.booking,
    required this.descriptionController,
    required this.index,
    required this.userName,
    this.isCompletedSection = false,
  });

  @override
  _ProfessionalBookingCardState createState() =>
      _ProfessionalBookingCardState();
}

class _ProfessionalBookingCardState extends State<ProfessionalBookingCard> {
  bool _isExpanded = false;
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _imageFiles = [];
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _otherPaymentController = TextEditingController();
  bool _isPickingImages = false;
  bool _isReadOnly = false;
  bool _isUploading = false;
  String _currentStatus = '';
  String _selectedPaymentType = 'Cash';
  String _selectedPaymentMethod = 'Visiting Charge';
  List<Map<String, dynamic>> _payments = [];
  double? _capturedLat;
  double? _capturedLng;
  DateTime? _capturedTimestamp;
  bool _isLoadingLocation = false;

  Future<void> _logManualLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _capturedLat = position.latitude;
        _capturedLng = position.longitude;
        _capturedTimestamp = DateTime.now();
      });
      _showSnackBar('Location captured!', ProfessionalTheme.success);
    } catch (e) {
      _showSnackBar('Error capturing location: $e', ProfessionalTheme.error);
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.booking.amount;
    _currentStatus = widget.booking.selectedStatus;
    _selectedPaymentType = widget.booking.paymentType.isNotEmpty
        ? ([
                'Cash',
                'UPI Transaction',
                'Cheque',
                'Net Banking',
                'Others',
              ].contains(widget.booking.paymentType)
              ? widget.booking.paymentType
              : 'Others')
        : 'Cash';
    if (_selectedPaymentType == 'Others') {
      _otherPaymentController.text = widget.booking.paymentType;
    }

    _loadExistingPayments();
    _updateReadOnlyStatus();
  }

  void _loadExistingPayments() {
    FirestoreService.instance
        .collection('Admin_details')
        .where('bookingId', isEqualTo: widget.booking.bookingId)
        .get()
        .then((query) {
          if (query.docs.isNotEmpty) {
            var data = query.docs.first.data();
            if (data.containsKey('payments') && data['payments'] is List) {
              try {
                List paymentsList = data['payments'];
                final parsed = paymentsList
                    .map<Map<String, dynamic>>((p) {
                      if (p is Map) return Map<String, dynamic>.from(p);
                      return {};
                    })
                    .where((m) => m.isNotEmpty)
                    .toList();

                setState(() {
                  _payments = parsed;
                });
                _recomputeTotalAmountFromPayments();
              } catch (_) {}
            }
          }
        });
  }

  void _recomputeTotalAmountFromPayments() {
    if (_payments.isEmpty) return;
    final total = _payments.fold<num>(0, (sum, p) {
      final v = p['amount'];
      if (v is num) return sum + v;
      if (v is String) return sum + (double.tryParse(v) ?? 0);
      return sum;
    }).toDouble();

    _amountController.text = total.toStringAsFixed(2);
    widget.booking.amount = _amountController.text;
  }

  void _updateReadOnlyStatus() {
    // Check if the job was previously completed
    final bool wasCompleted =
        widget.booking.selectedStatus.toLowerCase() == 'completed';

    setState(() {
      // Job becomes read-only if:
      // 1. It was previously completed (already closed before opening)
      // 2. The current selection is Completed (so after a successful update we lock it)
      // 3. It was canceled
      // 4. We're in the completed tickets section
      _isReadOnly =
          wasCompleted ||
          _currentStatus.toLowerCase() == 'completed' ||
          widget.booking.isCanceled ||
          widget.isCompletedSection;

      // If the job was previously completed or current status is completed,
      // force the status to remain completed
      if (wasCompleted || _currentStatus.toLowerCase() == 'completed') {
        _currentStatus = 'Completed';
      }
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _pickImages() async {
    if (_isPickingImages || _isReadOnly) return;

    setState(() {
      _isPickingImages = true;
    });

    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _imageFiles = selectedImages.length <= 3
              ? selectedImages
              : selectedImages.sublist(0, 3);
        });
      }
    } finally {
      setState(() {
        _isPickingImages = false;
      });
    }
  }

  Future<List<String>> _uploadImages(List<XFile> imageFiles) async {
    List<String> downloadUrls = [];
    for (var imageFile in imageFiles) {
      try {
        final downloadUrl = await StorageService.instance.uploadWorkerImage(
          userName: widget.userName,
          file: File(imageFile.path),
        );
        if (downloadUrl != null) {
          downloadUrls.add(downloadUrl);
        }
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    return downloadUrls;
  }

  void _addPayment() {
    if (_isReadOnly) return;

    String paymentTypeToSave = _selectedPaymentType == 'Others'
        ? _otherPaymentController.text.trim()
        : _selectedPaymentType;

    String method = _selectedPaymentMethod;
    String amtText = _paymentAmountController.text.trim();

    if (paymentTypeToSave.isEmpty || method.isEmpty || amtText.isEmpty) {
      _showSnackBar(
        'Please select payment method and enter amount',
        ProfessionalTheme.error,
      );
      return;
    }

    double? amt = double.tryParse(amtText);
    if (amt == null) {
      _showSnackBar('Enter a valid amount', ProfessionalTheme.error);
      return;
    }

    Map<String, dynamic> paymentEntry = {
      'paymentType': paymentTypeToSave,
      'paymentMethod': method,
      'amount': amt,
      'addedBy': widget.userName,
      'addedAt': Timestamp.now(),
    };

    setState(() {
      _payments.add(paymentEntry);
      _paymentAmountController.clear();
    });

    _recomputeTotalAmountFromPayments();
    _showSnackBar('Payment added to list', ProfessionalTheme.success);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _performUpdate() async {
    String paymentTypeToSave = _selectedPaymentType == 'Others'
        ? _otherPaymentController.text.trim()
        : _selectedPaymentType;

    if (_currentStatus.isEmpty ||
        widget.descriptionController.text.trim().isEmpty) {
      _showSnackBar(
        'Status and Status Description are required!',
        ProfessionalTheme.error,
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primary(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.update,
                  color: ProfessionalTheme.primary(context),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm Update',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to update this job with the current information?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ProfessionalTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: ProfessionalTheme.borderMedium(context),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: ProfessionalTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalTheme.primary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          color: ProfessionalTheme.textInverse(context),
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
    );

    if (confirm == true) {
      setState(() => _isUploading = true);
      try {
        List<String> newImageUrls = await _uploadImages(_imageFiles ?? []);
        List<String> allImageUrls = [
          ...widget.booking.imageUrls,
          ...newImageUrls,
        ];

        var query = await FirestoreService.instance
            .collection('Admin_details')
            .where('bookingId', isEqualTo: widget.booking.bookingId)
            .get();

        for (var doc in query.docs) {
          Map<String, dynamic> updateData = {
            'engineerStatus': _currentStatus,
            'description': widget.descriptionController.text,
            'amount': double.tryParse(_amountController.text.trim()) ?? 0,
            'imageUrls': allImageUrls,
            'lastUpdated': FieldValue.serverTimestamp(),
            'PaymentType': paymentTypeToSave,
            'lastUpdatedBy': widget.userName,
          };

          // Payments: Use Timestamp.now() for nested timestamps
          if (_payments.isNotEmpty) {
            updateData['payments'] = _payments.map((p) {
              return {
                ...p,
                'addedAt': Timestamp.now(), // Use Timestamp.now() here
              };
            }).toList();
          }

          // Status history tracking: Use Timestamp.now() for nested
          updateData['statusHistory'] = [
            {
              'status': _currentStatus,
              'timestamp': Timestamp.now(), // Use Timestamp.now() here
              'updatedBy': widget.userName,
            },
          ];

          // If status is completed, set both engineerStatus and adminStatus
          if (_currentStatus.toLowerCase() == 'completed') {
            updateData['engineerStatus'] = 'Completed';
            // updateData['adminStatus'] = 'Closed';
            updateData['completedAt'] = FieldValue.serverTimestamp();
            updateData['completedBy'] = widget.userName;
          }

          await doc.reference.set(updateData, SetOptions(merge: true));
        }

        await FirestoreService.instance
            .collection('Engineer_updates')
            .doc(widget.booking.bookingId.trim())
            .set({
              'bookingId': widget.booking.bookingId,
              'PaymentType': paymentTypeToSave,
              'engineerStatus': _currentStatus,
              'statusDescription': widget.descriptionController.text.trim(),
              'amount': double.tryParse(_amountController.text.trim()) ?? 0,
              'updatedBy': widget.userName,
              'updatedAt': FieldValue.serverTimestamp(),
              'imageUrls': allImageUrls,
              'payments': _payments
                  .map((p) => {...p, 'addedAt': Timestamp.now()})
                  .toList(),
              'lat': _capturedLat,
              'lng': _capturedLng,
            }, SetOptions(merge: true));

        _showSnackBar('Job updated successfully!', ProfessionalTheme.success);

        setState(() {
          _imageFiles = [];
          widget.booking.imageUrls = allImageUrls;
          widget.booking.selectedStatus = _currentStatus;
          widget.booking.paymentType = paymentTypeToSave;
          _payments = [];

          // If engineer marked the job as Completed and update succeeded,
          // make the form read-only immediately and update UI accordingly.
          _isReadOnly =
              _currentStatus.toLowerCase() == 'completed' ||
              widget.booking.isCanceled ||
              widget.isCompletedSection;
          // Keep the existing centralized logic in case other rules apply.
          _updateReadOnlyStatus();
        });
      } catch (e, stack) {
        String errorType = e.runtimeType.toString();
        String errorMsg = e.toString();
        String stackMsg = stack.toString().split('\n').first;
        _showSnackBar(
          'Failed to update job [$errorType]: $errorMsg\n$stackMsg',
          ProfessionalTheme.error,
        );
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _makePhoneCall() async {
    String phone = widget.booking.mobileNumber.trim().replaceAll(' ', '');
    if (!phone.startsWith('+91')) {
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      phone = '+91$phone';
    }
    final Uri dialUri = Uri(scheme: 'tel', path: phone);
    try {
      if (!await launchUrl(dialUri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('Could not launch dialer', ProfessionalTheme.error);
      }
    } catch (e) {
      _showSnackBar('Could not launch dialer: $e', ProfessionalTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ProfessionalAnimations.medium,
      curve: ProfessionalAnimations.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ProfessionalTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Index Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ProfessionalTheme.primary(context),
                          ProfessionalTheme.primaryDark(context),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: ProfessionalTheme.primary(
                            context,
                          ).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          color: ProfessionalTheme.textInverse(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info Area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.booking.bookingId,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ProfessionalTheme.textSecondary(context),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            _buildStatusChip(_currentStatus),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.booking.customerName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ProfessionalTheme.textPrimary(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 14,
                              color: ProfessionalTheme.textTertiary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.booking.deviceBrand} • ${widget.booking.deviceType}',
                              style: TextStyle(
                                fontSize: 13,
                                color: ProfessionalTheme.textSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDaysInfo(),
                      ],
                    ),
                  ),
                ],
              ),

              if (widget.booking.isCanceled) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ProfessionalTheme.errorLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ProfessionalTheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel,
                        size: 16,
                        color: ProfessionalTheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.booking.cancellationMessage,
                          style: TextStyle(
                            color: ProfessionalTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Expandable Content
              if (_isExpanded) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                _buildSectionHeader('Job Details', Icons.info_outline),
                const SizedBox(height: 12),
                _buildDetailsSection(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Status Management',
                  Icons.assignment_outlined,
                ),
                const SizedBox(height: 12),
                _buildStatusSection(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Update Description',
                  Icons.description_outlined,
                ),
                const SizedBox(height: 12),
                _buildDescriptionSection(),
                const SizedBox(height: 24),
                _buildSectionHeader('Payments', Icons.payments_outlined),
                const SizedBox(height: 12),
                _buildPaymentSection(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Completion Photos',
                  Icons.photo_library_outlined,
                ),
                const SizedBox(height: 12),
                _buildImageSection(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],

              // Expand/Collapse Label
              const SizedBox(height: 12),
              Center(
                child: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ProfessionalTheme.textTertiary(context),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ProfessionalTheme.primary(context)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: ProfessionalTheme.sectionHeader(context),
        ),
      ],
    );
  }

  Widget _buildDaysInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ProfessionalTheme.infoLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ProfessionalTheme.info(context).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 12,
            color: ProfessionalTheme.info(context),
          ),
          const SizedBox(width: 4),
          Text(
            widget.booking.daysDisplayText,
            style: TextStyle(
              fontSize: 12,
              color: ProfessionalTheme.info(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final statusConfig = {
      'Completed': {
        'color': ProfessionalTheme.success,
        'icon': Icons.check_circle_outline,
        'text': 'Completed',
      },
      'Assigned': {
        'color': ProfessionalTheme.success,
        'icon': Icons.assignment_ind_outlined,
        'text': 'Assigned',
      },
      'Pending for Approval': {
        'color': const Color(0xFF9C27B0), // Purple
        'icon': Icons.hourglass_empty_rounded,
        'text': 'Pending',
      },
      'Pending for Spares': {
        'color': Colors.amber, // Amber
        'icon': Icons.settings_input_component_outlined,
        'text': 'Spares',
      },
      'Under Observation': {
        'color': Colors.cyan, // Cyan
        'icon': Icons.visibility_outlined,
        'text': 'Observation',
      },
      'Order Taken': {
        'color': const Color(
          0xFF8B5CF6,
        ), // Violet - keeping as is if not in palette
        'icon': Icons.handshake_outlined,
        'text': 'Order Taken',
      },
      'Order Received': {
        'color': const Color(
          0xFFEC4899,
        ), // Pink - keeping as is if not in palette
        'icon': Icons.inventory_2_outlined,
        'text': 'Received',
      },
    };

    final config =
        statusConfig[status] ??
        {
          'color': ProfessionalTheme.textSecondary(context),
          'icon': Icons.help_outline,
          'text': status,
        };

    final color = config['color'] as Color;
    final text = config['text'] as String;
    final icon = config['icon'] as IconData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      decoration: BoxDecoration(
        color: ProfessionalTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ProfessionalTheme.borderLight(context).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          _buildEnhancedDetailRow(
            label: 'Address',
            value: widget.booking.address,
            icon: Icons.location_on_outlined,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: widget.booking.address));
              _showSnackBar(
                'Address copied to clipboard',
                ProfessionalTheme.info(context),
              );
            },
          ),
          Divider(height: 1, color: ProfessionalTheme.borderLight(context)),
          _buildEnhancedDetailRow(
            label: 'Mobile',
            value: widget.booking.mobileNumber,
            icon: Icons.phone_android_outlined,
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: widget.booking.mobileNumber),
              );
              _showSnackBar(
                'Phone number copied',
                ProfessionalTheme.info(context),
              );
            },
          ),
          Divider(height: 1, color: ProfessionalTheme.borderLight(context)),
          _buildEnhancedDetailRow(
            label: 'Condition',
            value: widget.booking.deviceCondition,
            icon: Icons.build_circle_outlined,
          ),
          Divider(height: 1, color: ProfessionalTheme.borderLight(context)),
          _buildEnhancedDetailRow(
            label: 'Assigned',
            value: widget.booking.assignedDateTimeFormatted,
            icon: Icons.event_available_outlined,
          ),
          if (widget.booking.selectedStatus.toLowerCase() == 'completed' &&
              widget.booking.completionMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ProfessionalTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 16,
                    color: ProfessionalTheme.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.booking.completionMessage,
                      style: const TextStyle(
                        color: ProfessionalTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildEnhancedDetailRow({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ProfessionalTheme.primary(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: ProfessionalTheme.primary(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ProfessionalTheme.textSecondary(context),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ProfessionalTheme.textPrimary(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: Icon(
                Icons.copy_rounded,
                size: 16,
                color: ProfessionalTheme.textTertiary(context),
              ),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final allowedStatuses = [
      'Completed',
      'Assigned',
      'Order Taken',
      'Order Received',
      'Pending for Approval',
      'Pending for Spares',
      'Under Observation',
    ];

    String? dropdownValue = allowedStatuses.contains(_currentStatus)
        ? _currentStatus
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: ProfessionalTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProfessionalTheme.borderLight(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.swap_horiz_rounded,
                color: ProfessionalTheme.primary(context),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
            dropdownColor: ProfessionalTheme.surface(context),
            style: TextStyle(
              fontSize: 14,
              color: ProfessionalTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
            items: allowedStatuses.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: _isReadOnly || widget.booking.isCanceled
                ? null
                : (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentStatus = newValue;
                      });
                    }
                  },
          ),
        ),
        if (widget.booking.isCanceled) ...[
          const SizedBox(height: 8),
          Text(
            widget.booking.cancellationMessage,
            style: TextStyle(
              fontSize: 12,
              color: ProfessionalTheme.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        // Manual Location Log Button
        if (_currentStatus == 'Order Taken' ||
            _currentStatus == 'Order Received') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingLocation ? null : _logManualLocation,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: ProfessionalTheme.primary(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _isLoadingLocation
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ProfessionalTheme.primary(context),
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: ProfessionalTheme.primary(context),
                    ),
              label: Text(
                _isLoadingLocation ? 'Logging...' : 'Log Current Location',
                style: TextStyle(
                  color: ProfessionalTheme.primary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // Display Captured Location
        if (_capturedLat != null && _capturedLng != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latitude',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ProfessionalTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ProfessionalTheme.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ProfessionalTheme.borderLight(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 16,
                            color: ProfessionalTheme.textTertiary(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _capturedLat!.toStringAsFixed(6),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ProfessionalTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Longitude',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ProfessionalTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ProfessionalTheme.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ProfessionalTheme.borderLight(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 16,
                            color: ProfessionalTheme.textTertiary(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _capturedLng!.toStringAsFixed(6),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ProfessionalTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Status Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ProfessionalTheme.textPrimary(context),
              ),
            ),
            const SizedBox(width: 4),
            Text('*', style: TextStyle(color: ProfessionalTheme.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.descriptionController,
          maxLines: 4,
          minLines: 3,
          enabled: !_isReadOnly,
          decoration: InputDecoration(
            hintText:
                'Describe the current status, issues found, or work completed...',
            hintStyle: TextStyle(
              color: ProfessionalTheme.textTertiary(context),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ProfessionalTheme.borderLight(context),
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: TextStyle(
            fontSize: 14,
            color: ProfessionalTheme.textPrimary(context),
          ),
          onChanged: (value) {
            if (!_isReadOnly) {
              widget.booking.description = value;
            }
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final paymentTypes = [
      'Cash',
      'UPI Transaction',
      'Check',
      'Net Banking',
      'Others',
      'No Payment',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ProfessionalTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),

        // Payment Type
        Text(
          'Payment Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ProfessionalTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ProfessionalTheme.borderLight(context)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPaymentType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: ProfessionalTheme.surface(context),
            ),
            dropdownColor: ProfessionalTheme.surface(context),
            style: TextStyle(
              fontSize: 14,
              color: ProfessionalTheme.textPrimary(context),
            ),
            items: paymentTypes.map((String type) {
              return DropdownMenuItem<String>(value: type, child: Text(type));
            }).toList(),
            onChanged: _isReadOnly
                ? null
                : (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPaymentType = newValue;
                        if (_selectedPaymentType != 'Others') {
                          _otherPaymentController.clear();
                        }
                      });
                    }
                  },
            icon: Icon(
              Icons.arrow_drop_down,
              color: ProfessionalTheme.textTertiary(context),
            ),
          ),
        ),

        if (_selectedPaymentType == 'Others') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otherPaymentController,
            enabled: !_isReadOnly,
            decoration: InputDecoration(
              labelText: 'Specify Payment Type',
              labelStyle: TextStyle(
                color: ProfessionalTheme.textTertiary(context),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: ProfessionalTheme.borderLight(context),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: ProfessionalTheme.textPrimary(context),
            ),
          ),
        ],

        if (_selectedPaymentType == 'UPI Transaction') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showQRCodeDialog(),
            icon: Icon(
              Icons.qr_code,
              color: ProfessionalTheme.primary(context),
            ),
            label: Text(
              'Show QR Code',
              style: TextStyle(color: ProfessionalTheme.primary(context)),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: ProfessionalTheme.borderMedium(context)),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 109,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        _buildPaymentMethodSection(),
        const SizedBox(height: 16),
        _buildAmountField(),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    final methods = ['Visiting Charge', 'Spare Charge', 'Service Charge'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfessionalTheme.surfaceElevated(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ProfessionalTheme.borderLight(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Payment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ProfessionalTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: methods.map((m) {
              return Row(
                children: [
                  Radio<String>(
                    value: m,
                    groupValue: _selectedPaymentMethod,
                    onChanged: _isReadOnly
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() {
                                _selectedPaymentMethod = v;
                              });
                            }
                          },
                  ),
                  Flexible(
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 16,
                        color: ProfessionalTheme.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _paymentAmountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  enabled: !_isReadOnly && _selectedPaymentType != 'No Payment',
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Amount',
                    hintStyle: TextStyle(
                      color: ProfessionalTheme.textTertiary(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: ProfessionalTheme.borderLight(context),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isReadOnly || _selectedPaymentType == 'No Payment'
                    ? null
                    : _addPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProfessionalTheme.primary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    color: ProfessionalTheme.textInverse(context),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPaymentsTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Added Payments',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ProfessionalTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ..._payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ProfessionalTheme.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ProfessionalTheme.borderLight(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment['paymentType'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ProfessionalTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        payment['paymentMethod'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: ProfessionalTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${payment['amount']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalTheme.primary(context),
                  ),
                ),
                if (!_isReadOnly) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _payments.removeAt(index);
                        _recomputeTotalAmountFromPayments();
                      });
                    },
                    child: Icon(
                      Icons.delete,
                      size: 18,
                      color: ProfessionalTheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ProfessionalTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          readOnly: true,
          enabled: _selectedPaymentType != 'No Payment',
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '0.00',
            hintStyle: TextStyle(
              color: ProfessionalTheme.textTertiary(context),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ProfessionalTheme.borderLight(context),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            helperText: 'Auto-calculated from added payments',
            helperStyle: TextStyle(
              color: ProfessionalTheme.textTertiary(context),
              fontSize: 12,
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ProfessionalTheme.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHOTOS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ProfessionalTheme.textSecondary(context),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Max 3 images required',
                  style: TextStyle(
                    fontSize: 11,
                    color: ProfessionalTheme.textTertiary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            if (!_isReadOnly && (_imageFiles?.length ?? 0) < 3)
              TextButton.icon(
                onPressed: _isPickingImages ? null : _pickImages,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add Photo'),
                style: TextButton.styleFrom(
                  foregroundColor: ProfessionalTheme.primary(context),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_imageFiles != null && _imageFiles!.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imageFiles!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = _imageFiles![index];
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(File(image.path)),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (!_isReadOnly)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _imageFiles!.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: ProfessionalTheme.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        else if (_isReadOnly && widget.booking.imageUrls.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ProfessionalTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ProfessionalTheme.borderLight(context).withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  color: ProfessionalTheme.textTertiary(context),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'No photos uploaded',
                  style: TextStyle(
                    color: ProfessionalTheme.textTertiary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else if (!_isReadOnly)
          GestureDetector(
            onTap: _isPickingImages ? null : _pickImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: ProfessionalTheme.primary(context).withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ProfessionalTheme.primary(context).withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: ProfessionalTheme.primary(context),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to capture or upload photos',
                    style: TextStyle(
                      color: ProfessionalTheme.primary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload up to 3 high-quality job photos',
                    style: TextStyle(
                      color: ProfessionalTheme.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Existing Uploaded Images Section
        if (widget.booking.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'UPLOADED JOB PHOTOS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ProfessionalTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.booking.imageUrls.map((imageUrl) {
              return GestureDetector(
                onTap: () => _showFullImage(imageUrl),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ProfessionalTheme.borderMedium(context),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            color: ProfessionalTheme.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: ProfessionalTheme.primary(context),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: ProfessionalTheme.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: ProfessionalTheme.textTertiary(context),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showQRCodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final maxWidth = size.width * 0.85;
        final maxHeight = size.height * 0.85;
        final qrSize = maxWidth < 400
            ? (maxWidth * 0.6).clamp(200.0, 300.0)
            : 300.0;
        final padding = size.width < 400 ? 16.0 : 24.0;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon header
                    Container(
                      width: qrSize * 0.2,
                      height: qrSize * 0.2,
                      decoration: BoxDecoration(
                        color: ProfessionalTheme.primary(
                          context,
                        ).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code,
                        color: ProfessionalTheme.primary(context),
                        size: qrSize * 0.1,
                      ),
                    ),
                    SizedBox(height: padding * 0.67),
                    Text(
                      'UPI QR Code',
                      style: TextStyle(
                        fontSize: size.width < 400 ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: ProfessionalTheme.textPrimary(context),
                      ),
                    ),
                    SizedBox(height: padding * 0.5),
                    Text(
                      'Scan this QR code to make payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ProfessionalTheme.textSecondary(context),
                        fontSize: size.width < 400 ? 12 : 14,
                      ),
                    ),
                    SizedBox(height: padding),
                    // Dynamic QR from Firebase Storage
                    FutureBuilder<String?>(
                      future: StorageService.instance.getQRCodeUrl(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            width: qrSize,
                            height: qrSize,
                            decoration: BoxDecoration(
                              color: ProfessionalTheme.surfaceElevated(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ProfessionalTheme.borderLight(context),
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: ProfessionalTheme.primary(context),
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasData && snapshot.data != null) {
                          return Container(
                            width: qrSize,
                            height: qrSize,
                            decoration: BoxDecoration(
                              color: ProfessionalTheme.surfaceElevated(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ProfessionalTheme.borderLight(context),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: ProfessionalTheme.primary(
                                            context,
                                          ),
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                errorBuilder: (_, __, ___) => Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: ProfessionalTheme.textTertiary(
                                          context,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load QR code',
                                        style: TextStyle(
                                          color:
                                              ProfessionalTheme.textSecondary(
                                                context,
                                              ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        // No QR uploaded yet
                        return Container(
                          width: qrSize,
                          height: qrSize,
                          decoration: BoxDecoration(
                            color: ProfessionalTheme.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ProfessionalTheme.borderLight(context),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_2_outlined,
                                  size: 56,
                                  color: ProfessionalTheme.textTertiary(
                                    context,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No QR code available.',
                                  style: TextStyle(
                                    color: ProfessionalTheme.textSecondary(
                                      context,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please ask admin to upload one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ProfessionalTheme.textTertiary(
                                      context,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: padding),
                    SizedBox(
                      width: qrSize * 0.5,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfessionalTheme.primary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: padding,
                            vertical: padding * 0.5,
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: ProfessionalTheme.textInverse(context),
                            fontSize: size.width < 400 ? 14 : 16,
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
      },
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: ProfessionalTheme.elevatedShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.network(imageUrl),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _toggleExpanded,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: ProfessionalTheme.borderMedium(context)),
            ),
            child: Text('Show Less'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _makePhoneCall,
          style: IconButton.styleFrom(
            backgroundColor: ProfessionalTheme.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            Icons.call,
            color: ProfessionalTheme.textInverse(context),
            size: 20,
          ),
        ),
        if (!_isReadOnly && !widget.booking.isCanceled) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _performUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfessionalTheme.primary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      Icons.update,
                      size: 16,
                      color: ProfessionalTheme.textInverse(context),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading ? 'Updating...' : 'Update Job',
                    style: TextStyle(
                      color: ProfessionalTheme.textInverse(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
