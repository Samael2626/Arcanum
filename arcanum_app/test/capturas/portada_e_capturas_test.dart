@Tags(['capturas'])
library;

import 'dart:io';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/reliquary_fx.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retrata la portada «Atlas de reliquias» por el router entero, con las
/// fuentes reales, para compararla con el prototipo E. Capturador manual:
///
///     flutter test test/capturas/portada_e_capturas_test.dart \
///       --update-goldens --run-skipped
Future<void> _cargarFuentes() async {
  final manifiesto = {
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
  };
  for (final ruta in [
    r'D:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    r'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]) {
    if (File(ruta).existsSync()) {
      manifiesto['MaterialIcons'] = [ruta];
      break;
    }
  }
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

/// Martes y hora de Marte de noche, Luna creciente: el estado del prototipo.
class _Api extends ArcanumApi {
  _Api() : super(Dio());

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) async => {
    'day_ruler': 'mars',
    'planetary_hour': {
      'planet': 'mars',
      'minutes_remaining': 41,
      'is_daytime': false,
      'hour_number': 1,
    },
    'moon': {
      'illumination': 0.38,
      'is_waxing': true,
      'phase_name': 'Creciente',
      'age_days': 6.0,
    },
  };

  @override
  Future<List<Map<String, dynamic>>> tarotReadings({int limit = 20}) async => [
    {
      'spread_type': 'three_card',
      'cards_drawn': [
        {'slug': 'el-sol', 'position': 'Pasado', 'reversed': false},
      ],
    },
  ];
}

Future<void> _retratar(
  WidgetTester tester,
  String nombre, {
  double ancho = 390,
  double alto = 844,
  double letra = 1,
  double scroll = 0,
  double back = 0,
}) async {
  tester.view
    ..physicalSize = Size(ancho, alto) * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  // flutter_test pinta las sombras como bloques solidos: aqui se quieren las
  // de verdad, que son parte del material
  debugDisableShadows = false;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_Api()),
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    for (final e in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(e.image, tester.element(find.byType(Image).first));
    }
  });
  if (scroll != 0) {
    await tester.drag(find.byType(ListView).first, Offset(0, -scroll));
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (back != 0) {
    // subir un poco: la cabecera flotante vuelve
    await tester.drag(find.byType(ListView).first, Offset(0, back));
    await tester.pump(const Duration(milliseconds: 300));
  }
  // en mitad del destello del canto (7 s, del 18 al 35 %)
  await tester.pump(const Duration(milliseconds: 1600));
  expect(tester.takeException(), isNull, reason: 'algo se desbordo');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('salida/$nombre.png'),
  );
  // se restaura antes de que el binding compruebe sus invariantes
  debugDisableShadows = true;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
    // el retrato es «Con vida»: la suite lo apaga por defecto
    ReliquaryClock.ambientMotion = true;
  });
  // sin la invitacion del Sendero encima: se retrata la portada
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'sendero_offer_hidden_user-a': true,
    }),
  );

  testWidgets('portada E 390', (t) => _retratar(t, 'portada-e-390'));
  testWidgets(
    'portada E 390 abajo',
    (t) => _retratar(t, 'portada-e-390-abajo', scroll: 420),
  );
  testWidgets(
    'portada E 360',
    (t) => _retratar(t, 'portada-e-360', ancho: 360, alto: 760),
  );
  testWidgets(
    'portada E 360 letra grande',
    (t) =>
        _retratar(t, 'portada-e-360-letra', ancho: 360, alto: 760, letra: 1.6),
  );
  testWidgets(
    'portada E 360 letra grande abajo',
    (t) => _retratar(
      t,
      'portada-e-360-letra-abajo',
      ancho: 360,
      alto: 760,
      letra: 1.6,
      scroll: 1150,
    ),
  );
  testWidgets(
    'portada E 390 sube un poco',
    (t) => _retratar(t, 'portada-e-390-sube', scroll: 420, back: 60),
  );
}
