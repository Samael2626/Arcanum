import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/state/confirmed_place.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:arcanum_app/shared/widgets/arcanum_frame.dart';
import 'package:arcanum_app/shared/widgets/arcanum_motion.dart';
import 'package:arcanum_app/shared/widgets/arcanum_surface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TodayApi extends ArcanumApi {
  _TodayApi() : super(Dio());

  var calls = 0;
  final List<(double, double, String?)> places = [];

  @override
  Future<Map<String, dynamic>> umbral({String? tz}) async =>
      throw StateError('el bloque del Umbral no es el sujeto de este test');

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
    String? tz,
  }) async {
    calls++;
    places.add((lat, lon, tz));
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
          // Hoy ya no adivina donde esta la persona: sin lugar confirmado no
          // pide cielo. El test declara uno para poder ejercitar la pantalla.
          confirmedPlaceProvider.overrideWithValue(
            const ConfirmedPlace(
              lat: 6.25,
              lon: -75.56,
              timezone: 'America/Bogota',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HoyScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(api.calls, 1);
    expect(api.places.single, (6.25, -75.56, 'America/Bogota'));
    expect(find.text('Día de Sol'), findsOneWidget);
    expect(find.text('Venus'), findsOneWidget);
    expect(find.text('Gibosa creciente'), findsOneWidget);
    expect(find.byType(ArcanumTilt), findsNothing);
    expect(find.byType(ArcanumFrame), findsNothing);
    // Dos y solo dos: el cielo de fondo y la tarjeta de la Lectura del Umbral.
    // El resto de paneles de Hoy siguen siendo contenedores planos, que es lo
    // que este test vigila: que nadie meta atmosferas de mas en la pantalla
    // que se abre en cada arranque.
    expect(find.byType(ArcanumSurface), findsNWidgets(2));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}
