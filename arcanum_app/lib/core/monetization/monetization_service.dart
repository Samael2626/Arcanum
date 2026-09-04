import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Estado de suscripción del usuario.
enum SubscriptionTier { free, premium }

/// Como acabo un intento de compra.
///
/// Cancelar y fallar no son lo mismo y no pueden compartir respuesta: quien
/// cancela ya sabe lo que hizo y un aviso ahi es ruido, pero a quien le fallo
/// la tienda hay que decirselo o se queda mirando un boton que no hizo nada.
enum PurchaseOutcome { comprada, cancelada, fallida }

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

  /// Consumibles a la venta. La unidad es una Lectura del Umbral = 1 credito.
  static const credit1 = 'arcanum_credit_1';
  static const pack3 = 'arcanum_pack_3';

  /// Retirados de la tienda. El backend los sigue honrando para eventos
  /// tardios y reembolsos de compras viejas, pero no se ofrecen ya.
  @Deprecated('Retirado: 10 creditos por USD 1,99 devalua la unidad')
  static const credits10 = 'arcanum_credits_10';
  @Deprecated('Retirado: pack de 50 fuera del catalogo de beta')
  static const credits50 = 'arcanum_credits_50';
  @Deprecated('Retirado: sustituido por pack3')
  static const bundleCard = 'arcanum_bundle_explora_carta';

  static const enVenta = <String>[credit1, pack3];
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
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
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
      return parseSubscription(info);
    } catch (_) {
      return const SubscriptionState();
    }
  }

  /// Escuchar cambios en la suscripción.
  void startListening() {
    Purchases.addCustomerInfoUpdateListener((info) {
      _controller.add(parseSubscription(info));
    });
  }

  /// Detener escucha.
  void dispose() {
    _controller.close();
  }

  /// Ofrecimientos disponibles (precios, _trial).
  ///
  /// OJO: se traga la excepcion y devuelve `null`. Un fallo de red, una tienda
  /// caida y "la cuenta no tiene productos configurados" son indistinguibles
  /// desde fuera. Eso hace que [storePricesProvider] y [descuentoAnualProvider]
  /// NUNCA entren en estado de error: van de `loading` a `data` vacio.
  ///
  /// Quien consuma esos providers no puede apoyarse en `hasError` — no se
  /// dispara nunca. Lo que hay que mirar es `isLoading` y si el resultado viene
  /// vacio. Si algun dia hace falta distinguir el fallo de "no hay nada que
  /// vender", el cambio es aqui: propagar la excepcion en vez de devolver null,
  /// y entonces revisar los consumidores.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Precios de tienda por SKU, ya localizados por Play/App Store.
  ///
  /// Nunca se escribe un precio a mano en la UI: el que ve el usuario depende
  /// de su pais, su moneda y los impuestos que aplique la tienda, y un numero
  /// fijo en el codigo miente en cuanto sale de Estados Unidos. Ambas tiendas
  /// rechazan por eso.
  ///
  /// Devuelve un mapa vacio si las ofertas no cargan; quien lo consuma debe
  /// tratar la ausencia de precio como "no vendible todavia", no rellenarla.
  Future<Map<String, String>> storePrices() async {
    final offerings = await getOfferings();
    final paquetes = offerings?.current?.availablePackages ?? const <Package>[];
    return {
      for (final p in paquetes) p.storeProduct.identifier: p.storeProduct.priceString,
    };
  }

  /// Comprar una suscripción.
  ///
  /// Devuelve [PurchaseOutcome] y no un bool: antes, cancelar y que la tienda
  /// fallara daban el mismo `false`, asi que la pantalla no podia decir nada
  /// sin arriesgarse a regañar a quien solo cambio de idea. El resultado era
  /// que no decia nada nunca, ni cuando la compra fallaba de verdad.
  ///
  /// TODO(pagos): sin test del camino de compra fallida ni del cancelado.
  /// Para llegar hasta aqui desde el paywall hay que fabricar un `Offerings`
  /// completo de RevenueCat —`current`, `annual`, `storeProduct`—, porque
  /// `_purchaseAnnual` pide las ofertas antes de comprar. Lo unico cubierto hoy
  /// es la rama sin ofertas (`paywall_screen_test.dart`). Si esta distincion se
  /// rompe, no lo va a avisar ningun test: se ve comprando en un aparato.
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    try {
      // purchase() ya devuelve el CustomerInfo sincronizado: no hace falta pedirlo aparte
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active
              .containsKey(EntitlementIds.premium)
          ? PurchaseOutcome.comprada
          : PurchaseOutcome.fallida;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelada
          : PurchaseOutcome.fallida;
    } catch (_) {
      return PurchaseOutcome.fallida;
    }
  }

  /// Comprar un consumible (créditos, tiradas).
  ///
  /// TODO(pagos): mismo hueco que [purchasePackage]. Aqui ademas queda sin
  /// cubrir el `StateError` de producto no encontrado, que acaba en `fallida`.
  Future<PurchaseOutcome> purchaseProduct(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final all = offerings.current?.availablePackages ?? [];
      final pkg = all.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => throw StateError('Product not found: $productId'),
      );
      await Purchases.purchase(PurchaseParams.package(pkg));
      return PurchaseOutcome.comprada;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelada
          : PurchaseOutcome.fallida;
    } catch (_) {
      return PurchaseOutcome.fallida;
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

  /// Traduce lo que devuelve RevenueCat a estado de suscripcion.
  ///
  /// Publico a proposito: es donde vive la correccion de `restorePurchases` y
  /// de la sincronizacion, y es lo unico de esta clase que se puede probar sin
  /// la tienda delante.
  @visibleForTesting
  SubscriptionState parseSubscription(CustomerInfo info) {
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

final subscriptionProvider = StreamProvider<SubscriptionState>((ref) async* {
  final service = ref.watch(monetizationServiceProvider);
  yield await service.getCurrentSubscription();
  yield* service.subscriptionStream;
});

/// Helper rápido: ¿es premium?
final isPremiumProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub.value?.isPremium ?? false;
});

