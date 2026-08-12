import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('opciones de Firebase para Android', () {
    test('no quedan placeholders sin sustituir', () {
      final android = DefaultFirebaseOptions.android;
      for (final valor in [
        android.apiKey,
        android.appId,
        android.messagingSenderId,
        android.projectId,
      ]) {
        expect(valor, isNot(startsWith('YOUR_')),
            reason: 'un placeholder aqui deja la app sin arrancar');
        expect(valor, isNotEmpty);
      }
      expect(android.projectId, 'arcanum-app-magick');
      expect(android.appId, contains(':android:'));
    });

    test('coinciden con google-services.json cuando esta presente', () {
      // El json no se versiona (lo inyecta el entorno de build). Si no esta,
      // este test no puede comparar y se salta.
      final file = File('android/app/google-services.json');
      if (!file.existsSync()) {
        return;
      }
      final gs = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final info = gs['project_info'] as Map<String, dynamic>;
      final client = (gs['client'] as List).firstWhere((c) =>
          (((c as Map)['client_info'] as Map)['android_client_info']
              as Map)['package_name'] ==
          'com.arcanum.magick') as Map<String, dynamic>;

      final android = DefaultFirebaseOptions.android;
      expect(android.projectId, info['project_id']);
      expect(android.messagingSenderId, info['project_number']);
      expect(android.storageBucket, info['storage_bucket']);
      expect(android.appId,
          (client['client_info'] as Map)['mobilesdk_app_id']);
      expect(android.apiKey,
          ((client['api_key'] as List).first as Map)['current_key']);
    });
  });
}
