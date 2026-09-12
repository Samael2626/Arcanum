// EL SELLO: que no se genere solo, que el consentimiento mande, y que al
// abrirlo el texto llegue con su retardo.
//
// Vivian en `hoy_screen_test` porque la tarjeta estaba en Hoy. Desde el
// 12-sep-2026 ya no: estaba montada TAMBIEN en la pestana Horoscopo, y eran
// dos instancias con estado propio -- abrir el sello en una dejaba la otra
// cerrada. Se quito de Hoy y la lectura vive donde tiene su pestana.
//
// Los tests se mudan enteros, sin relajarse: montan `SkyTodayCard` directa,
// que es la pieza que prueban, y no la pantalla que la contiene.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/level_three_aspects.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:arcanum_app/shared/widgets/ai_output.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hoy solo pide el cielo del lugar cuando hay lugar confirmado: sin esto la
/// pantalla se quedaría en la luna y no habría nada que medir.
class _AuthWithPlace extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

class _TodayApi extends ArcanumApi {
  _TodayApi() : super(Dio());

  var calls = 0;
  var horoscopeCalls = 0;
  final consentimientos = <bool>[];

  /// El consentimiento se persiste en el SERVIDOR, no solo en el dispositivo.
  ///
  /// Sin este doble, la llamada saldria por el Dio real, fallaria, y
  /// `ensureGranted` devolveria false aun habiendo pulsado "Acepto": el
  /// servicio FALLA CERRADO a proposito — si no se puede dejar constancia de la
  /// autorizacion, no se manda nada al proveedor de IA. Es lo correcto, y sin
  /// este override el test parecia decir que aceptar no abre el sello.
  @override
  Future<Map<String, dynamic>> recordConsent({
    required String kind,
    required String policyVersion,
    required bool granted,
  }) async {
    consentimientos.add(granted);
    return {'kind': kind, 'policy_version': policyVersion, 'granted': granted};
  }

  var skyCalls = 0;
  var celestialOverviewCalls = 0;

