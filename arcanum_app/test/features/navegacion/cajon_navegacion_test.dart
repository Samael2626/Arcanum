// Navegación entre secciones: los MOSAICOS de la portada desde el 07-oct-2026.
//
// Primero fue la barra de abajo; el 21-sep-2026 pasó al cajón; el 07-oct-2026
// las secciones se abren desde los mosaicos de Cielo, se vuelve por la casa de
// la barra superior y el cajón se queda con la cuenta y la ayuda. Lo que se
// prueba no ha cambiado: que cada destino lleve a su rama, que se sepa dónde
// estás, y que se pueda volver -- sobre `StatefulNavigationShell`, que es
// quien de verdad sabe en qué rama estás.
//
// Se monta la app ENTERA por el router y no una pantalla suelta, porque lo que
// se prueba vive en la carcasa: un test que montara `HoroscopoScreen` a pelo
// pasaría aunque no hubiera forma de llegar a ella.
import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/state/flow_providers.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/horoscopo/horoscopo_screen.dart';
import 'package:arcanum_app/features/settings/settings_screen.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:arcanum_app/features/sendero/application/sendero_guide_controller.dart';
import 'package:arcanum_app/features/tarot/reading/readings_history.dart';
import 'package:arcanum_app/features/sendero/domain/sendero_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../apoyo/saldo_falso.dart';

class _AuthDePrueba extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

class _ApiMuda extends ArcanumApi {
  _ApiMuda() : super(Dio());

  @override
  Future<Map<String, dynamic>> fragmentsBalance() async => {
    'balance': 0,
    'credits_balance': 0,
    'conversion_rate': 12,
    'weekly_conversions_remaining': 3,
    'weekly_conversion_limit': 3,
    'tutorial_reward': 1,
  };

  /// Este arnes prueba navegacion de una cuenta existente, no el primer uso.
  /// Sin progreso, Sendero abre su invitacion y la barrera modal absorbe el
  /// toque de la hamburguesa antes de que el cajon llegue a existir.
  @override
  Future<List<Map<String, dynamic>>> senderoProgress() async => [
    {
      'journey_id': 'orientation',
      'version': 1,
      'step': 0,
      'status': 'dismissed',
    },
  ];

  @override
  Future<Map<String, dynamic>> updateSenderoProgress({
    required String journeyId,
    required int version,
    required int step,
    required String status,
  }) async => {
    'journey_id': journeyId,
    'version': version,
    'step': step,
    'status': status,
  };

  /// Saber monta Plantas y Biblioteca al entrar, y el lector pide su capitulo.
  /// Sin doblarlos, las llamadas se van al Dio real y quedan temporizadores
  /// colgando: el test muere por algo que no es lo que prueba.
  @override
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> libraryWorks() async => [];

  /// `/lecturas` pide el historial de la mesa y su catalogo de tiradas.
  @override
  Future<List<Map<String, dynamic>>> tarotReadings({int limit = 20}) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> tarotDecks() async => [];

  @override
  Future<List<Map<String, dynamic>>> tarotSpreads() async => [];

  @override
  Future<List<Map<String, dynamic>>> allProgress() async => [];

  @override
  Future<Map<String, dynamic>> progressForWork(String workSlug) async => {};

  @override
  Future<Map<String, dynamic>> libraryWork(String slug, {String? kind}) async =>
      {'slug': slug, 'title': 'Culpeper', 'chapters': <Map>[]};

