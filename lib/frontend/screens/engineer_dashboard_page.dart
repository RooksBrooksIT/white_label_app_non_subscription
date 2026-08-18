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
import 'package:subscription_rooks_app/services/attendance_service.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_edit_profile_screen.dart';
import 'package:subscription_rooks_app/services/app_tour_service.dart';
import 'package:subscription_rooks_app/widgets/interactive_tour/tour_step_model.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ProfessionalTheme {
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color primaryDark(BuildContext context) =>
      Theme.of(context).primaryColor;
  static Color primaryLight(BuildContext context) =>
      Theme.of(context).primaryColor.withValues(alpha: 0.8);
  static Color primaryExtraLight(BuildContext context) =>
      Theme.of(context).primaryColor.withValues(alpha: 0.1);

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
      Theme.of(context).dividerColor.withValues(alpha: 0.5);
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

  bool get isCompleted {
    final engStatus = selectedStatus.toLowerCase().trim();
    final admStatus = adminStatus.toLowerCase().trim();
    return engStatus == 'completed' ||
        engStatus.contains('complete') ||
        admStatus == 'completed' ||
        admStatus == 'delivered' ||
        completedAt != null;
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
              color: ProfessionalTheme.primary(context).withValues(alpha: 0.1),
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

// Professional Navigation Drawer with Staggered Entrance Animation
class ProfessionalNavigationDrawer extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final String currentSection;
  final Function(String) onSectionChange;
  final bool barcodeEnabled;
  final VoidCallback? onStartTour;

  const ProfessionalNavigationDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.currentSection,
    required this.onSectionChange,
    this.barcodeEnabled = true,
    this.onStartTour,
  });

  @override
  State<ProfessionalNavigationDrawer> createState() =>
      _ProfessionalNavigationDrawerState();
}

