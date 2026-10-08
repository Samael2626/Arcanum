import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/arcanum_drawer.dart';
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:arcanum_app/core/state/flow_providers.dart';
import 'package:arcanum_app/features/fragmentos/application/fragment_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoyo/saldo_falso.dart';

/// Fragmentos de mentira: la cifra pequena de la cabecera los ensena.
class _FragmentosFalsos extends FragmentBalanceController {
  @override
  Future<FragmentBalance> build() async => const FragmentBalance(
    balance: 12,
    creditsBalance: 3,
    conversionRate: 12,
    weeklyConversionsRemaining: 3,
    weeklyConversionLimit: 3,
    tutorialReward: 1,
  );
}

/// El menu: indice con sellos (Samuel, 08-oct). Cinco secciones con su numero
/// romano, las que tienen partes se despliegan, y la cuenta al pie. Se monta un
/// shell real para probar el cambio de rama.
void main() {
  /// Rutas fuera del shell, como en `app_router.dart`.
  const fuera = [
    '/perfil',
    '/settings',
    '/privacy',
    '/sendero',
    '/tarot',
    '/lecturas',
    '/respirar',
    '/sigilos',
    '/fragmentos',
    '/paywall',
  ];

  /// Secciones del menu, en su orden. Que es el de la portada lo vigila
  /// `cajon_navegacion_test.dart`, contra la portada de verdad.
  const secciones = ['Cielo', 'Tarot', 'Horóscopo', 'Grimorio', 'Saber'];
  const romanos = ['I', 'II', 'III', 'IV', 'V'];

  /// Cada parte: (seccion que la despliega, rotulo, ruta a la que lleva).
  const partes = [
    ('Cielo', 'Hoy y la hora', '/hoy'),
    ('Cielo', 'Tu carta natal', '/hoy'),
    ('Cielo', 'Respirar', '/respirar'),
    ('Tarot', 'Mesa', '/tarot'),
    ('Tarot', 'Oráculo', '/oraculo'),
    ('Tarot', 'Tus lecturas', '/lecturas'),
    ('Grimorio', 'Diario', '/grimorio'),
    ('Grimorio', 'Taller de sigilos', '/sigilos'),
    ('Tu cuenta', 'Perfil', '/perfil'),
    ('Tu cuenta', 'Ajustes', '/settings'),
    ('Tu cuenta', 'Privacidad y datos', '/privacy'),
    ('Tu cuenta', 'Fragmentos Arcanos', '/fragmentos'),
    ('Tu cuenta', 'Ayuda y recorrido', '/sendero'),
  ];

  /// [enRama] mete ademas una ruta de fuera COMO RAMA del shell: en la app el
  /// cajon no se ve sobre las pantallas apiladas, asi que para probar la marca
  /// de una parte de la cuenta hace falta que viva dentro.
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
        for (final r in fuera.where((r) => r != enRama))
          GoRoute(
            path: r,
            builder: (c, s) => Scaffold(body: Text('pantalla $r')),
          ),
      ],
    );
    // Se vacia antes: cada llamada estrena router y scope.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          saldoProvider.overrideWith(() => SaldoFalso(creditos: 3)),
          fragmentBalanceProvider.overrideWith(_FragmentosFalsos.new),
        ],
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

  Future<void> tocar(WidgetTester t, String rotulo) async {
    final f = enCajon(find.text(rotulo));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// Despliega [seccion] si [parte] no esta a la vista.
  Future<void> desplegar(WidgetTester t, String seccion, String parte) async {
    if (enCajon(find.text(parte)).evaluate().isEmpty) {
      await tocar(t, seccion);
    }
    expect(enCajon(find.text(parte)), findsOneWidget, reason: parte);
  }

  /// La zona tactil de un rotulo: el InkWell que lo envuelve.
  Finder zona(Finder rotulo) =>
      find.ancestor(of: rotulo, matching: find.byType(InkWell)).first;

  Color? color(WidgetTester t, String rotulo) =>
      t.widget<Text>(enCajon(find.text(rotulo))).style!.color;

  /// El sello es el Container circular que envuelve al numero.
  BoxDecoration sello(WidgetTester t, String numero) =>
      t
              .widget<Container>(
                find
                    .ancestor(
                      of: enCajon(find.text(numero)),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('las cinco secciones llevan su numero romano, I a V en orden', (
    t,
  ) async {
    await abrir(t);
    await abrirCajon(t);

    double y(String s) => t.getCenter(enCajon(find.text(s))).dy;
    for (var i = 0; i < secciones.length; i++) {
      expect(enCajon(find.text(romanos[i])), findsOneWidget);
      expect(
        y(romanos[i]),
        moreOrLessEquals(y(secciones[i]), epsilon: 2),
        reason: '${romanos[i]} no esta en la fila de ${secciones[i]}',
      );
      if (i > 0) {
        expect(y(secciones[i]), greaterThan(y(secciones[i - 1])));
      }
    }
    expect(enCajon(find.text('Tu cuenta')), findsOneWidget);
    expect(y('Tu cuenta'), greaterThan(y('Saber')), reason: 'al pie');
  });

  testWidgets('cada seccion y cada parte llevan a una ruta que existe', (
    t,
  ) async {
    for (final (seccion, ruta) in [
      ('Horóscopo', '/horoscopo'),
      ('Saber', '/saber'),
    ]) {
      await abrir(t);
      await abrirCajon(t);
      await tocar(t, seccion);
      expect(find.text('pantalla $ruta'), findsOneWidget, reason: seccion);
      expect(find.byType(ArcanumDrawer), findsNothing, reason: 'se cerro');
    }
    for (final (seccion, rotulo, ruta) in partes) {
      // Desde el horoscopo, para que ir a /hoy sea un cambio de verdad.
      await abrir(t, en: '/horoscopo');
      await abrirCajon(t);
      await desplegar(t, seccion, rotulo);
      await tocar(t, rotulo);
      expect(find.text('pantalla $ruta'), findsOneWidget, reason: rotulo);
      expect(find.byType(ArcanumDrawer), findsNothing, reason: rotulo);
    }
  });

  testWidgets('Tu carta natal abre la otra cara de Cielo sin apilar ruta', (
    t,
  ) async {
    final router = await abrir(t);
    await abrirCajon(t);
    await tocar(t, 'Tu carta natal');

    expect(router.routeInformationProvider.value.uri.path, '/hoy');
    expect(find.byType(ArcanumDrawer), findsNothing);
    expect(
      ProviderScope.containerOf(
        t.element(find.text('pantalla /hoy')),
      ).read(cieloCaraProvider),
      1,
    );
    expect(router.canPop(), isFalse);
  });

  testWidgets('Tus lecturas abre /lecturas encima del shell', (t) async {
    final router = await abrir(t);
    await abrirCajon(t);
    await desplegar(t, 'Tarot', 'Tus lecturas');
    await tocar(t, 'Tus lecturas');

    expect(find.text('pantalla /lecturas'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'se vuelve con atras');
  });

  testWidgets('al abrir se despliega la seccion donde se esta', (t) async {
    await abrir(t, en: '/oraculo');
    await abrirCajon(t);
    expect(enCajon(find.text('Oráculo')), findsOneWidget);
    expect(enCajon(find.text('Hoy y la hora')), findsNothing);
    expect(enCajon(find.text('Perfil')), findsNothing);

    await abrir(t, en: '/horoscopo');
    await abrirCajon(t);
    for (final (_, rotulo, _) in partes) {
      expect(enCajon(find.text(rotulo)), findsNothing, reason: rotulo);
    }
  });

  testWidgets('desplegar y plegar: una seccion a la vez', (t) async {
    final semantica = t.ensureSemantics();
    await abrir(t, en: '/horoscopo');
    await abrirCajon(t);

    expect(
      t.getSemantics(find.bySemanticsLabel('Tarot')),
      isSemantics(isButton: true, hasExpandedState: true),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Tarot')),
      isNot(isSemantics(isExpanded: true)),
    );

    await tocar(t, 'Tarot');
    expect(enCajon(find.text('Mesa')), findsOneWidget);
    expect(
      t.getSemantics(find.bySemanticsLabel('Tarot')),
      isSemantics(isExpanded: true),
    );

    // Abrir otra pliega la anterior.
    await tocar(t, 'Grimorio');
    expect(enCajon(find.text('Diario')), findsOneWidget);
    expect(enCajon(find.text('Mesa')), findsNothing);

    // Tocar la abierta la pliega, sin navegar.
    await tocar(t, 'Grimorio');
    expect(enCajon(find.text('Diario')), findsNothing);
    expect(find.byType(ArcanumDrawer), findsOneWidget);
    expect(find.text('pantalla /horoscopo'), findsOneWidget);

    // Las que no despliegan no anuncian estado de despliegue.
    expect(
      t.getSemantics(find.bySemanticsLabel('Saber')),
      isNot(isSemantics(hasExpandedState: true)),
    );
    semantica.dispose();
  });

  testWidgets('Privacidad llega en TRES toques desde el arranque (08-oct)', (
    t,
  ) async {
    await abrir(t);
    // 1 · abrir el menu
    await abrirCajon(t);
    // 2 · desplegar la cuenta
    await tocar(t, 'Tu cuenta');
    // 3 · tocarla
    await tocar(t, 'Privacidad y datos');

    expect(
      find.text('pantalla /privacy'),
      findsOneWidget,
      reason:
          'Estuvo a tres toques dentro de Ajustes. Si se aleja mas, el menu '
          'deja de tener sentido.',
    );
  });

  testWidgets('la ayuda cuesta tres toques desde el 08-oct, y el menu se '
      'cierra', (t) async {
    await abrir(t);
    // menu · Tu cuenta · Ayuda: antes dos, la cuenta ahora se despliega
    await abrirCajon(t);
    await tocar(t, 'Tu cuenta');
    await tocar(t, 'Ayuda y recorrido');

    expect(find.text('pantalla /sendero'), findsOneWidget);
    expect(find.byType(ArcanumDrawer), findsNothing, reason: 'se cerro');
  });

  testWidgets('el saldo completo vive dentro de «Tu cuenta», sobre Perfil', (
    t,
  ) async {
    await abrir(t);
    await abrirCajon(t);
    expect(enCajon(find.byKey(const Key('saldo-cajon'))), findsNothing);

    await tocar(t, 'Tu cuenta');
    final saldo = enCajon(find.byKey(const Key('saldo-cajon')));
    expect(saldo, findsOneWidget);
    expect(
      t.getTopLeft(saldo).dy,
      lessThan(t.getTopLeft(enCajon(find.text('Perfil'))).dy),
    );
    expect(
      t.getTopLeft(saldo).dy,
      greaterThan(t.getTopLeft(enCajon(find.text('Tu cuenta'))).dy),
    );
  });

  testWidgets('la cifra pequena de la cabecera abre /paywall', (t) async {
    await abrir(t);
    await abrirCajon(t);

    final cifra = zona(enCajon(find.text('12')));
    expect(
      find.descendant(of: cifra, matching: find.text('3')),
      findsOneWidget,
      reason: 'creditos y Fragmentos en la misma zona',
    );
    // Arriba, junto a ARCANUM, y no dentro de la cuenta.
    expect(
      t.getCenter(cifra).dy,
      moreOrLessEquals(
        t.getCenter(enCajon(find.text('ARCANUM'))).dy,
        epsilon: 4,
      ),
    );
    await t.tap(cifra);
    await t.pumpAndSettle();
    expect(find.text('pantalla /paywall'), findsOneWidget);
    expect(find.byType(ArcanumDrawer), findsNothing);
  });

  testWidgets('ninguna fila baja de 48, ni la cifra pequena', (t) async {
    await abrir(t, en: '/horoscopo');
    await abrirCajon(t);

    Future<void> mide(String rotulo) async {
      final f = enCajon(find.text(rotulo));
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      expect(
        t.getSize(zona(f)).height,
        greaterThanOrEqualTo(48),
        reason: rotulo,
      );
    }

    for (final s in [...secciones, 'Tu cuenta']) {
      await mide(s);
    }
    for (final (seccion, rotulo, _) in partes) {
      await desplegar(t, seccion, rotulo);
      await mide(rotulo);
    }
    final cifra = t.getSize(zona(enCajon(find.text('12'))));
    expect(cifra.height, greaterThanOrEqualTo(48));
    expect(cifra.width, greaterThanOrEqualTo(48));
  });

  testWidgets('la seccion abierta: sello con halo y nombre en oro', (t) async {
    final semantica = t.ensureSemantics();
    await abrir(t, en: '/horoscopo');
    await abrirCajon(t);

    expect(color(t, 'Horóscopo'), ArcanumColors.gold);
    expect(color(t, 'Cielo'), ArcanumColors.ivory);
    // El halo es una sombra de mas en el sello.
    expect(sello(t, 'III').boxShadow, hasLength(2));
    expect(sello(t, 'I').boxShadow, hasLength(1));
    expect(sello(t, 'III').border!.top.color, ArcanumColors.goldLight);
    expect(
      t.getSemantics(find.bySemanticsLabel('Horóscopo')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Cielo')),
      isNot(isSemantics(isSelected: true)),
    );
    semantica.dispose();
  });

  testWidgets('la parte abierta va en oro', (t) async {
    await abrir(t, en: '/oraculo');
    await abrirCajon(t);

    expect(color(t, 'Tarot'), ArcanumColors.gold);
    expect(color(t, 'Oráculo'), ArcanumColors.gold);
    expect(color(t, 'Mesa'), ArcanumColors.ivoryMuted);

    await abrir(t, en: '/perfil', enRama: '/perfil');
    await abrirCajon(t);
    await tocar(t, 'Tu cuenta');
    expect(color(t, 'Perfil'), ArcanumColors.gold);
    expect(color(t, 'Ajustes'), ArcanumColors.ivoryMuted);
  });

  // Tocar donde ya estas no apila la misma pantalla otra vez: solo cierra.
  testWidgets('tocar donde ya estas solo cierra el menu', (t) async {
    // Una seccion sin partes.
    var router = await abrir(t, en: '/horoscopo');
    await abrirCajon(t);
    await tocar(t, 'Horóscopo');
    expect(find.text('pantalla /horoscopo'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(find.byType(ArcanumDrawer), findsNothing);

    // Una parte de una seccion.
    router = await abrir(t, en: '/oraculo');
    await abrirCajon(t);
    await tocar(t, 'Oráculo');
    expect(find.text('pantalla /oraculo'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(find.byType(ArcanumDrawer), findsNothing);

    // Una parte de la cuenta que se apila.
    router = await abrir(t, en: '/perfil', enRama: '/perfil');
    await abrirCajon(t);
    await tocar(t, 'Tu cuenta');
    await tocar(t, 'Perfil');
    expect(find.text('pantalla /perfil'), findsOneWidget);
    expect(router.canPop(), isFalse, reason: 'se apilo la misma pantalla');
    expect(find.byType(ArcanumDrawer), findsNothing);
  });
}
