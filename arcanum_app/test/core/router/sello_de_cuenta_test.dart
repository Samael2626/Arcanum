import 'dart:io';

import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// El sello de la esquina superior izquierda.
///
/// Lo que se fija aqui es que sea UN cajon con DOS tiradores, y no dos cajones
/// que se parecen. Y que el glifo siga siendo uno de los que la fuente propia
/// empaqueta: si alguien lo cambia por otro sin regenerar `ArcanumGlifos`, el
/// simbolo se lo inventa el telefono de quien instale.
void main() {
  /// Los glifos que `ArcanumGlifos` trae, leidos del manifiesto que genera
  /// `tool/generar_fuente_glifos.py`.
  Set<String> glifosEmpaquetados() {
    final manifiesto = File(
      'assets/fonts/glifos_manifest.txt',
    ).readAsLinesSync();
    return {
      for (final linea in manifiesto)
        if (linea.startsWith('U+'))
          String.fromCharCode(
            int.parse(linea.split(' ').first.substring(2), radix: 16),
          ),
    };
  }

  testWidgets('el sello y el avatar abren el MISMO cajon', (t) async {
    // Con GoRouter de verdad: `_Fila` lee la ruta actual para saber cual esta
    // abierta, y sin router encima lanza -- que es lo correcto, porque un
    // cajon fuera de una ruta es un error de programacion, no un caso a
    // tolerar en silencio.
    final router = GoRouter(
      initialLocation: '/hoy',
      routes: [
        GoRoute(
          path: '/hoy',
          builder: (c, s) => Scaffold(
            endDrawer: const ArcanumDrawer(),
            body: Builder(
              builder: (c) => Row(
                children: [
                  TextButton(
                    onPressed: Scaffold.of(c).openEndDrawer,
                    child: const Text('sello'),
                  ),
                  TextButton(
                    onPressed: Scaffold.of(c).openEndDrawer,
                    child: const Text('avatar'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(path: '/perfil', builder: (c, s) => const Scaffold()),
        GoRoute(path: '/settings', builder: (c, s) => const Scaffold()),
        GoRoute(path: '/privacy', builder: (c, s) => const Scaffold()),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    for (final tirador in ['sello', 'avatar']) {
      await t.tap(find.text(tirador));
      await t.pumpAndSettle();
      expect(
        find.byType(ArcanumDrawer),
        findsOneWidget,
        reason: 'Dos tiradores, un solo cajon: nunca dos a la vez.',
      );
      expect(find.text('Privacidad y datos'), findsOneWidget);
      await t.tapAt(const Offset(10, 400));
      await t.pumpAndSettle();
      expect(find.text('Privacidad y datos'), findsNothing);
    }
  });

  test('el glifo del sello viaja dentro de la fuente propia', () {
    const sello = '⛤';
    expect(
      glifosEmpaquetados(),
      contains(sello),
      reason:
          'U+26E4 tiene que estar en glifos_manifest.txt. Si se cambia el '
          'sello por otro simbolo, hay que correr tool/generar_fuente_glifos.py '
          'o el telefono lo pintara con la fuente que le parezca.',
    );
  });

  test('el sello se pinta con el respaldo de glifos declarado', () {
    // Mismo motivo que el resto de glifos de la app: sin fallback explicito,
    // en varios Android sale un emoji de colores.
    expect(kGlyphFallback, ['ArcanumGlifos']);
  });
}