  /// El cielo sin interpretar: gratis y sin terceros. La tarjeta lo pide al
  /// construirse, asi que el falso API tiene que responderlo o queda un
  /// temporizador colgando cuando la llamada se va a la implementacion real.
  @override
  Future<Map<String, dynamic>> skyToday() async {
    skyCalls++;
    return {
      'date': '2026-08-16',
      'day_ruler': 'sun',
      'today': {
        'transit': 'moon',
        'natal': 'midheaven',
        'aspect': 'trine',
        'angle': 120,
        'orb': 0.66,
        'separation': 119.34,
        'applying': true,
        'tempo': 'fast',
      },
      'chapter': null,
      'sect': 'day',
      'total_aspects': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> horoscope({DateTime? day}) async {
    horoscopeCalls++;
    return {
      'date': '2026-08-16',
      'text': 'Saturno aprieta sobre tu Sol natal.',
      'primary': {
        'transit': 'saturn',
        'natal': 'sun',
        'aspect': 'square',
        'orb': 0.2,
        'applying': true,
        'exact_at': '2026-08-20T00:00:00+00:00',
      },
      'supporting': const [],
      'total_aspects': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> celestialOverview() async {
    celestialOverviewCalls++;
    return {
      'natal_chart': {
        'chart_data': {
          'planets': [
            {'name': 'moon', 'longitude': 162.0},
            {'name': 'sun', 'longitude': 85.0},
            {'name': 'venus', 'longitude': 121.0},
          ],
          'ascendant': {'longitude': 0.0},
          'midheaven': {'longitude': 90.0},
        },
      },
      'transits': {
        'transiting': [
          {'name': 'uranus', 'longitude': 42.0},
          {'name': 'neptune', 'longitude': 355.0},
          {'name': 'pluto', 'longitude': 301.0},
        ],
        'aspects_to_natal': [
          {
            'transit': 'uranus',
            'natal': 'moon',
            'aspect': 'trine',
            'angle': 120,
            'separation': 120.0,
          },
          {
            'transit': 'neptune',
            'natal': 'sun',
            'aspect': 'square',
            'angle': 90,
            'separation': 90.0,
          },
          {
            'transit': 'pluto',
            'natal': 'venus',
            'aspect': 'opposition',
            'angle': 180,
            'separation': 180.0,
          },
        ],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) async {
    calls++;
    return {
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
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('abrir la app NO genera el horoscopo', (tester) async {
    // El motivo de toda la pieza del sello. Antes, montar la tarjeta llamaba a
    // `/horoscope`: se generaba el texto de todo el mundo lo leyera o no, se
    // quemaba su cupo del dia —que la idempotencia congela— y el primer
    // contacto con ARCANUM era un dialogo de consentimiento.
    final api = _TodayApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthWithPlace.new),
        ],
        // En un `ListView`, que es como la monta la pantalla del horoscopo:
        // los tests arrastran por el scrollable para llegar al sello.
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [SkyTodayCard()]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(api.skyCalls, 1, reason: 'el cielo gratis si se pide');
    expect(api.horoscopeCalls, 0, reason: 'la interpretacion NO se pide sola');
  });

  testWidgets('el sello muestra el transito sin haber generado nada', (
    tester,
  ) async {
    final api = _TodayApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthWithPlace.new),
        ],
        // En un `ListView`, que es como la monta la pantalla del horoscopo:
        // los tests arrastran por el scrollable para llegar al sello.
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [SkyTodayCard()]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Lo que se ve antes de tocar: el transito real y la invitacion.
    expect(find.text('Luna trígono Medio Cielo'), findsOneWidget);
    expect(find.textContaining('119,3'), findsOneWidget);
    expect(find.text('Abrir el sello del Sol'), findsOneWidget);
    expect(api.horoscopeCalls, 0);
  });

  testWidgets('rechazar consentimiento mantiene el sello cerrado', (
    tester,
  ) async {
    final api = _TodayApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthWithPlace.new),
        ],
        // En un `ListView`, que es como la monta la pantalla del horoscopo:
        // los tests arrastran por el scrollable para llegar al sello.
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [SkyTodayCard()]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir el sello del Sol'), findsOneWidget);
    expect(api.horoscopeCalls, 0);
    expect(api.celestialOverviewCalls, 0);
  });

  testWidgets('aceptar abre una vez y retrasa el texto 400 ms', (tester) async {
    final api = _TodayApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthWithPlace.new),
        ],
        // En un `ListView`, que es como la monta la pantalla del horoscopo:
        // los tests arrastran por el scrollable para llegar al sello.
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [SkyTodayCard()]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir el sello del Sol'));
    await tester.pumpAndSettle();

    // Ya no hay dos casillas en este dialogo: el consentimiento de datos
    // sensibles se pide en su propio paso del onboarding
    // (features/onboarding/.../sensitive_data_consent_step.dart) y con su
    // propia version de politica. Dos permisos distintos, dos momentos.
    await tester.tap(find.widgetWithText(FilledButton, 'Acepto'));
    // Aceptar dispara dos asincronias antes de pedir el horoscopo: registrar el
    // consentimiento en el servidor y guardar la copia local.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(api.consentimientos, [true]);
    expect(api.horoscopeCalls, 1);
    expect(find.text('Saturno aprieta sobre tu Sol natal.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('Saturno aprieta sobre tu Sol natal.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('Abrir el sello del Sol'), findsNothing);
    // Acotado a la lectura VISIBLE: el mismo texto vive tambien en la tarjeta
    // que se comparte, montada fuera de pantalla para poder capturarla.
    expect(
      find.descendant(
        of: find.byType(AiOutput),
        matching: find.text('Saturno aprieta sobre tu Sol natal.'),
      ),
      findsOneWidget,
    );
    final routeTarget = find.ancestor(
      of: find.text('trígono'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(routeTarget).height, greaterThanOrEqualTo(48));
    expect(api.horoscopeCalls, 1);
    expect(api.celestialOverviewCalls, 1);
    expect(await AiConsentService().status('user-a'), AiConsentStatus.granted);
    // Los otros aspectos ya no salen desplegados: tapaban la pantalla entera.
    // Se piden, y a partir de ahi todo lo de abajo sigue igual.
    expect(find.byType(AspectWheel), findsNothing);
    await tester.tap(find.text('VER TODOS LOS ASPECTOS (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Urano trígono Luna'), findsOneWidget);
    expect(find.text('Neptuno cuadratura Sol'), findsOneWidget);
    expect(find.text('Plutón oposición Venus'), findsOneWidget);
    expect(find.byType(AspectWheel), findsNWidgets(3));
    expect(aspectBodyHaloScale, 1.5);

    final firstTarget = find.byKey(const Key('hoy-aspect-target-0'));
    expect(tester.getSize(firstTarget).shortestSide, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(find.byKey(const Key('hoy-aspect-wheel-0'))),
      tester.getCenter(find.byKey(const Key('hoy-aspect-glyph-0'))),
    );

    await tester.ensureVisible(firstTarget);
    await tester.pumpAndSettle();
    await tester.tap(firstTarget);
    await tester.pumpAndSettle();
    expect(find.text('Tránsito 42,0° · natal 162,0°'), findsOneWidget);
  });
}