/// Precios localizados de la tienda, cacheados por Riverpod.
///
/// **Este provider no falla nunca.** [MonetizationService.getOfferings] se come
/// la excepcion, asi que el AsyncValue va de `loading` a `data` con un mapa
/// vacio y `hasError` no se cumple jamas. No escribas una rama de error aqui
/// esperando que se dispare: para saber si la tienda no respondio, mira
/// `isLoading` y si el mapa viene vacio.
final storePricesProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(monetizationServiceProvider).storePrices();
});

/// Ahorro real del plan anual frente a pagar doce meses sueltos.
///
/// Se calcula con los importes de la tienda, no con un porcentaje escrito a
/// mano: el numero fijo era cierto solo en dolares y solo hasta el siguiente
/// cambio de precio en la consola. Devuelve `null` si falta alguno de los dos
/// planes o si el anual no sale a cuenta, y en ese caso no se anuncia nada.
///
/// Hereda lo de [storePricesProvider]: tampoco entra nunca en estado de error,
/// porque bebe del mismo `getOfferings` que se traga la excepcion.
final descuentoAnualProvider = FutureProvider<String?>((ref) async {
  final offerings = await ref.watch(monetizationServiceProvider).getOfferings();
  final actual = offerings?.current;
  final mensual = actual?.monthly?.storeProduct.price;
  final anual = actual?.annual?.storeProduct.price;
  if (mensual == null || anual == null) return null;

  return formatAhorroAnual(mensual: mensual, anual: anual);
});

/// Etiqueta de ahorro del plan anual, o `null` si no hay nada que presumir.
///
/// Separada del provider para poder probarla: una promesa de descuento que se
/// pasa de optimista es publicidad enganosa en las dos tiendas.
@visibleForTesting
String? formatAhorroAnual({required double mensual, required double anual}) {
  if (mensual <= 0 || anual <= 0) return null;
  final ahorro = (1 - anual / (mensual * 12)) * 100;
  if (ahorro < 1) return null;
  return 'AHORRA ${ahorro.round()}%';
}
