export 'connectivity_checker_base.dart';

import 'connectivity_checker_base.dart';
import 'connectivity_checker_stub.dart'
    if (dart.library.io) 'connectivity_checker_io.dart'
    if (dart.library.js_interop) 'connectivity_checker_web.dart' as impl;

/// Creates a platform-specific connectivity checker instance.
PlatformConnectivityChecker createPlatformConnectivityChecker() =>
    impl.getPlatformConnectivityChecker();
