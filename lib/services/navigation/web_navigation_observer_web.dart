import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/utils/logger_util.dart';
import 'web_navigation_observer_base.dart';

@JS('history.pushState')
external void _historyPushState(JSAny? data, JSString unused, JSString? url);

@JS('history.back')
external void _historyBack();

@JS('window.addEventListener')
external void _windowAddEventListener(JSString type, JSFunction listener);

@JS('window.removeEventListener')
external void _windowRemoveEventListener(JSString type, JSFunction listener);

/// Web navigation observer that synchronizes Flutter's internal Navigator stack
/// with the browser's history API (`window.history.pushState`, `window.onpopstate`).
///
/// Enables fast, smooth Back and Forward browser button navigation without full-page reloads,
/// redundant splash screens, or accidental exits when internal routes exist.
class BrowserNavigationObserver extends WebNavigationObserver {
  static final BrowserNavigationObserver instance =
      BrowserNavigationObserver._();
  BrowserNavigationObserver._();

  GlobalKey<NavigatorState>? _navigatorKey;
  int _historyDepth = 0;
  bool _isHandlingPopState = false;
  bool _isPoppingFromApp = false;
  JSFunction? _popStateListener;
  bool _initialized = false;

  @override
  void init(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    try {
      _popStateListener = ((JSAny? _) {
        _handleBrowserPop();
      }).toJS;

      _windowAddEventListener('popstate'.toJS, _popStateListener!);
      LoggerUtil.d('BrowserNavigationObserver: popstate listener registered');
    } catch (e) {
      LoggerUtil.w('BrowserNavigationObserver init error: $e');
    }
  }

  /// Only genuine full-screen PageRoutes participate in browser history synchronization.
  /// Transient popup routes (such as DropdownRoute, DialogRoute, ModalBottomSheetRoute,
  /// PopupMenuRoute) are UI overlays and must never push to or pop from browser history.
  bool _isPageRoute(Route<dynamic> route) => route is PageRoute;

  void _handleBrowserPop() {
    if (_isPoppingFromApp) {
      // Pop was initiated by in-app Navigator.pop() which called history.back().
      _isPoppingFromApp = false;
      return;
    }

    final nav = _navigatorKey?.currentState ?? navigator;
    if (nav != null && nav.canPop()) {
      _isHandlingPopState = true;
      try {
        nav.pop();
      } finally {
        _isHandlingPopState = false;
      }
    } else {
      // Root screen reached. Push one entry to prevent browser accidentally
      // exiting the application when internal routes have finished popping.
      try {
        _historyPushState(null, ''.toJS, null);
      } catch (_) {}
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!_isPageRoute(route)) return;
    if (previousRoute != null && _isPageRoute(previousRoute)) {
      _historyDepth++;
      if (!_isHandlingPopState) {
        try {
          _historyPushState(null, ''.toJS, null);
        } catch (_) {}
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!_isPageRoute(route)) return;
    if (_historyDepth > 0) {
      _historyDepth--;
    }

    if (!_isHandlingPopState) {
      _isPoppingFromApp = true;
      try {
        _historyBack();
      } catch (_) {
        _isPoppingFromApp = false;
      }
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (!_isPageRoute(route)) return;
    if (_historyDepth > 0) _historyDepth--;
  }

  @override
  void dispose() {
    if (_popStateListener != null) {
      try {
        _windowRemoveEventListener('popstate'.toJS, _popStateListener!);
      } catch (_) {}
    }
  }
}

WebNavigationObserver getPlatformNavigationObserver() =>
    BrowserNavigationObserver.instance;
