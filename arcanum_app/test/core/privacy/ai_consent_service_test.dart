import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConsentApi extends ArcanumApi {
  _ConsentApi() : super(Dio());

  final recorded = <bool>[];

  @override
  Future<List<Map<String, dynamic>>> userConsents() async => const [];

  @override
  Future<Map<String, dynamic>> recordConsent({
    required String kind,
    required String policyVersion,
    required bool granted,
  }) async {
    recorded.add(granted);
    return {'kind': kind, 'policy_version': policyVersion, 'granted': granted};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rechazo bloquea IA y queda persistido', (tester) async {
    final api = _ConsentApi();
    final service = AiConsentService(api);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await service.ensureGranted(context, userId: 'user-a');
              },
              child: const Text('Consultar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    // El texto nombra a la empresa y su pais (Apple 5.1.2(i) y transferencia
    // internacional) y dice que puede negarse (Ley 1581 art. 6).
    expect(find.textContaining('Groq, Inc.'), findsOneWidget);
    expect(find.textContaining('Estados Unidos'), findsOneWidget);
    expect(find.textContaining('No enviaremos tu correo'), findsOneWidget);
    expect(find.textContaining('No estás obligado'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(api.recorded, [false]);
    expect(await service.status('user-a'), AiConsentStatus.declined);
  });

  testWidgets('aceptacion se puede revocar', (tester) async {
    final api = _ConsentApi();
    final service = AiConsentService(api);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => service.ensureGranted(context, userId: 'user-a'),
              child: const Text('Consultar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acepto'));
    await tester.pumpAndSettle();
    expect(await service.status('user-a'), AiConsentStatus.granted);
    expect(api.recorded, [true]);

    await service.revoke('user-a');
    expect(api.recorded, [true, false]);
    expect(await service.status('user-a'), AiConsentStatus.declined);
  });
}
