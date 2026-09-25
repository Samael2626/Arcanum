import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia contra la REINTRODUCCION de AdMob, no contra su mala configuracion.
///
/// Este fichero comprobaba lo contrario: que el App ID estuviera bien resuelto
/// en Gradle y declarado en el manifiesto. Desde la 1.0.5 no hay SDK que
/// configurar, y el motivo no fue estetico:
///
/// `MobileAdsInitProvider` es un ContentProvider declarado por el propio SDK.
/// Arranca ANTES que Dart, asi que la bandera `ADS_ENABLED=false` NO lo
/// detenia: el SDK viajaba dentro del AAB e inicializaba igual. Para enviar a
/// produccion habia dos salidas, implementar el consentimiento UMP o sacar el
/// SDK, y la via de ingreso por anuncios no estaba dando ninguno.
///
/// Por eso el test se invierte. Volver a meter `google_mobile_ads` sin UMP es
/// exactamente el fallo que se acaba de arreglar, y tiene que costar un test
/// rojo en vez de un envio rechazado.
void main() {
  group('sin AdMob', () {
    test('el pubspec no declara google_mobile_ads', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        isNot(contains('google_mobile_ads')),
        reason: 'sin UMP el SDK no puede volver: se inicializa antes que Dart',
      );
    });

    test('nada en lib/ importa el SDK ni nombra una unidad de anuncio', () {
      final ofensores = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if (src.contains('package:google_mobile_ads') ||
            src.contains('ca-app-pub-')) {
          ofensores.add(f.path);
        }
      }
      expect(ofensores, isEmpty);
    });

    test('el manifiesto no declara el APPLICATION_ID de ads', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      // Sin SDK, este meta-data apuntaria a un placeholder que Gradle ya no
      // define, y el build fallaria al fusionar el manifiesto.
      expect(manifest, isNot(contains('com.google.android.gms.ads')));
      expect(manifest, isNot(contains(r'${admobApplicationId}')));
    });

    test('gradle no inyecta el placeholder ni exige la credencial', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle, isNot(contains('manifestPlaceholders["admobApplicationId"]')));
      expect(gradle, isNot(contains('ADMOB_APP_ID')));
      // Ni el de prueba de Google: si no hay SDK, no hay ID de ninguna clase.
      expect(gradle, isNot(contains('ca-app-pub-')));
    });
  });
}
