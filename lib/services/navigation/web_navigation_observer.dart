export 'web_navigation_observer_base.dart';

import 'web_navigation_observer_base.dart';
import 'web_navigation_observer_stub.dart'
    if (dart.library.io) 'web_navigation_observer_io.dart'
    if (dart.library.js_interop) 'web_navigation_observer_web.dart' as impl;

/// Returns the platform-appropriate WebNavigationObserver instance.
WebNavigationObserver getWebNavigationObserver() =>
    impl.getPlatformNavigationObserver();
