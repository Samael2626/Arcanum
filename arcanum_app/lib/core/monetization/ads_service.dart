import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Las unidades de anuncio de AdMob.
///
/// Estaban cableadas a las de PRUEBA de Google, sin aviso de ninguna clase. El
/// App ID sí tenía guarda —el build de release se para si falta— pero la unidad
/// no, así que un release firmado y subido habría pedido anuncios a la unidad
/// de test: cero ingresos, y tráfico que a Google no le gusta ver en una cuenta
/// de producción. Un fallo silencioso al lado de uno ruidoso.
///
/// Ahora la unidad real entra por `--dart-define` y las de prueba solo sirven
/// en debug. En release sin definirla, [esDePrueba] lo dice y `AdsService` se
/// niega a cargar en vez de fingir que funciona.
class AdUnitIds {
  /// El prefijo de todas las unidades de demostración de Google.
  static const _prefijoDePrueba = 'ca-app-pub-3940256099942544';

  static const _pruebaRewardedAndroid = '$_prefijoDePrueba/5224354917';
  static const _pruebaRewardedIos = '$_prefijoDePrueba/1712485313';

  /// La unidad real, si se pasó al compilar:
  ///
  ///     flutter build appbundle --release \
  ///       --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY
  static const _rewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  static String get rewarded {
    final esIos = defaultTargetPlatform == TargetPlatform.iOS;
    final real = esIos ? _rewardedIos : _rewardedAndroid;
    if (real.isNotEmpty) return real;
    return esIos ? _pruebaRewardedIos : _pruebaRewardedAndroid;
  }

  /// Si la unidad que se va a usar es una de demostración.
  ///
  /// En debug es lo correcto y no pasa nada. En release significa que alguien
  /// compiló sin pasar la unidad real, y eso hay que decirlo.
  static bool get esDePrueba => rewarded.startsWith(_prefijoDePrueba);
}

class AdsService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  final _controller = StreamController<AdEvent>.broadcast();

  Stream<AdEvent> get events => _controller.stream;

  /// Si hay un anuncio cargado y listo para mostrarse AHORA.
  ///
  /// Se consulta antes de ofrecerlo: un botón que dice «ve un anuncio» y no
  /// tiene anuncio que enseñar es peor que no ofrecer nada, porque la persona
  /// ya contaba con lo que iba a ganar.
  bool get listo => _rewardedAd != null;

  /// Precargar un rewarded ad.
  void preloadRewarded() {
    if (_isLoading || _rewardedAd != null) return;
    // Ruidoso y sin cargar nada: pedir anuncios a una unidad de demostración
    // desde una app publicada no da ingresos y ensucia la cuenta de AdMob.
    // Mejor que la vía de créditos por anuncio no exista a que exista falsa.
    if (kReleaseMode && AdUnitIds.esDePrueba) {
      debugPrint(
        'AdMob: unidad de PRUEBA en un build de release. Compila con '
        '--dart-define=ADMOB_REWARDED_ANDROID=<tu unidad real>.',
      );
      _controller.add(const AdEvent.failedToLoad());
      return;
    }
    _isLoading = true;

    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _controller.add(const AdEvent.loaded());
          _attachCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _rewardedAd = null;
          _controller.add(const AdEvent.failedToLoad());
        },
      ),
    );
  }

  /// Mostrar un rewarded ad. Retorna true si el usuario completó la vista.
  Future<bool> showRewarded() async {
    final ad = _rewardedAd;
    if (ad == null) {
      preloadRewarded();
      return false;
    }

    final completer = Completer<bool>();

    // Los callbacks van ANTES de `show`: asignarlos después es una carrera con
    // un anuncio que se cierre rápido, y perder el aviso de cierre deja el
    // completer colgado para siempre.
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        _controller.add(AdEvent.earnedReward(
          reward.type,
          reward.amount.toDouble(),
        ));
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  void _attachCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewarded();
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _controller.close();
  }
}

/// Eventos del ads service.
sealed class AdEvent {
  const AdEvent();
  const factory AdEvent.loaded() = AdLoaded;
  const factory AdEvent.failedToLoad() = AdFailedToLoad;
  const factory AdEvent.earnedReward(String type, double amount) =
      AdEarnedReward;
}

class AdLoaded extends AdEvent {
  const AdLoaded();
}

class AdFailedToLoad extends AdEvent {
  const AdFailedToLoad();
}

class AdEarnedReward extends AdEvent {
  final String type;
  final double amount;
  const AdEarnedReward(this.type, this.amount);
}

final adsServiceProvider = Provider<AdsService>((ref) {
  final service = AdsService();
  service.preloadRewarded();
  ref.onDispose(() => service.dispose());
  return service;
});
