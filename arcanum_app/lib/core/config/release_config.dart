import 'package:flutter/foundation.dart';

abstract final class ReleaseConfig {
  static const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY');
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

  /// SIN ANUNCIOS desde la 1.0.5. `google_mobile_ads` se saco del pubspec: no
  /// bastaba con apagarlo por bandera, porque `MobileAdsInitProvider` es un
  /// ContentProvider que arranca ANTES que Dart, asi que el SDK viajaba dentro
  /// del AAB y recogia datos aunque `ADS_ENABLED` fuera false. La alternativa
  /// era implementar el consentimiento UMP para una via de ingreso que no
  /// estaba dando ninguno.
  ///
  /// Si algun dia vuelven: primero UMP, despues el SDK. En ese orden.
  static void validateForStartup({
    bool releaseMode = kReleaseMode,
    String apiKey = revenueCatApiKey,
  }) {
    if (!releaseMode) return;

    final missing = <String>[if (apiKey.trim().isEmpty) 'REVENUECAT_API_KEY'];
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuración release ausente: ${missing.join(', ')}. '
        'Inyecta valores con --dart-define.',
      );
    }
  }
}
