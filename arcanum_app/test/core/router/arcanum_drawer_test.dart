import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoyo/saldo_falso.dart';

/// El cajon: TODA la navegacion desde el 21-sep-2026.
///
/// Lo que se fija aqui es lo que justifico cada pieza: que Privacidad no vuelva
/// a estar a tres toques, que las secciones salgan de `arcanumSections` y no de
/// una lista escrita a mano, y que la regla de seleccion de la casa se aplique
/// igual a las dos mitades del cajon.
///
/// Se monta un `StatefulShellRoute` de verdad y no un `Scaffold` suelto: el
/// cajon pide el shell para saber en que rama estas, y fabricarlo a mano seria
/// probar otra cosa.
void main() {
  Future<GoRouter> abrir(WidgetTester t, {String en = '/hoy'}) async {
    final router = GoRouter(
      initialLocation: en,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => Scaffold(
            drawer: ArcanumDrawer(navigationShell: shell),
            appBar: AppBar(
              leading: Builder(
                builder: (c) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: Scaffold.of(c).openDrawer,
                ),
              ),
            ),
            body: shell,
          ),
          branches: [
            for (final seccion in arcanumSections)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: seccion.route,
                    builder: (c, s) => Text('pantalla ${seccion.route}'),
                  ),
                ],
              ),
          ],
        ),
        for (final r in ['/perfil', '/settings', '/privacy'])
          GoRoute(
            path: r,
            builder: (c, s) => Scaffold(body: Text('pantalla $r')),
          ),
      ],
    );
    // ProviderScope: desde la 1.0.6 el cajon lleva el bloque de saldo, que es
    // un ConsumerWidget. Sin scope no monta, y con uno vacio pediria por red.
    await t.pumpWidget(
      ProviderScope(
        overrides: [saldoProvider.overrideWith(() => SaldoFalso(creditos: 3))],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    return router;
  }

  Future<void> abrirCajon(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.menu));
    await t.pumpAndSettle();
  }

  testWidgets(
    'las secciones salen de arcanumSections, no de una lista aparte',
    (t) async {
      await abrir(t);
      await abrirCajon(t);

      for (final seccion in arcanumSections) {
        expect(
          find.text(seccion.title),
          findsWidgets,
          reason: '${seccion.title} no esta en el cajon',
        );
      }
    },
  );

  testWidgets('las tres de la cuenta viven al mismo nivel', (t) async {
    await abrir(t);
    await abrirCajon(t);

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Privacidad y datos'), findsOneWidget);
  });

  testWidgets('Privacidad llega en DOS toques desde el arranque', (t) async {
    await abrir(t);
    // 1 · abrir el cajon
    await abrirCajon(t);
    // 2 · tocarla
    //
    // HAY QUE DESPLAZAR PARA LLEGAR, desde que el bloque de saldo ocupa la
    // cabecera del cajon (1.0.6). No son tres toques: el cajon ya scrolleaba
    // antes en pantallas cortas, y desplazar no cuenta como toque. Pero queda
    // escrito que Privacidad es la fila que se cae del pliegue la proxima vez
    // que alguien anada algo aqui arriba.
    await t.ensureVisible(find.text('Privacidad y datos'));
    await t.pumpAndSettle();
    await t.tap(find.text('Privacidad y datos'));
    await t.pumpAndSettle();

    expect(
      find.text('pantalla /privacy'),
      findsOneWidget,
      reason:
          'Estaba a tres toques metida dentro de Ajustes. Si vuelve a '
          'estarlo, el cajon deja de tener sentido.',
    );
  });

  testWidgets('una seccion cuesta dos toques, y cambia de rama', (t) async {
    await abrir(t);
    await abrirCajon(t);
    await t.tap(find.text('Horóscopo'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /horoscopo'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing, reason: 'el cajon se cerro');
  });

  testWidgets('la fila de la pantalla abierta lleva los tres avisos', (
    t,
  ) async {
    await abrir(t, en: '/horoscopo');
    await abrirCajon(t);

    final activa = t.widget<Text>(find.text('Horóscopo')).style!;
    final otra = t.widget<Text>(find.text('Grimorio')).style!;

    expect(activa.color, ArcanumColors.goldLight);
    expect(activa.fontWeight, FontWeight.w600);
    expect(otra.color, ArcanumColors.ivoryMuted);
    expect(otra.fontWeight, FontWeight.w400);
    // Y la forma: relleno la de aqui, contorno las otras.
    expect(find.byIcon(arcanumSections[1].selectedIcon), findsOneWidget);
    expect(find.byIcon(arcanumSections[1].icon), findsNothing);
    expect(find.byIcon(arcanumSections[2].icon), findsOneWidget);
  });

  testWidgets('ninguna fila baja de 48 de alto', (t) async {
    await abrir(t);
    await abrirCajon(t);

    final rotulos = [
      for (final s in arcanumSections) s.title,
      'Perfil',
      'Ajustes',
      'Privacidad y datos',
    ];
    for (final rotulo in rotulos) {
      final caja = find
          .ancestor(
            of: find.text(rotulo),
            matching: find.byType(ConstrainedBox),
          )
          .first;
      expect(t.getSize(caja).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('tocar la seccion en la que ya estas vuelve a su raiz', (
    t,
  ) async {
    await abrir(t);
    await abrirCajon(t);
    await t.tap(find.text('Cielo'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /hoy'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing, reason: 'el cajon se cerro');
  });
}
