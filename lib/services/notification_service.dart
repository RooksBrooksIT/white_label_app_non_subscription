import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:subscription_rooks_app/firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_notifications_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_notifications_page.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_notifications_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_feedback_screen.dart';
import 'package:subscription_rooks_app/subscription/plan_expired_screen.dart';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure Firebase is initialized for background work
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    LoggerUtil.i("Handling a background message: ${message.messageId}");

    // If the message has a notification payload, Android system handles it automatically
    // using the FCM notification payload and default notification channel.
    // We only show a local notification if it's a data-only message (message.notification == null).
    if (message.notification == null && message.data.isNotEmpty) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('ic_stat_notification');
      const iosInit = DarwinInitializationSettings();
      await localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      final title =
          message.data['title'] ??
          message.data['notificationTitle'] ??
          'New Update';
      final body =
          message.data['body'] ??
          message.data['notificationBody'] ??
          'You have a new message';
      final appName = message.data['appName'] ?? 'ServNex';

      final bigTextStyle = BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: appName,
        htmlFormatSummaryText: true,
      );

      final androidDetails = AndroidNotificationDetails(
        'servnex_channel',
        'ServNex Alerts',
        channelDescription:
            'Notifications for new tickets, assignments, urgent status updates, and OTPs.',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: bigTextStyle,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
      );
      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

      await localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: jsonEncode(message.data),
      );
      LoggerUtil.i(
        "Background data-only notification displayed for message: ${message.messageId}",
      );
    } else {
      LoggerUtil.i(
        "Background notification payload handled natively by Android OS: ${message.notification?.title}",
      );
    }
  } catch (e) {
    LoggerUtil.e("Error in firebaseMessagingBackgroundHandler: $e");
  }
}

class NotificationService {
  // Android Notification Channels
  static const String channelServnex = 'servnex_channel';
  static const String channelHighImportance = 'servnex_channel';
  static const String channelLegacyHighImportance = 'high_importance_channel';
  static const String channelGeneral = 'general_notifications_channel';
  static const String channelSubscription = 'subscription_channel';

  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _pendingNotificationPayload;
  String? _currentRegisteredRole;
  String? _currentRegisteredUserId;
  String? _currentRegisteredToken;
  String? _currentRegisteredTenant;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _customerNotificationsSubscription;
  final Set<String> _locallyHandledNotificationIds = {};
  final Map<String, int> _recentNotificationTimestamps = {};

  bool _isDuplicateNotification(String? key) {
    if (key == null || key.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Clean old keys (> 30s)
    _recentNotificationTimestamps.removeWhere((_, time) => now - time > 30000);
    if (_recentNotificationTimestamps.containsKey(key)) {
      return true;
    }
    _recentNotificationTimestamps[key] = now;
    return false;
  }

  bool get hasPendingNotification => _pendingNotificationPayload != null;

  NotificationService._internal();

  /// Consumes and deep-links any pending notification once session & tenant are ready
  void consumePendingNotification() {
    if (_pendingNotificationPayload != null) {
      final payload = _pendingNotificationPayload;
      _pendingNotificationPayload = null;
      LoggerUtil.i("Consuming pending notification deep link: $payload");
      _handleNotificationResponse(payload);
    }
  }

  Future<void> initialize() async {
    LoggerUtil.i(
      "Initializing NotificationService with white-label UI enhancements...",
    );

    // Skip FCM and local notifications on web - they're not supported
    if (kIsWeb) {
      LoggerUtil.i(
        "Running on web, skipping FCM and local notifications initialization",
      );
      return;
    }

    // 1. Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    LoggerUtil.i('User granted permission: ${settings.authorizationStatus}');

    // Request Android 13+ notification permissions
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    // 2. Setup Notification Channels for Android
    final List<AndroidNotificationChannel> channels = [
      const AndroidNotificationChannel(
        channelServnex,
        'ServNex Alerts',
        description:
            'Notifications for new tickets, assignments, urgent status updates, and OTPs.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        channelLegacyHighImportance,
        'Urgent & Ticket Alerts',
        description:
            'Notifications for new tickets, urgent status updates, and OTPs.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        channelGeneral,
        'General Notifications',
        description: 'General updates, announcements, and activity alerts.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        channelSubscription,
        'Subscription & Billing',
        description:
            'Reminders for subscription renewals, payment confirmations, and invoices.',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    ];

    if (androidImplementation != null) {
      for (final ch in channels) {
        await androidImplementation.createNotificationChannel(ch);
      }
    }

    // 3. Initialize Local Notifications with compliant status bar icon
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('ic_stat_notification');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    final InitializationSettings initSettings = const InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationResponse(details.payload);
        },
      );
      LoggerUtil.i("Local Notifications initialized successfully.");
    } catch (e) {
      LoggerUtil.e("Error initializing local notifications: $e");
    }

