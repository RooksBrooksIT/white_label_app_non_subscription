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
  final Color backgroundColor = const Color(0xFFF8FAFC);
  final Color textColor = const Color(0xFF0F172A);
  final Color textLightColor = const Color(0xFF64748B);
  final Color errorColor = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadAdminData();
    NotificationService.instance.initialize();
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

  void _initAdminNotificationListener() async {
    final tenantId = ThemeService.instance.databaseName;
    final prefs = await SharedPreferences.getInstance();

    _adminNotificationSubscription = FirestoreService.instance
        .collection('notifications', tenantId: tenantId)
        .where('audience', isEqualTo: 'admin')
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
          final List<String> shownNotificationIds =
              prefs.getStringList('shown_admin_notification_ids') ?? [];
          final Set<String> shownSet = Set<String>.from(shownNotificationIds);

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final docId = change.doc.id;
              final data = change.doc.data();

              if (data != null) {
                // Skip if notification has already been shown on this device
                if (shownSet.contains(docId)) {
                  continue;
                }

                final title = data['title'] ?? 'New Notification';
                final body = data['body'] ?? '';

                NotificationService.instance.showNotification(
                  title: title,
                  body: body,
                );

                // Store in SharedPreferences so reopening the app won't trigger it again
                shownSet.add(docId);
                await prefs.setStringList(
                  'shown_admin_notification_ids',
                  shownSet.toList(),
                );

                // Update Firestore document to seen
                try {
                  change.doc.reference.update({'seen': true});
                } catch (_) {}
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
          userId: user.uid,
          email: adminEmail,
        );

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

  Color _getPlanColor(String planName) {
    final name = planName.toLowerCase();
    if (name.contains('silver')) return Colors.grey.shade300;
    if (name.contains('gold')) return const Color(0xFFFFD700);
    if (name.contains('platinum')) {
      return const Color(0xFFE5E4E2);
    }
    if (name.contains('trial')) return Colors.lightBlueAccent;
    return Colors.white;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
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

  void _navigateToCreateTicket() {
    Navigator.push(
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
    );
  }

  void _openDomainDetailPage(DomainModel domain) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DomainDetailPage(domain: domain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    primaryColor = ThemeService.instance.primaryColor;
    secondaryColor = ThemeService.instance.secondaryColor;

    // All 5 Main Domain Cards formatted as full-width list items!
    final allDomains = [
      DomainModel(
        id: 'tickets',
        title: 'Ticket Management',
        description: 'Track, assign, and manage all customer service tickets',
        icon: Icons.confirmation_number_rounded,
        backgroundColor: const Color(0xFFE0F2FE), // Soft sky blue
        iconColor: const Color(0xFF0284C7),
        textColor: const Color(0xFF0369A1),
        badgeText: engineerUpdateCount > 0 ? '$engineerUpdateCount updates' : '4 actions',
        items: [
          DomainSubItem(
            title: 'Create Ticket',
            subtitle: 'Raise a new service request',
            icon: Icons.add_task_rounded,
            iconColor: primaryColor,
            onTap: _navigateToCreateTicket,
          ),
          DomainSubItem(
            title: 'All Tickets',
            subtitle: 'View and manage all customer support tickets',
            icon: Icons.assignment_rounded,
            iconColor: const Color(0xFF0984E3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPage_CusDetails(statusFilter: ""),
                ),
              );
            },
          ),
          DomainSubItem(
            title: 'Engineer Updates',
            subtitle: 'Real-time updates from field engineers',
            icon: Icons.history_rounded,
            iconColor: const Color(0xFFE17055),
            badge: engineerUpdateCount > 0 ? '$engineerUpdateCount Updates' : null,
            badgeColor: const Color(0xFFFF7675),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EngineerUpdates(),
                ),
              );
            },
          ),
        ],
      ),
      DomainModel(
        id: 'staff',
        title: 'Staff Hub',
        description: 'Manage engineers, field attendance & live locations',
        icon: Icons.people_alt_rounded,
        backgroundColor: const Color(0xFFF3E8FF), // Soft lavender
        iconColor: const Color(0xFF9333EA),
        textColor: const Color(0xFF7E22CE),
        badgeText: '$activeEngineers/$totalEngineers active',
        items: [
          DomainSubItem(
            title: 'Engineers',
            subtitle: 'Manage engineer team accounts & status',
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF6C5CE7),
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
            DomainSubItem(
              title: 'Attendance',
              subtitle: 'Check-in history and daily attendance status',
              icon: Icons.how_to_reg_rounded,
              iconColor: const Color(0xFFF0932B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAttendancePage(),
                  ),
                );
              },
            ),
          if (_hasAttendanceFeature)
            DomainSubItem(
              title: 'Attendance Reports',
              subtitle: 'Detailed monthly/weekly attendance logs & analytics',
              icon: Icons.analytics_rounded,
              iconColor: const Color(0xFF3949AB),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAttendanceReportsPage(),
                  ),
                );
              },
            ),
          if (_hasGeoLocationFeature)
            DomainSubItem(
              title: 'Engineer Location',
              subtitle: 'Live engineer location tracking on map',
              icon: Icons.location_pin,
              iconColor: const Color(0xFFD63031),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminGeoLocationScreen(
                      engineerId: '',
                      engineerName: '',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      DomainModel(
        id: 'customer',
        title: 'Customer Hub',
        description: 'Manage AMC contracts and customer service reports',
        icon: Icons.assignment_ind_rounded,
        backgroundColor: const Color(0xFFDCFCE7), // Soft mint green
        iconColor: const Color(0xFF16A34A),
        textColor: const Color(0xFF15803D),
        badgeText: '$totalCustomers customers',
        items: [
          DomainSubItem(
            title: 'Create AMC Customer',
            subtitle: 'Register new maintenance contract',
            icon: Icons.person_add_alt_1_rounded,
            iconColor: const Color(0xFF2E7D32),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AMCCreatePage(),
                ),
              );
            },
          ),
          DomainSubItem(
            title: 'Customer Reports',
            subtitle: 'Generate customer activity and service reports',
            icon: Icons.assessment_rounded,
            iconColor: const Color(0xFF7D2E76),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerReportGenerator(),
                ),
              );
            },
          ),
        ],
      ),
      DomainModel(
        id: 'assets',
        title: 'Assets & Inventory',
        description: 'Device catalog, barcode verification & parameters',
        icon: Icons.inventory_2_rounded,
        backgroundColor: const Color(0xFFCCFBF1), // Soft teal
        iconColor: const Color(0xFF0D9488),
        textColor: const Color(0xFF0F766E),
        badgeText: '5 modules',
        items: [
          DomainSubItem(
            title: 'Device Configuration',
            subtitle: 'Manage equipment catalog items',
            icon: Icons.branding_watermark_rounded,
            iconColor: const Color(0xFFD63031),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrandModelPage(),
                ),
              );
            },
          ),
          if (_hasBarcodeFeature)
            DomainSubItem(
              title: 'Barcode Scanner',
              subtitle: 'Scan barcodes for fast asset verification',
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF1E3799),
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
            DomainSubItem(
              title: 'Barcode Identity',
              subtitle: 'Verify asset barcode details',
              icon: Icons.fact_check_rounded,
              iconColor: const Color(0xFF38ADA9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BarcodeIdentifierScreen(scannedBarcode: ""),
                  ),
                );
              },
            ),
          if (_hasBarcodeFeature)
            DomainSubItem(
              title: 'Barcode Details',
              subtitle: 'Comprehensive inventory details',
              icon: Icons.find_in_page_rounded,
              iconColor: const Color(0xFF483785),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminViewBarcodeDetails(),
                  ),
                );
              },
            ),
        ],
      ),
      DomainModel(
        id: 'financials',
        title: 'Financials & Analytics',
        description: 'Transactions, payment receipts & work analytics',
        icon: Icons.receipt_long_rounded,
        backgroundColor: const Color(0xFFFFF3E0), // Soft warm peach
        iconColor: const Color(0xFFE65100),
        textColor: const Color(0xFFBF360C),
        badgeText: '2 modules',
        items: [
          DomainSubItem(
            title: 'Transactions',
            subtitle: 'Payment receipts & refund logs',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF00B894),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminTransactionsScreen(),
                ),
              );
            },
          ),
          DomainSubItem(
            title: 'Engineer Reports',
            subtitle: 'Performance analytics and work summary',
            icon: Icons.bar_chart_rounded,
            iconColor: secondaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminEngineerReports(),
                ),
              );
            },
          ),
        ],
      ),
    ];

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
        SystemNavigator.pop();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        drawerScrimColor: Colors.black.withValues(alpha: 0.5),
        drawer: _buildModernLeftDrawer(),
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _buildModernHeader(),
                ),
              ),

              // Hero Primary Action: CREATE TICKET
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeroCreateTicketCTA(),
                      const SizedBox(height: 28),

                      // Section Title for Domains List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Main Domains',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Tap domain to open details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textLightColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // FULL WIDTH LIST OF ALL 5 DOMAINS
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final domain = allDomains[index];
                      return _buildFullWidthDomainCard(domain);
                    },
                    childCount: allDomains.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FULL WIDTH DOMAIN CARD (Used for all 5 domains!)
  // ==========================================
  Widget _buildFullWidthDomainCard(DomainModel domain) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _openDomainDetailPage(domain),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: domain.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: domain.iconColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: domain.iconColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: domain.iconColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  domain.icon,
                  color: domain.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      domain.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: domain.textColor,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      domain.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: domain.textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: domain.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER SECTION
  // ==========================================
  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: ClipOval(
                    child: _profileImageUrl() != null
                        ? Image.network(
                            _profileImageUrl()!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 26,
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
                      _getGreeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminNotificationsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4757),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
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

                  const SizedBox(width: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: _showManageSubscriptionSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
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
                  const SizedBox(width: 8),
                  Text(
                    _appBarSubscriptionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HERO CREATE TICKET CTA
  // ==========================================
  Widget _buildHeroCreateTicketCTA() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.add_task_rounded,
                  color: primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a New Ticket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Primary Action • Fast Service Request',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Raise a new service request and assign it to the appropriate engineer immediately.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: textLightColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToCreateTicket,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Create Ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DRAWER & DIALOGS
  // ==========================================
  // ==========================================
  // REDESIGNED MODERN LEFT NAVIGATION DRAWER
  // ==========================================
  Widget _buildModernLeftDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildModernDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // SECTION 1: PRIMARY ACTION
                _buildDrawerSectionHeader('PRIMARY ACTION'),
                const SizedBox(height: 8),
                _buildDrawerHeroCreateTicketCard(),
                const SizedBox(height: 20),

                // SECTION 2: ACCOUNT & UTILITIES
                _buildDrawerSectionHeader('ACCOUNT'),
                const SizedBox(height: 8),
                _buildDrawerReferralCard(),
                _buildDrawerTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Manage your profile',
                  iconColor: primaryColor,
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
                _buildDrawerTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR Code Upload',
                  subtitle: 'Upload payment QR code',
                  iconColor: const Color(0xFF0984E3),
                  onTap: () {
                    Navigator.pop(context);
                    _showQRUploadDialog();
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Manage Subscription',
                  subtitle: _appBarSubscriptionText,
                  iconColor: const Color(0xFF6C5CE7),
                  onTap: () {
                    Navigator.pop(context);
                    _showManageSubscriptionSheet();
                  },
                ),
                const SizedBox(height: 20),

                // SECTION 4: SUPPORT
                _buildDrawerSectionHeader('SUPPORT'),
                const SizedBox(height: 8),
                _buildDrawerTile(
                  icon: Icons.contact_mail_rounded,
                  title: 'Contact Us',
                  subtitle: 'View company contact details',
                  iconColor: const Color(0xFF00B894),
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
                _buildDrawerTile(
                  icon: Icons.info_rounded,
                  title: 'About Us',
                  subtitle: 'Learn more about ServNex',
                  iconColor: const Color(0xFFE17055),
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
                const SizedBox(height: 12),
                _buildDrawerTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  iconColor: errorColor,
                  textColor: errorColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmationDialog(context);
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: textLightColor.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: ClipOval(
                    child: _profileImageUrl() != null
                        ? Image.network(
                            _profileImageUrl()!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            adminName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            adminEmail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _showManageSubscriptionSheet();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: _appBarSubscriptionColor,
                    size: 15,
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
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerHeroCreateTicketCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _navigateToCreateTicket();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Create New Ticket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Raise a service request immediately',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildDrawerReferralCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () {
            if (referralCode.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: referralCode));
              _showFrontAnimatedToast('Referral code copied to clipboard');
            }
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code_rounded, color: primaryColor, size: 20),
          ),
          title: const Text(
            'Referral Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            referralCode.isEmpty ? 'Not Available' : referralCode,
            style: TextStyle(
              fontSize: referralCode.isEmpty ? 11 : 15,
              fontWeight: referralCode.isEmpty ? FontWeight.w500 : FontWeight.w900,
              color: referralCode.isEmpty ? textLightColor : primaryColor,
              letterSpacing: referralCode.isEmpty ? 0 : 1.2,
            ),
          ),
          trailing: referralCode.isNotEmpty
              ? Icon(Icons.copy_rounded, size: 18, color: primaryColor)
              : null,
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor ?? const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            subtitle,
          ),
        ),
      ),
    );
  }

  void _showFrontAnimatedToast(String message, {IconData icon = Icons.check_circle_rounded}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _FrontToastWidget(
          message: message,
          icon: icon,
          onDismissed: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlay.insert(overlayEntry);
  }

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
                              value: true,
                              activeColor: const Color(0xFF6C5CE7),
                              onChanged: (val) async {
                                if (!val) {
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
                                    Navigator.pop(context);
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
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Modal Top Header with Close Button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              color: primaryColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Payment QR Code',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Upload payment QR code for field engineers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isUploadingQR ? null : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // QR Code Content Preview Container
                      FutureBuilder<String?>(
                        future: StorageService.instance.getQRCodeUrl(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              height: 190,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Active Payment QR',
                                                  style: TextStyle(
                                                    color: Color(0xFF15803D),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            snapshot.data!,
                                            height: 150,
                                            width: 150,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => const Icon(
                                              Icons.broken_image_outlined,
                                              size: 60,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 32,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No QR Code Uploaded Yet',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'PNG or JPG formats up to 5MB',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Action Button (Upload / Replace)
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
                                  final url = await StorageService.instance.uploadQRCode(file: file);

                                  setState(() => _isUploadingQR = false);

                                  if (context.mounted) {
                                    Navigator.pop(dialogContext);
                                    if (url != null) {
                                      _showFrontAnimatedToast('QR code uploaded successfully!');
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Upload failed. Please try again.'),
                                          backgroundColor: errorColor,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: _isUploadingQR
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                          label: Text(
                            _isUploadingQR ? 'Uploading...' : 'Upload QR Code',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shadowColor: primaryColor.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Cancel Text Button
                      TextButton(
                        onPressed: _isUploadingQR ? null : () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
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

// ==========================================
// DOMAIN MODELS & DEDICATED DETAIL PAGE
// ==========================================

class DomainModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final String badgeText;
  final List<DomainSubItem> items;

  DomainModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.badgeText,
    required this.items,
  });
}

class DomainSubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  DomainSubItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });
}

class DomainDetailPage extends StatelessWidget {
  final DomainModel domain;

  const DomainDetailPage({super.key, required this.domain});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          domain.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: domain.backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: domain.iconColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: domain.iconColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: domain.iconColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        domain.icon,
                        color: domain.iconColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            domain.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: domain.textColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            domain.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: domain.textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Available Actions & Details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),

              ...domain.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      item.onTap();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item.icon,
                              color: item.iconColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.badge != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.badgeColor ?? const Color(0xFFFF7675),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrontToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onDismissed;

  const _FrontToastWidget({
    required this.message,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<_FrontToastWidget> createState() => _FrontToastWidgetState();
}

class _FrontToastWidgetState extends State<_FrontToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            elevation: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF22C55E),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
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
