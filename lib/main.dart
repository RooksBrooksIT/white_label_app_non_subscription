import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:subscription_rooks_app/firebase_options.dart';
import 'package:subscription_rooks_app/frontend/screens/splash_screen.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:subscription_rooks_app/services/subscription_expiry_service.dart';
import 'package:subscription_rooks_app/services/invoice_email_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Info: .env not loaded or not available on web: $e');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    debugPrint('Firebase App Check initialized');
  } catch (e) {
    debugPrint('Firebase App Check initialization failed: $e');
  }

  // Set up background message handler (mobile only)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize Notification Service
  await NotificationService.instance.initialize();

  // Initialize Auth
  await AuthStateService.instance.init();

  // Initialize Theme
  await ThemeService.instance.init();

  // Pre-initialize and warm up branding logo cache for instant Admin Dashboard display
  StorageService.instance.initLogoCache().catchError((e) {
    debugPrint('Logo cache init error: $e');
    return null;
  });

  // Initialize Subscription Expiry Service
  SubscriptionExpiryService.instance.initialize();

  // Retry any pending invoice emails in the background (fire-and-forget)
  InvoiceEmailService.instance.retryPendingInvoices().catchError((e) {
    debugPrint('Background invoice retry failed: $e');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: SubscriptionExpiryService.instance.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Servnex',
          theme: ThemeService.instance.themeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}
