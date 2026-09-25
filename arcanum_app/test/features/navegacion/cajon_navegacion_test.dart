// El horóscopo como SECCIÓN DEL CAJÓN, que es lo que se decidió el
// 21-sep-2026 al quitar la barra de abajo.
//
// Antes esto probaba la barra: que cada destino llevara a su rama y que el
// horóscopo quedara MARCADO al leerlo. La barra ya no existe, así que lo que
// se prueba es lo mismo un piso más abajo -- sobre `StatefulNavigationShell`,
// que es quien de verdad sabe en qué rama estás. El cajón solo lo dibuja.
//
// Se monta la app ENTERA por el router y no una pantalla suelta, porque lo que
// se prueba vive en la carcasa: un test que montara `HoroscopoScreen` a pelo
// pasaría aunque no hubiera forma de llegar a ella.
import 'package:arcanum_app/core/monetization/saldo.dart';
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
}

/// En que rama estamos. Sale del shell y no del cajon a proposito: el cajon
/// no existe mientras esta cerrado, y lo que importa es donde estas, no lo que
/// se este dibujando.
int _rama(WidgetTester tester) => tester
    .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
    .currentIndex;

/// Abre el cajon por la hamburguesa. Dos toques para cada seccion: ese es el
/// precio del patron y por eso esta escrito aqui una sola vez.
Future<void> _abrirCajon(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  // Tiempo fijo y no `pumpAndSettle`, por lo mismo que abajo: desde el
  // Grimorio el arbol nunca se queda quieto y el settle expira.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _irA(WidgetTester tester, String titulo) async {
  await _abrirCajon(tester);
  await tester.tap(find.text(titulo));
  // `pump` con tiempo fijo y no `pumpAndSettle`: el Grimorio tiene un sello
  // que respira en bucle y el arbol no se queda quieto nunca. Dos tiempos
  // porque aqui se encadenan dos animaciones: el cajon que se cierra y la
  // rama que entra.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // El cajon y las ramas del shell tienen que ser la MISMA lista. Lo fueron
  // hasta que se quito Cielos de `arcanumSections` y el destino se quedo
  // escrito a mano en el shell: seis destinos, cinco ramas, y tocar el ultimo
  // llamaba a una rama que no existia. Ningun test lo veia porque cada uno
  // miraba su lado. Quitar la barra no relaja esto: el cajon se construye de
  // la misma lista y el indice de la fila sigue siendo el de la rama.
  testWidgets('cada fila del cajón lleva a una rama que existe', (
    tester,
  ) async {
    await _montar(tester);
    // Se tocan todas, de atras adelante: si alguna apuntara a una rama
    // inexistente, `goBranch` reventaria aqui.
    for (var i = arcanumSections.length - 1; i >= 0; i--) {
      await _irA(tester, arcanumSections[i].title);
      expect(
        _rama(tester),
        i,
        reason: 'la fila ${arcanumSections[i].title} no llego a su rama',
      );
    }
  });

  // Ya no hace falta devolver el router a /hoy entre tests: cada uno construye
  // el suyo desde su contenedor. Cuando era global, el que navegaba dejaba al
  // siguiente empezando dentro del horoscopo.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el cajón lista las cinco secciones y la cuenta', (tester) async {
    await _montar(tester);
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    // Y ninguna barra abajo, que es lo que cambio.
    expect(find.byType(NavigationBar), findsNothing);

    await _abrirCajon(tester);
    for (final seccion in arcanumSections) {
      expect(
        find.text(seccion.title),
        findsWidgets,
        reason: '${seccion.title} no esta en el cajon',
      );
    }
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Privacidad y datos'), findsOneWidget);
    expect(find.text('Cielos'), findsNothing);
  });

  testWidgets('la fila lleva a su pantalla', (tester) async {
    await _montar(tester);
    await _irA(tester, 'Horóscopo');
    expect(find.byType(HoroscopoScreen), findsOneWidget);
  });

  testWidgets('y ahí dentro SÍ queda marcada, al abrir el cajón', (
    tester,
  ) async {
    await _montar(tester);
    await _irA(tester, 'Horóscopo');
    expect(_rama(tester), 1);

    // Lo que la barra daba gratis ahora cuesta un toque: hay que abrir el
    // cajon para ver donde estas. Marcada lo esta, pero solo ahi dentro.
    await _abrirCajon(tester);
    // La regla de la casa: sin filete, lo que marca es el icono RELLENO (mas
    // el color y el peso, que viajan con el).
    final horoscopo = arcanumSections[1];
    expect(find.byIcon(horoscopo.selectedIcon), findsOneWidget);
    expect(find.byIcon(horoscopo.icon), findsNothing);
  });

  // Un capítulo de la Biblioteca abierto desde OTRA sección tiene que acabar
  // en la rama de Saber. Con `push` se apilaba en la rama de origen: se leía
  // con la cabecera de esa sección encima. Visto en el aparato el 12-sep-2026.
  testWidgets('un capítulo abierto desde fuera aterriza en Saber', (
    tester,
  ) async {
    await _montar(tester);
    expect(_rama(tester), 0, reason: 'se arranca en Cielo');

    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    router.go('/saber/culpeper-complete-herbal/henbane');
    await tester.pump(const Duration(milliseconds: 400));

    final saber = arcanumSections.indexWhere((s) => s.route == '/saber');
    expect(
      _rama(tester),
      saber,
      reason: 'el capítulo se quedó en la rama de la sección de origen',
    );
  });

  testWidgets('desde el horóscopo se vuelve por el cajón', (tester) async {
    await _montar(tester);
    await _irA(tester, 'Horóscopo');
    await _irA(tester, 'Cielo');
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(HoroscopoScreen), findsNothing);
    expect(_rama(tester), 0);
  });
}
