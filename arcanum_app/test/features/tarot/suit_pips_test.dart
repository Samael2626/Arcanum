// Simbolos del palo junto a la carta desvelada (especificacion §6).
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/suit_pips.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
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

class _Effects extends TableEffects {}

TarotFace face(String slug, String name, String arcana, String? suit, int n) =>
    TarotFace.resolve({
      'slug': slug,
      'name': name,
      'arcana': arcana,
      'suit': suit,
      'number': n,
    });

const _five = CardFace(
  slug: 'cinco-de-oros',
  reversed: false,
  name: 'Cinco de Oros',
  nameEs: 'Cinco de Oros',
  arcana: 'minor',
  suit: 'oros',
  number: 5,
);

void main() {
  group('que simbolos lleva cada carta', () {
    test('tantos como su numero', () {
      expect(
        pipsFor(face('cinco-de-oros', 'Cinco de Oros', 'minor', 'oros', 5)),
        List.filled(5, 'oros'),
      );
      expect(
        pipsFor(
          face('diez-de-espadas', 'Diez de Espadas', 'minor', 'espadas', 10),
        ),
        hasLength(10),
      );
    });

    test('figuras: corona y su palo', () {
      expect(
        pipsFor(face('reina-de-copas', 'Reina de Copas', 'minor', 'copas', 13)),
        ['corona', 'copas'],
      );
    });

    test('Mayores: su numero romano y ningun icono', () {
      final torre = face('la-torre', 'La Torre', 'major', null, 16);
      expect(pipsFor(torre), isEmpty);
      expect(romanFor(torre), 'XVI');
    });

    test('el Diez cabe en una columna, como en el prototipo', () {
      expect(SuitPipsPainter.perColumn, greaterThanOrEqualTo(10));
      expect(
        SuitPipsPainter.centerOf(9).dy + 8,
        lessThanOrEqualTo(SuitPips.area.height),
      );
    });

    test('cada icono entra con un salto: 0,2, sube a 1,35 y se asienta', () {
      expect(pipScale(0), 0);
      expect(pipScale(1), closeTo(.2, .02));
      final peak = [
        for (var ms = 0; ms <= 420; ms += 5) pipScale(ms.toDouble()),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, closeTo(1.35, .02));
      expect(pipScale(420), 1);
      expect(pipScale(900), 1);
    });

    test('hay trazo para cada palo y la corona', () {
      for (final k in ['oros', 'copas', 'espadas', 'bastos', 'corona']) {
        expect(pipPath(k).getBounds().isEmpty, isFalse, reason: k);
      }
    });
  });

  group('en la mesa', () {
    late ProviderContainer c;
    late TableController ops;

    Future<void> pump(
      WidgetTester tester, {
      bool still = false,
      List<TableCard> cards = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view
        ..physicalSize = const Size(360, 760)
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
      ops = c.read(tableControllerProvider.notifier);
      await tester.runAsync(() => ops.openDeck('rws'));
      for (final k in cards) {
        ops.arrange((s) => s.addCard(k));
      }
      final dir = TableDirector(ops: ops, effects: _Effects());
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
                  return TarotTableView(director: dir);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    SuitPipsPainter? painter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SuitPipsPainter>()
        .firstOrNull;

    void reveal() => ops.arrange(
      (s) => s.updateCard(_five.slug, (k) => k.copyWith(faceUp: true)),
    );

    Future<void> leaveSaved(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 2));

    testWidgets('boca abajo no hay simbolos; al desvelarla entran tras el '
        'volteo, uno a uno', (tester) async {
      await pump(tester, cards: const [TableCard(face: _five, scale: .9)]);
      expect(find.byType(SuitPips), findsNothing);
      reveal();
      await tester.pump();
      expect(find.byType(SuitPips), findsNothing, reason: 'aun se voltea');
      for (var i = 0; i < 40 && painter(tester) == null; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final first = painter(tester)!;
      expect(first.icons, List.filled(5, 'oros'));
      expect(first.elapsed, lessThan(400), reason: 'acaba de empezar a entrar');
      await tester.pump(const Duration(seconds: 1));
      expect(painter(tester)!.elapsed, greaterThan(first.elapsed));
      await leaveSaved(tester);
    });

    testWidgets('una carta que ya llego desvelada los tiene sin entrada', (
      tester,
    ) async {
      await pump(
        tester,
        cards: const [TableCard(face: _five, scale: .9, faceUp: true)],
      );
      await tester.pump();
      final p = painter(tester)!;
      expect(pipScale(p.elapsed - 120 - 70 * 4), 1, reason: 'todos ya puestos');
      await leaveSaved(tester);
    });

    testWidgets('con «reducir movimiento» estan sin salto', (tester) async {
      await pump(
        tester,
        still: true,
        cards: const [TableCard(face: _five, scale: .9)],
      );
      reveal();
      await tester.pump();
      await tester.pump();
      final p = painter(tester)!;
      expect(pipScale(p.elapsed - 120 - 70 * 4), 1);
      await leaveSaved(tester);
    });

    testWidgets('invertida, los simbolos van invertidos', (tester) async {
      await pump(
        tester,
        cards: const [
          TableCard(
            face: CardFace(
              slug: 'reina-de-copas',
              reversed: true,
              name: 'Reina de Copas',
              nameEs: 'Reina de Copas',
              arcana: 'minor',
              suit: 'copas',
              number: 13,
            ),
            scale: .9,
            faceUp: true,
          ),
        ],
      );
      await tester.pump();
      final p = painter(tester)!;
      expect(p.reversed, isTrue);
      expect(p.icons, ['corona', 'copas']);
      await leaveSaved(tester);
    });
  });
}
