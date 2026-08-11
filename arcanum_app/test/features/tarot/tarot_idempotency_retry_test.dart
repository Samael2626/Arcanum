import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        AuthStatus.authenticated,
        {'id': 'test-user'},
      );
}

class _RetryingArcanumApi extends ArcanumApi {
  _RetryingArcanumApi() : super(Dio());

  final List<String?> idempotencyKeys = [];

  @override
  Future<Map<String, dynamic>> tarotDrawOne({
    String? question,
    String? idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    if (idempotencyKeys.length == 1) {
      throw StateError('offline');
    }
    return {'resolved': <Map<String, dynamic>>[]};
  }
}

void main() {
  testWidgets('retry reutiliza key y una accion nueva genera otra', (tester) async {
    final api = _RetryingArcanumApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: TarotScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final drawButton = find.text('Sacar una carta');
    expect(drawButton, findsOneWidget);

    await tester.tap(drawButton);
    await tester.pumpAndSettle();
    // El fallo se comunica sin filtrar el error tecnico: el usuario no ve
    // 'offline' ni 'StateError', solo el mensaje humano del mapeador.
    expect(find.text('La IA ritual no respondió. Intenta de nuevo.'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
    expect(drawButton, findsOneWidget);

    await tester.tap(drawButton);
    await tester.pumpAndSettle();
    expect(api.idempotencyKeys, hasLength(2));
    expect(api.idempotencyKeys.first, isNotNull);
    expect(api.idempotencyKeys[1], api.idempotencyKeys.first);

    await tester.tap(drawButton);
    await tester.pumpAndSettle();
    expect(api.idempotencyKeys, hasLength(3));
    expect(api.idempotencyKeys[2], isNot(api.idempotencyKeys.first));
  });
}