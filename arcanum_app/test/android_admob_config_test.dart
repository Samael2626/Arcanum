import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App ID de prueba oficial de Google para desarrollo. No factura impresiones.
const _testAppId = 'ca-app-pub-3940256099942544~3347511713';

void main() {
  group('AdMob application id', () {
    // Sin este meta-data, MobileAdsInitProvider aborta el arranque con
    // "IllegalStateException: Missing application ID" y la app no abre.
    test('el manifiesto declara APPLICATION_ID con placeholder', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('com.google.android.gms.ads.APPLICATION_ID'),
        reason: 'sin el meta-data, la app muere al arrancar',
      );
      expect(
        manifest,
        contains(r'android:value="${admobApplicationId}"'),
        reason: 'el valor lo inyecta Gradle, no se escribe a mano',
      );
      // El ID no puede vivir en el manifiesto: se filtraria en cada clon.
      expect(manifest, isNot(contains('ca-app-pub-')));
    });

    test('gradle resuelve el id: prueba en debug, entorno en release', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();

      expect(gradle, contains('manifestPlaceholders["admobApplicationId"]'));
      expect(gradle, contains("System.getenv(\"ADMOB_APP_ID\")"));
      expect(gradle, contains(_testAppId),
          reason: 'debug debe usar el App ID de prueba de Google');
      // Falla cerrado: un release sin ADMOB_APP_ID no debe producir APK.
      expect(gradle, contains('ADMOB_APP_ID ausente'));
      expect(
        RegExp(r'releaseRequested\s*&&\s*!admobApplicationId').hasMatch(gradle),
        isTrue,
        reason: 'el build release debe abortar si falta ADMOB_APP_ID',
      );
      // El unico ca-app-pub del repositorio es el de prueba.
      final ids = RegExp(r'ca-app-pub-[0-9]+~[0-9]+')
          .allMatches(gradle)
          .map((m) => m.group(0))
          .toSet();
      expect(ids, {_testAppId});
    });

    test('el APK debug ya construido lleva el id de prueba', () {
      // Solo corre si hay APK: no dispara un build de 2 minutos en cada suite.
      final apk = File('build/app/outputs/flutter-apk/app-debug.apk');
      if (!apk.existsSync()) {
        return;
      }
      final aapt = _findAapt2();
      if (aapt == null) {
        return;
      }
      final dump = Process.runSync(aapt, [
        'dump', 'xmltree', apk.path, '--file', 'AndroidManifest.xml',
      ]);
      final out = '${dump.stdout}';
      expect(out, contains('com.google.android.gms.ads.APPLICATION_ID'));
      expect(out, contains(_testAppId));
      expect(out, isNot(contains(r'${admobApplicationId}')),
          reason: 'el placeholder debe quedar resuelto en el APK');
    });
  });
}

String? _findAapt2() {
  final home = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (home == null) return null;
  final buildTools = Directory('$home/build-tools');
  if (!buildTools.existsSync()) return null;
  final versions = buildTools.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final dir in versions.reversed) {
    for (final name in ['aapt2.exe', 'aapt2']) {
      final candidate = File('${dir.path}/$name');
      if (candidate.existsSync()) return candidate.path;
    }
  }
  return null;
}
