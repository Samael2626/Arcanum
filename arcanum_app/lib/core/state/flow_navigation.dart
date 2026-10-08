import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'flow_providers.dart';

// Saltos entre secciones que comparten varias pantallas (Horoscopo, Saber).
// Un solo sitio para que el mismo enlace no navegue distinto segun desde donde
// se toque.

/// Cara de Cielo: la del instante.
const cieloCaraAhora = 0;

/// Cara de Cielo: la carta natal.
const cieloCaraCarta = 1;

/// Abre Cielo en la cara pedida. La cara se fija ANTES de navegar: si ya se
/// esta en '/hoy', navegar no hace nada y lo unico que cambia es la cara.
void goCielo(WidgetRef ref, BuildContext context, {required int cara}) {
  ref.read(cieloCaraProvider.notifier).set(cara);
  context.go('/hoy');
}

/// Abre Saber (Plantas) filtrado por el planeta.
void goMateriaOf(WidgetRef ref, BuildContext context, String planet) {
  ref.read(materiaPlanetProvider.notifier).set(planet);
  context.go('/saber');
}

/// Abre el editor del grimorio, con el titulo precargado si se da.
void goGrimoireCompose(WidgetRef ref, BuildContext context, {String? title}) {
  ref.read(grimoireComposeTitleProvider.notifier).set(title);
  ref.read(grimoireComposeProvider.notifier).set(true);
  context.go('/grimorio');
}
