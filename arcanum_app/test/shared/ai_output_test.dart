/// Las tres obligaciones del cliente, comprobadas donde se ven.
///
/// No se testea "el widget existe": se testea que el aviso acompane al texto,
/// que se pueda reportar sin salir de la app, y que el consentimiento no se
/// pueda dar por omision. Eso ultimo es lo que separa consentir de no negarse.
import 'package:arcanum_app/core/consent/ai_consent.dart';
import 'package:arcanum_app/shared/widgets/ai_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('el aviso de IA', () {
    testWidgets('acompaña al texto, no vive solo en los Términos',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'Saturno cuadra tu Sol.', surface: 'oraculo'),
      ));

      expect(find.text('Saturno cuadra tu Sol.'), findsOneWidget);
      // El art. 50(5) del AI Act pide la informacion "at the latest at the time
      // of the first interaction": pegada, no en otra pantalla.
      expect(find.textContaining('generado con IA'), findsOneWidget);
    });

    testWidgets('dice que no sustituye orientación profesional',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'x', surface: 'horoscopo'),
      ));
      final aviso = tester.widget<Text>(find.textContaining('generado con IA'));
      for (final dominio in ['médica', 'legal', 'financiera']) {
        expect(aviso.data, contains(dominio));
      }
    });

    testWidgets('respeta la presentación de cada pantalla', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(
          text: 'crudo',
          surface: 'oraculo',
          child: Text('presentado', key: Key('propio')),
        ),
      ));
      expect(find.byKey(const Key('propio')), findsOneWidget);
      expect(find.textContaining('generado con IA'), findsOneWidget);
    });
  });

  group('el botón de reportar', () {
    testWidgets('está presente y abre la hoja SIN salir de la app',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'texto reportable', surface: 'oraculo'),
      ));

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // Requisito literal de Google Play: "without needing to exit the app".
      expect(find.text('Reportar este texto'), findsOneWidget);
    });

    testWidgets('no deja enviar sin elegir un motivo', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'texto', surface: 'oraculo'),
      ));
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar reporte'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('ofrece un motivo para el consejo de salud', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'texto', surface: 'horoscopo'),
      ));
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Da consejo médico o de salud'), findsOneWidget);
    });
  });

  group('el consentimiento', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empieza pendiente', () async {
      expect(await AiConsent.isPending(), isTrue);
    });

    test('deja de estarlo al aceptar, y guarda cuándo', () async {
      await AiConsent.accept(sensitive: true);
      expect(await AiConsent.isPending(), isFalse);
      final estado = await AiConsent.current();
      expect(estado['version'], kConsentVersion);
      expect(estado['sensitive'], isTrue);
      expect(DateTime.tryParse(estado['at']! as String), isNotNull);
    });

    test('vuelve a preguntar si sube la versión del texto', () async {
      SharedPreferences.setMockInitialValues({
        'ai_consent_version': kConsentVersion - 1,
      });
      // Un consentimiento vale para lo que la persona leyo, no para siempre.
      expect(await AiConsent.isPending(), isTrue);
    });

    test('revocar lo devuelve a pendiente', () async {
      await AiConsent.accept(sensitive: true);
      await AiConsent.revoke();
      expect(await AiConsent.isPending(), isTrue);
    });

    testWidgets('nombra al proveedor REAL y su país', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return TextButton(
            onPressed: () => ensureAiConsent(context),
            child: const Text('ir'),
          );
        }),
      ));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      // Nombrar a Anthropic aqui seria decirle a la persona que sus datos van
      // a una empresa a la que no van. El proveedor es Groq.
      expect(find.textContaining('Groq, Inc.'), findsWidgets);
      expect(find.textContaining('Estados Unidos'), findsWidgets);
      expect(find.textContaining('Anthropic'), findsNothing);
    });

    testWidgets('ninguna casilla viene premarcada', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return TextButton(
            onPressed: () => ensureAiConsent(context),
            child: const Text('ir'),
          );
        }),
      ));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      // Marcar por defecto no es consentir: es la ausencia de una negativa.
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
      expect(find.byIcon(Icons.check_box), findsNothing);

      final aceptar = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Acepto'),
      );
      expect(aceptar.onPressed, isNull);
    });

    testWidgets('avisa de que no está obligado a dar el dato sensible',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return TextButton(
            onPressed: () => ensureAiConsent(context),
            child: const Text('ir'),
          );
        }),
      ));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      // Deber de informacion del art. 6 de la Ley 1581 de 2012.
      expect(find.textContaining('No estás obligado'), findsOneWidget);
    });

    testWidgets('cerrar sin aceptar devuelve false', (tester) async {
      bool? resultado;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return TextButton(
            onPressed: () async => resultado = await ensureAiConsent(context),
            child: const Text('ir'),
          );
        }),
      ));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(resultado, isFalse);
    });
  });
}
