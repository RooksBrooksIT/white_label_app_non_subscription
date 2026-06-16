import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'package:subscription_rooks_app/frontend/screens/admin_Engineer_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_tickets.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_barcode_scanner.dart';
import 'package:subscription_rooks_app/services/subscription_queue_service.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_brandandmodel_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_amc_customer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_engineer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_customer_report_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_device_config_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_barcode_details.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_engineer_updates.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/barcode_identifier.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:flutter/services.dart';

import 'package:subscription_rooks_app/backend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/subscription/branding_customization_screen.dart';
import 'package:subscription_rooks_app/subscription/subscription_plans_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_transactions_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/about_us_screen.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/contact_us_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_notifications_page.dart';
import 'package:subscription_rooks_app/frontend/screens/refund_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/widgets/subscription_welcome_modal.dart';

class admindashboard extends StatefulWidget {
  const admindashboard({super.key});

  @override
  _admindashboardState createState() => _admindashboardState();
}

class _admindashboardState extends State<admindashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int engineerUpdateCount = 0;
  int totalCustomers = 0;
  int activeEngineers = 0;
  int totalEngineers = 0;
  int pendingTickets = 0;
  String adminName = 'Loading...';
  String adminEmail = '';
  String referralCode = '';
  DateTime? _lastBackPressed;
  bool _isUploadingQR = false;
  String? currentPlanName;
  String? subscriptionStatus;
  String? billingCycle;
  int? remainingDays;
  bool _hasAttendanceFeature = true;
  bool _hasBarcodeFeature = true;
  bool _hasGeoLocationFeature = true;
  StreamSubscription<QuerySnapshot>? _adminNotificationSubscription;
  bool _welcomeModalShowing = false;

  // Dynamic Color Palette from ThemeService
  late Color primaryColor;
  late Color secondaryColor;
  late Color backgroundColor;
  final Color accentColor = const Color(0xFF00D2FF);
  final Color textColor = const Color(0xFF2D3436);
  final Color textLightColor = const Color(0xFF636E72);
  final Color errorColor = const Color(0xFFD63031);
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadAdminData();
    NotificationService.instance.initialize();
    // Listen to ThemeService changes so colors/appName update reactively
    ThemeService.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    _adminNotificationSubscription?.cancel();
    super.dispose();
  }

  void _initStreams() {
    _initAdminNotificationListener();
    AdminDashboardBackend.getEngineerUpdateCountStream().listen((count) {
      if (mounted) setState(() => engineerUpdateCount = count);
    });
    AdminDashboardBackend.getTotalCustomersStream().listen((count) {
      if (mounted) setState(() => totalCustomers = count);
    });
    AdminDashboardBackend.getActiveEngineersStream().listen((count) {
      if (mounted) setState(() => activeEngineers = count);
    });
    AdminDashboardBackend.getTotalEngineersStream().listen((count) {
      if (mounted) setState(() => totalEngineers = count);
    });
    AdminDashboardBackend.getPendingTicketsStream().listen((count) {
      if (mounted) setState(() => pendingTickets = count);
    });
  }

  void _initAdminNotificationListener() {
    final tenantId = ThemeService.instance.databaseName;

    _adminNotificationSubscription = FirestoreService.instance
        .collection('notifications', tenantId: tenantId)
        .where('audience', isEqualTo: 'admin')
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final title = data['title'] ?? 'New Notification';
                final body = data['body'] ?? '';

                // Show local notification for foreground updates
                NotificationService.instance.showNotification(
                  title: title,
                  body: body,
                );
              }
            }
          }
        });
  }

  void _loadAdminData() async {
    final profile = await AdminDashboardBackend.getAdminProfile();
    final code = await AdminDashboardBackend.getReferralCode();
    if (mounted) {
      setState(() {
        adminName = profile['name']!;
        adminEmail = profile['email']!;
        referralCode = code;
      });
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        NotificationService.instance.registerToken(
          role: 'admin',
          userId: user.uid, // Use UID instead of name
          email: adminEmail,
        );

        // Check for active subscription
        final tenantId = ThemeService.instance.databaseName;
        final appId = ThemeService.instance.appName;
        final isSubscribed = await FirestoreService.instance.isTenantActive(
          tenantId: tenantId,
          appId: appId,
        );

        if (!isSubscribed) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const SubscriptionPlansScreen(),
              ),
            );
          }
          return;
        }

        // Fetch Subscription Info dynamically
        try {
          final tenantId = ThemeService.instance.databaseName;
          final appId = ThemeService.instance.appName;

          final actualAppId = await FirestoreService.instance
              .getActiveSubscriptionAppId(tenantId: tenantId, appId: appId);

          FirestoreService.instance
              .streamTenantSubscription(tenantId, appId: actualAppId)
              .listen((data) {
                if (mounted) {
                  setState(() {
                    if (data != null) {
                      currentPlanName = data['planName'] as String?;
                      subscriptionStatus = data['status'] as String?;

                      final isYearly = data['isYearly'] as bool? ?? false;
                      final isSixMonths = data['isSixMonths'] as bool? ?? false;

                      if (currentPlanName?.toLowerCase().contains('trial') ??
                          false) {
                        billingCycle = '7 Days';
                      } else if (isYearly) {
                        billingCycle = 'Yearly';
                      } else if (isSixMonths) {
                        billingCycle = '6 Months';
                      } else {
                        billingCycle = 'Monthly';
                      }

                      _hasAttendanceFeature =
                          data['attendance'] as bool? ?? true;
                      _hasBarcodeFeature = data['barcode'] as bool? ?? true;
                      _hasGeoLocationFeature =
                          data['geoLocation'] as bool? ?? true;

                      final expiresAt = data['expiresAt'];
                      if (expiresAt != null) {
                        DateTime expiryDate;
                        if (expiresAt is Timestamp) {
                          expiryDate = expiresAt.toDate();
                        } else if (expiresAt is String) {
                          expiryDate =
                              DateTime.tryParse(expiresAt) ?? DateTime.now();
                        } else {
                          expiryDate = DateTime.now();
                        }
                        remainingDays = expiryDate
                            .difference(DateTime.now())
                            .inDays;
                      } else {
                        remainingDays = 0;
                      }
                    } else {
                      currentPlanName = null;
                      subscriptionStatus = null;
                      remainingDays = null;
                      billingCycle = null;
                    }
                  });
                  if (data != null) {
                    _checkAndShowWelcomeModal(data);
                  }
                }
              });
        } catch (e) {
          debugPrint('Error loading subscription info: $e');
        }
      }
    }
  }

  void _checkAndShowWelcomeModal(Map<String, dynamic> data) async {
    if (_welcomeModalShowing) return;

    final planName = data['planName'] as String?;
    final status = data['status'] as String? ?? '';
    final startedAt = data['startedAt'] as String? ?? '';
    final isYearly = data['isYearly'] as bool? ?? false;
    final isSixMonths = data['isSixMonths'] as bool? ?? false;

    if (planName == null || status != 'active') return;

    String calculatedCycle;
    if (planName.toLowerCase().contains('trial')) {
      calculatedCycle = '7 Days';
    } else if (isYearly) {
      calculatedCycle = 'Yearly';
    } else if (isSixMonths) {
      calculatedCycle = '6 Months';
    } else {
      calculatedCycle = 'Monthly';
    }

    final prefs = await SharedPreferences.getInstance();
    final bool welcomeViewed = prefs.getBool('subscriptionWelcomeViewed') ?? false;
    final String? lastPlanName = prefs.getString('lastWelcomePlanName');
    final String? lastStartedAt = prefs.getString('lastWelcomeStartedAt');
    final String? lastStatus = prefs.getString('lastWelcomeStatus');

    final bool shouldShow = !welcomeViewed ||
        lastPlanName != planName ||
        lastStartedAt != startedAt ||
        (lastStatus != 'active' && status == 'active');

    if (shouldShow && mounted) {
      _welcomeModalShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return SubscriptionWelcomeModal(
            planName: planName,
            billingCycle: calculatedCycle,
            status: status,
            onContinue: () async {
              Navigator.pop(ctx);
              final p = await SharedPreferences.getInstance();
              await p.setBool('subscriptionWelcomeViewed', true);
              await p.setString('lastWelcomePlanName', planName);
              await p.setString('lastWelcomeStartedAt', startedAt);
              await p.setString('lastWelcomeStatus', status);
            },
            onViewDetails: () async {
              Navigator.pop(ctx);
              final p = await SharedPreferences.getInstance();
              await p.setBool('subscriptionWelcomeViewed', true);
              await p.setString('lastWelcomePlanName', planName);
              await p.setString('lastWelcomeStartedAt', startedAt);
              await p.setString('lastWelcomeStatus', status);

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionPlansScreen(
                      currentPlanName: planName,
                      hideTrial: planName.toLowerCase().contains('trial') != true,
                      remainingDays: remainingDays,
                      billingCycle: calculatedCycle,
                    ),
                  ),
                );
              }
            },
          );
        },
      ).then((_) {
        _welcomeModalShowing = false;
      });
    }
  }

  String get _appBarSubscriptionText {
    if (currentPlanName == null) {
      return 'No Active Plan';
    }
    final isExpired =
        subscriptionStatus == 'expired' ||
        (remainingDays != null && remainingDays! < 0);
    if (isExpired) {
      return '$currentPlanName • Expired';
    }
    return '$currentPlanName • ${remainingDays ?? 0} days left';
  }

  Color get _appBarSubscriptionColor {
    if (currentPlanName == null) {
      return Colors.grey.shade400;
    }
    final isExpired =
        subscriptionStatus == 'expired' ||
        (remainingDays != null && remainingDays! < 0);
    if (isExpired) {
      return errorColor;
    }
    return _getPlanColor(currentPlanName!);
  }

  @override
  Widget build(BuildContext context) {
    // Refresh colors from ThemeService
    primaryColor = ThemeService.instance.primaryColor;
    secondaryColor = ThemeService.instance.secondaryColor;
    backgroundColor = Colors.white; // Ensure clean white background

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
        SystemNavigator.pop(); // Exit the app
        return true; // This line will not be reached if SystemNavigator.pop() is called
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        endDrawer: _buildDrawer(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildMetricsSection(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildManagementSection('Ticket Management', [
                      _buildMenuCard(
                        title: 'Service Tickets',
                        subtitle: 'Manage support requests',
                        icon: Icons.confirmation_number_rounded,
                        color: const Color(0xFF0984E3),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminPage_CusDetails(statusFilter: ""),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        title: 'Call Logs',
                        subtitle: 'Track interactions',
                        icon: Icons.phone_callback_rounded,
                        color: const Color(0xFF00B894),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminDeliveryTickets(statusFilter: ""),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Engineer Updates',
                        subtitle: 'Real-time activities',
                        icon: Icons.engineering_rounded,
                        color: const Color(0xFFE17055),
                        badge: engineerUpdateCount > 0
                            ? engineerUpdateCount.toString()
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EngineerUpdates(),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Staff Hub', [
                      _buildMenuCard(
                        title: 'Engineers',
                        subtitle: 'Team management',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF6C5CE7),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EngineerManagementPage(),
                            ),
                          );
                        },
                      ),
                      if (_hasAttendanceFeature)
                        _buildMenuCard(
                          title: 'Attendance',
                          subtitle: 'Check-in history',
                          icon: Icons.how_to_reg_rounded,
                          color: const Color(0xFFF0932B),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminAttendancePage(),
                              ),
                            );
                          },
                        ),
                      if (_hasAttendanceFeature)
                        _buildMenuCard(
                          title: 'Attendance Reports',
                          subtitle: 'Analytics and logs',
                          icon: Icons.analytics_rounded,
                          color: const Color(0xFF3949AB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminAttendanceReportsPage(),
                              ),
                            );
                          },
                        ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Customer Hub', [
                      _buildMenuCard(
                        title: 'Create AMC',
                        subtitle: 'New service contract',
                        icon: Icons.assignment_ind_rounded,
                        color: const Color(0xFF2E7D32),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AMCCreatePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        title: 'Service Reports',
                        subtitle: 'Generate customer reports',
                        icon: Icons.assessment_rounded,
                        color: const Color(0xFF7D2E76),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerReportGenerator(),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Device & Assets', [
                      _buildMenuCard(
                        title: 'Brand & Model',
                        subtitle: 'Catalog management',
                        icon: Icons.branding_watermark_rounded,
                        color: const Color(0xFFD63031),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BrandModelPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        title: 'Configuration',
                        subtitle: 'Device parameters',
                        icon: Icons.settings_input_component_rounded,
                        color: const Color(0xFF2D3436),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminDeviceConfigurationPage(),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Inventory Control', [
                      if (_hasBarcodeFeature)
                        _buildMenuCard(
                          title: 'Barcode Scanner',
                          subtitle: 'Scanner and verification',
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF1E3799),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminBarcodeScanner(),
                              ),
                            );
                          },
                        ),
                      if (_hasBarcodeFeature)
                        _buildMenuCard(
                          title: 'Barcode Identity',
                          subtitle: 'Asset verification',
                          icon: Icons.fact_check_rounded,
                          color: const Color(0xFF38ADA9),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BarcodeIdentifierScreen(scannedBarcode: ""),
                              ),
                            );
                          },
                        ),
                      if (_hasBarcodeFeature)
                        _buildMenuCard(
                          title: 'Barcode Details',
                          subtitle: 'Comprehensive asset info',
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF483785),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminViewBarcodeDetails(),
                              ),
                            );
                          },
                        ),
                      if (_hasGeoLocationFeature)
                        _buildMenuCard(
                          title: 'Engineer Location',
                          subtitle: 'Comprehensive asset info',
                          icon: Icons.location_pin,
                          color: const Color(0xFF483785),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminGeoLocationScreen(
                                      engineerId: '',
                                      engineerName: '',
                                    ),
                              ),
                            );
                          },
                        ),
                      //   onTap: () => Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => const Engineershiftscreen(),
                      //     ),
                      //   ),
                      // ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Financials', [
                      _buildMenuCard(
                        title: 'Transactions',
                        subtitle: 'Payments & Refunds',
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF00B894),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminTransactionsScreen(),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _appBarExpandedHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height) {
      return 150;
    }
    if (size.height < 640) {
      return 180;
    }
    return 200;
  }

  /// 1.0 = fully expanded, 0.0 = fully collapsed.
  double _appBarExpandRatio(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null || settings.maxExtent <= settings.minExtent) {
      return 1;
    }
    return ((settings.currentExtent - settings.minExtent) /
            (settings.maxExtent - settings.minExtent))
        .clamp(0.0, 1.0);
  }

  double _expandedHeaderOpacity(double expandRatio) {
    if (expandRatio >= 0.35) return 1;
    if (expandRatio <= 0.15) return 0;
    return (expandRatio - 0.15) / 0.2;
  }

  double _collapsedTitleOpacity(double expandRatio) {
    if (expandRatio >= 0.35) return 0;
    if (expandRatio <= 0.1) return 1;
    return (0.35 - expandRatio) / 0.25;
  }

  String? _profileImageUrl() {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return photoUrl;
    }
    final logoUrl = ThemeService.instance.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return logoUrl;
    }
    return null;
  }

  Widget _profileImagePlaceholder({
    required double size,
    required IconData icon,
  }) {
    return Icon(icon, color: Colors.white, size: size * 0.55);
  }

  Widget _buildNetworkAvatar({
    required double radius,
    required String? imageUrl,
    required IconData fallbackIcon,
    Color borderColor = Colors.white,
    double borderWidth = 2,
    Color? backgroundColor,
  }) {
    final diameter = radius * 2;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withValues(alpha: 0.55),
          width: borderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Colors.white.withValues(alpha: 0.2),
        child: ClipOval(
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _profileImagePlaceholder(
                    size: diameter,
                    icon: fallbackIcon,
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      width: diameter,
                      height: diameter,
                      child: Center(
                        child: SizedBox(
                          width: radius * 0.6,
                          height: radius * 0.6,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : _profileImagePlaceholder(
                  size: diameter,
                  icon: fallbackIcon,
                ),
        ),
      ),
    );
  }

  Widget _buildAppBarBrandMark({required double radius}) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildNetworkAvatar(
            radius: radius,
            imageUrl: ThemeService.instance.logoUrl,
            fallbackIcon: Icons.business_rounded,
            borderColor: Colors.white,
            backgroundColor: Colors.white,
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      StreamBuilder<int>(
        stream: NotificationService.instance
            .getUnreadAdminNotificationsCountStream(
              ThemeService.instance.databaseName,
            ),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminNotificationsPage(),
                    ),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      const SizedBox(width: 4),
    ];
  }

  Widget _buildAppBarGradientBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        Positioned(
          right: -50,
          top: -50,
          child: CircleAvatar(
            radius: 100,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        Positioned(
          left: -30,
          bottom: -40,
          child: CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white.withValues(alpha: 0.04),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedProfileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ListenableBuilder(
            listenable: ThemeService.instance,
            builder: (context, _) {
              return _buildNetworkAvatar(
                radius: 32,
                imageUrl: _profileImageUrl(),
                fallbackIcon: Icons.person_rounded,
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListenableBuilder(
                  listenable: ThemeService.instance,
                  builder: (context, _) {
                    return Text(
                      ThemeService.instance.appName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  adminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentPlanName == null ||
                                subscriptionStatus == 'expired' ||
                                (remainingDays != null && remainingDays! < 0)
                            ? Icons.info_outline_rounded
                            : Icons.workspace_premium_rounded,
                        color: _appBarSubscriptionColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _appBarSubscriptionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildCollapsedAppBarTitle() {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final appName = ThemeService.instance.appName;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppBarBrandMark(radius: 14),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar() {
    final expandedHeight = _appBarExpandedHeight(context);
    final actionWidth = MediaQuery.sizeOf(context).width < 360 ? 108.0 : 120.0;
    final topInset = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      snap: false,
      stretch: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: primaryColor,
      automaticallyImplyLeading: false,
      actions: _buildAppBarActions(),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final expandRatio = _appBarExpandRatio(context);
          final expandedOpacity = _expandedHeaderOpacity(expandRatio);
          final collapsedOpacity = _collapsedTitleOpacity(expandRatio);

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildAppBarGradientBackground(),
                if (expandedOpacity > 0.01)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: IgnorePointer(
                        ignoring: expandedOpacity < 0.5,
                        child: _buildExpandedProfileHeader(),
                      ),
                    ),
                  ),
                if (collapsedOpacity > 0.01)
                  Positioned(
                    left: 0,
                    right: actionWidth,
                    top: topInset,
                    height: kToolbarHeight,
                    child: Opacity(
                      opacity: collapsedOpacity,
                      child: IgnorePointer(
                        ignoring: collapsedOpacity < 0.5,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: _buildCollapsedAppBarTitle(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildMetricCard(
                'Total Customers',
                totalCustomers.toString(),
                Icons.people_rounded,
                accentColor,
              ),
              _buildMetricCard(
                'Active Engineers',
                '$activeEngineers/$totalEngineers',
                Icons.engineering_rounded,
                const Color(0xFF00D2FF),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Create Ticket',
                Icons.add_task_rounded,
                primaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateTickets(
                      statusFilter: '',
                      customerId: '',
                      customerName: '',
                      mobileNumber: '',
                      categoryName: '',
                      loggedInName: '',
                      name: '',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Reports',
                Icons.analytics_rounded,
                secondaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminEngineerReports(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSection(String title, List<Widget> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        ...cards,
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: textLightColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.qr_code_rounded,
                  title: 'Referral Code',
                  subtitle: referralCode.isEmpty
                      ? 'Not Available'
                      : referralCode,
                  subtitleStyle: TextStyle(
                    fontSize: referralCode.isEmpty ? 14 : 18,
                    fontWeight: referralCode.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w900,
                    color: referralCode.isEmpty ? textLightColor : primaryColor,
                    letterSpacing: referralCode.isEmpty ? 0 : 1.2,
                  ),
                  onTap: () {
                    if (referralCode.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referral code copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  trailing: referralCode.isNotEmpty
                      ? const Icon(Icons.copy_rounded, size: 20)
                      : null,
                ),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Manage your profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const BrandingCustomizationScreen(isEditMode: true),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR Code Upload',
                  subtitle: 'Upload payment QR code',
                  onTap: () {
                    Navigator.pop(context);
                    _showQRUploadDialog();
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Manage Subscription',
                  subtitle: _appBarSubscriptionText,
                  subtitleStyle:
                      remainingDays != null && currentPlanName != null
                      ? TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color:
                              (subscriptionStatus == 'expired' ||
                                  remainingDays! <= 3)
                              ? errorColor
                              : primaryColor,
                        )
                      : TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: errorColor,
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    _showManageSubscriptionSheet();
                  },
                ),
                const Divider(indent: 20, endIndent: 20),

                
                _buildDrawerItem(
                  icon: Icons.contact_mail_rounded,
                  title: 'Contact Us',
                  subtitle: 'View company contact details',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactUsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.info_rounded,
                  title: 'About Us',
                  subtitle: 'Learn more about ServNex',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutUsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(indent: 20, endIndent: 20),

                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  color: errorColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: textLightColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: ThemeService.instance,
            builder: (context, _) {
              return CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: ThemeService.instance.logoUrl != null
                    ? NetworkImage(ThemeService.instance.logoUrl!)
                    : null,
                child: ThemeService.instance.logoUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 40,
                      )
                    : null,
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            adminName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            adminEmail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _appBarSubscriptionColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentPlanName == null ||
                          subscriptionStatus == 'expired' ||
                          (remainingDays != null && remainingDays! < 0)
                      ? Icons.info_outline_rounded
                      : Icons.workspace_premium_rounded,
                  color: _appBarSubscriptionColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _appBarSubscriptionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(String planName) {
    final name = planName.toLowerCase();
    if (name.contains('silver')) return Colors.grey.shade300;
    if (name.contains('gold')) return const Color(0xFFFFD700); // Gold
    if (name.contains('platinum')) {
      return const Color(0xFFE5E4E2); // Platinum color
    }
    if (name.contains('trial')) return Colors.lightBlueAccent;
    return Colors.white;
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? color,
    TextStyle? subtitleStyle,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? primaryColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color ?? textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            subtitleStyle ??
            TextStyle(
              fontSize: 12,
              color: textLightColor,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  /// Navigates to the SubscriptionPlansScreen with the plan name pre-highlighted.
  void _showManageSubscriptionSheet() {
    final tenantId = ThemeService.instance.databaseName;
    final user = AuthStateService.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manage Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Current Plan Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Active Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentPlanName ?? 'No Active Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _appBarSubscriptionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            subscriptionStatus?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _appBarSubscriptionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expires in: ${remainingDays ?? 0} days',
                      style: TextStyle(
                        fontSize: 14,
                        color: textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Queued Plan Info
              StreamBuilder<Map<String, dynamic>?>(
                stream: SubscriptionQueueService.instance.streamQueuedPlan(
                  tenantId: tenantId,
                  uid: user.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final queuedData = snapshot.data;
                  if (queuedData == null) {
                    return const SizedBox.shrink();
                  }

                  final queuedPlanName = queuedData['planName'] ?? 'Unknown Plan';
                  final scheduledDate = queuedData['scheduledActivationDate'];
                  String formattedDate = 'On current plan expiry';
                  if (scheduledDate is Timestamp) {
                    formattedDate = DateFormat('dd MMM yyyy')
                        .format(scheduledDate.toDate().toLocal());
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6C5CE7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Queued Upgrade',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          queuedPlanName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scheduled for: $formattedDate',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Activate after current plan expires',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: true, // Always true if queued
                              activeColor: const Color(0xFF6C5CE7),
                              onChanged: (val) async {
                                if (!val) {
                                  // User toggled it off -> activate immediately!
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Activate Immediately?'),
                                      content: const Text(
                                        'Turning this off will immediately activate the queued plan, replacing your current plan. This cannot be undone. Are you sure?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Activate Now'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context); // close sheet
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Activating plan...')),
                                    );
                                    await SubscriptionQueueService.instance
                                        .activateQueuedPlan(tenantId: tenantId, uid: user.uid);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Plan activated successfully!')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancel Queued Plan?'),
                                  content: const Text(
                                    'Are you sure you want to cancel this queued plan? This will remove it from your account. If you need a refund, please use the Support/Refund page.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Keep Plan'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Cancel Plan'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await SubscriptionQueueService.instance
                                    .clearQueuedPlan(tenantId: tenantId, uid: user.uid);
                              }
                            },
                            child: const Text('Cancel Queued Plan', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToChangePlan();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Upgrade / Change Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _navigateToChangePlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionPlansScreen(
          currentPlanName: currentPlanName,
          hideTrial: true,
          remainingDays: remainingDays,
          billingCycle: billingCycle,
        ),
      ),
    );
  }

  void _showQRUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isUploadingQR,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR Code Upload',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Upload a payment QR code for engineers',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textLightColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Current QR preview
                    FutureBuilder<String?>(
                      future: StorageService.instance.getQRCodeUrl(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasData && snapshot.data != null) {
                          return Column(
                            children: [
                              Text(
                                'Current QR Code',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textLightColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  snapshot.data!,
                                  height: 180,
                                  width: 180,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 60,
                                    color: textLightColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap below to replace',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textLightColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        }
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.upload_file_outlined,
                                  size: 40,
                                  color: textLightColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No QR code uploaded yet',
                                  style: TextStyle(
                                    color: textLightColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Upload button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingQR
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 90,
                                );
                                if (picked == null) return;

                                setDialogState(() {});
                                setState(() => _isUploadingQR = true);

                                final file = File(picked.path);
                                final url = await StorageService.instance
                                    .uploadQRCode(file: file);

                                setState(() => _isUploadingQR = false);

                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        url != null
                                            ? 'QR code uploaded successfully!'
                                            : 'Upload failed. Please try again.',
                                      ),
                                      backgroundColor: url != null
                                          ? Colors.green
                                          : errorColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        icon: _isUploadingQR
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.upload_rounded,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isUploadingQR ? 'Uploading...' : 'Upload QR Code',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: textLightColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: errorColor, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to log out?',
                style: TextStyle(color: textLightColor),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: textLightColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await AuthStateService.instance.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const RoleSelectionScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
}
