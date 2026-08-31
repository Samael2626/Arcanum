import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// CustomerInfo minimo con el entitlement que se le pida activo.
CustomerInfo _customerInfo({Map<String, dynamic> entitlements = const {}}) {
  return CustomerInfo.fromJson({
    'entitlements': {'all': entitlements, 'active': entitlements},
    'allPurchaseDates': <String, String?>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'usuario',
    'allExpirationDates': <String, String?>{},
    'requestDate': '2026-08-30T00:00:00Z',
    'latestExpirationDate': null,
    'originalPurchaseDate': null,
    'originalApplicationVersion': null,
    'managementURL': null,
  });
}

Map<String, dynamic> _entitlement({
  required String productId,
  String periodType = 'NORMAL',
  String? expirationDate,
}) {
  return {
    'identifier': EntitlementIds.premium,
    'isActive': true,
    'willRenew': true,
    'periodType': periodType,
    'latestPurchaseDate': '2026-08-01T00:00:00Z',
    'originalPurchaseDate': '2026-08-01T00:00:00Z',
    'productIdentifier': productId,
    'isSandbox': false,
    'expirationDate': expirationDate,
    'store': 'PLAY_STORE',
    'unsubscribeDetectedAt': null,
    'billingIssueDetectedAt': null,
    'ownershipType': 'PURCHASED',
    'verification': 'NOT_REQUESTED',
  };
}

void main() {
  group('parseSubscription — es donde vive la correccion de restore', () {
    final service = MonetizationService();

    test('sin entitlement activo no hay premium', () {
      final estado = service.parseSubscription(_customerInfo());

      expect(estado.isActive, isFalse);
      expect(estado.tier, SubscriptionTier.free);
      expect(estado.productId, isNull);
    });

    test('un entitlement de otro nombre no concede premium', () {
      final estado = service.parseSubscription(
        _customerInfo(
          entitlements: {
            'otra_cosa': _entitlement(productId: 'arcanum_premium_annual'),
          },
        ),
      );

      expect(estado.isActive, isFalse);
    });

    test('restaurar una suscripcion activa devuelve premium con su producto', () {
      final estado = service.parseSubscription(
        _customerInfo(
          entitlements: {
            EntitlementIds.premium: _entitlement(
              productId: ProductIds.premiumAnnual,
              expirationDate: '2027-08-01T00:00:00Z',
            ),
          },
        ),
      );

      expect(estado.isActive, isTrue);
      expect(estado.tier, SubscriptionTier.premium);
      expect(estado.productId, ProductIds.premiumAnnual);
      expect(estado.expirationDate, DateTime.parse('2027-08-01T00:00:00Z'));
      expect(estado.isTrial, isFalse);
    });

    test('la prueba gratuita se distingue de una compra pagada', () {
      final estado = service.parseSubscription(
        _customerInfo(
          entitlements: {
            EntitlementIds.premium: _entitlement(
              productId: ProductIds.premiumAnnual,
              periodType: 'TRIAL',
            ),
          },
        ),
      );

      expect(estado.isTrial, isTrue);
      expect(estado.isActive, isTrue);
    });

    test('una fecha de expiracion ilegible no tumba el parseo', () {
      final estado = service.parseSubscription(
        _customerInfo(
          entitlements: {
            EntitlementIds.premium: _entitlement(
              productId: ProductIds.premiumMonthly,
              expirationDate: 'no-es-una-fecha',
            ),
          },
        ),
      );

      expect(estado.isActive, isTrue);
      expect(estado.expirationDate, isNull);
    });
  });

  group('formatAhorroAnual — la promesa tiene que ser cierta', () {
    test('calcula el ahorro real frente a doce meses sueltos', () {
      expect(formatAhorroAnual(mensual: 7.99, anual: 59.99), 'AHORRA 37%');
    });

    test('no anuncia nada si el anual no sale a cuenta', () {
      expect(formatAhorroAnual(mensual: 4.99, anual: 59.99), isNull);
    });

    test('no anuncia un ahorro despreciable', () {
      expect(formatAhorroAnual(mensual: 5.0, anual: 59.9), isNull);
    });

    test('precios sin sentido no producen etiqueta', () {
      expect(formatAhorroAnual(mensual: 0, anual: 59.99), isNull);
      expect(formatAhorroAnual(mensual: 7.99, anual: 0), isNull);
    });
  });

  group('catalogo de SKUs', () {
    test('a la venta solo van la unidad y el pack de tres', () {
      expect(ProductIds.enVenta, [ProductIds.credit1, ProductIds.pack3]);
    });
  });
}
