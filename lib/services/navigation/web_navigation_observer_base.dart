import 'package:flutter/material.dart';

/// Base contract for web navigation synchronization with browser history.
abstract class WebNavigationObserver extends NavigatorObserver {
  /// Initializes browser history synchronization with the application's root Navigator.
  void init(GlobalKey<NavigatorState> navigatorKey);

  /// Disposes any registered platform listeners.
  void dispose();
}
