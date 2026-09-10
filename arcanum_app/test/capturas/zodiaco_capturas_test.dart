@Tags(['capturas'])
library;

import 'dart:io';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/zodiaco_laminas.g.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retrata la tarjeta de Hoy con la lamina de CADA signo, desde el Dart que
/// corre en el telefono.
///
///     flutter test test/capturas/zodiaco_capturas_test.dart \
///       --update-goldens --run-skipped
///
/// Por que existe: el encuadre y el delta del velo se decidieron sobre un
/// prototipo HTML, y un prototipo y la pantalla compilada se separan sin que
/// nadie lo note. Esto sale del widget de verdad, con su asset de verdad.
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

/// Publica para los otros medidores de esta carpeta.
Future<void> cargarFuentesParaMedir() => _cargarFuentes();

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

class _AuthConLugar extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

/// El mismo cielo para los doce: lo unico que cambia es el signo solar, que es
/// justo lo que se quiere comparar.
class _ApiDeUnSigno extends ArcanumApi {
  _ApiDeUnSigno(this.signoIngles) : super(Dio());

  final String signoIngles;

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-08-24',
    'day_ruler': 'sun',
    'sun_sign': signoIngles,
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
    'profection': {
      'age': 35, 'house': 5, 'sign': 'capricorn', 'sign_es': 'Capricornio',
      'lord': 'saturn', 'points_in_sign': ['saturn'],
    },
    'sect': 'day',
    'total_aspects': 9,
  };
}

const _telefono = Size(360, 640);
const _escala = 3.0;

/// Publica para que el medidor de geometria monte lo mismo.
Future<void> montarParaMedir(WidgetTester tester, String s) =>
    _montar(tester, s);

Future<void> _montar(WidgetTester tester, String signoIngles) async {
  tester.view
    ..physicalSize = _telefono * _escala
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_ApiDeUnSigno(signoIngles)),
        authProvider.overrideWith(_AuthConLugar.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildArcanumTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: SkyTodayCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();

  // Las laminas son JPEG y su decodificacion es asincrona: en un test, sin
  // `runAsync` el `Image.asset` nunca llega a resolverse y el retrato sale con
  // la tarjeta vacia -- que fue justo lo que paso la primera vez y parecia un
  // fallo del widget. Se precargan a mano y se vuelve a asentar.
  await tester.runAsync(() async {
    for (final elemento in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(elemento.image, tester.element(find.byType(Image)));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  signoDesdeIngles.forEach((ingles, signo) {
    testWidgets('lamina de ${signo.name}', (tester) async {
      await _montar(tester, ingles);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('salida/zodiaco-${signo.name}.png'),
      );
    });
  });
}
