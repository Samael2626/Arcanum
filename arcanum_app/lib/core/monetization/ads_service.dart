import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/release_config.dart';

class AdUnitIds {
  static const _rewardedAndroidTest = 'ca-app-pub-3940256099942544/5224354917';
  static const _interstitialAndroidTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const _rewardedIosTest = 'ca-app-pub-3940256099942544/1712485313';
  static const _interstitialIosTest = 'ca-app-pub-3940256099942544/4411468910';

  static String get rewarded {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _rewardedIosTest;
    }
    return kReleaseMode
        ? ReleaseConfig.admobRewardedAndroid
        : _rewardedAndroidTest;
  }

  static String get interstitial {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _interstitialIosTest;
    }
    return kReleaseMode
        ? ReleaseConfig.admobInterstitialAndroid
        : _interstitialAndroidTest;
  }
}

class AdsService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  final _controller = StreamController<AdEvent>.broadcast();

  Stream<AdEvent> get events => _controller.stream;

  /// Precargar un rewarded ad.
  void preloadRewarded() {
    if (_isLoading || _rewardedAd != null) return;
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

    ad.show(
      onUserEarnedReward: (ad, reward) {
        _controller.add(
          AdEvent.earnedReward(reward.type, reward.amount.toDouble()),
        );
        if (!completer.isCompleted) completer.complete(true);
      },
    );

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
