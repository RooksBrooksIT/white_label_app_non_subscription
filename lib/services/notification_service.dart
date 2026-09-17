import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_notifications_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/subscription/plan_expired_screen.dart';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background work
  await Firebase.initializeApp();
  LoggerUtil.i("Handling a background message: ${message.messageId}");

  // If the message has a notification payload, the OS handles it automatically on Android/iOS.
  // We only show a local notification if it's a data-only message or if explicitly requested.
  if (message.notification == null && message.data.isNotEmpty) {
    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    const iosInit = DarwinInitializationSettings();
    await localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final title = message.data['title'] ?? 'New Update';
    final body = message.data['body'] ?? 'You have a new message';
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
      'high_importance_channel',
      'Urgent & Ticket Alerts',
      channelDescription: 'Notifications for new tickets, urgent status updates, and OTPs.',
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
  }
}

class NotificationService {
  // Android Notification Channels
  static const String channelHighImportance = 'high_importance_channel';
  static const String channelGeneral = 'general_notifications_channel';
  static const String channelSubscription = 'subscription_channel';

  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> initialize() async {
    LoggerUtil.i("Initializing NotificationService with white-label UI enhancements...");

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
        channelHighImportance,
        'Urgent & Ticket Alerts',
        description: 'Notifications for new tickets, urgent status updates, and OTPs.',
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
        description: 'Reminders for subscription renewals, payment confirmations, and invoices.',
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
        _handleNotificationResponse(_encodeRemoteMessageData(message));
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
      final navState = SubscriptionExpiryService.instance.navigatorKey.currentState;
      if (navState == null) {
        LoggerUtil.w("Navigator key not ready for notification deep linking");
        return;
      }

      final bookingId = data['bookingId']?.toString();
      final type = data['type']?.toString();
      final role = data['role']?.toString() ?? data['audience']?.toString() ?? 'admin';

      if (bookingId != null && bookingId.isNotEmpty) {
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

      if (type == 'subscription_expiry' || type == 'plan_expired') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => PlanExpiredScreen(role: role),
          ),
        );
        return;
      }

      if (type == 'new_ticket' || type == 'notification' || data['audience'] == 'admin') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const AdminNotificationsPage(),
          ),
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

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
          groupKey: 'com.servnex.${theme.databaseName.isNotEmpty ? theme.databaseName : "general"}.notifications',
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

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
          groupKey: 'com.servnex.${theme.databaseName.isNotEmpty ? theme.databaseName : "general"}.notifications',
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
    if (type == 'subscription_expiry' || type == 'plan_expired' || type == 'invoice') {
      return channelSubscription;
    }
    if (type == 'new_ticket' || type == 'new_assignment' || type == 'urgent' || type == 'otp') {
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
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, dynamic> notificationData = {
        'audience': audience,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
        'type': type,
        'bookingId': bookingId,
        'customerId': customerId,
        'customerName': customerName,
        'engineerName': engineerName,
      };

      if (additionalData != null) {
        notificationData.addAll(additionalData);
      }

      await FirestoreService.instance
          .collection('notifications')
          .add(notificationData);
      LoggerUtil.i("Notification sent to Firestore for audience: $audience");
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
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

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
        .map((snapshot) => snapshot.docs.length);
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

  Future<void> registerToken({
    required String role,
    required String userId,
    String email = '',
  }) async {
    try {
      if (kIsWeb) {
        LoggerUtil.i("Skipping FCM token registration on web (not supported).");
        return;
      }

      if (userId.isEmpty) {
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

      LoggerUtil.i("Registering FCM token for $role ($userId): $token");
      final docPath = FirestoreService.instance
          .collection('notifications_tokens')
          .doc(role)
          .collection('tokens')
          .doc(userId)
          .path;
      LoggerUtil.d("Full Firestore Path: $docPath");

      String platform = defaultTargetPlatform.name;

      await FirestoreService.instance
          .collection('notifications_tokens')
          .doc(role)
          .collection('tokens')
          .doc(userId)
          .set({
            'token': token,
            'email': email,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': platform,
          }, SetOptions(merge: true))
          .then(
            (_) => LoggerUtil.i("Token registered SUCCESSFULLY at $docPath"),
          )
          .catchError((e) {
            LoggerUtil.e("Token registration FAILED: $e");
            return null;
          });

      LoggerUtil.i("Token registration initiated for $userId");

      _fcm.onTokenRefresh.listen((newToken) {
        LoggerUtil.i("FCM Token refreshed: $newToken");
        FirestoreService.instance
            .collection('notifications_tokens')
            .doc(role)
            .collection('tokens')
            .doc(userId)
            .update({
              'token': newToken,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      });
    } catch (e) {
      // SERVICE_NOT_AVAILABLE is transient — Firebase retries automatically.
      LoggerUtil.w(
        "FCM token registration temporarily unavailable (will retry): $e",
      );
    }
  }
}
