import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background work
  await Firebase.initializeApp();
  LoggerUtil.i("Handling a background message: ${message.messageId}");

  // If the message has a notification payload, the OS handles it automatically on Android/iOS.
  // We only need to show a local notification if it's a data-only message or if we want custom behavior.
  if (message.notification == null && message.data.isNotEmpty) {
    // For data-only messages, we show it manually.
    // Note: We create a separate plugin instance here because the singleton might not be ready in the background isolate.
    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await localNotifications.initialize(
      settings: InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final title = message.data['title'] ?? 'New Update';
    final body = message.data['body'] ?? 'You have a new message';

    await localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: message.data.toString(),
    );
  }
}

class NotificationService {
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription =
      'This channel is used for important notifications.';

  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> initialize() async {
    LoggerUtil.i("Initializing NotificationService...");

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

    // 2. Setup High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }

    // 3. Initialize Local Notifications
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    final InitializationSettings initSettings = InitializationSettings(
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

    // 4. Set up iOS Foreground Presentation Options, 5. Foreground handling, 6. App opened, 7. Get token
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Set up Foreground handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      LoggerUtil.i(
        "Foreground message received: ${message.notification?.title}",
      );
      _showLocalNotification(message);
    });

    // 6. Handle app opened from notification (Background state)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      LoggerUtil.i(
        "App opened from notification (background): ${message.notification?.title}",
      );
      _handleNotificationResponse(message.data.toString());
    });

    // 7. Handle app opened from notification (Terminated state)
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        LoggerUtil.i(
          "App opened from notification (terminated): ${message.notification?.title}",
        );
        _handleNotificationResponse(message.data.toString());
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

  void _handleNotificationResponse(String? payload) {
    LoggerUtil.i("Notification response handled: $payload");
    // You can add global navigation logic here using a navigator key if needed
  }

  /// General purpose notification method
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: data?.toString(),
      );
    } catch (e) {
      LoggerUtil.e('Error displaying local notification: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    String title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    String body = message.notification?.body ?? message.data['body'] ?? '';

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: message.data.toString(),
    );
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