  @override
  Future<Map<String, dynamic>> libraryChapter(
    String workSlug,
    String chapterSlug,
  ) async => {
    'slug': chapterSlug,
    'title': 'Henbane',
    'paragraphs': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) async => {
    'day_ruler': 'sun',
    'planetary_hour': {
      'planet': 'venus',
      'minutes_remaining': 38,
      'is_daytime': true,
      'hour_number': 4,
    },
    'moon': {
      'illumination': 0.62,
      'is_waxing': true,
      'phase_name': 'Gibosa creciente',
      'age_days': 10.0,
    },
  };

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-04',
    'day_ruler': 'sun',
    'today': {
      'transit': 'moon',
      'natal': 'midheaven',
      'aspect': 'trine',
      'angle': 120,
      'orb': 0.66,
      'separation': 119.34,
      'applying': true,
    },
    'chapter': null,
    'year': null,
    'ingress': null,
    'profection': {
      'age': 35,
      'house': 5,
      'sign': 'capricorn',
      'sign_es': 'Capricornio',
      'lord': 'saturn',
      'points_in_sign': ['saturn'],
    },
    'sect': 'day',
    'total_aspects': 3,
  };
}

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  double ancho = 411,
}) async {
  // Con sesion: sin ella, el redirect central manda todo a /login y no habria
  // barra ni boton que probar. Ese camino tiene sus propios tests en
  // `core/router/redirect_sesion_test.dart`.
  // 411x915 logicos, un telefono normal de hoy. NO 360x640 como el capturador:
  // a ese ancho, el boton de "tu siguiente paso" de Hoy se desborda 26 px con
  // una etiqueta larga -- un fallo suyo, anterior a esto, que no toca arreglar
  // aqui pero que haria fallar este test por algo que no es lo que prueba.
  tester.view
    ..physicalSize = Size(ancho * 3, 2745)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_ApiMuda()),
      saldoProvider.overrideWith(() => SaldoFalso(creditos: 3)),
      authProvider.overrideWith(_AuthDePrueba.new),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: contenedor.read(arcanumRouterProvider),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return contenedor;
}

/// En que rama estamos. Sale del shell y no de la pantalla a proposito: lo
/// que importa es donde estas, no lo que se este dibujando.
int _rama(WidgetTester tester) => tester
    .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
    .currentIndex;

int _indice(String route) =>
    arcanumSections.indexWhere((s) => s.route == route);

/// Dos tiempos fijos y no `pumpAndSettle`: el Grimorio tiene un sello que
/// respira en bucle y el arbol no se queda quieto nunca.
Future<void> _esperar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Abre el cajon por la hamburguesa.
Future<void> _abrirCajon(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await _esperar(tester);
}

/// El mosaico de la portada. El del horoscopo no lleva su `Key` propia en la
/// app: la cambia por la del objetivo de Sendero, que es por donde se le
/// apunta.
Finder _mosaico(ProviderContainer c, String titulo) => switch (titulo) {
  'Horóscopo' => find.byKey(
    c.read(senderoGuideTargetsProvider).keyFor('section_horoscopo'),
  ),
  'Grimorio' => find.byKey(const Key('atlas-grimorio')),
  'Saber' => find.byKey(const Key('atlas-saber')),
  'Mesa de tarot' => find.byKey(const Key('atlas-mesa')),
  _ => throw ArgumentError(titulo),
};

/// Un toque en el mosaico, desde la portada. Dos toques por seccion contando
/// el de la casa: el mismo precio que tenia el cajon.
Future<void> _irA(WidgetTester tester, ProviderContainer c, String t) async {
  final mosaico = _mosaico(c, t);
  await tester.ensureVisible(mosaico);
  await tester.pump();
  await tester.tap(mosaico);
  await _esperar(tester);
}

/// La casa de la barra superior: vuelve a la portada desde cualquier seccion.
Future<void> _aCasa(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Volver a la portada'));
  await _esperar(tester);
}

