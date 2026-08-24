import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rechazo bloquea IA y queda persistido', (tester) async {
    final service = AiConsentService();
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
    expect(find.textContaining('Groq recibirá tu consulta'), findsOneWidget);
    expect(find.textContaining('No enviaremos tu correo'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(await service.status('user-a'), AiConsentStatus.declined);
  });

  testWidgets('aceptacion se puede revocar', (tester) async {
    final service = AiConsentService();

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

    await service.revoke('user-a');
    expect(await service.status('user-a'), AiConsentStatus.declined);
  });
}
