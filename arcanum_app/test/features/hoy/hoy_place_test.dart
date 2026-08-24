import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que no sale a la red: guarda cada peticion y responde por ruta.
///
/// Se prueba a nivel de HTTP y no sustituyendo `ArcanumApi` a proposito: lo que
/// importa es la coordenada que VIAJA, y un fake de la clase la escondaria
/// detras de su propia firma.
class _AstralAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    switch (options.path) {
      case '/astral/today':
        return _json({
          'day_ruler': 'sun',
          'planetary_hour': {
            'planet': 'venus',
            'minutes_remaining': 38,
            'is_daytime': true,
            'hour_number': 4,
          },
          'moon': _moon,
        });
      case '/astral/moon':
        return _json(_moon);
      case '/astral/sky-today':
        return _json({
          'date': '2026-08-24',
          'day_ruler': 'sun',
          'today': null,
          'chapter': null,
        });
      default:
        // El horoscopo de SkyTodayCard no es lo que se mide aqui: falla y la
        // tarjeta muestra su propio estado de error, como en produccion.
        return _json({'detail': 'fuera de alcance'}, 404);
    }
  }

  static const _moon = {
    'illumination': 0.62,
    'is_waxing': true,
    'phase_name': 'Gibosa creciente',
    'age_days': 10.0,
  };

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> to(String path) =>
      requests.where((r) => r.path == path);
}

class _AuthWithPlace extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    // Tal como lo serializa `/users/me`: texto, no numero.
    'birth_lat': '40.416800',
    'birth_lon': '-3.703800',
    'birth_timezone': 'Europe/Madrid',
  });
}

class _AuthWithoutPlace extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'user-b'});
}

void main() {
  late _AstralAdapter adapter;
  late ArcanumApi api;

  setUp(() {
    adapter = _AstralAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    api = ArcanumApi(dio);
  });

  Future<void> pumpHoy(
    WidgetTester tester,
    AuthNotifier Function() auth,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(auth),
        ],
        child: const MaterialApp(home: Scaffold(body: HoyScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Hoy pide el cielo del lugar de la persona, no el de Bogotá', (
    tester,
  ) async {
    await pumpHoy(tester, _AuthWithPlace.new);

    final today = adapter.to('/astral/today');
    expect(today, hasLength(1), reason: 'con lugar confirmado se pide /today');
    expect(today.single.queryParameters['lat'], closeTo(40.4168, 1e-6));
    expect(today.single.queryParameters['lon'], closeTo(-3.7038, 1e-6));
  });

  testWidgets('sin lugar confirmado no hay regente ni hora, pero sí luna', (
    tester,
  ) async {
    await pumpHoy(tester, _AuthWithoutPlace.new);

    expect(
      adapter.to('/astral/today'),
      isEmpty,
      reason: 'sin coordenadas no se pide una hora planetaria de nadie',
    );
    expect(adapter.to('/astral/moon'), hasLength(1));
    // La luna es global: se calcula siempre.
    expect(find.text('Gibosa creciente'), findsOneWidget);
    // El regente y la hora se declaran ausentes, no se rellenan.
    expect(find.textContaining('Día de '), findsNothing);
    expect(find.text('No disponible sin tu lugar'), findsOneWidget);
  });
}
