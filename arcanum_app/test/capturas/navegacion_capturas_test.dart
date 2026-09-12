@Tags(['capturas'])
library;

/// Retrata la NAVEGACIÓN: la barra de abajo y la cabecera de Consultar.
///
/// Escrito para poder correrlo tal cual en dos sitios -- la rama del rediseño y
/// `main` -- y comparar las fotos. Por eso solo toca API pública (el router, el
/// tema, los providers) y no nombra nada que exista únicamente en una de las
/// dos: si mencionara `Interprete`, no compilaría en `main` y no habría "antes".
///
///     flutter test test/capturas/navegacion_capturas_test.dart \
///       --update-goldens --run-skipped
import 'dart:io';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _telefono = Size(360, 800);
const _escala = 3.0;

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
  final manifiesto = <String, List<String>>{
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
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

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'display_name': 'Samuel',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

class _Api extends ArcanumApi {
  _Api() : super(Dio());

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
    'date': '2026-09-11',
    'day_ruler': 'sun',
    'today': {
      'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
      'angle': 120, 'orb': 0.66, 'separation': 119.34, 'applying': true,
    },
    'chapter': null, 'year': null, 'ingress': null,
    'profection': {
      'age': 35, 'house': 5, 'sign': 'capricorn', 'sign_es': 'Capricornio',
      'lord': 'saturn', 'points_in_sign': ['saturn'],
    },
    'sect': 'day', 'total_aspects': 3,
  };

  @override
  Future<Map<String, dynamic>> celestialOverview() async => {};

  /// El Grimorio pide su lista al construirse. Sin doblarla, la llamada se va
  /// al Dio real y el test muere con un temporizador pendiente.
  @override
  Future<List<Map<String, dynamic>>> grimoireList() async => [];
}

Future<void> _montar(WidgetTester tester) async {
  tester.view
    ..physicalSize = _telefono * _escala
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_Api()),
      authProvider.overrideWith(_Auth.new),
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

Future<void> _retratar(WidgetTester tester, String nombre) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('n1 la barra de abajo, desde Hoy', (tester) async {
    await _montar(tester);
    await _retratar(tester, 'nav-1-barra');
  });

  testWidgets('n3 la cara Tu carta, del mismo Cielo', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Tu carta'));
    await tester.pump(const Duration(milliseconds: 400));
    await _retratar(tester, 'nav-3-cielo-carta');
  });

  testWidgets('n2 la cabecera de Consultar, en el Oráculo', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Oráculo'));
    await tester.pumpAndSettle();
    await _retratar(tester, 'nav-2-oraculo-consultar');
  });

  testWidgets('n4 el Grimorio, con su frase nueva', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Grimorio'));
    await tester.pump(const Duration(milliseconds: 400));
    await _retratar(tester, 'nav-4-grimorio');
  });
}
