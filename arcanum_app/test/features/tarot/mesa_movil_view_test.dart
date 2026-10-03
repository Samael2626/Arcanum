// La mesa dibujada en el tamaño del GN2200 con la red lenta: el toque se ve
// en el mismo fotograma, los toques seguidos no se pierden y las cartas que
// llegan caben en pantalla. Complementa `mesa_movil_test.dart` (sin dibujo).
import 'dart:async';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:arcanum_app/features/tarot/table/table_pieces.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Effects extends TableEffects {
  final errors = <Object>[];
  @override
  void error(Object error) => errors.add(error);
}

class _SlowServer extends FakeServer {
  bool slow = false;
  final List<Completer<void>> waiting = [];

  @override
  Future<Map<String, dynamic>> tarotTableOp(
    String sessionId,
    String op,
    Map<String, dynamic> body,
  ) async {
    if (slow) {
      final gate = Completer<void>();
      waiting.add(gate);
      await gate.future;
    }
    return super.tarotTableOp(sessionId, op, body);
  }

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

SpreadDef _spread(String slug, double scale, List<(double, double, int)> s) =>
    SpreadDef(
      slug: slug,
      name: slug,
      description: '',
      cardScale: scale,
      labelByName: true,
      slots: [
        for (var i = 0; i < s.length; i++)
          SpreadSlotDef(
            x: s[i].$1,
            y: s[i].$2,
            rotation: s[i].$3,
            name: 'Hueco ${i + 1}',
            meaning: 'm.',
          ),
      ],
    );

// `arcanum-api/app/domain/spreads.py`
final _three = _spread('three_card', .9, [
  (.2, .46, 0),
  (.5, .46, 0),
  (.8, .46, 0),
]);
final _celtic = _spread('celtic_cross', .56, [
  (.34, .5, 0),
  (.34, .5, 90),
  (.34, .8, 0),
  (.13, .5, 0),
  (.34, .2, 0),
  (.55, .5, 0),
  (.86, .87, 0),
  (.86, .62, 0),
  (.86, .38, 0),
  (.86, .13, 0),
]);

/// Pantalla util del GN2200 (1080 x 2400 a 3x, sin barras).
const _gn2200 = Size(360, 760);

/// La mesa tiene animaciones que piden frames mientras se mueven: se dejan
/// pasar fotogramas en vez de `pumpAndSettle`.
Future<void> settleFrames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late ProviderContainer c;
  late TableDirector dir;
  late _SlowServer server;
  late _Effects fx;
  var now = Duration.zero;

  Future<void> pumpTable(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view
      ..physicalSize = _gn2200
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = _SlowServer();
    c = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(server),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    fx = _Effects();
    dir = TableDirector(
      ops: c.read(tableControllerProvider.notifier),
      effects: fx,
      decks: _decks,
      spreads: [_three, _celtic],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
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

  /// Deja que el servidor falso conteste (sus Futures son reales).
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
  }

  Future<void> openWithFan(WidgetTester tester, String spread) async {
    await tapAt(tester, screen(shelfPose(0, 2).offset));
    await settle(tester);
    c
        .read(tableControllerProvider.notifier)
        .arrange((s) => s.copyWith(spread: () => spread));
    await tester.pump();
    final p = dir.table.piles.single;
    await tapAt(tester, screen(Offset(p.x, p.y)));
    await settleFrames(tester);
    expect(dir.table.fan, isNotNull);
  }

  /// Un punto de la carta i del abanico que no tapa la siguiente.
  Offset fanPoint(int i) {
    final fan = dir.pieces().where((p) => p.kind == PieceKind.fanCard).toList();
    return screen(fan[i].pose.offset.translate(0, 20));
  }

  Finder pending() => find.byType(PendingCardPiece);

  Future<void> answerAll(WidgetTester tester) async {
    for (var n = 0; n < 60 && dir.pendingTakes.isNotEmpty; n++) {
      await settle(tester);
      if (server.waiting.isNotEmpty) server.waiting.removeAt(0).complete();
    }
    await settle(tester);
    await settleFrames(tester);
  }

  /// Todas las cartas en juego dentro de la pantalla.
  void expectCardsOnScreen(WidgetTester tester) {
    final screenRect = Offset.zero & _gn2200;
    for (final e in find.byType(TableCardPiece).evaluate()) {
      final box = e.renderObject! as RenderBox;
      final view = (e.widget as TableCardPiece).view;
      final hw = TableGeometry.cardW * view.pose.scale / 2,
          hh = TableGeometry.cardH * view.pose.scale / 2;
      for (final d in [Offset(-hw, -hh), Offset(hw, hh)]) {
        final p = screen(view.pose.offset + d);
        expect(screenRect.contains(p), isTrue, reason: '${view.id} en $p');
      }
      expect(box.attached, isTrue);
    }
  }

  testWidgets(
    'tres cartas con la red lenta: cada toque se ve en el mismo fotograma',
    (tester) async {
      await pumpTable(tester);
      await openWithFan(tester, 'three_card');
      server.slow = true;

      await tapAt(tester, fanPoint(10));
      // un fotograma despues del toque, sin respuesta del servidor
      expect(pending(), findsOneWidget);
      await tapAt(tester, fanPoint(30));
      await tapAt(tester, fanPoint(50));
      expect(pending(), findsNWidgets(3), reason: 'ningun toque perdido');
      expect(find.byType(TableCardPiece), findsNothing);

      await answerAll(tester);
      expect(pending(), findsNothing);
      for (var i = 0; i < 3; i++) {
        expect(
          find.bySemanticsLabel(
            'Carta boca abajo. Posición ${i + 1}, '
            'Hueco ${i + 1}',
          ),
          findsOneWidget,
        );
      }
      expectCardsOnScreen(tester);
      expect(fx.errors, isEmpty);
      expect(dir.takeTimings, hasLength(3));
    },
  );

  testWidgets('Cruz Celta completa a toques, con la red lenta', (tester) async {
    await pumpTable(tester);
    await openWithFan(tester, 'celtic_cross');
    server.slow = true;
    for (var i = 0; i < 10; i++) {
      await tapAt(tester, fanPoint(2 + i * 5));
      expect(pending(), findsNWidgets(i + 1));
    }
    await answerAll(tester);
    for (var i = 0; i < 10; i++) {
      expect(dir.table.cardInSlot(i), isNotNull, reason: 'hueco $i');
    }
    expect(find.byType(TableCardPiece), findsNWidgets(10));
    expectCardsOnScreen(tester);
  });
}
