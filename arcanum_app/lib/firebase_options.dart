// Archivo auto-generado por FlutterFire CLI.
// Reemplazar con el real descargado desde Firebase Console
// después de registrar la app Android (com.arcanum.magick).
//
// Para generar: flutterfire configure
// O manualmente: Firebase Console → Project Settings → Add app → Android
// → descargar google-services.json + crear firebase_options.dart

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

  // TODO: Reemplazar con valores reales de Firebase Console
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'arcanum-app-magick',
    storageBucket: 'arcanum-app-magick.firebasestorage.app',
  );

  // TODO: Configurar cuando se agregue iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'arcanum-app-magick',
    storageBucket: 'arcanum-app-magick.firebasestorage.app',
    iosBundleId: 'com.arcanum.magick',
  );
}
