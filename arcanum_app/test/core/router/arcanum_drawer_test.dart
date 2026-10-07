import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoyo/saldo_falso.dart';

/// El cajon: CUENTA Y AYUDA desde el 07-oct-2026.
///
/// Del 21-sep al 07-oct-2026 fue toda la navegacion. Con la portada de
/// mosaicos las secciones salieron de aqui: se abren desde Cielo, y la barra
/// superior lleva una casa para volver a ella. Lo que se fija ahora es lo que
/// justifico cada pieza que queda: que Privacidad no vuelva a estar a tres
/// toques, que las secciones NO se cuelen de nuevo en el cajon (dos sitios
/// para lo mismo), y que la regla de seleccion de la casa siga aplicandose.
///
/// Se monta un `StatefulShellRoute` de verdad y no un `Scaffold` suelto: el
/// cajon pide el shell, y fabricarlo a mano seria probar otra cosa.
void main() {
  /// Rutas de la cuenta, FUERA del shell, como en `app_router.dart`.
  const cuenta = ['/perfil', '/settings', '/privacy', '/sendero', '/tarot'];

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
    'Mesa de tarot · en pruebas',
    'Ayuda y recorrido',
    'Perfil',
    'Ajustes',
    'Privacidad y datos',
  ];

  testWidgets('las secciones viven en la portada, no en el cajon', (t) async {
    await abrir(t);
    await abrirCajon(t);

    expect(enCajon(find.text('CUENTA Y AYUDA')), findsOneWidget);
    for (final seccion in arcanumSections) {
      expect(
        enCajon(find.text(seccion.title)),
        findsNothing,
        reason:
            '${seccion.title} volvio al cajon: la abre su mosaico de la '
            'portada, y dos entradas para lo mismo es lo que se quito',
      );
    }
  });

  testWidgets('las de la cuenta viven al mismo nivel', (t) async {
    await abrir(t);
    await abrirCajon(t);

    for (final rotulo in filas) {
      expect(enCajon(find.text(rotulo)), findsOneWidget, reason: rotulo);
    }
  });

  testWidgets('Privacidad llega en DOS toques desde el arranque', (t) async {
    await abrir(t);
    // 1 · abrir el cajon
    await abrirCajon(t);
    // 2 · tocarla
    //
    // HAY QUE DESPLAZAR PARA LLEGAR, pero SOLO EN EL TEST: el viewport por
    // defecto de flutter_test es 800x600, mas corto que cualquier telefono.
    //
    // En el aparato de verdad no hace falta. Medido en el OnePlus (360x800 dp)
    // el 25-sep-2026 con el bloque de saldo ya puesto: el cajon entero termina
    // a los 443 dp y cabe de sobra. Siguen siendo DOS toques, que es lo que
    // este test defiende.
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

  // Antes: "una seccion cuesta dos toques, y cambia de rama". Las secciones ya
  // no estan aqui (07-oct-2026); lo que queda es la ayuda, que tambien tiene
  // que costar dos toques y cerrar el cajon detras.
  testWidgets('la ayuda cuesta dos toques, y el cajon se cierra', (t) async {
    await abrir(t);
    await abrirCajon(t);
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
    await t.tap(find.text('Perfil'));
    await t.pumpAndSettle();

    expect(find.text('pantalla /perfil'), findsOneWidget);
    expect(router.canPop(), isFalse, reason: 'se apilo la misma pantalla');
    expect(find.text('Ajustes'), findsNothing, reason: 'el cajon se cerro');
  });
}
