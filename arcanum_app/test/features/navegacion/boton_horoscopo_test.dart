// El boton flotante del horoscopo: que este en las cinco pantallas, que lleve
// a la suya, y que ahi dentro se apague sin desaparecer.
//
// Se monta la app ENTERA por el router y no una pantalla suelta, porque lo que
// se prueba es justo lo que vive en la carcasa: un test que montara
// `HoroscopoScreen` a pelo pasaria aunque el boton no existiera.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/horoscopo/horoscopo_screen.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  // 411x915 logicos, un telefono normal de hoy. NO 360x640 como el capturador:
  // a ese ancho, el boton de "tu siguiente paso" de Hoy se desborda 26 px con
  // una etiqueta larga -- un fallo suyo, anterior a esto, que no toca arreglar
  // aqui pero que haria fallar este test por algo que no es lo que prueba.
  tester.view
    ..physicalSize = const Size(1233, 2745)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_ApiMuda()),
        authProvider.overrideWith(_AuthDePrueba.new),
      ],
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: appRouter,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NavigationBar _barra(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // `appRouter` es un singleton de la app: sin esto, el test que navega al
    // horoscopo deja al siguiente empezando ya dentro. Lo cazo la suite: solos
    // pasaban y juntos no.
    appRouter.go('/hoy');
  });

  testWidgets('el boton esta sobre Hoy, sin ser una pestaña', (tester) async {
    await _montar(tester);
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsWidgets);
    expect(find.byTooltip('Horóscopo'), findsOneWidget);
    // La barra sigue teniendo CINCO destinos: esto no añade una sexta.
    expect(_barra(tester).destinations.length, 5);
  });

  testWidgets('lleva a la pantalla del horoscopo', (tester) async {
    await _montar(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();
    expect(find.byType(HoroscopoScreen), findsOneWidget);
  });

  testWidgets('dentro, el boton sigue ahi pero ya no hace nada', (
    tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();

    // No desaparece: si se escondiera, el sitio al que se vuelve dejaria de
    // estar donde estaba.
    final fab = tester.widget<FloatingActionButton>(
      find.byWidgetPredicate(
        (w) => w is FloatingActionButton && w.heroTag == 'fab-horoscopo',
      ),
    );
    expect(fab.onPressed, isNull);
    expect(find.byTooltip('Horóscopo'), findsNothing);

    // Y tocarlo no cambia nada.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is FloatingActionButton && w.heroTag == 'fab-horoscopo',
    ));
    await tester.pumpAndSettle();
    expect(find.byType(HoroscopoScreen), findsOneWidget);
  });

  testWidgets('ninguna pestaña se marca cuando estas en el horoscopo', (
    tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();

    // `NavigationBar` exige un indice valido y no admite "ninguno": se le da el
    // 0 y se apaga el indicador. Marcar "Hoy" sin estar en Hoy seria mentir.
    expect(_barra(tester).selectedIndex, 0);
    final tema = tester.widget<NavigationBarTheme>(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationBarTheme),
      ),
    );
    expect(tema.data.indicatorColor, Colors.transparent);
  });

  testWidgets('desde el horoscopo se vuelve por la barra', (tester) async {
    await _montar(tester);
    await tester.tap(find.byTooltip('Horóscopo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.byType(HoyScreen), findsOneWidget);
    expect(find.byType(HoroscopoScreen), findsNothing);
  });
}
