import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:subscription_rooks_app/firebase_options.dart';
import 'package:subscription_rooks_app/frontend/screens/splash_screen.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Notification Service
  await NotificationService.instance.initialize();

  // Initialize Auth
  await AuthStateService.instance.init();

  // Initialize Theme
  await ThemeService.instance.init();

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
          debugShowCheckedModeBanner: false,
          title: 'Flutter App',
          theme: ThemeService.instance.themeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}
