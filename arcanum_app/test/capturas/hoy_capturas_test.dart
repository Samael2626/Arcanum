@Tags(['capturas'])
library;

import 'dart:io';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/features/horoscopo/compartir_horoscopo.dart';
import 'package:arcanum_app/features/horoscopo/widgets/tarjeta_compartir.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retrata la pantalla Hoy DE VERDAD, para poder mirarla sin compilar la app.
///
/// No es un test: no afirma nada. Es un capturador. Se ejecuta a mano con
///
///     flutter test test/capturas --update-goldens --run-skipped
///
/// y deja los PNG en `test/capturas/salida/`. Lleva su propio `@Tags` para que
/// la suite normal lo salte: un fichero que reescribe imagenes cada vez que
/// corre no tiene sitio en un CI.
///
/// POR QUE EXISTE
///     Un prototipo HTML dibujado aparte y la pantalla compilada se separan sin
///     que nadie lo note, y entonces se revisa el dibujo en vez del producto.
///     Esto sale del mismo Dart que se ejecuta en el telefono.
///
/// LAS FUENTES HAY QUE CARGARLAS A MANO
///     En un entorno de test Flutter usa Ahem, una fuente de cuadros negros: si
///     no se cargan las reales, el retrato sale ilegible y ademas mentiria
///     justo sobre lo ultimo que se toco, que fue la tipografia.
/// La fuente de los iconos de Material vive en la cache del SDK, no en el
/// proyecto, y su ruta ha cambiado de sitio entre versiones de Flutter. Se
/// prueban las conocidas y se sigue sin ella si no aparece ninguna: perder los
/// iconos estropea el retrato, pero no justifica romper el capturador.
String? _iconosDeMaterial() {
  const candidatas = [
    r'D:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    r'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final ruta in candidatas) {
    if (File(ruta).existsSync()) return ruta;
  }
  return null;
}