GoRouter _router(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
        as GoRouter;

void main() {
  // Ya no hace falta devolver el router a /hoy entre tests: cada uno construye
  // el suyo desde su contenedor. Cuando era global, el que navegaba dejaba al
  // siguiente empezando dentro del horoscopo.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Los destinos y las ramas del shell tienen que casar. Lo hacian la barra y
  // luego el cajon hasta que se quito Cielos de `arcanumSections` y el
  // destino se quedo escrito a mano: seis destinos, cinco ramas, y tocar el
  // ultimo llamaba a una rama que no existia. Ningun test lo veia porque cada
  // uno miraba su lado.
  //
  // 07-oct-2026: los destinos son ahora los mosaicos de Cielo, y van escritos
  // a mano en `AtlasHomePanel`. Razon de mas para tocarlos todos y comprobar
  // que cada uno cae en la rama de SU seccion, y no en otra.
  testWidgets('cada mosaico de la portada lleva a una rama que existe', (
    tester,
  ) async {
    final c = await _montar(tester);
    for (final (titulo, ruta) in [
      ('Saber', '/saber'),
      ('Grimorio', '/grimorio'),
      ('Horóscopo', '/horoscopo'),
    ]) {
      await _irA(tester, c, titulo);
      expect(
        _rama(tester),
        _indice(ruta),
        reason: 'el mosaico $titulo no llego a su rama',
      );
      await _aCasa(tester);
      expect(_rama(tester), 0, reason: 'la casa no volvio a Cielo');
    }
  });

  // Antes: "el cajon lista las cinco secciones y la cuenta" (21-sep-2026).
  // 08-oct: el menu es un indice con sellos y lleva LAS MISMAS secciones que
  // la portada, con el mismo nombre y EN EL MISMO ORDEN. El orden se lee de la
  // portada de verdad: el 08-oct el menu salio con Horoscopo antes que Tarot y
  // nadie lo vio hasta compararlos.
  testWidgets('portada y menu ofrecen las mismas secciones y en su orden', (
    tester,
  ) async {
    final c = await _montar(tester);
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);

    // Cielo es la propia portada: su cabecera (Atlas de reliquias, 08-oct)
    // lleva la marca y dice en llano que es Cielo. Sin «?», sin casa y sin
    // pestanas: eso queda para las demas secciones.
    expect(find.text('ARCANUM'), findsOneWidget);
    expect(
      find.textContaining('${arcanumSections[0].title} · '),
      findsOneWidget,
    );
    expect(find.byTooltip('Volver a la portada'), findsNothing);
    expect(find.text('Tu carta'), findsOneWidget);
    expect(find.text('Ahora'), findsNothing);

    // Cada mosaico con la seccion del menu a la que pertenece. En debug y
    // perfil la placa de Tarot que va primero es la mesa, y los tests corren
    // en debug; la del Oraculo de la tienda la vigila
    // `atlas_home_panel_test.dart`.
    final mosaicos = <(Finder, String)>[
      (find.byKey(const Key('atlas-cielo')), 'Cielo'),
      (_mosaico(c, 'Mesa de tarot'), 'Tarot'),
      (_mosaico(c, 'Horóscopo'), 'Horóscopo'),
      (_mosaico(c, 'Grimorio'), 'Grimorio'),
      (_mosaico(c, 'Saber'), 'Saber'),
    ];
    for (final (f, nombre) in mosaicos) {
      expect(f, findsOneWidget, reason: nombre);
    }
    // Orden de lectura: de arriba abajo y, en la misma fila, de izquierda a
    // derecha (Grimorio y Saber van lado a lado).
    final enPortada =
        [for (final (f, nombre) in mosaicos) (tester.getTopLeft(f), nombre)]
          ..sort((a, b) {
            final dy = a.$1.dy.compareTo(b.$1.dy);
            return dy != 0 ? dy : a.$1.dx.compareTo(b.$1.dx);
          });
    final ordenPortada = [for (final (_, nombre) in enPortada) nombre];

    await _abrirCajon(tester);
    final cajon = find.byType(Drawer);
    double y(String rotulo) {
      final f = find.descendant(of: cajon, matching: find.text(rotulo));
      expect(f, findsOneWidget, reason: rotulo);
      return tester.getCenter(f).dy;
    }

    final ordenMenu = [...ordenPortada]..sort((a, b) => y(a).compareTo(y(b)));
    expect(ordenMenu, ordenPortada, reason: 'el menu no sigue a la portada');
    // Y los numeros romanos siguen ese orden, cada uno en su fila.
    const romanos = ['I', 'II', 'III', 'IV', 'V'];
    for (var i = 0; i < romanos.length; i++) {
      expect(y(romanos[i]), moreOrLessEquals(y(ordenPortada[i]), epsilon: 2));
    }
    expect(y('Tu cuenta'), greaterThan(y(ordenPortada.last)));
  });

  // 08-oct: el menu nuevo puso en su fila Horoscopo la MISMA GlobalKey del
  // Sendero que lleva la placa de la portada. El shell es indexedStack: la
  // portada sigue montada en cualquier rama, y abrir el menu reventaba con
  // "Multiple widgets used the same GlobalKey". Se abre con la app entera,
  // desplegando todo, y no puede saltar ninguna excepcion.
  testWidgets('abrir el menu con la portada montada no lanza nada', (
    tester,
  ) async {
    await _montar(tester);
    await _abrirCajon(tester);
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.takeException(), isNull);
    final cajon = find.byType(Drawer);
    for (final seccion in ['Tarot', 'Grimorio', 'Tu cuenta']) {
      final f = find.descendant(of: cajon, matching: find.text(seccion));
      await tester.ensureVisible(f);
      await _esperar(tester);
      await tester.tap(f);
      await _esperar(tester);
      expect(tester.takeException(), isNull, reason: seccion);
    }
    // Y desde otra rama, con la portada debajo en el indexedStack.
    _router(tester).go('/horoscopo');
    await _esperar(tester);
    await _abrirCajon(tester);
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 08-oct: el saldo de «Tu cuenta» colgaba del hilo, y con su relleno se
  // quedaba en 190 dp: desbordaba 1-2 px a 411 de ancho. A 360, peor. Se
  // despliega la cuenta en los dos anchos y no puede saltar nada de layout.
  for (final ancho in [360.0, 411.0]) {
    testWidgets(
      '«Tu cuenta» se despliega a ${ancho.round()} dp sin desbordes',
      (tester) async {
        await _montar(tester, ancho: ancho);
        // la portada tampoco desborda ya a 360 (el boton de «tu siguiente
        // paso» parte linea desde el 08-oct): nada que descartar
        expect(tester.takeException(), isNull);
        await _abrirCajon(tester);
        final cuenta = find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Tu cuenta'),
        );
        await tester.tap(cuenta);
        await _esperar(tester);
        expect(find.byKey(const Key('saldo-cajon')), findsOneWidget);
        expect(find.text('Ayuda y recorrido'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // Estudio del 08-oct: la mesa decia «quedo guardada en Lecturas» y no habia
  // puerta. Con el router de la app: la fila existe y abre el historial.
  testWidgets('«Tus lecturas» abre el historial de la mesa', (tester) async {
    await _montar(tester);
    await _abrirCajon(tester);
    // Tus lecturas cuelga de Tarot: un toque para desplegarlo.
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Tarot')),
    );
    await _esperar(tester);
    final fila = find.text('Tus lecturas');
    await tester.ensureVisible(fila);
    await _esperar(tester);
    await tester.tap(fila);
    await _esperar(tester);
    expect(find.byType(TarotReadingsScreen), findsOneWidget);
    expect(find.text('Todavía no has cerrado ningún círculo.'), findsOneWidget);
    expect(_router(tester).canPop(), isTrue);
  });

  testWidgets('el mosaico lleva a su pantalla', (tester) async {
    final c = await _montar(tester);
    await _irA(tester, c, 'Horóscopo');
    expect(find.byType(HoroscopoScreen), findsOneWidget);
  });

  // Antes: "y ahi dentro SI queda marcada, al abrir el cajon". El cajon ya no
  // marca secciones (07-oct-2026); donde estas lo dice la barra superior, que
  // lleva el nombre y la linea llana de la seccion abierta, sin abrir nada.
  testWidgets('y ahí dentro la barra dice dónde estás', (tester) async {
    final c = await _montar(tester);
    await _irA(tester, c, 'Horóscopo');
    expect(_rama(tester), _indice('/horoscopo'));

    final horoscopo = arcanumSections[_indice('/horoscopo')];
    expect(find.text(horoscopo.subtitle), findsWidgets);
    expect(find.text(arcanumSections[0].subtitle), findsNothing);
  });

  // Un capítulo de la Biblioteca abierto desde OTRA sección tiene que acabar
  // en la rama de Saber. Con `push` se apilaba en la rama de origen: se leía
  // con la cabecera de esa sección encima. Visto en el aparato el 12-sep-2026.
  testWidgets('un capítulo abierto desde fuera aterriza en Saber', (
    tester,
  ) async {
    await _montar(tester);
    expect(_rama(tester), 0, reason: 'se arranca en Cielo');

    _router(tester).go('/saber/culpeper-complete-herbal/henbane');
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _rama(tester),
      _indice('/saber'),
      reason: 'el capítulo se quedó en la rama de la sección de origen',
    );
  });

  // Antes: "desde el horoscopo se vuelve por el cajon". Desde el 07-oct-2026
  // se vuelve por la casa, y la casa ademas deja Cielo en su cara de "Ahora":
  // es lo que hacia tocar en el cajon la seccion en la que ya estabas.
  testWidgets('desde el horóscopo se vuelve por la casa, a su raíz', (
    tester,
  ) async {
    final c = await _montar(tester);
    await _irA(tester, c, 'Horóscopo');
    c.read(cieloCaraProvider.notifier).set(1);
    await _aCasa(tester);
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(HoroscopoScreen), findsNothing);
    expect(_rama(tester), 0);
    expect(c.read(cieloCaraProvider), 0, reason: 'Cielo no volvio a Ahora');
  });

  // El Sendero avanza SOLO con gestos reales sobre la app montada: el mosaico
  // de la portada, la lectura opcional (que no gasta) y la hamburguesa.
  // Primer umbral v3 (07-oct) unido a los arreglos de release 1.0.6.
  testWidgets('Sendero avanza al tocar mosaico, lectura opcional y menú', (
    tester,
  ) async {
    final container = await _montar(tester);
    await _abrirCajon(tester);
    // Desde el 08-oct la ayuda vive dentro de «Tu cuenta».
    await tester.tap(find.text('Tu cuenta'));
    await _esperar(tester);
    final ayuda = find.text('Ayuda y recorrido');
    await tester.ensureVisible(ayuda);
    await _esperar(tester);
    await tester.tap(ayuda);
    await _esperar(tester);
    await tester.tap(find.text('Primer umbral'));
    await _esperar(tester);
    expect(find.byKey(const ValueKey('sendero_guide_card')), findsOneWidget);
    expect(container.read(senderoGuideProvider)?.journey.id, 'orientation');
    expect(container.read(senderoGuideProvider)?.step, 0);

    // Se toca donde esta, sin desplazar: es el hueco que el velo deja abierto.
    // Si la placa queda bajo el pliegue, el propio foco la trae a la vista
    // (07-oct); se espera a que termine antes de tocar.
    await _esperar(tester);
    await tester.tap(_mosaico(container, 'Horóscopo'));
    await _esperar(tester);
    expect(find.byType(HoroscopoScreen), findsOneWidget);
    expect(container.read(senderoGuideProvider)?.step, 1);

    await tester.tap(find.text('Terminar sin gastar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(senderoGuideProvider), isNull);
    expect(find.byKey(const ValueKey('sendero_guide_card')), findsNothing);

    // La ayuda dejo su hoja abierta: se cierra tocando fuera, como en el
    // aparato. Y luego la hamburguesa, en el recorrido de la cuenta.
    await tester.tapAt(const Offset(200, 20));
    await _esperar(tester);
    _router(tester).go('/hoy');
    await _esperar(tester);
    container
        .read(senderoGuideProvider.notifier)
        .start(senderoJourneyById('account')!);
    await _esperar(tester);
    expect(container.read(senderoGuideProvider)?.step, 0);
    await _abrirCajon(tester);
    expect(container.read(senderoGuideProvider)?.step, 1);
    // El paso siguiente senala Ajustes, que vive dentro de «Tu cuenta»: la
    // cuenta se despliega sola y Ajustes se toca sin buscarla.
    final ajustes = find.byKey(
      container.read(senderoGuideTargetsProvider).keyFor('settings'),
    );
    expect(ajustes, findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    // La cuenta se despliega con animacion y la tarjeta del Sendero se
    // recoloca al medir: se espera a que las dos terminen.
    await _esperar(tester);
    await _esperar(tester);
    await tester.tap(ajustes);
    await _esperar(tester);
    expect(
      find.byType(SettingsScreen),
      findsOneWidget,
      reason: 'Ajustes no se abrio',
    );
    expect(
      container.read(senderoGuideProvider),
      isNull,
      reason: 'tocar Ajustes no cerro el recorrido de la cuenta',
    );
  });
}
