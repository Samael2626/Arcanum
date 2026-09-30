import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
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

  Future<void> pumpTable(WidgetTester tester) async {
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

  testWidgets('mantener el mazo abre el radial dibujado con su orden fijo', (
    tester,
  ) async {
    await pumpTable(tester);
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
}
