import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:arcanum_app/shared/widgets/arcanum_frame.dart';
import 'package:arcanum_app/shared/widgets/arcanum_motion.dart';
import 'package:arcanum_app/shared/widgets/arcanum_surface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  @override
  Future<Map<String, dynamic>> horoscope() async {
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
  testWidgets('Hoy evita animaciones y marcos costosos permanentes', (
    tester,
  ) async {
    final api = _TodayApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthWithPlace.new),
        ],
        child: const MaterialApp(home: Scaffold(body: HoyScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(api.calls, 1);
    expect(find.text('Día de Sol'), findsOneWidget);
    expect(find.text('Venus'), findsOneWidget);
    expect(find.text('Gibosa creciente'), findsOneWidget);
    expect(find.byType(ArcanumTilt), findsNothing);
    expect(find.byType(ArcanumFrame), findsNothing);
    expect(find.byType(ArcanumSurface), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}
