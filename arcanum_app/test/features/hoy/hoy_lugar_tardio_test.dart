import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que retrasa la luna a proposito.
///
/// El retraso ES la prueba: reproduce el orden real de llegada en un arranque
/// en frio, donde el perfil aparece ANTES de que la peticion hecha sin lugar
/// haya contestado.
class _LentaLaLunaAdapter implements HttpClientAdapter {
  /// La luna no contesta hasta que la prueba lo diga: asi la carrera es
  /// determinista y no depende del reloj.
  final Completer<void> lunaLista = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    switch (options.path) {
      case '/astral/moon':
        await lunaLista.future;
        return _json(_moon);
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
      default:
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
}

/// Empieza sin perfil, como el bootstrap de auth de verdad, y lo recibe luego.
class _AuthTardio extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, null);

  void llegaElPerfil() => state = const AuthState(AuthStatus.authenticated, {
    'id': 'user-c',
    'birth_lat': '40.416800',
    'birth_lon': '-3.703800',
  });
}

void main() {
  testWidgets(
    'Hoy se recupera cuando el lugar llega despues de pedir el cielo',
    (tester) async {
      final adapter = _LentaLaLunaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arcanumApiProvider.overrideWithValue(ArcanumApi(dio)),
            authProvider.overrideWith(_AuthTardio.new),
          ],
          child: const MaterialApp(home: Scaffold(body: HoyScreen())),
        ),
      );
      await tester.pump();

      // El perfil llega mientras la peticion sin lugar sigue en vuelo.
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(HoyScreen)),
      );
      (scope.read(authProvider.notifier) as _AuthTardio).llegaElPerfil();

      // Y solo DESPUES contesta la luna, que es lo que antes se quedaba
      // pintado para siempre.
      adapter.lunaLista.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.text('No disponible sin tu lugar'),
        findsNothing,
        reason: 'el lugar SI llego: la pantalla no puede seguir negandolo',
      );
      expect(find.textContaining('Día de'), findsOneWidget);
    },
  );
}
