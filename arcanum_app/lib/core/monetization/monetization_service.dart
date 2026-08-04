import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Estado de suscripción del usuario.
enum SubscriptionTier { free, premium }

/// Datos de la suscripción actual.
class SubscriptionState {
  final SubscriptionTier tier;
  final bool isActive;
  final String? productId;
  final DateTime? expirationDate;
  final bool isTrial;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.isActive = false,
    this.productId,
    this.expirationDate,
    this.isTrial = false,
  });

  bool get isPremium => tier == SubscriptionTier.premium && isActive;
}

/// IDs de los productos en RevenueCat / Play Console.
class ProductIds {
  static const premiumMonthly = 'arcanum_premium_monthly';
  static const premiumAnnual = 'arcanum_premium_annual';
  static const credits10 = 'arcanum_credits_10';
  static const credits50 = 'arcanum_credits_50';
  static const tarot5 = 'arcanum_tarot_5';
  static const bundleCard = 'arcanum_bundle_explora_carta';
}

/// IDs de entitlements en RevenueCat.
class EntitlementIds {
  static const premium = 'premium';
}

class MonetizationService {
  final _controller = StreamController<SubscriptionState>.broadcast();

  Stream<SubscriptionState> get subscriptionStream => _controller.stream;

  /// Inicializar RevenueCat con la API key de RevenueCat.
  /// Llamar en main() antes de runApp().
  static Future<void> initialize(String apiKey) async {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(apiKey),
    );
  }

  /// Identificar al usuario en RevenueCat después del login.
  Future<void> identify(String userId) async {
    await Purchases.logIn(userId);
    await _syncSubscription();
  }

  /// Logout de RevenueCat.
  Future<void> logout() async {
    await Purchases.logOut();
    _controller.add(const SubscriptionState());
  }

  /// Obtener la info de suscripción actual.
  Future<SubscriptionState> getCurrentSubscription() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return _parseSubscription(info);
    } catch (_) {
      return const SubscriptionState();
    }
  }

  /// Escuchar cambios en la suscripción.
  void startListening() {
    Purchases.addCustomerInfoUpdateListener((info) {
      _controller.add(_parseSubscription(info));
    });
  }

  /// Detener escucha.
  void dispose() {
    _controller.close();
  }

  /// Ofrecimientos disponibles (precios, _trial).
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Comprar una suscripción.
  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(EntitlementIds.premium);
    } catch (_) {
      return false;
    }
  }

  /// Comprar un consumible (créditos, tiradas).
  Future<bool> purchaseProduct(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final all = offerings.current?.availablePackages ?? [];
      final pkg = all.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => all.first,
      );
      await Purchases.purchasePackage(pkg);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restaurar compras.
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(EntitlementIds.premium);
    } catch (_) {
      return false;
    }
  }

  // --- Private ---

  SubscriptionState _parseSubscription(CustomerInfo info) {
    final active = info.entitlements.active;
    final isPremium = active.containsKey(EntitlementIds.premium);

    if (!isPremium) {
      return const SubscriptionState();
    }

    final entitlement = active[EntitlementIds.premium]!;
    final productId = entitlement.productIdentifier;
    final expirationDateStr = entitlement.expirationDate;
    final isTrial = entitlement.periodType == PeriodType.trial;

    DateTime? expirationDate;
    if (expirationDateStr != null) {
      expirationDate = DateTime.tryParse(expirationDateStr);
    }

    return SubscriptionState(
      tier: SubscriptionTier.premium,
      isActive: true,
      productId: productId,
      expirationDate: expirationDate,
      isTrial: isTrial,
    );
  }

  Future<void> _syncSubscription() async {
    final sub = await getCurrentSubscription();
    _controller.add(sub);
  }
}

final monetizationServiceProvider = Provider<MonetizationService>((ref) {
  final service = MonetizationService();
  service.startListening();
  ref.onDispose(() => service.dispose());
  return service;
});

final subscriptionProvider =
    StreamProvider<SubscriptionState>((ref) async* {
  final service = ref.watch(monetizationServiceProvider);
  yield await service.getCurrentSubscription();
  yield* service.subscriptionStream;
});

/// Helper rápido: ¿es premium?
final isPremiumProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub.value?.isPremium ?? false;
});
