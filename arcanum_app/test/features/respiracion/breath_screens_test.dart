// Las dos pantallas del motor de respiracion: ajustes y practica con orbe.
// Incluye el movil mas pequeño (360 x 640), texto grande y movimiento reducido.
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/respiracion/application/breath_settings.dart';
import 'package:arcanum_app/features/respiracion/domain/breath_pattern.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_awake.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_cues.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_orb.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_practice_screen.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_setup_screen.dart';
import 'package:arcanum_app/features/respiracion/presentation/breath_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _small = Size(360, 640);

void _phone(WidgetTester tester, [Size size = _small]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Apunta las senales en vez de vibrar, y si la pantalla debe seguir
/// encendida en vez de pedirselo al sistema.
class _Recorder implements BreathCue, ScreenAwake {
  final phases = <BreathKind>[];
  var finished = 0;
  final awake = <bool>[];

  @override
  Future<void> keep(bool on) async => awake.add(on);

  @override
  Future<void> phase(BreathKind kind) async => phases.add(kind);

  @override
  Future<void> finish() async => finished++;
}

class _Preset extends BreathSettingsNotifier {
  _Preset(this.initial);
  final BreathSettings initial;

  @override
  BreathSettings build() => initial;
}

Future<_Recorder> _pumpApp(
  WidgetTester tester, {
  BreathSettings settings = const BreathSettings(),
  String start = '/respirar',
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  final rec = _Recorder();
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/respirar',
        builder: (c, s) => const BreathSetupScreen(),
        routes: [
          GoRoute(
            path: 'practica',
            builder: (c, s) => const BreathPracticeScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        breathSettingsProvider.overrideWith(() => _Preset(settings)),
        breathHapticCueProvider.overrideWithValue(rec),
        screenAwakeProvider.overrideWithValue(rec),
      ],
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: router,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  return rec;
}

Text _textOf(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(ValueKey(key)));

/// Sube hasta el patron, lo deja fuera de la barra y lo elige.
Future<void> _pick(WidgetTester t, String id) async {
  final f = find.byKey(ValueKey('breath_pattern_$id'));
  await t.scrollUntilVisible(f, -200);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

/// El total vive al final de una lista perezosa: hay que llegar a el.
Future<String?> _total(WidgetTester t) async {
  await t.scrollUntilVisible(find.byKey(const ValueKey('breath_total')), 200);
  return _textOf(t, 'breath_total').data;
}

void main() {
  group('ajustes', () {
    testWidgets('muestra los siete patrones y el total del elegido', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester);
      for (final p in breathPatterns) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('breath_pattern_${p.id}')),
          200,
        );
        expect(find.text(p.name), findsOneWidget);
      }
      // Regardie: 12 ciclos de 8 s
      expect(await _total(tester), '1 min 36 s');
    });

    testWidgets('la ficha «i» abre la fuente del patron', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      final bardon = breathPatternById('bardon');
      expect(find.text(bardon.source), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('breath_info_bardon')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('breath_info_bardon')));
      await tester.pump();
      expect(find.text(bardon.source), findsOneWidget);
      expect(find.bySemanticsLabel('Fuente de ${bardon.name}'), findsOneWidget);
    });

    testWidgets('retenciones apagadas; al activarlas sale el aviso', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester);
      Finder sw() => find.byKey(const ValueKey('breath_retention'));
      // Regardie no retiene: interruptor desactivado
      await tester.scrollUntilVisible(sw(), 200);
      expect(tester.widget<SwitchListTile>(sw()).onChanged, isNull);
      expect(find.text('Este patrón no retiene el aire'), findsOneWidget);

      await _pick(tester, 'gd');
      await tester.scrollUntilVisible(sw(), 200);
      expect(tester.widget<SwitchListTile>(sw()).value, isFalse);
      expect(find.text(retentionWarning), findsNothing);
      // sin retencion, 8 ciclos de 1+4+1+4
      expect(await _total(tester), '1 min 20 s');

      await tester.scrollUntilVisible(sw(), -200);
      await tester.ensureVisible(sw());
      await tester.pump();
      await tester.tap(sw());
      await tester.pump();
      expect(find.text(retentionWarning), findsOneWidget);
      expect(await _total(tester), '2 min 8 s');
    });

    testWidgets('ciclos con tope y minutos en «Observar el aliento»', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester);
      final minus = find.byKey(const ValueKey('breath_amount_minus'));
      await tester.scrollUntilVisible(minus, 200);
      expect(_textOf(tester, 'breath_amount').data, '12');
      await tester.tap(minus);
      await tester.pump();
      expect(_textOf(tester, 'breath_amount').data, '11');

      await _pick(tester, 'observe');
      await tester.scrollUntilVisible(minus, 200);
      expect(_textOf(tester, 'breath_amount').data, '2');
      expect(find.text('Minutos'), findsOneWidget);
      expect(
        find.text('Sin cuenta: toca al cambiar el aliento'),
        findsOneWidget,
      );
      await tester.tap(minus);
      await tester.pump();
      expect(_textOf(tester, 'breath_amount').data, '1');
      expect(tester.widget<IconButton>(minus).onPressed, isNull);
    });

    testWidgets('movimiento reducido del sistema: marcado y bloqueado', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester, reduceMotion: true);
      final sw = find.byKey(const ValueKey('breath_reduced'));
      await tester.scrollUntilVisible(sw, 200);
      final w = tester.widget<SwitchListTile>(sw);
      expect(w.value, isTrue);
      expect(w.onChanged, isNull);
      expect(find.text('Activado por tu sistema'), findsOneWidget);
    });

    testWidgets('360x640 con texto grande no desborda', (tester) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(patternId: 'nadi', retention: true),
        textScale: 2,
      );
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 40; i++) {
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('breath_start')), findsOneWidget);
    });

    testWidgets('los objetivos tactiles miden al menos 48 dp', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('Empezar abre la practica', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      final start = find.byKey(const ValueKey('breath_start'));
      await tester.scrollUntilVisible(start, 300);
      await tester.tap(start);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BreathPracticeScreen), findsOneWidget);
      // sale enseguida para que el Ticker no deje pumpAndSettle colgado
      await tester.tap(find.byTooltip('Salir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BreathSetupScreen), findsOneWidget);
    });
  });

  group('practica', () {
    const regardie = BreathSettings(amount: 2);

    String phaseName(WidgetTester t) => t
        .widget<Semantics>(find.byKey(const ValueKey('breath_phase')))
        .properties
        .label!;

    testWidgets('recorre fases, cuenta, ciclo y restante', (tester) async {
      _phone(tester);
      await _pumpApp(tester, settings: regardie, start: '/respirar/practica');
      expect(find.text('Inhala'), findsOneWidget);
      expect(_textOf(tester, 'breath_count').data, '1');
      expect(find.text('Ciclo 1 de 2'), findsOneWidget);
      expect(_textOf(tester, 'breath_left').data, '0:16');
      expect(find.byKey(const ValueKey('breath_orb')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2500));
      expect(_textOf(tester, 'breath_count').data, '3');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Exhala'), findsOneWidget);
      expect(find.text('despacio'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Ciclo 2 de 2'), findsOneWidget);
      expect(_textOf(tester, 'breath_left').data, '0:08');
    });

    testWidgets('la fase vive en una region viva para el lector', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester, settings: regardie, start: '/respirar/practica');
      final sem = tester.widget<Semantics>(
        find.byKey(const ValueKey('breath_phase')),
      );
      expect(sem.properties.liveRegion, isTrue);
      expect(phaseName(tester), 'Inhala');
      await tester.pump(const Duration(seconds: 5));
      expect(phaseName(tester), 'Exhala, despacio');
    });

    testWidgets('sin retencion el vacio y el retener son «Gira» sin cuenta', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(patternId: 'gd', amount: 1),
        start: '/respirar/practica',
      );
      expect(find.text('Gira'), findsOneWidget);
      expect(find.text('sin detener el aire'), findsOneWidget);
      expect(_textOf(tester, 'breath_count').data, '');
      expect(
        find.text('RESPIRACIÓN CUÁDRUPLE · SIN RETENCIÓN'),
        findsOneWidget,
      );
      expect(find.text('Quédate vacío'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('Inhala'), findsOneWidget);
    });

    testWidgets('pausar congela; reanudar sigue', (tester) async {
      _phone(tester);
      await _pumpApp(tester, settings: regardie, start: '/respirar/practica');
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      expect(find.text('Reanudar'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(_textOf(tester, 'breath_left').data, '0:13');
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Exhala'), findsOneWidget);
      expect(_textOf(tester, 'breath_left').data, '0:11');
    });

    testWidgets('se pausa sola al pasar a segundo plano', (tester) async {
      _phone(tester);
      await _pumpApp(tester, settings: regardie, start: '/respirar/practica');
      await tester.pump(const Duration(seconds: 1));
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Reanudar'), findsOneWidget);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 10));
      // sigue en pausa hasta que la persona decida
      expect(find.text('Reanudar'), findsOneWidget);
      expect(_textOf(tester, 'breath_left').data, '0:15');
    });

    // 08-oct (Samuel): una respiracion de varios minutos no puede apagar la
    // pantalla a medias
    testWidgets('la pantalla sigue encendida solo mientras se respira', (
      tester,
    ) async {
      _phone(tester);
      final rec = await _pumpApp(
        tester,
        settings: const BreathSettings(amount: 1),
        start: '/respirar/practica',
      );
      expect(rec.awake, [true], reason: 'al empezar');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      expect(rec.awake.last, isFalse, reason: 'en pausa se puede apagar');
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      expect(rec.awake.last, isTrue, reason: 'al reanudar');
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Terminado'), findsOneWidget);
      expect(rec.awake.last, isFalse, reason: 'al terminar');
    });

    testWidgets('al salir se devuelve el apagado al sistema', (tester) async {
      _phone(tester);
      final rec = await _pumpApp(tester, settings: regardie);
      final start = find.byKey(const ValueKey('breath_start'));
      await tester.scrollUntilVisible(start, 300);
      await tester.tap(start);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rec.awake.last, isTrue);
      await tester.tap(find.byTooltip('Salir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BreathSetupScreen), findsOneWidget);
      expect(rec.awake.last, isFalse);
    });

    testWidgets('al terminar dice «Terminado» y avisa una vez', (tester) async {
      _phone(tester);
      final rec = await _pumpApp(
        tester,
        settings: const BreathSettings(amount: 1, vibration: true),
        start: '/respirar/practica',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.text(cyclesDoneText(1)), findsOneWidget);
      expect(find.text('Pausar'), findsNothing);
      expect(find.text('Volver'), findsOneWidget);
      expect(rec.finished, 1);
      expect(rec.phases, [BreathKind.inhale, BreathKind.exhale]);
      await tester.pump(const Duration(seconds: 5));
      expect(rec.finished, 1);
    });

    testWidgets('sin vibracion no se llama a ninguna senal', (tester) async {
      _phone(tester);
      final rec = await _pumpApp(
        tester,
        settings: regardie,
        start: '/respirar/practica',
      );
      await tester.pump(const Duration(seconds: 17));
      expect(rec.phases, isEmpty);
      expect(rec.finished, 0);
    });

    testWidgets('reanudar no vuelve a vibrar la misma fase', (tester) async {
      _phone(tester);
      final rec = await _pumpApp(
        tester,
        settings: const BreathSettings(amount: 2, vibration: true),
        start: '/respirar/practica',
      );
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      expect(rec.phases, [BreathKind.inhale]);
    });

    testWidgets('movimiento reducido: indicador fijo y sin orbe', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(patternId: 'gd', amount: 1),
        start: '/respirar/practica',
        reduceMotion: true,
      );
      expect(find.byKey(const ValueKey('breath_orb')), findsNothing);
      expect(find.byType(BreathStaticIndicator), findsOneWidget);
      expect(find.text('Gira 1'), findsNWidgets(2));
      expect(find.text('Inhala 4'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      final ind = tester.widget<BreathStaticIndicator>(
        find.byType(BreathStaticIndicator),
      );
      expect(ind.current, 1);
    });

    testWidgets('el interruptor de movimiento reducido tambien quita el orbe', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(reducedMotion: true),
        start: '/respirar/practica',
      );
      expect(find.byKey(const ValueKey('breath_orb')), findsNothing);
      expect(find.byType(BreathStaticIndicator), findsOneWidget);
    });

    testWidgets('observar el aliento: sin cuenta, el toque cambia', (
      tester,
    ) async {
      _phone(tester);
      final rec = await _pumpApp(
        tester,
        settings: const BreathSettings(
          patternId: 'observe',
          amount: 1,
          vibration: true,
        ),
        start: '/respirar/practica',
      );
      expect(find.text('Entra…'), findsOneWidget);
      expect(find.text('Sin cuenta'), findsOneWidget);
      expect(find.text('Toca cuando el aliento cambie'), findsOneWidget);
      expect(_textOf(tester, 'breath_left').data, '1:00');
      final zone = find.byKey(const ValueKey('breath_tapzone'));
      await tester.tap(zone);
      await tester.pump();
      expect(find.text('Sale…'), findsOneWidget);
      expect(rec.phases, [BreathKind.exhale]);
      await tester.tap(zone);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.text(observedText(1)), findsOneWidget);
    });

    testWidgets('360x640 con texto grande no desborda en la practica', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(patternId: 'nadi', retention: true),
        start: '/respirar/practica',
        textScale: 2,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Retén'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('360x640 terminado con texto grande no desborda', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(
        tester,
        settings: const BreathSettings(amount: 1),
        start: '/respirar/practica',
        textScale: 2,
      );
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(find.text('Terminado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('vibracion', () {
    testWidgets('un golpe distinto por fase', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const cue = HapticBreathCue();
      await cue.phase(BreathKind.turn);
      await cue.phase(BreathKind.inhale);
      await cue.phase(BreathKind.exhale);
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
      calls.clear();
      final f = cue.phase(BreathKind.empty);
      await tester.pump(const Duration(milliseconds: 500));
      await f;
      expect(calls, List.filled(3, 'HapticFeedbackType.mediumImpact'));
    });
  });
}
