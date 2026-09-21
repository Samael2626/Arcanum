import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// El cajon de la cuenta.
///
/// Lo que se fija aqui es la promesa que justifico anadirlo: Privacidad deja de
/// estar a tres toques. Si alguien la devuelve dentro de Ajustes, esto se cae.
void main() {
  Future<void> abrir(WidgetTester t, {String en = '/hoy'}) async {
    final router = GoRouter(
      initialLocation: en,
      routes: [
        for (final r in ['/hoy', '/perfil', '/settings', '/privacy'])
          GoRoute(
            path: r,
            builder: (c, s) => Scaffold(
              endDrawer: const ArcanumDrawer(),
              appBar: AppBar(
                actions: [
                  Builder(
                    builder: (c) => IconButton(
                      icon: const Icon(Icons.person),
                      onPressed: Scaffold.of(c).openEndDrawer,
                    ),
                  ),
                ],
              ),
              body: Text('pantalla $r'),
            ),
          ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
  }

  testWidgets('las tres viven al mismo nivel, ninguna dentro de otra', (
    t,
  ) async {
    await abrir(t);
    await t.tap(find.byIcon(Icons.person));
    await t.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Privacidad y datos'), findsOneWidget);
  });

  testWidgets('Privacidad llega en DOS toques desde el arranque', (t) async {
    await abrir(t);
    // 1 · abrir el cajon
    await t.tap(find.byIcon(Icons.person));
    await t.pumpAndSettle();
    // 2 · tocarla
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

  testWidgets('la fila de la pantalla abierta lleva los tres avisos', (
    t,
  ) async {
    await abrir(t, en: '/perfil');
    await t.tap(find.byIcon(Icons.person));
    await t.pumpAndSettle();

    final activa = t.widget<Text>(find.text('Perfil')).style!;
    final otra = t.widget<Text>(find.text('Ajustes')).style!;

    expect(activa.color, ArcanumColors.goldLight);
    expect(activa.fontWeight, FontWeight.w600);
    expect(otra.color, ArcanumColors.ivoryMuted);
    expect(otra.fontWeight, FontWeight.w400);
    // Y la forma: relleno la de aqui, contorno las otras.
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
  });

  testWidgets('ninguna fila baja de 48 de alto', (t) async {
    await abrir(t);
    await t.tap(find.byIcon(Icons.person));
    await t.pumpAndSettle();

    for (final rotulo in ['Perfil', 'Ajustes', 'Privacidad y datos']) {
      final caja = find
          .ancestor(
            of: find.text(rotulo),
            matching: find.byType(ConstrainedBox),
          )
          .first;
      expect(t.getSize(caja).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('tocar la fila de donde ya estas solo cierra el cajon', (
    t,
  ) async {
    await abrir(t, en: '/perfil');
    await t.tap(find.byIcon(Icons.person));
    await t.pumpAndSettle();
    await t.tap(find.text('Perfil'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /perfil'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing, reason: 'el cajon se cerro');
  });
}
