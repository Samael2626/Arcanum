import 'package:flutter/foundation.dart';

abstract final class ReleaseConfig {
  static const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const admobRewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const admobInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
  );
  // Las tres apuntan a lo que GitHub Pages sirve DE VERDAD: la rama
  // `gh-pages`, en la raiz, con ficheros `.html` generados por Jekyll. Antes
  // apuntaban a `/privacy/` y `/account-deletion/`, que devuelven 404: la app
  // llevaba un enlace muerto a su propia politica de privacidad, y Play exige
  // que la URL de borrado de cuenta funcione.
  static const privacyPolicyUrl =
      'https://samael2626.github.io/Arcanum/privacy-policy.html';
  static const accountDeletionUrl =
      'https://samael2626.github.io/Arcanum/account-deletion.html';
  static const termsUrl =
      'https://samael2626.github.io/Arcanum/terms-of-service.html';

  /// Version de la politica publicada. Debe coincidir con el pie de
  /// `legal-site/privacy/index.html`: es lo que se guarda junto a cada
  /// consentimiento y lo que decide si hay que volver a pedirlo.
  static const policyVersion = '2026-08-30';

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
