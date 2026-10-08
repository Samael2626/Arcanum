import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:arcanum_app/core/state/flow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoyo/saldo_falso.dart';

/// El cajon comparte destinos con los mosaicos y abre directamente las dos
/// caras de Cielo. Se monta un shell real para probar el cambio de rama.
void main() {
  /// Rutas de la cuenta, FUERA del shell, como en `app_router.dart`.
  const cuenta = [
    '/perfil',
    '/settings',
    '/privacy',
    '/sendero',
    '/tarot',
    '/respirar',
    '/sigilos',
    '/fragmentos',
  ];

  /// [enRama] mete ademas una ruta de la cuenta COMO RAMA del shell. Solo para
  /// probar la regla de seleccion: en la app ninguna fila del cajon apunta
  /// dentro del shell, asi que la fila marcada no se ve nunca -- pero si un
  /// dia alguna apunta, tiene que marcarse como manda la casa.
  Future<GoRouter> abrir(
    WidgetTester t, {
    String en = '/hoy',
    String? enRama,
  }) async {
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
            for (final route in [
              for (final s in arcanumSections) s.route,
              ?enRama,
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: route,
                    builder: (c, s) => Text('pantalla $route'),
                  ),
                ],
              ),
          ],
        ),
        for (final r in cuenta.where((r) => r != enRama))
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

  Finder enCajon(Finder f) =>
      find.descendant(of: find.byType(ArcanumDrawer), matching: f);

  // Filas que lleva el cajon. La mesa solo existe en debug y perfil, y los
  // tests corren en debug: si sale en la tienda, lo vigila la condicion
  // `kDebugMode || kProfileMode` del propio cajon, no este test.
  const filas = [
    'Ahora y horas',
    'Carta natal',
    'Horóscopo',
    'Oráculo',
    'Grimorio',
    'Respirar',
    'Taller de sigilos',
    'Mesa de tarot',
    'Saber · plantas, libros y sellos',
    'Fragmentos Arcanos',
    'Ayuda y recorrido',
    'Perfil',
    'Ajustes',
    'Privacidad y datos',
  ];

  testWidgets('el cajon contiene las secciones principales', (t) async {
    await abrir(t);
    await abrirCajon(t);

    expect(enCajon(find.text('CIELO')), findsOneWidget);
    expect(enCajon(find.text('PRACTICAR')), findsOneWidget);
    expect(enCajon(find.text('DESCUBRIR')), findsOneWidget);
    expect(enCajon(find.text('CUENTA Y AYUDA')), findsOneWidget);
    for (final rotulo in filas) {
      expect(enCajon(find.text(rotulo)), findsOneWidget, reason: rotulo);
    }
  });

  testWidgets('Carta natal abre la otra cara de Cielo sin apilar ruta', (
    t,
  ) async {
    final router = await abrir(t);
    await abrirCajon(t);
    await t.tap(find.text('Carta natal'));
    await t.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/hoy');
    expect(find.text('Carta natal'), findsNothing);
    expect(
      ProviderScope.containerOf(
        t.element(find.text('pantalla /hoy')),
      ).read(cieloCaraProvider),
      1,
    );
    expect(router.canPop(), isFalse);
  });

  testWidgets('Horoscopo cambia de rama y cierra el cajon', (t) async {
    final router = await abrir(t);
    await abrirCajon(t);
    await t.tap(find.text('Horóscopo'));
    await t.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/horoscopo');
    expect(find.text('pantalla /horoscopo'), findsOneWidget);
    expect(find.text('Carta natal'), findsNothing);
  });

  testWidgets('las de la cuenta viven al mismo nivel', (t) async {
    await abrir(t);
    await abrirCajon(t);

    for (final rotulo in filas.skip(10)) {
      expect(enCajon(find.text(rotulo)), findsOneWidget, reason: rotulo);
    }
  });

  testWidgets('Privacidad llega en DOS toques desde el arranque', (t) async {
    await abrir(t);
    // 1 · abrir el cajon
    await abrirCajon(t);
    // 2 · tocarla
    //
    // El cajon es desplazable y conserva el acceso directo a Privacidad.
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

  testWidgets('la ayuda cuesta dos toques, y el cajon se cierra', (t) async {
    await abrir(t);
    await abrirCajon(t);
    await t.ensureVisible(find.text('Ayuda y recorrido'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ayuda y recorrido'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /sendero'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing, reason: 'el cajon se cerro');
  });

  testWidgets('la fila de la pantalla abierta lleva los tres avisos', (
    t,
  ) async {
    await abrir(t, en: '/perfil', enRama: '/perfil');
    await abrirCajon(t);

    final activa = t.widget<Text>(find.text('Perfil')).style!;
    final otra = t.widget<Text>(find.text('Ajustes')).style!;

    expect(activa.color, ArcanumColors.goldLight);
    expect(activa.fontWeight, FontWeight.w600);
    expect(otra.color, ArcanumColors.ivoryMuted);
    expect(otra.fontWeight, FontWeight.w400);
    // Y la forma: relleno la de aqui, contorno las otras.
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
  });

  testWidgets('ninguna fila baja de 48 de alto', (t) async {
    await abrir(t);
    await abrirCajon(t);

    for (final rotulo in filas) {
      await t.ensureVisible(find.text(rotulo));
      await t.pumpAndSettle();
      final caja = find
          .ancestor(
            of: find.text(rotulo),
            matching: find.byType(ConstrainedBox),
          )
          .first;
      expect(t.getSize(caja).height, greaterThanOrEqualTo(48), reason: rotulo);
    }
  });

  // Antes: "tocar la seccion en la que ya estas vuelve a su raiz". Volver a
  // la portada lo hace ahora la casa de la barra (ver cajon_navegacion_test).
  // Aqui queda la otra mitad: tocar la fila de donde ya estas no apila la
  // misma pantalla otra vez, solo cierra el cajon.
  testWidgets('tocar la fila en la que ya estas solo cierra el cajon', (
    t,
  ) async {
    final router = await abrir(t, en: '/perfil', enRama: '/perfil');
    await abrirCajon(t);
    await t.ensureVisible(find.text('Perfil'));
    await t.pumpAndSettle();
    await t.tap(find.text('Perfil'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /perfil'), findsOneWidget);
    expect(router.canPop(), isFalse, reason: 'se apilo la misma pantalla');
    expect(find.text('Ajustes'), findsNothing, reason: 'el cajon se cerro');
  });
}
