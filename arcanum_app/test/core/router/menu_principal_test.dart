import 'dart:io';

import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Los dos tiradores de la esquina superior: la hamburguesa y el avatar.
///
/// Lo que se fija aqui es que sean UN cajon con DOS tiradores, y no dos cajones
/// que se parecen. Fue un sello -- el pentaculo U+26E4 -- hasta el 21-sep-2026;
/// con las cinco secciones dentro pasa a ser el icono de tres lineas, porque
/// esto ya no es un adorno sino el unico camino a las secciones.
///
/// El glifo no se fue de la app: sigue en el Oraculo, y por eso la comprobacion
/// de la fuente se queda -- solo cambia de quien habla.
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

  testWidgets('la hamburguesa y el avatar abren el MISMO cajon', (t) async {
    // Con un shell de verdad: el cajon lo pide para saber en que rama estas, y
    // sin el lanza -- que es lo correcto, porque un cajon fuera del shell es
    // un error de programacion, no un caso a tolerar en silencio.
    final router = GoRouter(
      initialLocation: '/hoy',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => Scaffold(
            drawer: ArcanumDrawer(navigationShell: shell),
            body: Builder(
              builder: (c) => Row(
                children: [
                  TextButton(
                    onPressed: Scaffold.of(c).openDrawer,
                    child: const Text('hamburguesa'),
                  ),
                  TextButton(
                    onPressed: Scaffold.of(c).openDrawer,
                    child: const Text('avatar'),
                  ),
                ],
              ),
            ),
          ),
          branches: [
            for (final seccion in arcanumSections)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: seccion.route,
                    builder: (c, s) => const SizedBox(),
                  ),
                ],
              ),
          ],
        ),
        for (final r in ['/perfil', '/settings', '/privacy'])
          GoRoute(path: r, builder: (c, s) => const Scaffold()),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    for (final tirador in ['hamburguesa', 'avatar']) {
      await t.tap(find.text(tirador));
      await t.pumpAndSettle();
      expect(
        find.byType(ArcanumDrawer),
        findsOneWidget,
        reason: 'Dos tiradores, un solo cajon: nunca dos a la vez.',
      );
      expect(find.text('Privacidad y datos'), findsOneWidget);
      // Fuera del cajon, que ahora cuelga del borde izquierdo.
      await t.tapAt(const Offset(760, 400));
      await t.pumpAndSettle();
      expect(find.text('Privacidad y datos'), findsNothing);
    }
  });

  test('el glifo del Oraculo viaja dentro de la fuente propia', () {
    const glifo = '⛤';
    expect(
      glifosEmpaquetados(),
      contains(glifo),
      reason:
          'U+26E4 tiene que estar en glifos_manifest.txt. Si se cambia por '
          'otro simbolo, hay que correr tool/generar_fuente_glifos.py '
          'o el telefono lo pintara con la fuente que le parezca.',
    );
  });

  test('los glifos se pintan con el respaldo declarado', () {
    // Sin fallback explicito, en varios Android sale un emoji de colores.
    expect(kGlyphFallback, ['ArcanumGlifos']);
  });
}
