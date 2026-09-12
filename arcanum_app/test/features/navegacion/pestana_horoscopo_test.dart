// El horóscopo como PESTAÑA, que es lo que se decidió el 11-sep-2026.
//
// Sustituye a `boton_horoscopo_test.dart`. Aquel probaba un botón flotante que
// existía porque el horóscopo estaba fuera de la barra, y con él probaba el
// caso especial que eso obligaba: ninguna pestaña marcada, el indicador
// apagado a mano, un índice falso para que `NavigationBar` no protestara. Ese
// caso especial ya no existe, así que lo que aquí se prueba es lo contrario:
// que el horóscopo SÍ queda marcado, como cualquier otra sección.
//
// Se monta la app ENTERA por el router y no una pantalla suelta, porque lo que
// se prueba vive en la carcasa: un test que montara `HoroscopoScreen` a pelo
// pasaría aunque no hubiera pestaña.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/horoscopo/horoscopo_screen.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      'planet': 'venus', 'minutes_remaining': 38,
      'is_daytime': true, 'hour_number': 4,
    },
    'moon': {
      'illumination': 0.62, 'is_waxing': true,
      'phase_name': 'Gibosa creciente', 'age_days': 10.0,
    },
  };

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-04',
    'day_ruler': 'sun',
    'today': {
      'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
      'angle': 120, 'orb': 0.66, 'separation': 119.34, 'applying': true,
    },
    'chapter': null,
    'year': null,
    'ingress': null,
    'profection': {
      'age': 35, 'house': 5, 'sign': 'capricorn', 'sign_es': 'Capricornio',
      'lord': 'saturn', 'points_in_sign': ['saturn'],
    },
    'sect': 'day',
    'total_aspects': 3,
  };
}

Future<void> _montar(WidgetTester tester) async {
  // Con sesion: sin ella, el redirect central manda todo a /login y no habria
  // barra ni boton que probar. Ese camino tiene sus propios tests en
  // `core/router/redirect_sesion_test.dart`.
  // 411x915 logicos, un telefono normal de hoy. NO 360x640 como el capturador:
  // a ese ancho, el boton de "tu siguiente paso" de Hoy se desborda 26 px con
  // una etiqueta larga -- un fallo suyo, anterior a esto, que no toca arreglar
  // aqui pero que haria fallar este test por algo que no es lo que prueba.
  tester.view
    ..physicalSize = const Size(1233, 2745)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_ApiMuda()),
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
}

NavigationBar _barra(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  // La barra y las ramas del shell tienen que ser la MISMA lista. Lo fueron
  // hasta que se quito Cielos de `arcanumSections` y el destino se quedo
  // escrito a mano en el shell: seis destinos, cinco ramas, y tocar el ultimo
  // llamaba a una rama que no existia. Ningun test lo veia porque cada uno
  // miraba su lado.
  testWidgets('cada destino de la barra lleva a una rama que existe', (
    tester,
  ) async {
    await _montar(tester);
    final barra = _barra(tester);
    expect(barra.destinations.length, arcanumSections.length);
    // Y se tocan todos, de atras adelante: si alguno apuntara a una rama
    // inexistente, `goBranch` reventaria aqui.
    for (var i = barra.destinations.length - 1; i >= 0; i--) {
      await tester.tap(find.text(arcanumSections[i].title));
      // `pump` con tiempo fijo y no `pumpAndSettle`: el Grimorio tiene un
      // sello que respira en bucle y el arbol no se queda quieto nunca.
      await tester.pump(const Duration(milliseconds: 400));
      expect(_barra(tester).selectedIndex, i,
          reason: 'el destino ${arcanumSections[i].title} no llego a su rama');
    }
  });

  // Ya no hace falta devolver el router a /hoy entre tests: cada uno construye
  // el suyo desde su contenedor. Cuando era global, el que navegaba dejaba al
  // siguiente empezando dentro del horoscopo.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el horóscopo es una pestaña, y ya no hay botón flotante', (
    tester,
  ) async {
    await _montar(tester);
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    // Cinco destinos: Hoy y Cielos se fundieron en "Cielo", y el horóscopo
    // ocupa el hueco.
    final barra = _barra(tester);
    expect(barra.destinations.length, 5);
    expect(find.text('Horóscopo'), findsOneWidget);
    expect(find.text('Cielos'), findsNothing);
  });

  testWidgets('la pestaña lleva a su pantalla', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Horóscopo'));
    await tester.pumpAndSettle();
    expect(find.byType(HoroscopoScreen), findsOneWidget);
  });

  testWidgets('y ahí dentro SÍ queda marcada, que es lo que cambió', (
    tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.text('Horóscopo'));
    await tester.pumpAndSettle();

    // Antes se le daba el 0 y se apagaba el indicador, porque el horóscopo no
    // era ninguna de las pestañas. Ahora es la segunda y se dice.
    expect(_barra(tester).selectedIndex, 1);
    expect(
      find.byType(NavigationBarTheme),
      findsNothing,
      reason: 'el tema que apagaba el indicador ya no hace falta',
    );
  });

  // Un capítulo de la Biblioteca abierto desde OTRA pestaña tiene que acabar
  // en la rama de Saber. Con `push` se apilaba en la rama de origen: se leía
  // con la cabecera de esa sección encima y su pestaña marcada abajo. Visto en
  // el aparato el 12-sep-2026.
  testWidgets('un capítulo abierto desde fuera aterriza en Saber', (
    tester,
  ) async {
    await _montar(tester);
    expect(_barra(tester).selectedIndex, 0, reason: 'se arranca en Cielo');

    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    router.go('/saber/culpeper-complete-herbal/henbane');
    await tester.pump(const Duration(milliseconds: 400));

    final saber = arcanumSections.indexWhere((s) => s.route == '/saber');
    expect(
      _barra(tester).selectedIndex,
      saber,
      reason: 'el capítulo se quedó en la rama de la pestaña de origen',
    );
  });

  testWidgets('desde el horóscopo se vuelve por la barra', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Horóscopo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cielo'));
    await tester.pumpAndSettle();
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(HoroscopoScreen), findsNothing);
    expect(_barra(tester).selectedIndex, 0);
  });
}
