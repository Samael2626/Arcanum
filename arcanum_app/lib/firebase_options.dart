// Opciones de Firebase por plataforma.
//
// Los valores de Android salen de android/app/google-services.json (que NO se
// versiona) y estan verificados contra el: appId = mobilesdk_app_id,
// messagingSenderId = project_number. No son secretos: viajan dentro del APK y
// se protegen restringiendo la clave por package y huella SHA en la consola.
//
// Regenerar con: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma',
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

  // iOS sigue sin registrar en la consola: no hay cliente iOS en
  // google-services.json, asi que estos valores no se pueden verificar.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'arcanum-app-magick',
    storageBucket: 'arcanum-app-magick.firebasestorage.app',
    iosBundleId: 'com.arcanum.magick',
  );
}
