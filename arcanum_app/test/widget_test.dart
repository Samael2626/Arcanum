import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';
import 'package:arcanum_app/features/auth/login_screen.dart';
import 'package:arcanum_app/main.dart';

class _SilentArcanumApi extends ArcanumApi {
  _SilentArcanumApi() : super(Dio());

  final _sky = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) => _sky.future;

  /// Sin sesión no hay lugar confirmado, así que Hoy pide la luna y no /today.
  @override
  Future<Map<String, dynamic>> moon() => _sky.future;
}

/// El avatar de la barra superior lee `authProvider` al arrancar, que sin
/// override tocaría el secure storage real (MissingPluginException en tests).
/// Este fake resuelve a "sin sesión" sin tocar la plataforma.
class _AnonTokenStorage extends TokenStorage {
  @override
  Future<String?> get access async => null;
  @override
  Future<Map<String, dynamic>?> get profile async => null;
}

void main() {
  testWidgets('sin sesión, ARCANUM arranca en el login', (tester) async {
    // ESTE TEST FIJABA EL FALLO. Antes decía "ARCANUM arranca en Hoy con su
    // barra de sección" y pasaba: la app arrancaba en /hoy sin sesión, que es
    // exactamente lo que bloqueó la prueba cerrada -- un tester recién
    // instalado veía la luna y ninguna forma de entrar. Lo que era la
    // afirmación es ahora la regresión que hay que impedir.
    //
    // ProviderScope vive en main(), no dentro de ArcanumApp: el harness debe
    // envolverlo o cualquier ConsumerWidget rompe al arrancar.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(_SilentArcanumApi()),
          tokenStorageProvider.overrideWithValue(_AnonTokenStorage()),
        ],
        child: const ArcanumApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('El cielo de hoy y tu siguiente paso'), findsNothing);
  });
}
