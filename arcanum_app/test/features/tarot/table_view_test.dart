import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_fx.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:arcanum_app/features/tarot/table/table_motion.dart';
import 'package:arcanum_app/features/tarot/table/table_painters.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Effects extends TableEffects {}

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

final _one = SpreadDef.fromJson({
  'slug': 'one_card',
  'name': 'Una carta',
  'card_scale': 1,
  'label_mode': 'name',
  'slots': [
    {
      'x': .5,
      'y': .5,
      'rotation': 0,
      'name': 'Mensaje',
      'meaning': 'Lo esencial.',
    },
  ],
});

void main() {
  late ProviderContainer c;
  late TableDirector dir;
  var now = Duration.zero;

  Future<void> pumpTable(WidgetTester tester, {bool still = false}) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    c = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(FakeServer()),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    dir = TableDirector(
      ops: c.read(tableControllerProvider.notifier),
      effects: _Effects(),
      decks: _decks,
      spreads: [_one],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          // «reducir movimiento» del sistema
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: Scaffold(
            // como la pantalla: se reconstruye cuando cambia la mesa del controlador
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(tableControllerProvider);
                return TarotTableView(director: dir, clock: () => now);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Offset screen(Offset table) => dir.camera.toScreen(table);

  /// Espera a que el servidor falso conteste (va por Futures reales).
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tap(WidgetTester tester, Offset table) async {
    final g = await tester.startGesture(screen(table));
    now += const Duration(milliseconds: 60);
    await g.up();
    now += const Duration(milliseconds: 400);
    await tester.pump();
    await settle(tester);
  }

  testWidgets('el estante enseña los dos mazos y tocar uno lo pone en juego', (
    tester,
  ) async {
    await pumpTable(tester);
    expect(
      find.bySemanticsLabel(RegExp('Rider–Waite–Smith, 78 cartas')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Arcanos Mayores, 22 cartas')),
      findsOneWidget,
    );

    await tap(tester, shelfPose(0, 2).offset);
    expect(dir.table.hasTable, isTrue);
    expect(
      find.bySemanticsLabel(RegExp('Rider–Waite–Smith, 6 cartas')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada pieza se anuncia donde esta dibujada, no en el origen', (
    tester,
  ) async {
    // GN2200: los dos mazos, y todas las cartas, daban el mismo cuadro al
    // lector de pantalla porque la posicion iba por debajo del Semantics
    await pumpTable(tester);
    final rws = tester.getRect(
      find.bySemanticsLabel(RegExp('Rider–Waite–Smith, 78 cartas')),
    );
    final majors = tester.getRect(
      find.bySemanticsLabel(RegExp('Arcanos Mayores, 22 cartas')),
    );
    expect(rws.contains(screen(shelfPose(0, 2).offset)), isTrue);
    expect(majors.contains(screen(shelfPose(1, 2).offset)), isTrue);
    expect(rws.overlaps(majors), isFalse);

    await tap(tester, shelfPose(0, 2).offset);
    final ops = c.read(tableControllerProvider.notifier);
    ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
    final card = await tester.runAsync(() => ops.take('p0', 2));
    ops.arrange((s) => s.putInSlot(card!.slug, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final slot = tester.getRect(find.bySemanticsLabel(RegExp('Posición 1')));
    final pile = tester.getRect(
      find.bySemanticsLabel(RegExp('Rider–Waite–Smith, 5 cartas')),
    );
    expect(slot.overlaps(pile), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantener el mazo abre el radial dibujado con su orden fijo', (
    tester,
  ) async {
    await pumpTable(tester);
    tester.view.physicalSize = const Size(360, 760);
    await tester.pump();
    await tap(tester, shelfPose(0, 2).offset);
    final g = await tester.startGesture(screen(TableGeometry.homeSpot));
    now += const Duration(milliseconds: 460);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(dir.radial, isNotNull);
    for (final label in [
      'Barajar',
      'Cortar',
      'Extender',
      'Sacar',
      'Recoger',
      'Tirada',
      'Unir',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final option = find.bySemanticsLabel('Barajar');
    expect(
      tester
          .getSemantics(option)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    final center = find.bySemanticsLabel(RegExp(r'^(Deshacer|Cerrar)$'));
    expect(tester.getSize(center).height, 48);
    expect(
      tester
          .getSemantics(center)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    // soltar sobre Cortar
    final layout = dir.radial!;
    await g.moveTo(layout.positions[1]);
    await tester.pump();
    await g.up();
    await settle(tester);
    expect(dir.radial, isNull);
    expect(dir.table.piles, hasLength(2));
  });

  testWidgets('una carta desvelada se anuncia por su nombre y su hueco', (
    tester,
  ) async {
    await pumpTable(tester);
    await tap(tester, shelfPose(0, 2).offset);
    final ops = c.read(tableControllerProvider.notifier);
    ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
    final card = await tester.runAsync(() => ops.take('p0', 2));
    ops.arrange(
      (s) => s
          .putInSlot(card!.slug, 0)
          .updateCard(card.slug, (k) => k.copyWith(faceUp: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.bySemanticsLabel(RegExp(r'invertida\. Posición 1, Mensaje')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Interpretar tirada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el abanico se dibuja y el monton queda vacio mientras esta abierto',
    (tester) async {
      await pumpTable(tester);
      await tap(tester, shelfPose(0, 2).offset);
      await tap(tester, TableGeometry.homeSpot);
      expect(dir.table.fan, isNotNull);
      expect(
        find.bySemanticsLabel(RegExp('Rider–Waite–Smith, 0 cartas')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el sello se dibuja sobre el paño y se rompe al abrirse', (
    tester,
  ) async {
    await pumpTable(tester);
    await tap(tester, shelfPose(0, 2).offset);
    final ops = c.read(tableControllerProvider.notifier);
    ops.arrange((s) => s.copyWith(seal: () => const Seal(text: 'x')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Pregunta sellada'), findsOneWidget);
    ops.arrange(
      (s) => s.copyWith(seal: () => const Seal(text: 'x', open: true)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Pregunta abierta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('movimiento', () {
    testWidgets('una carta devuelta vuela al monton y luego desaparece', (
      tester,
    ) async {
      await pumpTable(tester);
      await tap(tester, shelfPose(0, 2).offset);
      final ops = c.read(tableControllerProvider.notifier);
      final card = (await tester.runAsync(() => ops.take('p0', 0)))!;
      await tester.pump(const Duration(seconds: 1));
      // arrastrada a la bandeja vuelve al monton (07-oct: antes, un toque)
      final from = screen(Offset(card.x, card.y)), to = dir.trayRect.center;
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 10; i++) {
        now += const Duration(milliseconds: 16);
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump();
      }
      expect(find.text('Suelta para recoger'), findsOneWidget);
      await g.up();
      var seen = false, gone = false;
      for (var i = 0; i < 40 && !gone; i++) {
        now += const Duration(milliseconds: 50);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final flying = find.byType(DepartingPiece).evaluate().isNotEmpty;
        seen |= flying;
        gone = seen && !flying;
      }
      expect(dir.table.card(card.slug), isNull);
      expect(seen, isTrue, reason: 'la carta tenia que verse volando');
      expect(gone, isTrue, reason: 'y desaparecer al llegar');
      expect(tester.takeException(), isNull);
    });

    testWidgets('barajar entra en escena y sale al terminar', (tester) async {
      await pumpTable(tester);
      await tap(tester, shelfPose(0, 2).offset);
      final g = await tester.startGesture(screen(TableGeometry.homeSpot));
      now += const Duration(milliseconds: 460);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveTo(dir.radial!.positions[0]); // Barajar
      await g.up();
      await tester.pump();
      // el radial de estilos: tocar Cascada
      await tester.tapAt(dir.radial!.positions[0]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      bool onStage() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((w) => w.painter is ShuffleTheaterPainter);
      expect(onStage(), isTrue);
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(onStage(), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el abanico se despliega sin romper nada', (tester) async {
      await pumpTable(tester);
      await tap(tester, shelfPose(0, 2).offset);
      await tap(tester, TableGeometry.homeSpot);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(dir.table.fan, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('gestos con el dedo', () {
    /// Arrastra con el dedo de verdad, en pasos, como la pantalla los recibe.
    Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
      final g = await tester.startGesture(screen(from));
      for (var i = 1; i <= 8; i++) {
        now += const Duration(milliseconds: 16);
        await g.moveTo(screen(Offset.lerp(from, to, i / 8)!));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
      await settle(tester);
    }

    Future<TableCard> looseCard(WidgetTester tester) async {
      await tap(tester, shelfPose(0, 2).offset);
      final ops = c.read(tableControllerProvider.notifier);
      ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
      final card = (await tester.runAsync(() => ops.take('p0', 0)))!;
      ops.arrange(
        (s) => s.updateCard(card.slug, (k) => k.copyWith(x: 150, y: 420)),
      );
      await tester.pump(const Duration(seconds: 1));
      return dir.table.card(card.slug)!;
    }

    testWidgets('arrastrar una carta suelta la encaja en el hueco', (
      tester,
    ) async {
      await pumpTable(tester);
      final card = await looseCard(tester);
      expect(card.slot, isNull);
      await drag(tester, Offset(card.x, card.y), slotPose(_one, 0).offset);
      final placed = dir.table.cardInSlot(0);
      expect(placed?.slug, card.slug);
      expect(placed!.x, closeTo(slotPose(_one, 0).x, .5));
      expect(placed.y, closeTo(slotPose(_one, 0).y, .5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la esquina voltea solo pasados 70 grados', (tester) async {
      await pumpTable(tester);
      final card = await looseCard(tester);
      expect(card.faceUp, isFalse);
      final hw = TableGeometry.cardW * card.scale / 2,
          hh = TableGeometry.cardH * card.scale / 2;
      final corner = Offset(card.x + hw * .85, card.y + hh * .85);

      // un tiron corto (pasado el umbral de 18 px; por debajo es un toque, y
      // un toque desvela) no llega a 70 grados: la carta vuelve boca abajo
      await drag(tester, corner, corner.translate(-hw * .7, 0));
      expect(dir.table.card(card.slug)!.faceUp, isFalse);

      // hasta el borde contrario pasa de 70 grados: se voltea
      await drag(tester, corner, corner.translate(-hw * 1.6, 0));
      expect(dir.table.card(card.slug)!.faceUp, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('tanda 1 de animaciones', () {
    double embroidery(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EmbroideryPainter>()
        .single
        .t;

    /// Una carta en la tirada de una, todavia boca abajo.
    Future<TableCard> laid(WidgetTester tester) async {
      await tap(tester, shelfPose(0, 2).offset);
      final ops = c.read(tableControllerProvider.notifier);
      ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
      final card = (await tester.runAsync(() => ops.take('p0', 0)))!;
      ops.arrange((s) => s.putInSlot(card.slug, 0));
      await tester.pump(const Duration(seconds: 1));
      return card;
    }

    void reveal(TableCard card) => c
        .read(tableControllerProvider.notifier)
        .arrange(
          (s) => s.updateCard(card.slug, (k) => k.copyWith(faceUp: true)),
        );

    Future<void> frames(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('el bordado despierta poco a poco al quedar lista la tirada', (
      tester,
    ) async {
      await pumpTable(tester);
      final card = await laid(tester);
      expect(dir.readyToInterpret, isFalse);
      expect(embroidery(tester), 0);
      reveal(card);
      await frames(tester, 300);
      expect(dir.readyToInterpret, isTrue);
      expect(embroidery(tester), inExclusiveRange(0, 1));
      await frames(tester, 1500);
      expect(embroidery(tester), 1);
      // si deja de estar lista, se apaga
      c
          .read(tableControllerProvider.notifier)
          .arrange(
            (s) => s.updateCard(card.slug, (k) => k.copyWith(faceUp: false)),
          );
      await frames(tester, 100);
      expect(embroidery(tester), 0);
      // deja guardar la mesa: el autoguardado espera un poco tras cada cambio
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('desvelar deja una huella bajo la carta que se va sola', (
      tester,
    ) async {
      await pumpTable(tester);
      final card = await laid(tester);
      expect(find.byType(ImprintPiece), findsNothing);
      reveal(card);
      await tester.pump();
      expect(find.byType(ImprintPiece), findsOneWidget);
      // espera al volteo y dura 1,6 s
      await frames(tester, 3500);
      expect(find.byType(ImprintPiece), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'con «reducir movimiento»: bordado encendido de golpe y sin huellas',
      (tester) async {
        await pumpTable(tester, still: true);
        final card = await laid(tester);
        reveal(card);
        await tester.pump();
        await tester.pump();
        expect(embroidery(tester), 1);
        expect(find.byType(ImprintPiece), findsNothing);
        // deja guardar la mesa: el autoguardado espera un poco tras cada cambio
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });

  test('el giro va por el camino corto', () {
    final p = lerpPose(
      const TablePose(0, 0, rot: 350),
      const TablePose(0, 0, rot: 10),
      .5,
    );
    expect(p.rot % 360, closeTo(0, 1e-9));
  });
}
