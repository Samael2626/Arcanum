import 'package:flutter/foundation.dart';

abstract final class ReleaseConfig {
  static const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const admobRewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const admobInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
  );
  static const privacyPolicyUrl =
      'https://samael2626.github.io/Arcanum/privacy/';
  static const accountDeletionUrl =
      'https://samael2626.github.io/Arcanum/account-deletion/';

  static bool get revenueCatEnabled => revenueCatApiKey.trim().isNotEmpty;

  /// Los anuncios estan apagados por defecto hasta que exista el consentimiento
  /// UMP, asi que sus unidades solo se exigen cuando ADS_ENABLED esta activo.
  /// Pedirlas siempre obligaria a inyectar credenciales que la app no usa.
  static const adsEnabled = bool.fromEnvironment('ADS_ENABLED');

  static void validateForStartup({
    bool releaseMode = kReleaseMode,
    String apiKey = revenueCatApiKey,
    String rewardedAndroid = admobRewardedAndroid,
    String interstitialAndroid = admobInterstitialAndroid,
    bool ads = adsEnabled,
  }) {
    if (!releaseMode) return;

    final missing = <String>[
      if (apiKey.trim().isEmpty) 'REVENUECAT_API_KEY',
      if (ads && rewardedAndroid.trim().isEmpty) 'ADMOB_REWARDED_ANDROID',
      if (ads && interstitialAndroid.trim().isEmpty) 'ADMOB_INTERSTITIAL_ANDROID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuración release ausente: ${missing.join(', ')}. '
        'Inyecta valores con --dart-define.',
      );
    }
  }
}
