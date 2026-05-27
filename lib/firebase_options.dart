
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCa7_BZdC0heXPWyQ-5LVyvkHZlZhz7q68',
    appId: '1:416851266920:web:ac0ef84936307b84981add',
    messagingSenderId: '416851266920',
    projectId: 'white-label-app-33300',
    authDomain: 'white-label-app-33300.firebaseapp.com',
    storageBucket: 'white-label-app-33300.firebasestorage.app',
    measurementId: 'G-2FPJB7F297',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDs7QWcGlXCl_vnX1XcWBuz2iahUrv-Hho',
    appId: '1:416851266920:android:b6a0eb5de156185f981add',
    messagingSenderId: '416851266920',
    projectId: 'white-label-app-33300',
    storageBucket: 'white-label-app-33300.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCjARQexL63AacrvSAtM35R1dZajdDKtuY',
    appId: '1:416851266920:ios:56571df5402249e6981add',
    messagingSenderId: '416851266920',
    projectId: 'white-label-app-33300',
    storageBucket: 'white-label-app-33300.firebasestorage.app',
    iosBundleId: 'com.example.subscriptionRooksApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCjARQexL63AacrvSAtM35R1dZajdDKtuY',
    appId: '1:416851266920:ios:56571df5402249e6981add',
    messagingSenderId: '416851266920',
    projectId: 'white-label-app-33300',
    storageBucket: 'white-label-app-33300.firebasestorage.app',
    iosBundleId: 'com.example.subscriptionRooksApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCa7_BZdC0heXPWyQ-5LVyvkHZlZhz7q68',
    appId: '1:416851266920:web:7470dab5635b18b4981add',
    messagingSenderId: '416851266920',
    projectId: 'white-label-app-33300',
    authDomain: 'white-label-app-33300.firebaseapp.com',
    storageBucket: 'white-label-app-33300.firebasestorage.app',
    measurementId: 'G-WJGLNB3CY3',
  );
}
