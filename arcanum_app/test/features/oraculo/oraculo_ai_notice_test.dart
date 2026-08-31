import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/oraculo/oraculo_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'test-user'});
}

class _OracleApi extends ArcanumApi {
  _OracleApi() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> tarotList({
    String? arcana,
    String? suit,
  }) async => const [];
}

void main() {
  testWidgets('muestra el aviso de IA al entrar al chat', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(_OracleApi()),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: OraculoScreen())),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Estás hablando con un modelo de IA. Sus respuestas son simbólicas y pueden contener errores.',
      ),
      findsOneWidget,
    );
  });
}
