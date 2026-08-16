import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';
import 'package:arcanum_app/main.dart';

class _SilentArcanumApi extends ArcanumApi {
  _SilentArcanumApi() : super(Dio());

  final _pending = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
    String? tz,
  }) => _pending.future;

  @override
  Future<Map<String, dynamic>> umbral({String? tz}) => _pending.future;
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
  testWidgets('ARCANUM arranca en Hoy con su barra de sección', (tester) async {
    // ProviderScope vive en main(), no dentro de ArcanumApp: el harness debe
    // envolverlo o cualquier ConsumerWidget (HoyScreen) rompe al arrancar.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(_SilentArcanumApi()),
          tokenStorageProvider.overrideWithValue(_AnonTokenStorage()),
        ],
        child: const ArcanumApp(),
      ),
    );
    await tester.pump();

    // El rediseño sustituyó el wordmark por-pantalla por la barra superior de
    // sección: nombre místico + subtítulo llano. Al arrancar (/hoy) se ve su
    // subtítulo, que es único en la app.
    expect(
      find.text('El cielo de hoy y tu siguiente paso'),
      findsOneWidget,
    );
  });
}