    // 4. Set up iOS Foreground Presentation Options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Set up Foreground handling (Styled local push in notification tray)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      LoggerUtil.i(
        "Foreground message received: ${message.notification?.title ?? message.data['title']}",
      );
      _showLocalNotification(message);
    });

    // 6. Handle app opened from notification (Background state)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      LoggerUtil.i(
        "App opened from notification (background): ${message.notification?.title}",
      );
      _handleNotificationResponse(_encodeRemoteMessageData(message));
    });

    // 7. Handle app opened from notification (Terminated state)
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        LoggerUtil.i(
          "App opened from notification (terminated): ${message.notification?.title}",
        );
        final payload = _encodeRemoteMessageData(message);
        _pendingNotificationPayload = payload;
        _handleNotificationResponse(payload);
      }
    });

    // 8. Get initial token
    try {
      String? token = await _fcm.getToken();
      LoggerUtil.d("FCM Token on init: $token");
    } catch (e) {
      LoggerUtil.w("FCM token unavailable (will retry): $e");
    }
  }

  String _encodeRemoteMessageData(RemoteMessage message) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);
    if (message.notification != null) {
      data['title'] ??= message.notification!.title;
      data['body'] ??= message.notification!.body;
    }
    return jsonEncode(data);
  }

  Map<String, dynamic> _parsePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) return {};
    try {
      if (rawPayload.startsWith('{') && rawPayload.endsWith('}')) {
        return jsonDecode(rawPayload) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Fallback: parse toString() format if not valid JSON
    final Map<String, dynamic> map = {};
    final cleaned = rawPayload.replaceAll('{', '').replaceAll('}', '');
    for (var pair in cleaned.split(',')) {
      final parts = pair.split(':');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts.sublist(1).join(':').trim();
      }
    }
    return map;
  }

  void _handleNotificationResponse(String? payload) {
    LoggerUtil.i("Notification response handled: $payload");
    if (payload == null) return;

    try {
      final data = _parsePayload(payload);
      final navState =
          SubscriptionExpiryService.instance.navigatorKey.currentState;
      if (navState == null) {
        LoggerUtil.w(
          "Navigator key not ready for notification deep linking - queuing payload",
        );
        _pendingNotificationPayload = payload;
        return;
      }

      final bookingId = (data['bookingId'] ?? data['ticketId'])?.toString();
      final type = (data['type'] ?? data['notificationType'])?.toString();
      final role = (data['role'] ?? data['audience'])?.toString() ?? 'admin';

      if (bookingId != null && bookingId.isNotEmpty) {
        if (role == 'customer') {
          if (type == 'ticket_completed_feedback') {
            navState.push(
              MaterialPageRoute(
                builder: (_) => CustomerFeedbackScreen(
                  ticketId: bookingId,
                  customerId: (data['customerId'] ?? data['id'] ?? '')
                      .toString(),
                  customerName: data['customerName']?.toString() ?? '',
                  deviceBrand: data['deviceBrand']?.toString(),
                  deviceType: data['deviceType']?.toString(),
                  engineerName: data['engineerName']?.toString(),
                ),
              ),
            );
            return;
          }
          navState.push(
            MaterialPageRoute(
              builder: (_) => AMCTrackMyService(
                customerName: data['customerName']?.toString() ?? '',
                customerId: (data['customerId'] ?? data['id'] ?? '').toString(),
                initialBookingId: bookingId,
              ),
            ),
          );
          return;
        } else if (role == 'engineer') {
          final user = FirebaseAuth.instance.currentUser;
          navState.push(
            MaterialPageRoute(
              builder: (_) => EngineerPage(
                userEmail: user?.email ?? '',
                userName:
                    data['engineerName'] ?? user?.displayName ?? 'Engineer',
                userId: user?.uid,
                notificationData: data,
              ),
            ),
          );
          return;
        } else {
          navState.push(
            MaterialPageRoute(
              builder: (_) => AdminPage_CusDetails(
                statusFilter: "",
                searchQuery: bookingId,
              ),
            ),
          );
          return;
        }
      }

      if (type == 'customer_notifications' ||
          data['audience'] == 'customer' ||
          role == 'customer') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => CustomerNotificationsPage(
              customerId: (data['customerId'] ?? data['id'] ?? '').toString(),
              customerName: data['customerName']?.toString() ?? '',
            ),
          ),
        );
        return;
      }

      if (type == 'engineer_notifications' ||
          data['audience'] == 'engineer' ||
          role == 'engineer') {
        final user = FirebaseAuth.instance.currentUser;
        navState.push(
          MaterialPageRoute(
            builder: (_) => EngineerNotificationsPage(
              engineerName:
                  data['engineerName'] ?? user?.displayName ?? 'Engineer',
              engineerId: user?.uid,
              userEmail: user?.email ?? '',
            ),
          ),
        );
        return;
      }

      if (type == 'subscription_expiry' || type == 'plan_expired') {
        navState.push(
          MaterialPageRoute(builder: (_) => PlanExpiredScreen(role: role)),
        );
        return;
      }

      if (type == 'new_ticket' ||
          type == 'notification' ||
          data['audience'] == 'admin') {
        navState.push(
          MaterialPageRoute(builder: (_) => const AdminNotificationsPage()),
        );
        return;
      }
    } catch (e) {
      LoggerUtil.e("Error navigating from notification response: $e");
    }
  }

  /// General purpose notification method with dynamic white-label branding
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    // Safety check: filter out test notifications
    final type = data?['type']?.toString().toLowerCase();
    final lowerTitle = title.toLowerCase();
    if (type == 'test' || lowerTitle.contains('test notification')) {
      return;
    }

    final theme = ThemeService.instance;
    final primaryColor = theme.primaryColor;
    final appName = theme.appName.isNotEmpty ? theme.appName : 'ServNex';
    final targetChannel = channelId ?? _resolveChannelId(data?['type']);

    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: appName,
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      targetChannel,
      _getChannelName(targetChannel),
      channelDescription: _getChannelDescription(targetChannel),
      importance: targetChannel == channelSubscription
          ? Importance.defaultImportance
          : Importance.max,
      priority: targetChannel == channelSubscription
          ? Priority.defaultPriority
          : Priority.high,
      icon: 'ic_stat_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: primaryColor,
      subText: appName,
      styleInformation: bigTextStyle,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      groupKey:
          'com.servnex.${theme.databaseName.isNotEmpty ? theme.databaseName : "general"}.notifications',
      category: _resolveCategory(data?['type']),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      final payloadString = data != null ? jsonEncode(data) : null;
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payloadString,
      );
    } catch (e) {
      LoggerUtil.e('Error displaying local notification: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notifType = message.data['type']?.toString().toLowerCase();
    final rawTitle = (message.notification?.title ?? message.data['title'] ?? '').toString().toLowerCase();
    if (notifType == 'test' || rawTitle.contains('test notification')) {
      LoggerUtil.d("Skipping test notification");
      return;
    }

    final notifKey = message.messageId ??
        message.data['eventId'] ??
        message.data['notificationId'] ??
        "${message.data['bookingId']}_${message.data['type']}_${message.data['status']}";
    if (_isDuplicateNotification(notifKey)) {
      LoggerUtil.d("Skipping duplicate foreground push: $notifKey");
      return;
    }

    final theme = ThemeService.instance;
    final primaryColor = theme.primaryColor;
    final appName = theme.appName.isNotEmpty ? theme.appName : 'ServNex';

    String title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    String body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type']?.toString();
    final targetChannel = _resolveChannelId(type);

    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: appName,
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      targetChannel,
      _getChannelName(targetChannel),
      channelDescription: _getChannelDescription(targetChannel),
      importance: targetChannel == channelSubscription
          ? Importance.defaultImportance
          : Importance.max,
      priority: targetChannel == channelSubscription
          ? Priority.defaultPriority
          : Priority.high,
      icon: 'ic_stat_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: primaryColor,
      subText: appName,
      styleInformation: bigTextStyle,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      groupKey:
          'com.servnex.${theme.databaseName.isNotEmpty ? theme.databaseName : "general"}.notifications',
      category: _resolveCategory(type),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    final payload = _encodeRemoteMessageData(message);
    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  String _resolveChannelId(String? type) {
    if (type == 'subscription_expiry' ||
        type == 'plan_expired' ||
        type == 'invoice') {
      return channelSubscription;
    }
    if (type == 'new_ticket' ||
        type == 'new_assignment' ||
        type == 'ticket_assigned' ||
        type == 'engineer_assigned' ||
        type == 'visit_scheduled' ||
        type == 'visit_rescheduled' ||
        type == 'ticket_cancelled' ||
        type == 'urgent' ||
        type == 'otp') {
      return channelHighImportance;
    }
    return channelGeneral;
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case channelSubscription:
        return 'Subscription & Billing';
      case channelGeneral:
        return 'General Notifications';
      case channelHighImportance:
      default:
        return 'Urgent & Ticket Alerts';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case channelSubscription:
        return 'Reminders for subscription renewals, payment confirmations, and invoices.';
      case channelGeneral:
        return 'General updates, announcements, and activity alerts.';
      case channelHighImportance:
      default:
        return 'Notifications for new tickets, urgent status updates, and OTPs.';
    }
  }

  AndroidNotificationCategory _resolveCategory(String? type) {
    if (type == 'subscription_expiry' || type == 'plan_expired') {
      return AndroidNotificationCategory.reminder;
    }
    if (type == 'new_ticket' || type == 'new_assignment') {
      return AndroidNotificationCategory.event;
    }
    return AndroidNotificationCategory.message;
  }

  /// Sends a notification to Firestore to be picked up by the targeted audience
  static Future<void> sendNotificationToFirestore({
    required String audience,
    required String title,
    required String body,
    String? type,
    String? bookingId,
    String? customerId,
    String? customerName,
    String? engineerName,
    String? tenantId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveTenant = (tenantId != null && tenantId.isNotEmpty)
          ? tenantId
          : (ThemeService.instance.databaseName.isNotEmpty
              ? ThemeService.instance.databaseName
              : (prefs.getString('tenantId') ??
                  prefs.getString('databaseName') ??
                  prefs.getString('admin_org_collection') ??
                  'global_user_directory'));

      final Map<String, dynamic> notificationData = {
        'audience': audience.trim().toLowerCase(),
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'seen': false,
        'fcmProcessed': false,
        'type': type,
        'bookingId': bookingId,
        'ticketId': bookingId,
        'customerId': customerId,
        'id': customerId,
        'customerName': customerName,
        'engineerName': engineerName,
        'tenantId': effectiveTenant,
      };

      if (additionalData != null) {
        notificationData.addAll(additionalData);
      }

      await FirestoreService.instance
          .collection('notifications', tenantId: effectiveTenant)
          .add(notificationData);
      LoggerUtil.i(
        "Notification sent to Firestore for audience: $audience in tenant: $effectiveTenant",
      );
    } catch (e) {
      LoggerUtil.e("Error sending notification to Firestore: $e");
    }
  }

  /// Marks all notifications as seen for an admin
  Future<void> markAllNotificationsAsRead(
    String tenantId, {
    String? appId,
  }) async {
    try {
      final query = await FirestoreService.instance
          .collection('notifications', tenantId: tenantId, appId: appId)
          .where('audience', isEqualTo: 'admin')
          .where('seen', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'seen': true});
      }
      await batch.commit();
    } catch (e) {
      LoggerUtil.e("Error marking all notifications as read: $e");
    }
  }

  /// Marks a specific notification as seen
  Future<void> markNotificationAsRead(
    String tenantId,
    String notificationId, {
    String? appId,
  }) async {
    try {
      await FirestoreService.instance
          .collection('notifications', tenantId: tenantId, appId: appId)
          .doc(notificationId)
          .update({'seen': true});
    } catch (e) {
      LoggerUtil.e("Error marking notification as read: $e");
    }
  }

  /// Stream of admin notifications
  Stream<List<Map<String, dynamic>>> getAdminNotificationsStream(
    String tenantId, {
    String? appId,
  }) {
    return FirestoreService.instance
        .collection('notifications', tenantId: tenantId, appId: appId)
        .where('audience', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .where((data) {
                final type = data['type']?.toString().toLowerCase();
                final title = data['title']?.toString().toLowerCase() ?? '';
                return type != 'test' && !title.contains('test notification');
              })
              .toList();

          // Sort in memory to avoid requiring a composite index
          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA); // Descending
          });
          return docs;
        });
  }

  /// Stream of unread admin notifications count
  Stream<int> getUnreadAdminNotificationsCountStream(
    String tenantId, {
    String? appId,
  }) {
    return FirestoreService.instance
        .collection('notifications', tenantId: tenantId, appId: appId)
        .where('audience', isEqualTo: 'admin')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final validDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            final type = data['type']?.toString().toLowerCase();
            final title = data['title']?.toString().toLowerCase() ?? '';
            return type != 'test' && !title.contains('test notification');
          });
          return validDocs.length;
        });
  }

  /// Stream of unread new ticket notifications for admin indicators and banners
  Stream<List<Map<String, dynamic>>> getUnreadNewTicketsNotificationStream(
    String tenantId, {
    String? appId,
  }) {
    return FirestoreService.instance
        .collection('notifications', tenantId: tenantId, appId: appId)
        .where('audience', isEqualTo: 'admin')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .where((data) => data['type'] == 'new_ticket')
              .toList();

          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA);
          });
          return docs;
        });
  }

  /// Stream of customer notifications
  Stream<List<Map<String, dynamic>>> getCustomerNotificationsStream(
    String tenantId, {
    required String customerId,
    String? uid,
    String? appId,
  }) {
    final cId = customerId.trim().toLowerCase();
    final uId = (uid ?? FirebaseAuth.instance.currentUser?.uid ?? '')
        .trim()
        .toLowerCase();

    return FirestoreService.instance
        .collection('notifications', tenantId: tenantId, appId: appId)
        .where('audience', isEqualTo: 'customer')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .where((doc) {
                final d = doc.data();
                final type = d['type']?.toString().toLowerCase();
                final title = d['title']?.toString().toLowerCase() ?? '';
                if (type == 'test' || title.contains('test notification')) {
                  return false;
                }
                final docCustId =
                    (d['customerId'] ?? d['userId'] ?? d['id'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                // If doc doesn't specify customerId or matches either customerId or uid
                if (docCustId.isEmpty) return true;
                return (cId.isNotEmpty && docCustId == cId) ||
                    (uId.isNotEmpty && docCustId == uId);
              })
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .toList();

          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA); // Descending
          });
          return docs;
        });
  }

  /// Stream of unread customer notifications count
  Stream<int> getCustomerUnreadNotificationsCountStream(
    String tenantId, {
    required String customerId,
    String? uid,
    String? appId,
  }) {
    return getCustomerNotificationsStream(
      tenantId,
      customerId: customerId,
      uid: uid,
      appId: appId,
    ).map((docs) => docs.where((d) => d['seen'] != true).length);
  }

  /// Marks all notifications as seen for a customer
  Future<void> markAllCustomerNotificationsAsRead(
    String tenantId, {
    required String customerId,
    String? uid,
    String? appId,
  }) async {
    try {
      final cId = customerId.trim().toLowerCase();
      final uId = (uid ?? FirebaseAuth.instance.currentUser?.uid ?? '')
          .trim()
          .toLowerCase();

      final query = await FirestoreService.instance
          .collection('notifications', tenantId: tenantId, appId: appId)
          .where('audience', isEqualTo: 'customer')
          .where('seen', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        final d = doc.data();
        final docCustId = (d['customerId'] ?? d['userId'] ?? d['id'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (docCustId.isEmpty ||
            (cId.isNotEmpty && docCustId == cId) ||
            (uId.isNotEmpty && docCustId == uId)) {
          batch.update(doc.reference, {'seen': true});
        }
      }
      await batch.commit();
    } catch (e) {
      LoggerUtil.e("Error marking all customer notifications as read: $e");
    }
  }

  /// Stream of engineer notifications
  Stream<List<Map<String, dynamic>>> getEngineerNotificationsStream(
    String tenantId, {
    required String engineerName,
    String? engineerId,
    String? appId,
  }) {
    final engName = engineerName.trim().toLowerCase();
    final engId = (engineerId ?? '').trim().toLowerCase();

    return FirestoreService.instance
        .collection('notifications', tenantId: tenantId, appId: appId)
        .where('audience', isEqualTo: 'engineer')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .where((doc) {
                final d = doc.data();
                final type = d['type']?.toString().toLowerCase();
                final title = d['title']?.toString().toLowerCase() ?? '';
                if (type == 'test' || title.contains('test notification')) {
                  return false;
                }

                final docEngName =
                    (d['engineerName'] ?? '').toString().trim().toLowerCase();
                final docEngId =
                    (d['engineerId'] ?? d['userId'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                // If doc has no specific engineer target, or matches name or id
                if (docEngName.isEmpty && docEngId.isEmpty) return true;
                if (engName.isNotEmpty && docEngName == engName) return true;
                if (engId.isNotEmpty &&
                    (docEngId == engId || docEngName == engId)) {
                  return true;
                }
                return false;
              })
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .toList();

          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA); // Descending (newest first)
          });
          return docs;
        });
  }

  /// Stream of unread engineer notifications count
  Stream<int> getUnreadEngineerNotificationsCountStream(
    String tenantId, {
    required String engineerName,
    String? engineerId,
    String? appId,
  }) {
    return getEngineerNotificationsStream(
      tenantId,
      engineerName: engineerName,
      engineerId: engineerId,
      appId: appId,
    ).map((docs) => docs.where((d) => d['seen'] != true).length);
  }

  /// Marks all notifications as seen for an engineer
  Future<void> markAllEngineerNotificationsAsRead(
    String tenantId, {
    required String engineerName,
    String? engineerId,
    String? appId,
  }) async {
    try {
      final engName = engineerName.trim().toLowerCase();
      final engId = (engineerId ?? '').trim().toLowerCase();

      final query = await FirestoreService.instance
          .collection('notifications', tenantId: tenantId, appId: appId)
          .where('audience', isEqualTo: 'engineer')
          .where('seen', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        final d = doc.data();
        final docEngName =
            (d['engineerName'] ?? '').toString().trim().toLowerCase();
        final docEngId =
            (d['engineerId'] ?? d['userId'] ?? '').toString().trim().toLowerCase();

        bool matches = false;
        if (docEngName.isEmpty && docEngId.isEmpty) matches = true;
        if (engName.isNotEmpty && docEngName == engName) matches = true;
        if (engId.isNotEmpty &&
            (docEngId == engId || docEngName == engId)) {
          matches = true;
        }

        if (matches) {
          batch.update(doc.reference, {'seen': true});
        }
      }
      await batch.commit();
    } catch (e) {
      LoggerUtil.e("Error marking all engineer notifications as read: $e");
    }
  }

  Future<void> registerToken({
    required String role,
    required String userId,
    String email = '',
    String? tenantId,
    String? customerId,
    String? username,
    String? phoneNumber,
    String? displayName,
  }) async {
    try {
      if (kIsWeb) {
        LoggerUtil.i("Skipping FCM token registration on web (not supported).");
        return;
      }

      final effectiveUserId = userId.isNotEmpty
          ? userId
          : (customerId ?? FirebaseAuth.instance.currentUser?.uid ?? '');

      if (effectiveUserId.isEmpty) {
        LoggerUtil.w(
          "Skipping token registration: UserId is empty for role $role",
        );
        return;
      }

      String? token = await _fcm.getToken();
      if (token == null) {
        LoggerUtil.w("FCM Token is null, cannot register.");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final effectiveTenant = (tenantId != null && tenantId.isNotEmpty)
          ? tenantId
          : (ThemeService.instance.databaseName.isNotEmpty
              ? ThemeService.instance.databaseName
              : (prefs.getString('tenantId') ??
                  prefs.getString('databaseName') ??
                  prefs.getString('admin_org_collection') ??
                  'global_user_directory'));

      final cleanRole = role.toLowerCase().trim();
      LoggerUtil.i(
        "Registering FCM token for $cleanRole ($effectiveUserId, customerId: $customerId, username: $username, phone: $phoneNumber) under tenant $effectiveTenant: $token",
      );

      _currentRegisteredRole = cleanRole;
      _currentRegisteredUserId = effectiveUserId;
      _currentRegisteredToken = token;
      _currentRegisteredTenant = effectiveTenant;

      String platform = defaultTargetPlatform.name;

      final tokenPayload = {
        'token': token,
        'tokens': FieldValue.arrayUnion([token]), // Multi-device support
        'email': email.trim().toLowerCase(),
        'userId': effectiveUserId,
        'uid': FirebaseAuth.instance.currentUser?.uid ?? effectiveUserId,
        'customerId': (customerId != null && customerId.isNotEmpty)
            ? customerId
            : effectiveUserId,
        'customerid': (customerId != null && customerId.isNotEmpty)
            ? customerId
            : effectiveUserId,
        'username': username ?? '',
        'userName': username ?? '',
        'engineerName': (cleanRole == 'engineer')
            ? (username ?? displayName ?? effectiveUserId)
            : '',
        'name': displayName ?? username ?? '',
        'displayName': displayName ?? username ?? '',
        'phone': phoneNumber ?? '',
        'mobileNumber': phoneNumber ?? '',
        'customerPhone': phoneNumber ?? '',
        'role': cleanRole,
        'tenantId': effectiveTenant,
        'lastUpdated': FieldValue.serverTimestamp(),
        'platform': platform,
      };

      // Collect all document IDs under which to register this token for foolproof lookup
      final targetDocIds = <String>{effectiveUserId};
      if (customerId != null && customerId.trim().isNotEmpty) {
        targetDocIds.add(customerId.trim());
      }
      if (username != null && username.trim().isNotEmpty) {
        targetDocIds.add(username.trim());
      }
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        targetDocIds.add(phoneNumber.trim());
      }
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        targetDocIds.add(currentUid);
      }

      // 1. Register in primary tenant
      for (final docId in targetDocIds) {
        final ref = FirestoreService.instance
            .collection('notifications_tokens', tenantId: effectiveTenant)
            .doc(cleanRole)
            .collection('tokens')
            .doc(docId);
        await ref
            .set(tokenPayload, SetOptions(merge: true))
            .then(
              (_) => LoggerUtil.i(
                "Token registered SUCCESSFULLY at ${ref.path}",
              ),
            )
            .catchError((e) {
              LoggerUtil.e("Token registration FAILED for $docId: $e");
              return null;
            });
      }

      // 2. Dual-register in global_user_directory if different from primary tenant
      if (effectiveTenant != 'global_user_directory') {
        for (final docId in targetDocIds) {
          final globalRef = FirestoreService.instance
              .collection(
                'notifications_tokens',
                tenantId: 'global_user_directory',
              )
              .doc(cleanRole)
              .collection('tokens')
              .doc(docId);
          await globalRef
              .set(tokenPayload, SetOptions(merge: true))
              .catchError((_) => null);
        }
      }

      // Setup token refresh listener
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) {
        LoggerUtil.i(
          "FCM Token refreshed: $newToken for $cleanRole ($effectiveUserId)",
        );
        _currentRegisteredToken = newToken;
        final refreshUpdate = {
          'token': newToken,
          'tokens': FieldValue.arrayUnion([newToken]),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        for (final docId in targetDocIds) {
          FirestoreService.instance
              .collection('notifications_tokens', tenantId: effectiveTenant)
              .doc(cleanRole)
              .collection('tokens')
              .doc(docId)
              .set(refreshUpdate, SetOptions(merge: true))
              .catchError((_) => null);

          if (effectiveTenant != 'global_user_directory') {
            FirestoreService.instance
                .collection(
                  'notifications_tokens',
                  tenantId: 'global_user_directory',
                )
                .doc(cleanRole)
                .collection('tokens')
                .doc(docId)
                .set(refreshUpdate, SetOptions(merge: true))
                .catchError((_) => null);
          }
        }
      });

      // Automatically maintain global notification listener for customer
      if (cleanRole == 'customer') {
        startCustomerNotificationListener(
          customerId: customerId ?? effectiveUserId,
          tenantId: effectiveTenant,
        );
      }
    } catch (e) {
      LoggerUtil.w(
        "FCM token registration temporarily unavailable (will retry): $e",
      );
    }
  }

  /// Starts global customer notification listener that stays active across all screens
  void startCustomerNotificationListener({
    required String customerId,
    String? tenantId,
  }) {
    if (kIsWeb) return;
    _customerNotificationsSubscription?.cancel();

    final effectiveTenant = (tenantId != null && tenantId.isNotEmpty)
        ? tenantId
        : (ThemeService.instance.databaseName.isNotEmpty
              ? ThemeService.instance.databaseName
              : 'global_user_directory');

    final cId = customerId.trim().toLowerCase();
    final uId = (FirebaseAuth.instance.currentUser?.uid ?? '')
        .trim()
        .toLowerCase();

    LoggerUtil.i(
      "Starting global customer notification listener for $customerId in $effectiveTenant",
    );

    try {
      _customerNotificationsSubscription = FirestoreService.instance
          .collection('notifications', tenantId: effectiveTenant)
          .where('audience', isEqualTo: 'customer')
          .where('seen', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final docId = change.doc.id;
                final data = change.doc.data();
                if (data == null) continue;

                final docCustId =
                    (data['customerId'] ?? data['userId'] ?? data['id'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                final matchesCustomer = docCustId.isEmpty ||
                    (cId.isNotEmpty && docCustId == cId) ||
                    (uId.isNotEmpty && docCustId == uId);

                if (!matchesCustomer) continue;

                // Deduplicate if already displayed in this local session
                if (_locallyHandledNotificationIds.contains(docId)) continue;
                _locallyHandledNotificationIds.add(docId);

                final notifKey = data['eventId'] ??
                    docId ??
                    "${data['bookingId']}_${data['type']}_${data['status']}";
                if (_isDuplicateNotification(notifKey?.toString())) {
                  LoggerUtil.d(
                    "Skipping duplicate local customer notification: $notifKey",
                  );
                  continue;
                }

                // Check timestamp: only show push for notifications received recently (within 5 minutes)
                final ts = data['timestamp'];
                if (ts is Timestamp) {
                  final age = DateTime.now().difference(ts.toDate());
                  if (age.inMinutes > 5) continue;
                }

                final title = (data['title'] ?? 'Service Update').toString();
                final body =
                    (data['body'] ?? 'Your ticket has been updated.').toString();

                showNotification(
                  title: title,
                  body: body,
                  data: data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                );
              }
            }
          }, onError: (err) {
            LoggerUtil.w("Global customer notification listener error: $err");
          });
    } catch (e) {
      LoggerUtil.w("Error setting up global customer notification listener: $e");
    }
  }

  /// Stops global customer notification listener on logout
  void stopCustomerNotificationListener() {
    _customerNotificationsSubscription?.cancel();
    _customerNotificationsSubscription = null;
    _locallyHandledNotificationIds.clear();
  }

  /// Removes current device token association when a user logs out
  Future<void> unregisterToken() async {
    try {
      if (kIsWeb) return;
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      stopCustomerNotificationListener();

      final role = _currentRegisteredRole;
      final userId = _currentRegisteredUserId;
      final token = _currentRegisteredToken ?? await _fcm.getToken();
      final tenant =
          _currentRegisteredTenant ??
          (ThemeService.instance.databaseName.isNotEmpty
              ? ThemeService.instance.databaseName
              : 'global_user_directory');

      if (role != null && userId != null && token != null) {
        LoggerUtil.i(
          "Unregistering FCM token for $role ($userId) in tenant $tenant",
        );
        final tokenDocRef = FirestoreService.instance
            .collection('notifications_tokens', tenantId: tenant)
            .doc(role)
            .collection('tokens')
            .doc(userId);

        await tokenDocRef
            .set({
              'tokens': FieldValue.arrayRemove([token]),
              'lastUnregistered': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((e) {
              LoggerUtil.w("Error removing token during unregistration: $e");
              return null;
            });
      }

      _currentRegisteredRole = null;
      _currentRegisteredUserId = null;
      _currentRegisteredToken = null;
      _currentRegisteredTenant = null;
    } catch (e) {
      LoggerUtil.w("FCM unregisterToken failed: $e");
    }
  }
}
