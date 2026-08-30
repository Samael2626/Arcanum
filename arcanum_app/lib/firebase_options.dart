// Generated from the Firebase Android app registered by FlutterFire CLI.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions solo soporta Android en esta versión.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLPFlUf7uMo1Rg4vse99l41xuHQTANCaw',
    appId: '1:330365004606:android:6dc30ffbaf05eec72c9a6f',
    messagingSenderId: '330365004606',
    projectId: 'arcanum-app-magick',
    storageBucket: 'arcanum-app-magick.firebasestorage.app',
  );
}
