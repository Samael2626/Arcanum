import 'package:arcanum_app/core/config/release_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release rechaza RevenueCat sin API key', () {
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: '',
        rewardedAndroid: 'rewarded_id',
        interstitialAndroid: 'interstitial_id',
      ),
      throwsStateError,
    );
  });

  test('release rechaza unidades AdMob ausentes cuando los anuncios estan activos', () {
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: 'public_sdk_key',
        ads: true,
      ),
      throwsStateError,
    );
  });

  test('con anuncios apagados no se exigen unidades AdMob', () {
    // Los anuncios estan apagados hasta que exista el UMP: exigir sus
    // credenciales impediria arrancar un release que no las necesita.
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: 'public_sdk_key',
        ads: false,
      ),
      returnsNormally,
    );
  });

  test('RevenueCat se exige aunque los anuncios esten apagados', () {
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: '',
        ads: false,
      ),
      throwsStateError,
    );
  });

  test('release acepta configuración externa completa', () {
    expect(
      () => ReleaseConfig.validateForStartup(
        releaseMode: true,
        apiKey: 'public_sdk_key',
        rewardedAndroid: 'rewarded_id',
        interstitialAndroid: 'interstitial_id',
        ads: true,
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
