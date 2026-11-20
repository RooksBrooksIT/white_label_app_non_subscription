import 'package:flutter/material.dart';
import 'web_navigation_observer_base.dart';

/// Native (Android / iOS / Desktop) no-op navigation observer.
/// Native platforms automatically dispatch back gestures via the Flutter engine.
class IONavigationObserver extends WebNavigationObserver {
  static final IONavigationObserver instance = IONavigationObserver._();
  IONavigationObserver._();

  @override
  void init(GlobalKey<NavigatorState> navigatorKey) {
    // Native platforms handle hardware back buttons and gestures via the platform channel.
  }

  @override
  void dispose() {}
}

WebNavigationObserver getPlatformNavigationObserver() =>
    IONavigationObserver.instance;
