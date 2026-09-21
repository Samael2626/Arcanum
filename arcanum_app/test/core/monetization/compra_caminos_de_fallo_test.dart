import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Cancelar y fallar NO son lo mismo, y aqui se comprueba que siguen sin serlo.
///
/// Quien cancela ya sabe lo que hizo: avisarle es ruido. A quien le fallo la
/// tienda hay que decirselo, o se queda mirando un boton que no hizo nada. La
/// version anterior devolvia `false` en los dos casos, asi que la pantalla no
/// podia decir nada sin arriesgarse a reganar a quien solo cambio de idea — y
/// acabo no diciendo nada nunca, tampoco cuando la compra fallaba de verdad.
///
/// El `TODO(pagos)` decia que para llegar hasta aqui habia que fabricar un
/// `Offerings` entero de RevenueCat. Se puede evitar: `purchases_flutter` habla
/// por un unico MethodChannel, asi que se le contesta a ese y el codigo de la
/// app corre entero y de verdad, sin tocar la tienda ni gastar nada.
const _canal = MethodChannel('purchases_flutter');

/// El codigo de error viaja como el INDICE del enum, en texto. No se escribe a
/// mano: si RevenueCat reordena el enum, esto se sigue refiriendo al mismo caso.
String _codigo(PurchasesErrorCode code) => code.index.toString();

Map<String, dynamic> _producto(String id) => {
  'identifier': id,
  'description': 'descripcion',
  'title': 'titulo',
  'price': 7.99,
  'priceString': 'US\$7.99',
  'currencyCode': 'USD',
  'productCategory': 'SUBSCRIPTION',
};

Map<String, dynamic> _paquete(String id) => {
  'identifier': id,
  'packageType': 'MONTHLY',
  'product': _producto(id),
  'presentedOfferingContext': {
    'offeringIdentifier': 'default',
    'placementIdentifier': null,
    'targetingContext': null,
  },
};

Map<String, dynamic> _ofertas(List<String> ids) {
  final oferta = {
    'identifier': 'default',
    'serverDescription': 'la oferta',
    'metadata': <String, Object>{},
    'availablePackages': [for (final id in ids) _paquete(id)],
  };
  return {
    'all': {'default': oferta},
    'current': oferta,
  };
}

Map<String, dynamic> _clienteCon({required bool premium}) {
  final entitlements = premium
      ? {
          EntitlementIds.premium: {
            'identifier': EntitlementIds.premium,
            'isActive': true,
            'willRenew': true,
            'periodType': 'NORMAL',
            'latestPurchaseDate': '2026-09-01T00:00:00Z',
            'originalPurchaseDate': '2026-09-01T00:00:00Z',
            'productIdentifier': ProductIds.premiumMonthly,
            'isSandbox': false,
            'expirationDate': '2027-09-01T00:00:00Z',
            'store': 'PLAY_STORE',
            'unsubscribeDetectedAt': null,
            'billingIssueDetectedAt': null,
            'ownershipType': 'PURCHASED',
            'verification': 'NOT_REQUESTED',
          },
        }
      : <String, dynamic>{};
  return {
    'entitlements': {'all': entitlements, 'active': entitlements},
    'allPurchaseDates': <String, String?>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'usuario',
    'allExpirationDates': <String, String?>{},
    'requestDate': '2026-09-21T00:00:00Z',
    'latestExpirationDate': null,
    'originalPurchaseDate': null,
    'originalApplicationVersion': null,
    'managementURL': null,
  };
}

