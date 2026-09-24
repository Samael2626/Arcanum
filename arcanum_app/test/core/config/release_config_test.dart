import 'package:arcanum_app/core/config/release_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los cuatro casos de anuncios se fueron con el SDK en la 1.0.5. Probaban que
/// las unidades de AdMob solo se exigieran con `ADS_ENABLED=true`; sin
/// `google_mobile_ads` no hay unidad que exigir, y la guardia contra volver a
/// meterlo vive en `test/android_admob_config_test.dart`.
void main() {
  test('release rechaza RevenueCat sin API key', () {
    expect(
      () => ReleaseConfig.validateForStartup(releaseMode: true, apiKey: ''),
      throwsStateError,
    );
  });

  test('release acepta configuración externa completa', () {
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: 'public_sdk_key',
      ),
      returnsNormally,
    );
  });

  test('desarrollo permite omitir configuración externa', () {
    expect(
      () => ReleaseConfig.validateForStartup(releaseMode: false),
      returnsNormally,
    );
  });
}
