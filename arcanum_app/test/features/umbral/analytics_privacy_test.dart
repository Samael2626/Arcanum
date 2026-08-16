import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Analitica de la Lectura del Umbral.
///
/// Estado real, comprobado y no comodo: **la app no tiene ni un emisor de
/// analitica**. `firebase_analytics` esta en `pubspec.yaml` pero no se importa
/// ni se instancia en ningun sitio de `lib/`. No hay eventos que auditar.
///
/// Este test no simula uno para tener algo verde. Fija la ausencia: el dia que
/// alguien conecte un emisor, falla y obliga a decidir a mano que puede llevar
/// un evento — que, segun la direccion editorial, nunca es texto, ni
/// ciphertext, ni fecha, hora o lugar natal exactos.
void main() {
  List<File> dartFiles(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('no existe ningun emisor de analitica en la app', () {
    const emisores = [
      'package:firebase_analytics/',
      'FirebaseAnalytics',
      'logEvent(',
      'setUserProperty',
      'setUserId(',
      'package:amplitude',
      'package:mixpanel',
      'package:posthog',
    ];
    for (final file in dartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final emisor in emisores) {
        expect(
          source,
          isNot(contains(emisor)),
          reason:
              '${file.path} introduce analitica. Antes de seguir: ningun evento '
              'puede llevar texto, ciphertext ni fecha, hora o lugar natal '
              'exactos.',
        );
      }
    }
  });

  test('el modulo del Umbral no habla con crashlytics ni con analitica', () {
    for (final file in dartFiles('lib/features/umbral')) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('firebase_analytics')));
      expect(source, isNot(contains('firebase_crashlytics')));
      expect(source, isNot(contains('recordError')));
    }
  });

  test('la reflexion no sale del modulo por ninguna via que no sea el Grimorio', () {
    final vista = File(
      'lib/features/umbral/presentation/umbral_reading_view.dart',
    ).readAsStringSync();

    // La unica salida del texto es grimoireCreate, y va cifrado.
    expect(vista, contains('encryptText'));
    expect(vista, contains('grimoireCreate'));
    expect(vista, contains("'encrypted_content': sealed.ciphertext"));
    // Nunca el texto en claro en el cuerpo de la peticion.
    expect(vista, isNot(contains("'content': text")));
    expect(vista, isNot(contains('_controller.text,')));
  });

  test('el cache de la lectura va cifrado, no en preferencias en claro', () {
    final cache = File(
      'lib/features/umbral/data/umbral_cache.dart',
    ).readAsStringSync();

    expect(cache, contains('GrimoireCrypto'));
    expect(cache, contains('FlutterSecureStorage'));
    expect(cache, contains('encryptText'));
    expect(cache, isNot(contains('SharedPreferences')));
  });
}