Future<void> _cargarFuentes() async {
  final manifiesto = {
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
    // Los iconos de Material tampoco existen en un entorno de test: sin
    // cargarlos, cada icono sale como un cuadrado vacio y el retrato parece
    // tener un fallo de fuentes que la app no tiene.
  };
  final iconos = _iconosDeMaterial();
  if (iconos != null) manifiesto['MaterialIcons'] = [iconos];
  for (final entrada in manifiesto.entries) {
    final cargador = FontLoader(entrada.key);
    for (final ruta in entrada.value) {
      cargador.addFont(
        File(ruta).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await cargador.load();
  }
}

class _AuthConLugar extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

/// Los mismos datos que usa `hoy_screen_test.dart`, para retratar la pantalla
/// en el estado que ya esta probado y no en uno inventado para la foto.
class _ApiDeMuestra extends ArcanumApi {
  _ApiDeMuestra() : super(Dio());

  /// El regente, la hora planetaria y la luna: el primer panel de la pantalla.
  /// Sin esto la tarjeta se va a la implementacion real, no hay servidor y Hoy
  /// se queda en "El cielo guarda silencio".
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
    'date': '2026-08-24',
    'day_ruler': 'sun',
    'today': {
      'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
      'angle': 120, 'orb': 0.66, 'separation': 119.34,
      'applying': true, 'tempo': 'fast',
    },
    'chapter': {
      'transit': 'saturn', 'natal': 'sun', 'aspect': 'square',
      'angle': 90, 'orb': 0.2, 'separation': 89.8,
      'applying': true, 'tempo': 'slow',
      'exact_at': '2026-08-28T00:00:00+00:00',
    },
    'year': {
      'transit': 'moon', 'natal': 'saturn', 'aspect': 'sextile',
      'angle': 60, 'orb': 1.1, 'separation': 61.1,
      'applying': true, 'tempo': 'fast',
    },
    // Profeccion anual: sin esto la banda del anio no se pinta, que es
    // justamente lo que hace la app cuando no hay fecha de nacimiento.
    'profection': {
      'age': 35, 'house': 5, 'sign': 'capricorn', 'sign_es': 'Capricornio',
      'lord': 'saturn', 'points_in_sign': ['saturn'],
    },
    'sect': 'day',
    'total_aspects': 9,
  };

  @override
  Future<Map<String, dynamic>> horoscope() async => {
    'date': '2026-08-24',
    'text': 'Saturno cierra un cuadrado con tu Sol: figura de tension entre '
        'cuerpos que se miran de frente. En la hora del Sol se trabajaba el oro.',
    'primary': {
      'transit': 'saturn', 'natal': 'sun', 'aspect': 'square',
      'orb': 0.2, 'applying': true,
      'exact_at': '2026-08-28T00:00:00+00:00',
    },
    'supporting': const [],
    'total_aspects': 9,
  };

  @override
  Future<Map<String, dynamic>> agenda({int days = 7}) async => {
    'from': '2026-08-24', 'to': '2026-08-31', 'days': days, 'max_days': 30,
    'background': {
      'transit': 'jupiter', 'natal': 'north_node', 'aspect': 'opposition',
    },
    'events': [
      {'kind': 'aspect_exact', 'date': '2026-08-25', 'transit': 'mercury',
       'natal': 'sun', 'aspect': 'square'},
      {'kind': 'house_ingress', 'date': '2026-08-27', 'transit': 'mars',
       'from_house': 6, 'to_house': 7},
      {'kind': 'aspect_exact', 'date': '2026-08-29', 'transit': 'venus',
       'natal': 'ascendant', 'aspect': 'trine'},
      {'kind': 'profection_change', 'date': '2026-08-30', 'age': 37,
       'house': 6, 'lord': 'mercury', 'from_lord': 'venus'},
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> horoscopeHistory({int limit = 30}) async => [
    {
      'date': '2026-08-23',
      'text': 'Marte entró en tu casa 7 y el trato de ayer pide una respuesta.',
      'sky': {
        'today': {'transit': 'mars', 'natal': 'venus', 'aspect': 'square'},
        'profection': {'house': 5, 'lord': 'saturn'},
      },
    },
    // Una de las primeras: su cielo no traia carriles ni profeccion.
    {
      'date': '2026-08-01',
      'text': 'De cuando el motor sabia menos y el texto era mas corto.',
      'sky': <String, dynamic>{},
    },
  ];

  @override
  Future<Map<String, dynamic>> celestialOverview() async => {
    'natal_chart': {
      'chart_data': {
        'planets': [
          {'name': 'sun', 'longitude': 85.0},
          {'name': 'moon', 'longitude': 162.0},
          {'name': 'venus', 'longitude': 121.0},
          {'name': 'saturn', 'longitude': 175.0},
        ],
        'ascendant': {'longitude': 0.0},
        'midheaven': {'longitude': 90.0},
      },
    },
    'transits': {
      'transiting': [
        {'name': 'saturn', 'longitude': 355.0},
        {'name': 'moon', 'longitude': 210.0},
        {'name': 'jupiter', 'longitude': 42.0},
      ],
      'aspects_to_natal': [
        {'transit': 'saturn', 'natal': 'sun', 'aspect': 'square',
         'angle': 90, 'separation': 89.8},
        {'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
         'angle': 120, 'separation': 119.34},
        {'transit': 'jupiter', 'natal': 'venus', 'aspect': 'sextile',
         'angle': 60, 'separation': 60.4},
      ],
    },
  };
}

/// Un telefono de referencia, no la ventana del que corre el test: si el ancho
/// cambia entre capturas, comparar dos retratos no dice nada.
///
/// 360x640 a x3 da 1080x1920 clavado, y eso NO es casualidad. Play exige que el
/// lado mayor de una captura no pase del DOBLE del menor, y el formato de movil
/// moderno (390x844) lo incumple: 844 pasa de 780. Ademas 1080x1920 es el minimo
/// para entrar en las secciones destacadas de la ficha.
const _telefono = Size(360, 640);
const _escala = 3.0;

Future<void> _montar(WidgetTester tester) async {
  tester.view
    ..physicalSize = _telefono * _escala
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_ApiDeMuestra()),
        authProvider.overrideWith(_AuthConLugar.new),
      ],
      child: MaterialApp(
        // Al retratar la RAIZ, el banner de DEBUG entra en la imagen. Retratando
        // solo la pantalla quedaba fuera del recorte y no se veia.
        debugShowCheckedModeBanner: false,
        theme: buildArcanumTheme(),
        home: const Scaffold(body: HoyScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Monta la APP ENTERA por el router, no una pantalla suelta.
///
/// Hace falta para retratar lo que solo existe en el shell: la barra de abajo y
/// el boton flotante del horoscopo. Montando `HoyScreen` a pelo, el boton no
/// sale en la foto porque no vive ahi -- vive en la carcasa, que es justo la
/// decision que hay que poder mirar.
Future<void> _montarApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = _telefono * _escala
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_ApiDeMuestra()),
      authProvider.overrideWith(_AuthConLugar.new),
    ],
  );
  addTearDown(contenedor.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildArcanumTheme(),
        routerConfig: contenedor.read(arcanumRouterProvider),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _retratar(WidgetTester tester, String nombre) async {
  // SIEMPRE la raiz, por dos razones. Un dialogo no vive dentro de la pantalla:
  // se monta en el overlay de la app, asi que retratando solo `HoyScreen` sale
  // la de detras y el dialogo no aparece -- que es lo que paso la primera vez.
  // Y ademas el golden de un hijo se captura en pixeles LOGICOS, ignorando el
  // devicePixelRatio: salian 360x640 en vez de 1080x1920, inservibles para Play.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('salida/$nombre.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });

  // Por captura, no una sola vez: el consentimiento se guarda en preferencias,
  // asi que tras la captura que lo acepta las siguientes ya no verian el
  // dialogo y el toque caeria en el vacio.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('01 arriba, con el sello cerrado', (tester) async {
    await _montar(tester);
    await _retratar(tester, '01-arriba');
  });

  testWidgets('02 el sello, al fondo de la pantalla', (tester) async {
    await _montar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await _retratar(tester, '02-sello-cerrado');
  });

  testWidgets('01b el instrumento y su selector', (tester) async {
    await _montar(tester);
    // -300 y no -420: con el instrumento entero en cuadro se ve el anillo, que
    // es justo lo que hay que revisar.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await _retratar(tester, '01b-instrumento-regente');

    // El mismo instrumento con la hora elegida: cambia el panel Y los chips.
    await tester.tap(find.byKey(const Key('hoy-selector-hour')));
    await tester.pumpAndSettle();
    await _retratar(tester, '01c-instrumento-hora');

    await tester.tap(find.byKey(const Key('hoy-selector-moon')));
    await tester.pumpAndSettle();
    await _retratar(tester, '01d-instrumento-luna');
  });

  testWidgets('03 el consentimiento, antes de gastar nada', (tester) async {
    await _montar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    // El boton puede quedar fuera del alto del telefono de referencia: sin
    // esto el toque cae en el vacio y la captura no llega a existir.
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await _retratar(tester, '03-consentimiento');
  });

  testWidgets('04 el sello abierto', (tester) async {
    await _montar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    // El boton puede quedar fuera del alto del telefono de referencia: sin
    // esto el toque cae en el vacio y la captura no llega a existir.
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Acepto'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await _retratar(tester, '04-sello-abierto');
  });

  testWidgets('04b el pliegue, a media apertura', (tester) async {
    // El gesto no se ve en un estado final: hay que parar la animacion a la
    // mitad. Con pumpAndSettle se salta entera y el pliegue seria invisible,
    // que es justo por lo que se dio por ausente la primera vez.
    await _montar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Acepto'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 260));
    await _retratar(tester, '04b-pliegue');
  });

  testWidgets('05 el texto, ya abierto', (tester) async {
    await _montar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Acepto'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    // Abrir alarga la tarjeta: la prosa y los otros aspectos quedan por debajo
    // del borde y hay que bajar para verlos.
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await _retratar(tester, '05-texto-abierto');
  });

  testWidgets('06 el boton del horoscopo, sobre Hoy', (tester) async {
    await _montarApp(tester);
    await _retratar(tester, '06-boton-horoscopo');
  });

  testWidgets('07 la pantalla del horoscopo, con el boton apagado', (
    tester,
  ) async {
    await _montarApp(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();
    await _retratar(tester, '07-horoscopo');
  });

  testWidgets('08 el historial, desplegado', (tester) async {
    await _montarApp(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();
    // El boton vive al final de la lista y `ListView` no construye lo que no
    // se ve: hay que bajar hasta el, no basta con `ensureVisible`.
    await tester.scrollUntilVisible(
      find.text('Ver días anteriores'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('DÍAS ANTERIORES'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await _retratar(tester, '08-historial');
  });

  testWidgets('09 la agenda de la semana', (tester) async {
    await _montarApp(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('LO QUE VIENE'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await _retratar(tester, '09-agenda');
  });

  testWidgets('10 la tarjeta que se comparte, tal cual se manda', (
    tester,
  ) async {
    // No es un golden: se guarda el PNG QUE DE VERDAD SALE de `pintarTarjeta`,
    // con su densidad y su tamano reales. Un golden del widget se capturaria
    // en pixeles logicos y ensenaria 360x450, que no es lo que recibe nadie.
    final clave = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildArcanumTheme(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: RepaintBoundary(
              key: clave,
              child: const TarjetaCompartir(
                aspecto: {
                  'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
                  'angle': 120, 'separation': 119.34,
                },
                profeccion: {
                  'age': 35, 'house': 5, 'sign_es': 'Capricornio',
                  'lord': 'saturn',
                },
                texto: 'Saturno cierra un cuadrado con tu Sol: figura de '
                    'tension entre cuerpos que se miran de frente. En la hora '
                    'del Sol se trabajaba el oro.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final png = await tester.runAsync(() => pintarTarjeta(clave));
    expect(png, isNotNull);
    File('test/capturas/salida/10-tarjeta-compartir.png')
        .writeAsBytesSync(png!);
  });

  testWidgets('99 diagnostico: que hay en pantalla', (tester) async {
    await _montar(tester);
    final textos = tester.widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d != null && d.trim().isNotEmpty)
        .toList();
    // ignore: avoid_print
    print('TEXTOS: ${textos.join(" | ")}');
  });
}
