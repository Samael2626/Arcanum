// Fases 6 y 7: medidor de fotogramas, calidad adaptativa (especificacion §6),
// vibracion (§7) y «reducir movimiento» en toda la mesa.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_fx.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:arcanum_app/features/tarot/table/table_haptics.dart';
import 'package:arcanum_app/features/tarot/table/table_motion.dart';
import 'package:arcanum_app/features/tarot/table/table_painters.dart';
import 'package:arcanum_app/features/tarot/table/table_pieces.dart';
import 'package:arcanum_app/features/tarot/table/table_quality.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _frame = 16667; // µs a 60 Hz

/// `n` fotogramas seguidos desde `from` (µs), cada `every` µs.
List<FrameSample> run(
  int from,
  int n, {
  int every = _frame,
  int build = 4000,
  int raster = 9000,
}) => [
  for (var i = 0; i < n; i++)
    FrameSample(
      vsyncStart: from + i * every,
      build: build,
      raster: raster,
      total: build + raster,
    ),
];

FrameWindow win(double fps, {int frames = 60}) => FrameWindow(
  frames: frames,
  activeSeconds: frames / fps,
  buildP90: 0,
  rasterP90: 0,
  slow: 0,
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Effects extends TableEffects {}

class _Buzzes extends TableHaptics {
  final played = <Buzz>[];
  @override
  Future<void> play(Buzz buzz) async => played.add(buzz);
}

class _Server78 extends FakeServer {
  @override
  Future<Map<String, dynamic>> tarotOpenTable(
    String deck, {
    String? fromReading,
  }) async {
    await super.tarotOpenTable(deck, fromReading: fromReading);
    piles = {
      'p0': [for (var i = 0; i < 78; i++) 'c$i'],
    };
    return (await tarotCurrentTable())!;
  }
}

const _decks = [
  DeckInfo(
    slug: 'rws',
    name: 'Rider–Waite–Smith',
    description: '',
    allowReversed: true,
    art: 'rws',
    cardCount: 78,
  ),
  DeckInfo(
    slug: 'mayores',
    name: 'Arcanos Mayores',
    description: '',
    allowReversed: true,
    art: 'rws',
    cardCount: 22,
  ),
];

final _three = SpreadDef(
  slug: 'three_card',
  name: 'Tres cartas',
  description: '',
  cardScale: .9,
  labelByName: true,
  slots: [
    for (final x in [.2, .5, .8])
      SpreadSlotDef(x: x, y: .46, rotation: 0, name: 'Hueco', meaning: 'm.'),
  ],
);

void main() {
  group('medidor', () {
    test(
      'cuenta los fps sobre el tiempo en movimiento, no sobre la espera',
      () {
        // un segundo moviendose, otro quieta (sin fotogramas), otro moviendose
        final w = summarize([...run(0, 60), ...run(2000000, 60)]);
        expect(w.frames, 120);
        expect(w.fps, closeTo(60, .5));
        expect(w.meaningful, isTrue);
      },
    );

    test('a 30 por segundo da 30, con su montaje y dibujo p90', () {
      final w = summarize(run(0, 60, every: 33333, build: 7000, raster: 21000));
      expect(w.fps, closeTo(30, .5));
      expect(w.buildP90, 7);
      expect(w.rasterP90, 21);
      expect(w.slow, 60, reason: '28 ms pasan de los 16,7 de 60 Hz');
    });

    test('una mesa casi quieta no decide nada', () {
      expect(summarize(run(0, 10)).meaningful, isFalse);
      expect(summarize(const []).fps, 0);
    });

    test('cierra una ventana cada 2 s y avisa a la calidad', () {
      final q = TableQuality();
      final m = FrameMeter(quality: q, log: false);
      m.add(run(0, 75, every: 33333)); // 2,5 s a 30 fps
      expect(m.last.fps, closeTo(30, .5));
      expect(q.value, 1);
    });
  });

  group('calidad adaptativa', () {
    test('por debajo de 40 baja un nivel cada vez, hasta 2', () {
      final q = TableQuality();
      expect((q.glow, q.imprints, q.halfRate), (true, true, false));
      q.onWindow(win(35));
      expect(q.value, 1);
      expect((q.glow, q.imprints, q.halfRate), (false, true, false));
      q.onWindow(win(30));
      expect(q.value, 2);
      expect((q.glow, q.imprints, q.halfRate), (false, false, true));
      q.onWindow(win(20));
      expect(q.value, 2);
    });

    test('quieta no baja y solo sube tras un rato holgado', () {
      final q = TableQuality();
      q.onWindow(win(10, frames: 5)); // casi sin fotogramas: no cuenta
      expect(q.value, 0);
      q
        ..onWindow(win(35))
        ..onWindow(win(35));
      expect(q.value, 2);
      q
        ..onWindow(win(58))
        ..onWindow(win(58));
      expect(q.value, 2, reason: 'dos ventanas holgadas no bastan');
      q.onWindow(win(58));
      expect(q.value, 1);
      // una ventana justa corta la racha
      q
        ..onWindow(win(58))
        ..onWindow(win(48))
        ..onWindow(win(58))
        ..onWindow(win(58));
      expect(q.value, 1);
      q.onWindow(win(58));
      expect(q.value, 0);
    });

    test(
      'si recae tras recuperar espera el doble; a la tercera, no vuelve',
      () {
        // Samuel, 07-oct: espera creciente. Sin ella, en un movil flojo los
        // brillos iban y venian: quitarlos dejaba la escena holgada y a los 6 s
        // volvian a tumbarla
        final q = TableQuality();
        void holgadas(int n) {
          for (var i = 0; i < n; i++) {
            q.onWindow(win(58));
          }
        }

        q.onWindow(win(35));
        holgadas(3);
        expect(q.value, 0, reason: 'primera vez: 6 s');
        q.onWindow(win(35));
        holgadas(3);
        expect(q.value, 1, reason: 'recaida: ya no bastan 6 s');
        holgadas(3);
        expect(q.value, 0, reason: '12 s');
        q.onWindow(win(35));
        holgadas(11);
        expect(q.value, 1);
        holgadas(1);
        expect(q.value, 0, reason: '24 s');
        q.onWindow(win(35));
        holgadas(60);
        expect(q.value, 1, reason: 'tercera recaida: no lo intenta mas');
      },
    );

    test('a medio ritmo el efecto cambia la mitad de veces', () {
      const len = Duration(seconds: 1);
      final seen = {for (var f = 0; f <= 60; f++) halfRate(f / 60, len)};
      expect(seen.length, inInclusiveRange(29, 32));
    });
  });

  group('vibracion', () {
    test('los milisegundos de la especificacion pasan a golpes', () {
      // lo corto tambien es golpe ligero: selectionClick no vibra en el GN2200
      expect(hapticFor(3), HapticKind.light);
      expect(hapticFor(4), HapticKind.light);
      expect(hapticFor(8), HapticKind.light);
      expect(hapticFor(10), HapticKind.light);
      expect(hapticFor(12), HapticKind.medium);
      expect(hapticFor(14), HapticKind.medium);
      expect(Buzz.revealMajor.pattern, [12, 40, 12]);
      expect(Buzz.closeCircle.pattern, [10, 60, 10]);
    });

    test('un patron da dos golpes separados por su pausa', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <(String, Duration)>[];
      final clock = Stopwatch()..start();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add((call.arguments as String, clock.elapsed));
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await const TableHaptics().play(Buzz.revealMajor);
      expect(calls.map((c) => c.$1), [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      expect(
        calls[1].$2 - calls[0].$2,
        greaterThanOrEqualTo(const Duration(milliseconds: 50)),
      );
      calls.clear();
      await const TableHaptics().play(Buzz.radialHover);
      expect(calls.single.$1, 'HapticFeedbackType.lightImpact');
      calls.clear();
      await const TableHaptics().play(Buzz.fanTick);
      expect(calls.single.$1, 'HapticFeedbackType.lightImpact');
    });
  });

  group('en la mesa', () {
    late ProviderContainer c;
    late TableDirector dir;
    late _Buzzes buzz;
    var now = Duration.zero;

    Future<void> pumpTable(
      WidgetTester tester, {
      bool still = false,
      TableQuality? quality,
    }) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view
        ..physicalSize = const Size(360, 760)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      c = ProviderContainer(
        overrides: [
          arcanumApiProvider.overrideWithValue(_Server78()),
          authProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(c.dispose);
      await tester.runAsync(() => c.read(tableControllerProvider.future));
      buzz = _Buzzes();
      dir = TableDirector(
        ops: c.read(tableControllerProvider.notifier),
        effects: _Effects(),
        decks: _decks,
        spreads: [_three],
        haptics: buzz,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: still),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(tableControllerProvider);
                  return TarotTableView(
                    director: dir,
                    clock: () => now,
                    quality: quality,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Offset screen(Offset t) => dir.camera.toScreen(t);

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    Future<void> tapAt(WidgetTester tester, Offset at) async {
      final g = await tester.startGesture(at);
      now += const Duration(milliseconds: 60);
      await g.up();
      now += const Duration(milliseconds: 400);
      await tester.pump();
      await settle(tester);
    }

    Future<void> openWithFan(WidgetTester tester) async {
      await tapAt(tester, screen(shelfPose(0, 2).offset));
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(spread: () => 'three_card'));
      await tester.pump();
      final p = dir.table.piles.single;
      await tapAt(tester, screen(Offset(p.x, p.y)));
    }

    Offset fanPoint(int i) => screen(
      dir
          .pieces()
          .where((p) => p.kind == PieceKind.fanCard)
          .elementAt(i)
          .pose
          .offset
          .translate(0, 20),
    );

    /// Poses que pinta el abanico ahora mismo.
    List<TablePose> fanPainted(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FanPainter>()
        .single
        .poses;

    Matrix4 cardMatrix(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(TableCardPiece),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;

    Future<void> leaveSaved(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 2));

    testWidgets('sacar, encajar, desvelar y barajar vibran como dice la '
        'especificacion', (tester) async {
      await pumpTable(tester);
      await openWithFan(tester);
      await tapAt(tester, fanPoint(10));
      expect(buzz.played, [Buzz.snap]);
      final card = dir.table.cardInSlot(0)!;
      // dos toques la desvelan (esta en su hueco: uno basta)
      await tapAt(tester, screen(Offset(card.x, card.y)));
      expect(buzz.played.last, Buzz.reveal);
      await leaveSaved(tester);
    });

    testWidgets('con «reducir movimiento» nada viaja ni se despliega', (
      tester,
    ) async {
      await pumpTable(tester, still: true);
      expect(dir.reduceMotion, isTrue);
      await openWithFan(tester);
      // el abanico ya esta abierto del todo, sin los 780 ms de despliegue
      await tester.pump();
      final f = dir.fan!;
      final count = dir.pieces().where((p) => p.kind == PieceKind.fanCard);
      expect(fanPainted(tester), fanPoses(f.start, f.end, count.length));

      // la carta aparece en su hueco, sin volar desde el abanico
      await tapAt(tester, fanPoint(10));
      await tester.pump();
      final view = tester.widget<TableCardPiece>(find.byType(TableCardPiece));
      expect(cardMatrix(tester), pieceMatrix(view.view.pose));

      // los circulos del radial estan en su sitio en el primer fotograma
      final p = dir.table.piles.single;
      final g = await tester.startGesture(screen(Offset(p.x, p.y)));
      now += const Duration(milliseconds: 450);
      await tester.pump(const Duration(milliseconds: 450));
      expect(dir.radial, isNotNull);
      await tester.pump();
      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(Positioned),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .where((o) => o > 0 && o < 1 && o != .28);
      expect(opacities, isEmpty, reason: 'ningun circulo a medio aparecer');
      await g.up();
      await tester.pump();
      await leaveSaved(tester);
    });

    testWidgets('sin «reducir movimiento» el abanico se despliega (control)', (
      tester,
    ) async {
      await pumpTable(tester);
      await openWithFan(tester);
      final f = dir.fan!;
      final n = dir.pieces().where((p) => p.kind == PieceKind.fanCard).length;
      await tester.pump(const Duration(milliseconds: 16));
      expect(fanPainted(tester), isNot(fanPoses(f.start, f.end, n)));
      await tester.pump(const Duration(seconds: 1));
      expect(fanPainted(tester), fanPoses(f.start, f.end, n));
      await leaveSaved(tester);
    });

    testWidgets('con «reducir movimiento» el sello no da golpe y la camara '
        'no sigue sola', (tester) async {
      await pumpTable(tester, still: true);
      await tapAt(tester, screen(shelfPose(0, 2).offset));
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(seal: () => const Seal(text: '?')));
      await tester.pump();
      final seal = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(SealPiece),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(seal.transform.getMaxScaleOnAxis(), closeTo(1, 1e-9));

      // girar la mesa con el dedo y soltar: se queda donde la dejo el dedo
      final from = screen(const Offset(300, 420));
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 5; i++) {
        now += const Duration(milliseconds: 16);
        await g.moveTo(from.translate(i * 14.0, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final yaw = dir.camera.tYaw;
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(dir.camera.tYaw, yaw, reason: 'sin inercia');
      expect(dir.camera.yaw, dir.camera.tYaw, reason: 'sin suavizado');
      await leaveSaved(tester);
    });

    testWidgets('con «reducir movimiento» no hay barajado en escena', (
      tester,
    ) async {
      await pumpTable(tester, still: true);
      await tapAt(tester, screen(shelfPose(0, 2).offset));
      final p = dir.table.piles.single;
      final g = await tester.startGesture(screen(Offset(p.x, p.y)));
      now += const Duration(milliseconds: 450);
      await tester.pump(const Duration(milliseconds: 450));
      final l = dir.radial!;
      await g.moveTo(l.positions[l.items.indexWhere((i) => i.id == 'shuffle')]);
      await g.up();
      await tester.pump();
      final l2 = dir.radial!;
      await tapAt(tester, l2.positions[0]);
      expect(buzz.played, contains(Buzz.shuffle));
      expect(dir.shuffling, isNotNull);
      final theater = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ShuffleTheaterPainter>();
      expect(theater, isEmpty);
      await leaveSaved(tester);
    });

    testWidgets('calidad 1 quita los brillos; calidad 2, ademas las huellas', (
      tester,
    ) async {
      final q = TableQuality();
      await pumpTable(tester, quality: q);
      await tapAt(tester, screen(shelfPose(0, 2).offset));
      bool pileGlows() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<PilePainter>()
          .any((p) => p.glow);
      EmbroideryPainter embroidery() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<EmbroideryPainter>()
          .single;
      expect(pileGlows(), isTrue, reason: 'el mazo recien abierto brilla');
      expect(embroidery().glow, isTrue);
      q.value = 1;
      await tester.pump();
      expect(pileGlows(), isFalse);
      expect(embroidery().glow, isFalse);

      q.value = 2;
      await tester.pump();
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(spread: () => 'three_card'));
      await tapAt(tester, screen(TableGeometry.homeSpot));
      await tapAt(tester, fanPoint(5));
      final card = dir.table.cardInSlot(0)!;
      c
          .read(tableControllerProvider.notifier)
          .arrange(
            (s) => s.updateCard(card.slug, (k) => k.copyWith(faceUp: true)),
          );
      await tester.pump();
      await tester.pump();
      expect(find.byType(ImprintPiece), findsNothing);
      await leaveSaved(tester);
    });

    testWidgets('calidad 1 tambien quita el desenfoque de las sombras', (
      tester,
    ) async {
      final q = TableQuality();
      await pumpTable(tester, quality: q);
      await openWithFan(tester);
      await tapAt(tester, fanPoint(5));
      await tester.pump(const Duration(milliseconds: 500));
      bool fanSoft() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<FanPainter>()
          .single
          .soft;
      double cardBlur() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(TableCardPiece),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).boxShadow!.first.blurRadius;
      }

      expect(fanSoft(), isTrue);
      expect(cardBlur(), greaterThan(0));
      q.value = 1;
      await tester.pump();
      expect(fanSoft(), isFalse);
      expect(cardBlur(), 0);
      await leaveSaved(tester);
    });

    testWidgets('en silencio la mesa no vibra; al quitarlo, vuelve', (
      tester,
    ) async {
      await pumpTable(tester);
      await openWithFan(tester);
      dir.muted = true;
      await tapAt(tester, fanPoint(5));
      dir.buzz(Buzz.seal);
      expect(buzz.played, isEmpty);
      dir.muted = false;
      await tapAt(tester, fanPoint(20));
      dir.buzz(Buzz.seal);
      expect(buzz.played, [Buzz.snap, Buzz.seal]);
      await leaveSaved(tester);
    });
  });
}
