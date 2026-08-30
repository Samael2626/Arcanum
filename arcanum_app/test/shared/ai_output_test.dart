/// Las tres obligaciones del cliente, comprobadas donde se ven.
///
/// No se testea "el widget existe": se testea que el aviso acompane al texto,
/// que se pueda reportar sin salir de la app, y que el consentimiento no se
/// pueda dar por omision. Eso ultimo es lo que separa consentir de no negarse.
library;

import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:arcanum_app/core/privacy/consent_policy.dart';
import 'package:arcanum_app/features/hoy/sky_today_state.dart';
import 'package:arcanum_app/shared/widgets/ai_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

/// Abre el dialogo de consentimiento y, si se indica, pulsa un boton.
/// Devuelve lo que `ensureGranted` respondio.
Future<bool?> _abrirDialogo(WidgetTester tester, {String? pulsar}) async {
  bool? resultado;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      // Sin API: el dialogo se prueba solo. Con el provider real, construir el
      // servicio arrastra Dio y el fallo se traga dentro del onPressed async,
      // dejando un test que dice "no aparece el texto" cuando lo que pasa es
      // que el dialogo nunca llego a abrirse.
      aiConsentServiceProvider.overrideWithValue(AiConsentService()),
    ],
    child: MaterialApp(home: Scaffold(body:
    Consumer(builder: (context, ref, _) {
      return TextButton(
        onPressed: () async => resultado = await ref
            .read(aiConsentServiceProvider)
            .ensureGranted(context, userId: 'usuario-1'),
        child: const Text('ir'),
      );
    }),
    ))));
  await tester.tap(find.text('ir'));
  await tester.pumpAndSettle();
  if (pulsar != null) {
    await tester.tap(find.text(pulsar));
    await tester.pumpAndSettle();
  }
  return resultado;
}

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
    // Se prueba contra AiConsentService, que es la unica implementacion que
    // queda. Hubo otra que guardaba en SharedPreferences y nada mas; se retiro
    // el 30-ago-2026 porque una preferencia local no es prueba de la
    // autorizacion, y en Colombia hay que poder demostrarla.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const usuario = 'usuario-1';

    test('empieza pendiente', () async {
      expect(await AiConsentService().status(usuario), AiConsentStatus.unknown);
    });

    test('vuelve a preguntar si sube la version del texto', () async {
      // Un consentimiento vale para lo que la persona leyo, no para siempre:
      // la clave local lleva la version dentro.
      SharedPreferences.setMockInitialValues({
        'groq_ai_consent_una-version-vieja_$usuario': true,
      });
      expect(await AiConsentService().status(usuario), AiConsentStatus.unknown);
    });

    test('una vez concedido, no se vuelve a preguntar', () async {
      SharedPreferences.setMockInitialValues({
        'groq_ai_consent_${aiConsentPolicyVersion}_$usuario': true,
      });
      expect(await AiConsentService().status(usuario), AiConsentStatus.granted);
    });

    test('negarse queda registrado como negativa, no como pendiente', () async {
      SharedPreferences.setMockInitialValues({
        'groq_ai_consent_${aiConsentPolicyVersion}_$usuario': false,
      });
      expect(await AiConsentService().status(usuario), AiConsentStatus.declined);
    });

    test('cada usuario tiene el suyo', () async {
      SharedPreferences.setMockInitialValues({
        'groq_ai_consent_${aiConsentPolicyVersion}_$usuario': true,
      });
      expect(await AiConsentService().status('otro'), AiConsentStatus.unknown);
    });

    testWidgets('nombra al proveedor REAL y su pais', (tester) async {
      await _abrirDialogo(tester);

      // Nombrar a Anthropic aqui seria decirle a la persona que sus datos van
      // a una empresa a la que no van. El proveedor es Groq.
      expect(find.textContaining(kAiProvider), findsWidgets);
      expect(find.textContaining(kAiProviderCountry), findsWidgets);
      expect(find.textContaining('Anthropic'), findsNothing);
    });

    testWidgets('dice lo que SI sale y lo que NO', (tester) async {
      await _abrirDialogo(tester);

      // `oracle_context.py:118` manda display_name. Callarlo seria dejar que
      // alguien escriba su nombre real creyendo que no sale de aqui.
      expect(find.textContaining('nombre visible'), findsWidgets);
      expect(find.textContaining('grimorio'), findsWidgets);
    });

    testWidgets('avisa de que no esta obligado', (tester) async {
      await _abrirDialogo(tester);

      // Deber de informacion del art. 6 de la Ley 1581 de 2012: hay que
      // decirle que puede negarse, no solo dejarle negarse.
      expect(find.textContaining('No estás obligado'), findsOneWidget);
    });

    testWidgets('no se puede aceptar por omision', (tester) async {
      await _abrirDialogo(tester);

      // Cerrar tocando fuera daria un consentimiento que nadie leyo.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Acepto'), findsOneWidget);
    });

    testWidgets('decir "Ahora no" devuelve false', (tester) async {
      final resultado = await _abrirDialogo(tester, pulsar: 'Ahora no');
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
