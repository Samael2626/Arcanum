/// El identificador de producto de Google, con y sin plan base.
///
/// POR QUE EXISTE ESTE FICHERO. En Google, desde 2023, una suscripcion de
/// RevenueCat mapea a un **base plan** y su identificador llega como
/// `<subscription_id>:<base_plan_id>` -- en ARCANUM,
/// `arcanum_premium_anual:anual`. Los consumibles NO llevan sufijo.
///
/// La app buscaba por el id sin plan base, asi que las dos suscripciones se
/// quedaban fuera del mapa de precios. Y no era solo cosmetico: con el precio
/// ausente, el anual avisaba de "no hay ofertas" y el boton del mensual **ni se
/// pintaba**. Cero suscripciones vendibles.
///
/// Fuente del formato: doc de RevenueCat, "Android products" --
/// «Newly set up products in RevenueCat follow the identifier format
/// `<subscription_id>:<base-plan-id>`».
library;

import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('idBaseDeProducto', () {
    test('recorta el plan base de una suscripcion', () {
      // Los planes base de ARCANUM en Play se llaman en espanol.
      expect(
        idBaseDeProducto('arcanum_premium_monthly:mensual'),
        'arcanum_premium_monthly',
      );
      expect(
        idBaseDeProducto('arcanum_premium_annual:anual'),
        'arcanum_premium_annual',
      );
    });

    test('deja intacto un producto de una sola compra', () {
      // Los consumibles no llevan plan base: su identificador es el SKU pelado,
      // y tocarlo seria romper lo unico que ya funcionaba.
      expect(idBaseDeProducto('arcanum_credit_1'), 'arcanum_credit_1');
      expect(idBaseDeProducto('arcanum_pack_3'), 'arcanum_pack_3');
    });

    test('aguanta los casos raros sin reventar', () {
      expect(idBaseDeProducto(''), '');
      // Mas de un separador: manda el primero, igual que hace el backend.
      expect(idBaseDeProducto('a:b:c'), 'a');
    });

    test('coincide con lo que hace el backend', () {
      // `revenuecat.py:52` normaliza con `split(":", 1)[0]`. Si las dos reglas
      // se separan, el cliente y el servidor dejan de hablar del mismo producto.
      for (final id in [
        'arcanum_premium_monthly:mensual',
        'arcanum_premium_annual:anual',
        'arcanum_credit_1',
        '',
      ]) {
        expect(idBaseDeProducto(id), id.split(':').first);
      }
    });
  });

  group('expandirPreciosPorIdBase', () {
    test('una suscripcion se encuentra por su id SIN plan base', () {
      // Es el caso que estaba roto: `ProductIds.premiumAnnual` no lleva sufijo.
      final precios = expandirPreciosPorIdBase({
        'arcanum_premium_annual:anual': r'$ 39.900',
      });

      expect(precios[ProductIds.premiumAnnual], r'$ 39.900');
    });

    test('y tambien por el identificador completo de la tienda', () {
      // Se conservan las dos claves: la completa es la verdad de la tienda.
      final precios = expandirPreciosPorIdBase({
        'arcanum_premium_monthly:mensual': r'$ 4.900',
      });

      expect(precios['arcanum_premium_monthly:mensual'], r'$ 4.900');
      expect(precios[ProductIds.premiumMonthly], r'$ 4.900');
    });

    test('los consumibles siguen igual que antes', () {
      final precios = expandirPreciosPorIdBase({
        'arcanum_credit_1': r'$ 2.900',
        'arcanum_pack_3': r'$ 6.900',
      });

      expect(precios[ProductIds.credit1], r'$ 2.900');
      expect(precios[ProductIds.pack3], r'$ 6.900');
      expect(precios.length, 2, reason: 'sin sufijo no hay clave que duplicar');
    });

    test('los cuatro productos a la vez, como llegan de Play', () {
      final precios = expandirPreciosPorIdBase({
        'arcanum_premium_monthly:mensual': r'$ 4.900',
        'arcanum_premium_annual:anual': r'$ 39.900',
        'arcanum_credit_1': r'$ 2.900',
        'arcanum_pack_3': r'$ 6.900',
      });

      // Lo que el paywall consulta, uno por uno.
      expect(precios[ProductIds.premiumMonthly], isNotNull);
      expect(precios[ProductIds.premiumAnnual], isNotNull);
      expect(precios[ProductIds.credit1], isNotNull);
      expect(precios[ProductIds.pack3], isNotNull);
      expect(ProductIds.enVenta.every(precios.containsKey), isTrue);
    });

    test('un mapa vacio sigue vacio, sin inventar claves', () {
      expect(expandirPreciosPorIdBase(const {}), isEmpty);
    });
  });
}
