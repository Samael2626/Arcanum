import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/cielos/cielos_screen.dart';
import 'package:arcanum_app/features/cielos/widgets/natal_wheel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'user-a'});
}

class _CielosApi extends ArcanumApi {
  _CielosApi() : super(Dio());

  var overviewCalls = 0;
  var natalCalls = 0;

  @override
  Future<Map<String, dynamic>> celestialOverview() async {
    overviewCalls++;
    const signs = [
      'aries',
      'taurus',
      'gemini',
      'cancer',
      'leo',
      'virgo',
      'libra',
      'scorpio',
      'sagittarius',
      'capricorn',
      'aquarius',
      'pisces',
    ];
    return {
      'natal_chart': {
        'chart_data': {
          'ascendant': {'longitude': 0.0, 'sign': 'aries'},
          'midheaven': {'longitude': 90.0, 'sign': 'cancer'},
          'houses': [
            for (var i = 0; i < 12; i++)
              {'house': i + 1, 'longitude': i * 30.0, 'sign': signs[i]},
          ],
          'planets': const [
            {
              'name': 'sun',
              'longitude': 12.0,
              'sign': 'aries',
              'degree_in_sign': 12.0,
              'house': 1,
              'retrograde': false,
            },
            {
              'name': 'moon',
              'longitude': 76.0,
              'sign': 'gemini',
              'degree_in_sign': 16.0,
              'house': 3,
              'retrograde': false,
            },
          ],
          'aspects': const [],
        },
      },
      'transits': {'aspects_to_natal': <Map<String, dynamic>>[]},
    };
  }

  @override
  Future<Map<String, dynamic>> natalChart() async {
    natalCalls++;
    return const {};
  }
}

void main() {
  testWidgets('Cielos usa overview cacheado y la rueda queda en reposo', (
    tester,
  ) async {
    final api = _CielosApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: CielosScreen())),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 10),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );

    expect(api.overviewCalls, 1);
    expect(api.natalCalls, 0);
    expect(find.byType(NatalWheel), findsOneWidget);
    // El subtítulo "Tu carta natal" migró a la barra superior del shell; la
    // pantalla en sí conserva la etiqueta de su rueda.
    expect(find.text('TU RUEDA NATAL'), findsOneWidget);
  });
}
