/// Las tres obligaciones del cliente, comprobadas donde se ven.
///
/// No se testea "el widget existe": se testea que el aviso acompane al texto,
/// que se pueda reportar sin salir de la app, y que el consentimiento no se
/// pueda dar por omision. Eso ultimo es lo que separa consentir de no negarse.
import 'package:arcanum_app/core/consent/ai_consent.dart';
import 'package:arcanum_app/features/hoy/sky_today_state.dart';
import 'package:arcanum_app/shared/widgets/ai_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  setUp(resetDisclosureForTest);

  group('el aviso de IA', () {
    testWidgets('acompaña al texto, no vive solo en los Términos',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'Saturno cuadra tu Sol.', surface: 'oraculo'),
      ));

      expect(find.text('Saturno cuadra tu Sol.'), findsOneWidget);
      // El art. 50(5) del AI Act pide la informacion "at the latest at the time
      // of the first interaction": pegada, no en otra pantalla.
      expect(find.textContaining('inteligencia artificial'), findsOneWidget);
    });

    testWidgets('la segunda vez se reduce a una linea',
        (tester) async {
      // Primera exposicion: aviso largo. El art. 50(5) pide "at the latest at
      // the time of the first interaction", no bajo cada parrafo.
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'uno', surface: 'oraculo'),
      ));
      expect(find.textContaining('inteligencia artificial'), findsOneWidget);

      // Segunda: solo la linea de pie.
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'dos', surface: 'oraculo'),
      ));
      expect(find.textContaining('inteligencia artificial'), findsNothing);
      expect(find.text('Generado con IA'), findsOneWidget);
      expect(find.text('Reportar'), findsOneWidget);
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
      // Primera exposicion de la sesion: aviso largo.
      expect(find.textContaining('inteligencia artificial'), findsOneWidget);
    });
  });

  group('el botón de reportar', () {
    testWidgets('está presente y abre la hoja SIN salir de la app',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'texto reportable', surface: 'oraculo'),
      ));

      expect(find.text('Reportar'), findsOneWidget);
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Requisito literal de Google Play: "without needing to exit the app".
      expect(find.text('Reportar este texto'), findsOneWidget);
    });

    testWidgets('no deja enviar sin elegir un motivo', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'texto', surface: 'oraculo'),
      ));
      await tester.tap(find.text('Reportar'));
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
      await tester.tap(find.text('Reportar'));
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

  group('la puerta del consentimiento', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin permiso, el horóscopo es lectura local y no un error de red',
        () {
      // El horoscopo manda fecha, hora y lugar de nacimiento fuera. Antes se
      // llamaba en el inicializador del campo: los datos salian del telefono
      // antes de que nadie preguntase. Se detecto revisando, no en pruebas.
      const declinado = ConsentDeclined();
      final fallo = classifySkyFailure(declinado);

      expect(fallo, SkyTodayFailure.sinConsentimiento);
      // Los transitos se calculan en el dispositivo: la lectura local es
      // exactamente lo que esa persona SI autorizo.
      expect(allowsLocalReading(fallo), isTrue);
      // Y no se le manda a ninguna pantalla a "arreglarlo": no hay nada roto.
      expect(skyFailureRoute(fallo), isNull);
    });

    test('el mensaje no culpa a la conexión', () {
      final texto = skyFailureMessage(SkyTodayFailure.sinConsentimiento);
      expect(texto.toLowerCase(), isNot(contains('conexión')));
      expect(texto, contains('autorizaste'));
    });
  });

  group('los avisos de plantas, ya adelgazados', () {
    setUp(resetDisclosureForTest);

    test('una infusion corriente NO trae parrafo propio', () {
      // Samuel: "esta demasiado extenso y con muchas alertas". Un parrafo
      // entero para una manzanilla era ruido, y el ruido se deja de leer justo
      // cuando aparece el aviso que si importa.
      expect(toxicNoticeFor('Bebe una infusión de manzanilla.'), isNull);
      expect(mentionsCulinary('Bebe una infusión de manzanilla.'), isTrue);
    });

    test('un veneno real si trae aviso duro, y ese no se acorta', () {
      // Aqui el riesgo no es una multa: es una intoxicacion.
      for (final t in ['acónito', 'beleño', 'mandrágora', 'belladona',
                       'cicuta', 'estramonio', 'digital']) {
        expect(toxicNoticeFor('Usa $t en el rito.'), kToxicNotice,
            reason: '$t debería disparar el aviso duro');
      }
    });

    testWidgets('con planta corriente, el recordatorio de salud va al pie',
        (tester) async {
      // Google Play: "Apps must also remind users to consult a healthcare
      // professional". Cabe en el pie, no hace falta un bloque.
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'Bebe una infusión de tilo.', surface: 'oraculo'),
      ));
      expect(find.text(kHealthReminder), findsOneWidget);
      expect(find.text(kToxicNotice), findsNothing);
    });

    testWidgets('sin plantas, el pie es solo IA y Reportar', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(text: 'Saturno cuadra tu Sol.', surface: 'horoscopo'),
      ));
      expect(find.text(kHealthReminder), findsNothing);
      expect(find.text('Reportar'), findsOneWidget);
    });
  });

  group('falsos positivos de plantas, vistos en el telefono', () {
    setUp(resetDisclosureForTest);

    test('una palabra que CONTIENE el nombre de una planta no cuenta', () {
      // Vistos en la captura del OnePlus y alrededores: "estetica" contiene
      // "te", "alimenta" y "mentalidad" contienen "menta", "estilo" contiene
      // "tilo". El horoscopo real hablaba de "proyeccion estetica" y salia con
      // recordatorio de atencion medica al pie.
      for (final frase in [
        'una proyección armoniosa y estética en el entorno laboral',
        'la mentalidad con la que alimenta su rutina',
        'un estilo propio, sutil y sostenido',
        'también conviene observar el resultado',
      ]) {
        expect(mentionsCulinary(frase), isFalse, reason: frase);
        expect(toxicNoticeFor(frase), isNull, reason: frase);
      }
    });

    test('la planta nombrada de verdad si cuenta', () {
      expect(mentionsCulinary('Bebe una infusión de tilo al anochecer.'), isTrue);
      expect(mentionsCulinary('Un té sereno antes del rito.'), isTrue);
      expect(mentionsCulinary('Menta fresca sobre el altar.'), isTrue);
      expect(toxicNoticeFor('Coloca beleño sobre el altar.'), kToxicNotice);
    });

    testWidgets('un texto sin plantas no trae recordatorio de salud',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AiOutput(
          text: 'El regente del día, Venus, invita a una proyección estética.',
          surface: 'horoscopo',
        ),
      ));
      // Un aviso que salta cuando no toca ensena a ignorarlo, y entonces
      // tampoco se lee el dia que la planta es beleno de verdad.
      expect(find.text(kHealthReminder), findsNothing);
    });
  });
}