class _ProfessionalNavigationDrawerState
    extends State<ProfessionalNavigationDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          bottomLeft: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Header Card with Admin Primary Gradient & Animated Avatar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 28,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary,
                  HSLColor.fromColor(primary).withLightness(0.30).toColor(),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _animController,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                ),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _animController,
                    curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
                  ),
                ),
                child: Column(
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
                        photoUrl ??= FirebaseAuth.instance.currentUser?.photoURL;

                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? const Icon(
                                    Icons.engineering_rounded,
                                    size: 36,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userEmail,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu Items with Staggered Entrance Animation
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                children: [
                  _buildAnimatedMenuItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    isSelected: widget.currentSection == 'dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSectionChange('dashboard');
                    },
                  ),
                  _buildAnimatedMenuItem(
                    index: 1,
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Completed Tickets',
                    isSelected: widget.currentSection == 'completed',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSectionChange('completed');
                    },
                  ),
                  if (widget.barcodeEnabled) ...[
                    _buildAnimatedMenuItem(
                      index: 2,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Barcode Scanner',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BarcodeScannerScreen(
                              userName: widget.userName,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildAnimatedMenuItem(
                      index: 3,
                      icon: Icons.qr_code_2_rounded,
                      title: 'Barcode Identifier',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EngineerBarcodeIdentifierScreen(
                              scannedBarcode: '',
                              userName: widget.userName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  _buildAnimatedMenuItem(
                    index: widget.barcodeEnabled ? 4 : 2,
                    icon: Icons.explore_rounded,
                    title: 'App Tour & Guide',
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        widget.onStartTour?.call();
                      });
                    },
                  ),
                  const Spacer(),
                  _buildAnimatedMenuItem(
                    index: widget.barcodeEnabled ? 5 : 3,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    isLogout: true,
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMenuItem({
    required int index,
    required IconData icon,
    required String title,
    bool isSelected = false,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    final double start = (0.15 + (index * 0.08)).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    final primary = Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset((1.0 - animation.value) * 35, 0),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: primary.withValues(alpha: 0.25))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLogout
                          ? const Color(0xFFFEE2E2)
                          : isSelected
                              ? primary.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isLogout
                          ? const Color(0xFFEF4444)
                          : isSelected
                              ? primary
                              : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isLogout
                            ? const Color(0xFFEF4444)
                            : isSelected
                                ? primary
                                : const Color(0xFF1E293B),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    )
                  else if (!isLogout)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFCBD5E1),
                    ),
                ],
              ),
            ),
          ),
        ),
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

  // GlobalKeys for Engineer Interactive Tour - Dashboard Tab
  final GlobalKey _engProfileHeaderKey = GlobalKey();
  final GlobalKey _engStatusToggleKey = GlobalKey();
  final GlobalKey _engActiveTaskKey = GlobalKey();
  final GlobalKey _engWorkSummaryKey = GlobalKey();
  final GlobalKey _engMonthlyBreakdownKey = GlobalKey();
  final GlobalKey _engBottomNavKey = GlobalKey();

  // GlobalKeys for Engineer Interactive Tour - Bookings Tab
  final GlobalKey _engBookingsSwitcherKey = GlobalKey();
  final GlobalKey _engBookingsSearchKey = GlobalKey();
  final GlobalKey _engBookingsFilterChipsKey = GlobalKey();

  int _selectedIndex = 0; // Current tab index
  String _currentSection = 'dashboard';

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
  bool _isCheckedIn = false;
  bool _isCheckingIn = false;
  bool _barcodeEnabled =
      true; // Default to true to maintain backward compatibility

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
    _requestInitialLocationPermission();
    _checkAttendanceStatus();
    _fetchSubscriptionData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _checkAndStartEngineerTour();
      });
    });
  }

  Future<void> _checkAndStartEngineerTour({bool force = false}) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('hasCompletedEngineerTour') ?? false;

    if (!completed) {
      // First-time tour: always ensure Dashboard tab is active so all 6 dashboard tour steps are shown on screen
      if (_selectedIndex != 0) {
        setState(() => _selectedIndex = 0);
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted) return;
      final steps = _buildEngineerTourSteps();
      if (steps.isNotEmpty) {
        AppTourService.instance.startTour(
          context: context,
          steps: steps,
          force: false,
          onComplete: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool('hasCompletedEngineerTour', true);
          },
        );
      }
    } else if (force) {
      // Replay tour: provide steps tailored to whichever tab the engineer is currently viewing
      List<TourStep> steps;
      if (_selectedIndex == 1) {
        steps = _buildBookingsTourSteps();
      } else {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          await Future.delayed(const Duration(milliseconds: 250));
        }
        steps = _buildEngineerTourSteps();
      }

      if (mounted && steps.isNotEmpty) {
        AppTourService.instance.startTour(
          context: context,
          steps: steps,
          force: true,
          onComplete: () {},
        );
      }
    }
  }

  List<TourStep> _buildEngineerTourSteps() {
    final primary = Theme.of(context).primaryColor;
    return [
      TourStep(
        id: 'eng_profile_header',
        targetKey: _engProfileHeaderKey,
        category: '👋 Welcome Engineer',
        title: 'Technician Command Center',
        description:
            'Welcome to your field workspace! Monitor your profile, active tickets, and daily performance metrics.',
        icon: Icons.engineering_rounded,
        accentColor: primary,
      ),
      TourStep(
        id: 'eng_online_toggle',
        targetKey: _engStatusToggleKey,
        category: '🟢 Duty Status',
        title: 'Go Online / Offline',
        description:
            'Toggle your status to "Online" when starting your shift so the dispatch admin can assign customer service tickets and track live GPS coordinates.',
        icon: Icons.toggle_on_rounded,
        accentColor: const Color(0xFF10B981),
      ),
      TourStep(
        id: 'eng_active_tasks',
        targetKey: _engActiveTaskKey,
        category: '🛠️ Priority Task',
        title: 'Recent & Active Tasks',
        description:
            'Your current priority service ticket. View customer contact, symptom details, and location. Tap "Call" to reach the customer or "View Ticket" to submit onsite updates and photo proofs.',
        icon: Icons.assignment_turned_in_rounded,
        accentColor: const Color(0xFFE17055),
        workflowSteps: const [
          '1. Assigned',
          '2. Check-In',
          '3. Add Notes & Photos',
          '4. Complete',
        ],
        currentWorkflowIndex: 0,
      ),
      TourStep(
        id: 'eng_work_summary',
        targetKey: _engWorkSummaryKey,
        category: '📊 Performance Metrics',
        title: 'Work Summary & Rate',
        description:
            'Monitor your daily task load at a glance — review counts for assigned, completed, pending, and in-progress jobs alongside your completion rate percentage.',
        icon: Icons.analytics_rounded,
        accentColor: const Color(0xFF0984E3),
      ),
      TourStep(
        id: 'eng_monthly_breakdown',
        targetKey: _engMonthlyBreakdownKey,
        category: '📅 Monthly Tracking',
        title: 'Monthly Performance',
        description:
            'Swipe horizontally across past months to inspect your completed tasks and track your overall job volume over time.',
        icon: Icons.calendar_month_rounded,
        accentColor: const Color(0xFF6C5CE7),
      ),
      TourStep(
        id: 'eng_bottom_nav',
        targetKey: _engBottomNavKey,
        category: '🧭 App Navigation',
        title: 'Quick Navigation Bar',
        description:
            'Navigate seamlessly between Dashboard, All Assigned Bookings, Live Maps & Navigation, and your Profile & Shift settings.',
        icon: Icons.grid_view_rounded,
        accentColor: primary,
      ),
    ];
  }

  List<TourStep> _buildBookingsTourSteps() {
    final primary = Theme.of(context).primaryColor;
    return [
      TourStep(
        id: 'eng_bookings_switcher',
        targetKey: _engBookingsSwitcherKey,
        category: '📋 Ticket Status',
        title: 'Assigned & Completed',
        description:
            'Easily toggle between your active Assigned service jobs and your history of Completed tickets.',
        icon: Icons.assignment_rounded,
        accentColor: primary,
      ),
      TourStep(
        id: 'eng_bookings_search',
        targetKey: _engBookingsSearchKey,
        category: '🔍 Smart Search',
        title: 'Find Tickets Instantly',
        description:
            'Quickly search for any job by Booking ID, Customer Name, or Phone Number.',
        icon: Icons.search_rounded,
        accentColor: const Color(0xFF0984E3),
      ),
      TourStep(
        id: 'eng_bookings_filters',
        targetKey: _engBookingsFilterChipsKey,
        category: '⚡ Quick Filters',
        title: 'Status Filtering',
        description:
            'Filter your workload by sub-statuses like Spares Required, Observation, In Progress, or Pending.',
        icon: Icons.filter_alt_rounded,
        accentColor: const Color(0xFFE17055),
      ),
      TourStep(
        id: 'eng_bottom_nav_bookings',
        targetKey: _engBottomNavKey,
        category: '🧭 App Navigation',
        title: 'Tab Navigation',
        description:
            'Switch anytime between your Bookings list, main Dashboard, Live Map, and Profile.',
        icon: Icons.grid_view_rounded,
        accentColor: primary,
      ),
    ];
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      final tenantId = await SharedPreferences.getInstance().then(
        (p) => p.getString('tenantId'),
      );
      if (tenantId != null) {
        final subscriptionData = await FirestoreService.instance
            .getTenantSubscriptionData(tenantId: tenantId);
        if (subscriptionData != null) {
          setState(() {
            _barcodeEnabled = subscriptionData['barcode'] ?? true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching subscription data: $e');
    }
  }

  Future<void> _checkAttendanceStatus() async {
    bool checkedIn = await AttendanceService.instance.hasCheckedInToday(
      widget.userName,
    );
    if (mounted) {
      setState(() {
        _isCheckedIn = checkedIn;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isCheckingIn = true);
    try {
      await AttendanceService.instance.checkIn(widget.userName);
      setState(() {
        _isCheckedIn = true;
      });
      _showSnackBar('Checked in successfully!', ProfessionalTheme.success);
      if (!_isOnline) {
        _toggleOnlineStatus(true);
      } else {
        LocationService.instance.startTracking(widget.userName);
      }
    } catch (e) {
      _showSnackBar(e.toString(), ProfessionalTheme.error);
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  Future<void> _requestInitialLocationPermission() async {
    // Prompt for location permission immediately after login
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Error requesting initial location permission: $e');
    }
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
        bool online = doc.docs.first.data()['isOnline'] ?? false;
        setState(() {
          _isOnline = online;
        });

        // If recovered state is online, start tracking automatically
        if (online) {
          LocationService.instance.startTracking(widget.userName);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final tenantId = await SharedPreferences.getInstance().then(
      (p) => p.getString('tenantId'),
    );
    if (tenantId != null) {
      setState(() => _isOnline = value);

      // Start/Stop location tracking based on online status
      if (value) {
        bool started = await LocationService.instance.startTracking(
          widget.userName,
        );
        if (!started && mounted) {
          // If tracking failed to start (likely due to permissions), revert toggle
          setState(() => _isOnline = false);
          _showSnackBar(
            'Could not start location tracking. Please enable location permissions.',
            ProfessionalTheme.error,
          );
          return; // Exit without updating Firestore status
        }
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
          .collection('Admin_ticket_entry')
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
                  color: ProfessionalTheme.primary(
                    context,
                  ).withValues(alpha: 0.1),
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
                  color: ProfessionalTheme.error.withValues(alpha: 0.1),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeEndDrawer();
            return;
          }
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeDrawer();
            return;
          }
          // Minimize app to home screen like Instagram without logging out
          SystemNavigator.pop();
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF8FAFC),
          endDrawer: ProfessionalNavigationDrawer(
            userName: widget.userName,
            userEmail: widget.userEmail,
            onLogout: _showLogoutConfirmation,
            currentSection: _currentSection,
            onSectionChange: (section) {
              setState(() {
                _currentSection = section;
                if (section == 'completed') {
                  _selectedIndex = 1;
                  _statusFilter = null;
                  _isLoading = true;
                } else if (section == 'dashboard') {
                  _selectedIndex = 0;
                  _statusFilter = null;
                  _isLoading = true;
                }
              });
            },
            barcodeEnabled: _barcodeEnabled,
            onStartTour: () => _checkAndStartEngineerTour(force: true),
          ),
          body: Column(
            children: [
              // Status bar background (time/battery area)
              Container(
                height: MediaQuery.of(context).padding.top,
                color: Colors.white,
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _buildTopSection(),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: [
                            _buildDashboardView(),
                            _buildBookingsView(),
                            _buildLocationView(),
                            _buildProfileView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo / Avatar & Profile
          Expanded(
            child: Container(
              key: _engProfileHeaderKey,
              child: Row(
                children: [
                  if (ThemeService.instance.logoUrl != null)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: NetworkImage(ThemeService.instance.logoUrl!),
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : 'E',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ThemeService.instance.appName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
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
          const SizedBox(width: 10),
          // Online Toggle
          _buildOnlineToggle(),
          const SizedBox(width: 10),
          // Burger Menu Button
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    final statusColor =
        _isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    return Container(
      key: _engStatusToggleKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.circle : Icons.circle_outlined,
            size: 8,
            color: statusColor,
          ),
          const SizedBox(width: 5),
          Text(
            _isOnline ? "Online" : "Offline",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 18,
            width: 30,
            child: FittedBox(
              fit: BoxFit.fill,
              child: Switch(
                value: _isOnline,
                onChanged: _toggleOnlineStatus,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor:
                    const Color(0xFF10B981).withValues(alpha: 0.4),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Replacing _buildSelectedTab with _buildDashboardView and helpers
  EdgeInsets _pagePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final horizontal = w >= 420 ? 20.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24);
  }

  double _sectionTitleSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 420 ? 20 : 18;
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: _sectionTitleSize(context),
      fontWeight: FontWeight.w800,
      color: ProfessionalTheme.textPrimary(context),
      letterSpacing: -0.2,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: titleStyle),
        ?trailing,
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.assignment_rounded,
                label: 'Bookings',
                color: primary,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
            const SizedBox(width: 10),
            if (_barcodeEnabled) ...[
              Expanded(
                child: _buildActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan Barcode',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => BarcodeScannerScreen(
                        userName: widget.userName,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _buildActionTile(
                icon: Icons.location_on_rounded,
                label: 'Live Map',
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.person_rounded,
                label: 'My Profile',
                color: const Color(0xFF8B5CF6),
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Attendance / Check-In Hero Card ──
          if (!_isCheckedIn) ...[
            _buildCheckInCard(),
            const SizedBox(height: 20),
          ],

          // ── 2. Quick Action Shortcuts Grid ──
          _buildQuickActionsGrid(),
          const SizedBox(height: 24),

          // ── 3. Featured Hero Task & Active Tasks ──
          Container(
            key: _engActiveTaskKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent & Active Tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _selectedIndex = 1); // Go to Bookings
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('View All',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRecentTasks(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. Work Summary Dashboard ──
          const Text(
            'Work Summary & Analytics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          _buildWorkSummaryDashboard(),
        ],
      ),
    );
  }

  Widget _buildCheckInCard() {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Check In to Start Your Day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'We need your location to assign nearby tasks and track your active hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingIn ? null : _handleCheckIn,
              icon: _isCheckingIn
                  ? const SizedBox.shrink()
                  : const Icon(Icons.login_rounded, size: 18),
              label: _isCheckingIn
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Check In Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where('assignedEmployee', isEqualTo: widget.userName)
          .snapshots(),
      builder: (context, snapshot) {
        int totalCompleted = 0;
        int activeTasks = 0;
        int newlyAssigned = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                data['engineerStatus']?.toString().toLowerCase() ?? '';
            if (status == 'completed') {
              totalCompleted++;
            } else if (status == 'assigned') {
              newlyAssigned++;
            } else {
              activeTasks++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completed',
                totalCompleted.toString(),
                Icons.check_circle_outline,
                ProfessionalTheme.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active',
                activeTasks.toString(),
                Icons.run_circle_outlined,
                ProfessionalTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'New',
                newlyAssigned.toString(),
                Icons.new_releases_outlined,
                ProfessionalTheme.primary(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ProfessionalTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: ProfessionalTheme.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkSummaryDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where('assignedEmployee', isEqualTo: widget.userName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        int currentMonthAssigned = 0;
        int currentMonthCompleted = 0;
        int pendingTickets = 0;
        int inProgressTickets = 0;

        Map<int, int> assignedPerMonth = {};
        Map<int, int> completedPerMonth = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['engineerStatus'] ?? data['adminStatus'] ?? '')
              .toString()
              .toLowerCase();

          DateTime? assignedDate;
          if (data['AssignedTimestamp'] != null) {
            assignedDate = (data['AssignedTimestamp'] as Timestamp).toDate();
          }

          DateTime? completedDate;
          if (data['completedAt'] != null) {
            completedDate = (data['completedAt'] as Timestamp).toDate();
          } else if (status == 'completed') {
            completedDate = assignedDate;
          }

          if (status != 'completed') {
            if (status == 'assigned') {
              pendingTickets++;
            } else {
              inProgressTickets++;
            }
          }

          if (assignedDate != null && assignedDate.year == now.year) {
            assignedPerMonth[assignedDate.month] =
                (assignedPerMonth[assignedDate.month] ?? 0) + 1;
            if (assignedDate.month == now.month) {
              currentMonthAssigned++;
            }
          }

          if (status == 'completed' &&
              completedDate != null &&
              completedDate.year == now.year) {
            completedPerMonth[completedDate.month] =
                (completedPerMonth[completedDate.month] ?? 0) + 1;
            if (completedDate.month == now.month) {
              currentMonthCompleted++;
            }
          }
        }

        final completionPercentage = currentMonthAssigned > 0
            ? (currentMonthCompleted / currentMonthAssigned).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ultra-Compact Single-Card 4-Column Metric Bar ──
            Container(
              key: _engWorkSummaryKey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactMetric(
                          'Assigned',
                          currentMonthAssigned.toString(),
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: _buildCompactMetric(
                          'Completed',
                          currentMonthCompleted.toString(),
                          const Color(0xFF10B981),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: _buildCompactMetric(
                          'Pending',
                          pendingTickets.toString(),
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: _buildCompactMetric(
                          'In Progress',
                          inProgressTickets.toString(),
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Completion Rate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: completionPercentage,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(completionPercentage * 100).toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Container(
              key: _engMonthlyBreakdownKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Breakdown (${now.year})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Row(
                        children: [
                          Text(
                            'Swipe',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: now.month,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        int month = now.month - index;
                        int assigned = assignedPerMonth[month] ?? 0;
                        int completed = completedPerMonth[month] ?? 0;
                        String monthName =
                            DateFormat('MMMM').format(DateTime(now.year, month));
                        bool isCurrentMonth = index == 0;
                        final primary = Theme.of(context).primaryColor;

                        return Container(
                          width: 145,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentMonth
                                  ? primary
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isCurrentMonth
                                    ? primary.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    monthName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrentMonth
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (isCurrentMonth)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'NOW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '$assigned ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: isCurrentMonth
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Assigned  ',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentMonth
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '$completed ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: isCurrentMonth
                                          ? Colors.white
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentMonth
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasks() {
    final primary = Theme.of(context).primaryColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where('assignedEmployee', isEqualTo: widget.userName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoActiveTasksEmptyState(primary);
        }

        final docs = snapshot.data!.docs;
        final activeTasks = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final engStatus = (data['engineerStatus'] ?? '').toString().toLowerCase().trim();
          final admStatus = (data['adminStatus'] ?? '').toString().toLowerCase().trim();
          final bool isCompleted = engStatus == 'completed' ||
              engStatus.contains('complete') ||
              admStatus == 'completed' ||
              admStatus == 'delivered' ||
              data['orderDelivered'] == true ||
              data['isDelivered'] == true ||
              data['completedAt'] != null;
          final bool isCanceled = admStatus == 'canceled' || admStatus == 'cancelled';
          return !isCompleted && !isCanceled;
        }).toList();

        if (activeTasks.isEmpty) {
          return _buildNoActiveTasksEmptyState(primary);
        }

        final firstDoc = activeTasks.first;
        final firstData = firstDoc.data() as Map<String, dynamic>;
        final otherDocs = activeTasks.skip(1).take(2).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO FEATURED TASK CARD (Admin Branding Color Highlighted) ──
            _buildHeroTaskCard(firstData, firstDoc.id),

            if (otherDocs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Other Active Tasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              ...otherDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildStandardTaskCard(data, doc.id);
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNoActiveTasksEmptyState(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 32,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No active tasks pending',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'All tasks are completed! When new requests are assigned to you, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchPhoneDialer(String rawPhone) async {
    String phone = rawPhone.trim().replaceAll(' ', '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number is not available'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri dialUri =
        Uri(scheme: 'tel', path: sanitized.isNotEmpty ? sanitized : phone);
    try {
      final success =
          await launchUrl(dialUri, mode: LaunchMode.externalApplication);
      if (!success) {
        final fallbackSuccess = await launchUrl(dialUri);
        if (!fallbackSuccess) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Phone app unavailable on Simulator. Number: $phone',
              ),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone app unavailable on Simulator. Number: $phone'),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildHeroTaskCard(Map<String, dynamic> data, String docId) {
    final primary = Theme.of(context).primaryColor;
    final bookingId = data['bookingId']?.toString() ?? 'N/A';
    final customerName = data['customerName']?.toString() ?? 'Customer';
    final deviceBrand = data['deviceBrand']?.toString() ?? '';
    final deviceType = data['deviceType']?.toString() ?? 'Service Request';
    final mobileNumber = (data['mobileNumber'] ??
            data['customerMobile'] ??
            data['mobile'] ??
            data['phone'] ??
            data['contactNumber'] ??
            '')
        .toString();
    final address = data['address']?.toString() ?? '';
    final status = (data['engineerStatus'] ?? data['adminStatus'] ?? 'Assigned')
        .toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            HSLColor.fromColor(primary).withLightness(0.32).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle decorative pattern
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.build_circle_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badges (Main Task Pill + Status Badge + Ticket ID)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.amberAccent,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'MAIN ACTIVE TASK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$bookingId',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer & Device Info
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [deviceBrand, deviceType]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),

                // Equal 50/50 Quick Action Buttons inside Hero Card
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchPhoneDialer(mobileNumber),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: const Text(
                          'Call',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _selectedIndex = 1);
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          'View Ticket',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardTaskCard(Map<String, dynamic> data, String docId) {
    final primary = Theme.of(context).primaryColor;
    final bookingId = data['bookingId']?.toString() ?? '';
    final customerName = data['customerName']?.toString() ?? 'Customer';
    final deviceBrand = data['deviceBrand']?.toString() ?? 'Task';
    final status = (data['engineerStatus'] ?? data['adminStatus'] ?? 'Assigned')
        .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedIndex = 1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment_rounded, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          deviceBrand,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (bookingId.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#$bookingId',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final primary = Theme.of(context).primaryColor;
    final navItems = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'icon': Icons.assignment_rounded, 'label': 'Bookings'},
      {'icon': Icons.location_on_rounded, 'label': 'Location'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      key: _engBottomNavKey,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final isSelected = _selectedIndex == index;
              final item = navItems[index];
              final icon = item['icon'] as IconData;
              final label = item['label'] as String;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                borderRadius: BorderRadius.circular(30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  padding: isSelected
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color:
                            isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationView() {
    return EngineerLocationScreen(engineerName: widget.userName);
  }

  Widget _buildProfileView() {
    final primary = Theme.of(context).primaryColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection(
            'EngineerLogin',
            tenantId: ThemeService.instance.databaseName,
          )
          .where('Username', isEqualTo: widget.userName)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = {};
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        }

        final email = data['Email'] ?? widget.userEmail;
        final phone = data['Phone'] ?? 'Not provided';
        final specialization = data['Specialization'] ?? 'Service Engineer';
        final address = data['Address'] ?? 'Not provided';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Spectacular Hero Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary,
                      HSLColor.fromColor(primary).withLightness(0.30).toColor(),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar Ring
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          (widget.userName.isNotEmpty ? widget.userName[0] : 'E')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Specialization Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            specialization,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PERSONAL & CONTACT INFORMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Modern Info Cards
              _buildProfileItem(
                Icons.email_outlined,
                'Email Address',
                email,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: email));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email copied to clipboard'),
                      backgroundColor: Colors.blueAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildProfileItem(
                Icons.phone_android_outlined,
                'Mobile Number',
                phone,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Phone number copied'),
                      backgroundColor: Colors.blueAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildProfileItem(
                Icons.engineering_outlined,
                'Specialization',
                specialization,
              ),
              _buildProfileItem(
                Icons.location_on_outlined,
                'Address',
                address,
              ),

              const SizedBox(height: 24),

              // Edit Profile Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EngineerEditProfileScreen(
                          engineerName: widget.userName,
                        ),
                      ),
                    );
                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutConfirmation,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Logout Account',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onCopy,
  }) {
    final primary = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .where('assignedEmployee', isEqualTo: widget.userName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const ProfessionalLoadingSpinner();
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          _isLoading = false;
          return _buildEmptyState();
        }

        final allBookings = snapshot.data!.docs
            .map((doc) => AdminDetails.fromFirestore(doc))
            .toList();

        final int assignedCount = allBookings.where((b) => !b.isCompleted).length;
        final int completedCount = allBookings.where((b) => b.isCompleted).length;

        // Filter based on current section
        if (_currentSection == 'completed') {
          _allBookings = allBookings.where((b) => b.isCompleted).toList();
        } else {
          // Assigned tab shows ONLY non-completed tickets
          _allBookings = allBookings.where((b) => !b.isCompleted).toList();
        }

        _allBookings.sort((a, b) => b.bookingId.compareTo(a.bookingId));
        _applyFilters();
        _isLoading = false;

        return Column(
          children: [
            Padding(
              padding: _pagePadding(context).copyWith(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Bookings'),
                  const SizedBox(height: 12),
                  Container(
                    key: _engBookingsSwitcherKey,
                    child: _buildBookingSectionSwitcher(
                      assignedCount: assignedCount,
                      completedCount: completedCount,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    key: _engBookingsSearchKey,
                    child: _buildSearchField(),
                  ),
                  if (_currentSection != 'completed') ...[
                    const SizedBox(height: 12),
                    Container(
                      key: _engBookingsFilterChipsKey,
                      child: _buildStatusFilterChips(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildResultsMeta(),
                ],
              ),
            ),

            // Bookings List
            Expanded(child: _buildSearchResults()),
          ],
        );
      },
    );
  }

  Widget _buildResultsMeta() {
    final primary = Theme.of(context).primaryColor;
    final label = _currentSection == 'completed' ? 'completed' : 'assigned';
    final count = _filteredBookings.length;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _currentSection == 'completed'
                    ? Icons.verified_rounded
                    : Icons.assignment_rounded,
                size: 14,
                color: primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$count ${count == 1 ? 'ticket' : 'tickets'} $label',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_searchQuery.isNotEmpty || _statusFilter != null)
          TextButton.icon(
            onPressed: () {
              _clearSearch();
              setState(() {
                _statusFilter = null;
                _applyFilters();
              });
            },
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Clear filters',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildBookingSectionSwitcher({
    required int assignedCount,
    required int completedCount,
  }) {
    final isCompleted = _currentSection == 'completed';

    Widget chip({
      required bool selected,
      required String title,
      required String count,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? ProfessionalTheme.primary(context)
                  : ProfessionalTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? ProfessionalTheme.primary(context)
                    : ProfessionalTheme.borderLight(context),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ProfessionalTheme.primary(
                          context,
                        ).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? ProfessionalTheme.textInverse(context)
                      : ProfessionalTheme.primary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? ProfessionalTheme.textInverse(context)
                          : ProfessionalTheme.textPrimary(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : ProfessionalTheme.primaryExtraLight(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? ProfessionalTheme.textInverse(context)
                          : ProfessionalTheme.primary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(
          selected: !isCompleted,
          title: 'Assigned',
          count: assignedCount.toString(),
          icon: Icons.assignment_rounded,
          onTap: () {
            if (_currentSection == 'dashboard' || _currentSection == 'assigned') return;
            setState(() {
              _currentSection = 'dashboard';
              _statusFilter = null;
            });
          },
        ),
        const SizedBox(width: 12),
        chip(
          selected: isCompleted,
          title: 'Completed',
          count: completedCount.toString(),
          icon: Icons.verified_rounded,
          onTap: () {
            if (_currentSection == 'completed') return;
            setState(() {
              _currentSection = 'completed';
              _statusFilter = null;
            });
          },
        ),
      ],
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
      padding: _pagePadding(context),
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
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search by Booking ID or Customer...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: primary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
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
    _filteredBookings = _allBookings.where((b) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          b.bookingId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == null || _statusFilter!.isEmpty
          ? true
          : b.selectedStatus.toLowerCase().trim() == _statusFilter!.toLowerCase().trim();
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _buildStatusFilterChips() {
    final primary = Theme.of(context).primaryColor;
    final statuses = [
      'Assigned',
      'Pending for Approval',
      'Pending for Spares',
      'Under Observation',
      'Delivered',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: statuses.map((status) {
          final isSelected = _statusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _statusFilter = isSelected ? null : status;
                  _applyFilters();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primary : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _shortenStatus(status),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
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

// Professional Booking List Card (Clean High-Density List Tile)
class ProfessionalBookingCard extends StatelessWidget {
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

  void _openDetailsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          booking: booking,
          descriptionController: descriptionController,
          index: index,
          userName: userName,
          isCompletedSection: isCompletedSection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final status = booking.selectedStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetailsPage(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '#${booking.bookingId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(context, status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  booking.customerName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.devices_other_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      [booking.deviceBrand, booking.deviceType]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            booking.daysDisplayText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: primary,
                          ),
                        ],
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
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final statusConfig = {
      'Completed': {
        'color': const Color(0xFF10B981),
        'icon': Icons.check_circle_outline,
        'text': 'Completed',
      },
      'Assigned': {
        'color': const Color(0xFF10B981),
        'icon': Icons.assignment_ind_outlined,
        'text': 'Assigned',
      },
      'Pending for Approval': {
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.hourglass_empty_rounded,
        'text': 'Pending',
      },
      'Pending for Spares': {
        'color': const Color(0xFFF59E0B),
        'icon': Icons.settings_input_component_outlined,
        'text': 'Spares',
      },
      'Under Observation': {
        'color': const Color(0xFF06B6D4),
        'icon': Icons.visibility_outlined,
        'text': 'Observation',
      },
    };

    final config = statusConfig[status] ?? {
      'color': const Color(0xFF64748B),
      'icon': Icons.help_outline,
      'text': status,
    };

    final color = config['color'] as Color;
    final text = config['text'] as String;
    final icon = config['icon'] as IconData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// Dedicated Full-Screen Ticket Details Page
class TicketDetailScreen extends StatefulWidget {
  final AdminDetails booking;
  final TextEditingController descriptionController;
  final int index;
  final String userName;
  final bool isCompletedSection;

  const TicketDetailScreen({
    super.key,
    required this.booking,
    required this.descriptionController,
    required this.index,
    required this.userName,
    this.isCompletedSection = false,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
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
  bool _isLoadingLocation = false;

  void _launchPhoneDialer(String rawPhone) async {
    String phone = rawPhone.trim().replaceAll(' ', '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number is not available'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri dialUri =
        Uri(scheme: 'tel', path: sanitized.isNotEmpty ? sanitized : phone);
    try {
      final success =
          await launchUrl(dialUri, mode: LaunchMode.externalApplication);
      if (!success) {
        final fallbackSuccess = await launchUrl(dialUri);
        if (!fallbackSuccess) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Phone app unavailable on Simulator. Number: $phone',
              ),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone app unavailable on Simulator. Number: $phone'),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _logManualLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _capturedLat = position.latitude;
        _capturedLng = position.longitude;
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
        .collection('Admin_ticket_entry')
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
    final total = _payments.fold<num>(0, (acc, p) {
      final v = p['amount'];
      if (v is num) return acc + v;
      if (v is String) return acc + (double.tryParse(v) ?? 0);
      return acc;
    }).toDouble();

    _amountController.text = total.toStringAsFixed(2);
    widget.booking.amount = _amountController.text;
  }

  void _updateReadOnlyStatus() {
    final bool wasCompleted =
        widget.booking.selectedStatus.toLowerCase() == 'completed';

    setState(() {
      _isReadOnly =
          wasCompleted ||
          _currentStatus.toLowerCase() == 'completed' ||
          widget.booking.isCanceled ||
          widget.isCompletedSection;

      if (wasCompleted || _currentStatus.toLowerCase() == 'completed') {
        _currentStatus = 'Completed';
      }
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
                  color: ProfessionalTheme.primary(
                    context,
                  ).withValues(alpha: 0.1),
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

        final String bookingId = widget.booking.bookingId.trim();
        final String updateDesc = widget.descriptionController.text.trim().isNotEmpty
            ? widget.descriptionController.text.trim()
            : 'Status updated to $_currentStatus by engineer';

        Map<String, dynamic> updateData = {
          'engineerStatus': _currentStatus,
          'description': updateDesc,
          'statusDescription': updateDesc,
          'amount': double.tryParse(_amountController.text.trim()) ?? 0,
          'imageUrls': allImageUrls,
          'lastUpdated': FieldValue.serverTimestamp(),
          'PaymentType': paymentTypeToSave,
          'lastUpdatedBy': widget.userName,
        };

        if (_payments.isNotEmpty) {
          updateData['payments'] = _payments.map((p) {
            return {
              ...p,
              'addedAt': Timestamp.now(),
            };
          }).toList();
        }

        updateData['statusHistory'] = [
          {
            'status': _currentStatus,
            'timestamp': Timestamp.now(),
            'updatedBy': widget.userName,
          },
        ];

        if (_currentStatus.toLowerCase() == 'completed') {
          updateData['engineerStatus'] = 'Completed';
          updateData['completedAt'] = FieldValue.serverTimestamp();
          updateData['completedBy'] = widget.userName;
        }

        // Direct write to Admin_ticket_entry
        await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .doc(bookingId)
            .set(updateData, SetOptions(merge: true));

        // Direct write to Raised_tickets
        try {
          await FirestoreService.instance
              .collection('Raised_tickets')
              .doc(bookingId)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}

        // Direct write to Engineer_updates
        await FirestoreService.instance
            .collection('Engineer_updates')
            .doc(bookingId)
            .set({
              'bookingId': bookingId,
              'PaymentType': paymentTypeToSave,
              'engineerStatus': _currentStatus,
              'statusDescription': updateDesc,
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

        await NotificationService.sendNotificationToFirestore(
          audience: 'admin',
          title: 'Engineer Job Update',
          body:
              'Engineer ${widget.userName} updated ticket ${widget.booking.bookingId} to: $_currentStatus',
          type: 'engineer_status_update',
          bookingId: widget.booking.bookingId,
          engineerName: widget.userName,
          customerName: widget.booking.customerName,
        );

        setState(() {
          _imageFiles = [];
          widget.booking.imageUrls = allImageUrls;
          widget.booking.selectedStatus = _currentStatus;
          widget.booking.paymentType = paymentTypeToSave;
          _payments = [];

          _isReadOnly =
              _currentStatus.toLowerCase() == 'completed' ||
              widget.booking.isCanceled ||
              widget.isCompletedSection;
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

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final mobileNumber = (widget.booking.mobileNumber).trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ticket #${widget.booking.bookingId}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _buildStatusHeaderChip(_currentStatus)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    HSLColor.fromColor(primary).withLightness(0.30).toColor(),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, size: 12, color: Colors.amberAccent),
                            SizedBox(width: 4),
                            Text(
                              'SERVICE TICKET DETAILS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        widget.booking.daysDisplayText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.booking.customerName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [widget.booking.deviceBrand, widget.booking.deviceType]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.booking.address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.booking.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchPhoneDialer(mobileNumber),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text('Call Customer', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.booking.address));
                          _showSnackBar('Address copied to clipboard', ProfessionalTheme.info(context));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Address', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('Job Details', Icons.info_outline),
            const SizedBox(height: 10),
            _buildDetailsSection(),
            const SizedBox(height: 20),
            _buildSectionHeader('Status Management', Icons.assignment_outlined),
            const SizedBox(height: 10),
            _buildStatusSection(),
            const SizedBox(height: 20),
            _buildSectionHeader('Update Description', Icons.description_outlined),
            const SizedBox(height: 10),
            _buildDescriptionSection(),
            const SizedBox(height: 20),
            _buildSectionHeader('Payments & Charges', Icons.payments_outlined),
            const SizedBox(height: 10),
            _buildPaymentSection(),
            const SizedBox(height: 20),
            _buildSectionHeader('Completion Photos', Icons.photo_library_outlined),
            const SizedBox(height: 10),
            _buildImageSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_isUploading || _isReadOnly || widget.booking.isCanceled) ? null : _performUpdate,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isUploading
                    ? 'Updating Ticket...'
                    : _isReadOnly
                        ? 'Ticket Read Only'
                        : 'Save & Update Ticket Status',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeaderChip(String status) {
    final statusConfig = {
      'Completed': {'color': const Color(0xFF10B981), 'text': 'Completed'},
      'Assigned': {'color': const Color(0xFF10B981), 'text': 'Assigned'},
      'Pending for Approval': {'color': const Color(0xFF8B5CF6), 'text': 'Pending'},
      'Pending for Spares': {'color': const Color(0xFFF59E0B), 'text': 'Spares'},
      'Under Observation': {'color': const Color(0xFF06B6D4), 'text': 'Observation'},
    };
    final config = statusConfig[status] ?? {'color': const Color(0xFF64748B), 'text': status};
    final color = config['color'] as Color;
    final text = config['text'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildEnhancedDetailRow(
            label: 'Address',
            value: widget.booking.address,
            icon: Icons.location_on_outlined,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: widget.booking.address));
              _showSnackBar('Address copied to clipboard', ProfessionalTheme.info(context));
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _buildEnhancedDetailRow(
            label: 'Mobile',
            value: widget.booking.mobileNumber,
            icon: Icons.phone_android_outlined,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: widget.booking.mobileNumber));
              _showSnackBar('Phone number copied', ProfessionalTheme.info(context));
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _buildEnhancedDetailRow(
            label: 'Condition',
            value: widget.booking.deviceCondition,
            icon: Icons.build_circle_outlined,
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.booking.completionMessage,
                      style: const TextStyle(
                        color: Color(0xFF059669),
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
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
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
      'Assigned',
      'In Progress',
      'Under Observation',
      'Pending for Spares',
      'Pending for Approval',
      'Completed',
    ];
    String? dropdownValue = allowedStatuses.contains(_currentStatus)
        ? _currentStatus
        : (_currentStatus.isNotEmpty ? _currentStatus : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.swap_horiz_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.transparent,
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
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
        const SizedBox(height: 12),
        // Quick Selection Status Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allowedStatuses.map((status) {
            final isSelected = _currentStatus.toLowerCase() == status.toLowerCase();
            Color chipColor = const Color(0xFF0284C7);
            if (status == 'Completed') chipColor = const Color(0xFF10B981);
            if (status.contains('Pending')) chipColor = const Color(0xFFD97706);
            if (status.contains('Observation')) chipColor = const Color(0xFF0D9488);

            return InkWell(
              onTap: (_isReadOnly || widget.booking.isCanceled)
                  ? null
                  : () {
                      setState(() {
                        _currentStatus = status;
                      });
                    },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? chipColor : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.booking.isCanceled) ...[
          const SizedBox(height: 8),
          Text(
            widget.booking.cancellationMessage,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.redAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (_currentStatus == 'Order Taken' || _currentStatus == 'Order Received') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingLocation ? null : _logManualLocation,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Theme.of(context).primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isLoadingLocation
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : Icon(Icons.my_location, color: Theme.of(context).primaryColor),
              label: Text(
                _isLoadingLocation ? 'Logging...' : 'Log Current Location',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.descriptionController,
          maxLines: 4,
          minLines: 3,
          enabled: !_isReadOnly,
          decoration: InputDecoration(
            hintText: 'Describe the current status, issues found, or work completed...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            contentPadding: const EdgeInsets.all(16),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
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
      'Cheque',
      'Others',
      'No Payment',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPaymentType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
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
          ),
        ),
        if (_selectedPaymentType == 'Others') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otherPaymentController,
            enabled: !_isReadOnly,
            decoration: InputDecoration(
              labelText: 'Specify Payment Type',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Payment Item',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  enabled: !_isReadOnly && _selectedPaymentType != 'No Payment',
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isReadOnly || _selectedPaymentType == 'No Payment' ? null : _addPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 14)),
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
        const Text(
          'Added Payments',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        ..._payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment['paymentType'] ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        payment['paymentMethod'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${payment['amount']}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor),
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
                    child: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
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
        const Text(
          'Total Amount',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          readOnly: true,
          enabled: _selectedPaymentType != 'No Payment',
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '0.00',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            helperText: 'Auto-calculated from added payments',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHOTOS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Max 3 images required',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ],
            ),
            if (!_isReadOnly && (_imageFiles?.length ?? 0) < 3)
              TextButton.icon(
                onPressed: _isPickingImages ? null : _pickImages,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add Photo'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
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
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                      ),
                    ),
                    if (!_isReadOnly)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageFiles!.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.no_photography_outlined, color: Color(0xFF94A3B8), size: 32),
                SizedBox(height: 8),
                Text('No photos uploaded', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_a_photo_rounded, color: Theme.of(context).primaryColor, size: 40),
                  const SizedBox(height: 12),
                  Text('Tap to capture or upload photos', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Upload up to 3 high-quality job photos', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
          ),
        if (widget.booking.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'UPLOADED JOB PHOTOS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
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
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
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
}