Map<String, dynamic> _compra({required bool premium}) => {
  'customerInfo': _clienteCon(premium: premium),
  'transaction': {
    'transactionIdentifier': 'tx-1',
    'productIdentifier': ProductIds.premiumMonthly,
    'purchaseDate': '2026-09-21T00:00:00Z',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = MonetizationService();
  late List<String> llamadas;

  /// Contesta al canal: `respuestas` mapea metodo -> valor, o excepcion a lanzar.
  void cablear(Map<String, Object?> respuestas) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
          llamadas.add(call.method);
          final r = respuestas[call.method];
          if (r is Exception) throw r;
          return r;
        });
  }

  setUp(() => llamadas = []);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  });

  Package paquete(String id) => Package.fromJson(_paquete(id));

  group('purchasePackage — la suscripcion', () {
    test('cancelar no es fallar', () async {
      cablear({
        'purchasePackage': PlatformException(
          code: _codigo(PurchasesErrorCode.purchaseCancelledError),
          message: 'user cancelled',
        ),
      });

      final salida = await service.purchasePackage(
        paquete(ProductIds.premiumMonthly),
      );

      expect(salida, PurchaseOutcome.cancelada);
    });

    test('una tienda que revienta si es fallar', () async {
      cablear({
        'purchasePackage': PlatformException(
          code: _codigo(PurchasesErrorCode.storeProblemError),
          message: 'store is down',
        ),
      });

      final salida = await service.purchasePackage(
        paquete(ProductIds.premiumMonthly),
      );

      expect(salida, PurchaseOutcome.fallida);
    });

    test('una compra que concede el entitlement es una compra', () async {
      cablear({'purchasePackage': _compra(premium: true)});

      final salida = await service.purchasePackage(
        paquete(ProductIds.premiumMonthly),
      );

      expect(salida, PurchaseOutcome.comprada);
    });

    test('cobrar sin conceder el entitlement NO es una compra', () async {
      // El caso peor: la tienda dice que si y RevenueCat no reconoce premium.
      // Devolver `comprada` aqui abriria la app a quien no la tiene pagada.
      cablear({'purchasePackage': _compra(premium: false)});

      final salida = await service.purchasePackage(
        paquete(ProductIds.premiumMonthly),
      );

      expect(salida, PurchaseOutcome.fallida);
    });
  });

  group('purchaseProduct — los consumibles', () {
    test('cancelar no es fallar', () async {
      cablear({
        'getOfferings': _ofertas([ProductIds.credit1]),
        'purchasePackage': PlatformException(
          code: _codigo(PurchasesErrorCode.purchaseCancelledError),
          message: 'user cancelled',
        ),
      });

      expect(
        await service.purchaseProduct(ProductIds.credit1),
        PurchaseOutcome.cancelada,
      );
    });

    test('una tienda caida es fallar', () async {
      cablear({
        'getOfferings': _ofertas([ProductIds.credit1]),
        'purchasePackage': PlatformException(
          code: _codigo(PurchasesErrorCode.storeProblemError),
          message: 'store is down',
        ),
      });

      expect(
        await service.purchaseProduct(ProductIds.credit1),
        PurchaseOutcome.fallida,
      );
    });

    test('un consumible que existe se compra', () async {
      cablear({
        'getOfferings': _ofertas([ProductIds.credit1, ProductIds.pack3]),
        'purchasePackage': _compra(premium: false),
      });

      expect(
        await service.purchaseProduct(ProductIds.pack3),
        PurchaseOutcome.comprada,
      );
    });

    test(
      'un SKU que no esta en la oferta falla, y NO intenta comprar',
      () async {
        // El StateError de "producto no encontrado" que el TODO daba por
        // descubierto. Lo que no puede pasar es que acabe en la tienda: seria
        // cobrar por algo que no se sabe que es.
        cablear({
          'getOfferings': _ofertas([ProductIds.credit1]),
          'purchasePackage': _compra(premium: false),
        });

        final salida = await service.purchaseProduct('arcanum_credits_50');

        expect(salida, PurchaseOutcome.fallida);
        expect(
          llamadas,
          ['getOfferings'],
          reason:
              'no puede llamarse a purchasePackage con un SKU que no existe',
        );
      },
    );

    test('sin ofertas no hay compra', () async {
      cablear({
        'getOfferings': {'all': <String, dynamic>{}, 'current': null},
      });

      expect(
        await service.purchaseProduct(ProductIds.credit1),
        PurchaseOutcome.fallida,
      );
    });
  });
}
