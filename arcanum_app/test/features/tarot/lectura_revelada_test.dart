import 'dart:ui' show Tristate;

import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/reading/lectura_revelada.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:arcanum_app/shared/revelado/reveal_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final _three = SpreadDef.fromJson({
  'slug': 'three_card',
  'name': 'Tres cartas',
  'card_scale': .9,
  'label_mode': 'name',
  'slots': [
    {'x': .2, 'y': .46, 'rotation': 0, 'name': 'Pasado', 'meaning': 'a'},
    {'x': .5, 'y': .46, 'rotation': 0, 'name': 'Presente', 'meaning': 'b'},
    {'x': .8, 'y': .46, 'rotation': 0, 'name': 'Futuro', 'meaning': 'c'},
  ],
});

Map<String, dynamic> _card(
  String slug,
  String nameEs,
  int slot,
  String pos,
  String meaning, {
  bool reversed = false,
  String arcana = 'major',
}) => {
  'slug': slug,
  'name_es': nameEs,
  'arcana': arcana,
  'reversed': reversed,
  'slot': slot,
  'position': pos,
  'position_meaning': 'Lo que pesa en $pos.',
  'meaning': meaning,
};

final _reading = Interpretation.fromJson({
  'spread': 'three_card',
  'spread_name': 'Tres cartas',
  'question': '¿Sigo en este trabajo?',
  'moon_phase': 'Luna creciente',
  'moon_illumination': .63,
  'read_at': '2026-10-02T21:14:00Z',
  'cards': [
    _card(
      'la-torre',
      'La Torre',
      0,
      'Pasado',
      'Lo que tenía que caer.',
      reversed: true,
    ),
    _card(
      'cinco-de-copas',
      'Cinco de Copas',
      1,
      'Presente',
      'Mirar solo lo derramado.',
      arcana: 'minor',
    ),
    _card('el-sol', 'El Sol', 2, 'Futuro', 'Claridad sencilla.'),
  ],
});

/// El fondo se mueve sin fin (ascuas, ondas…): no hay «quieto» que esperar.
/// Se dejan pasar los fotogramas de la animacion de pagina.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Donde estaban las tres cartas en la mesa, en pantalla.
const _fromTable = [
  Rect.fromLTWH(40, 380, 110, 176),
  Rect.fromLTWH(140, 380, 110, 176),
  Rect.fromLTWH(240, 380, 110, 176),
];

void main() {
  group('lectura revelada', () {
    late int closed, back;

    Future<void> pump(WidgetTester tester, {bool still = false}) async {
      closed = back = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: still,
            ),
            child: LecturaRevelada(
              reading: _reading,
              spread: _three,
              onCloseCircle: () => closed++,
              onBack: () => back++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    /// Abre la lectura con las cartas saliendo de la mesa, sin esperar.
    Future<void> open(WidgetTester tester, {bool still = false}) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: still,
            ),
            child: LecturaRevelada(
              reading: _reading,
              spread: _three,
              onCloseCircle: () {},
              onBack: () {},
              entrance: _fromTable,
            ),
          ),
        ),
      );
    }

    double readingOpacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(RevealPager),
                matching: find.byType(FadeTransition),
              )
              // la mas cercana: la de la lectura, no la de la ruta
              .first,
        )
        .opacity
        .value;

    testWidgets('las cartas vuelan de la mesa a la tirada mientras aparece', (
      tester,
    ) async {
      await open(tester);
      await tester.pump();
      // salen de donde estaban en la mesa, con la mesa aun a la vista
      final flying = find.byWidgetPredicate(
        (w) => w is TarotCardFaceArt && w.size.width == _fromTable[0].width,
      );
      expect(flying, findsWidgets);
      expect(readingOpacity(tester), lessThan(.2));
      expect(
        tester.getCenter(flying.first),
        offsetMoreOrLessEquals(_fromTable[0].center, epsilon: 1),
      );
      await settleFrames(tester);
      // al terminar ya no queda ninguna volando y la lectura se ve entera
      expect(
        find.byWidgetPredicate(
          (w) => w is TarotCardFaceArt && w.size.width > 104,
        ),
        findsNothing,
      );
      expect(readingOpacity(tester), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con «reducir movimiento» no vuelan: la lectura sale entera', (
      tester,
    ) async {
      await open(tester, still: true);
      await tester.pump();
      expect(readingOpacity(tester), 1);
      expect(
        find.byWidgetPredicate(
          (w) => w is TarotCardFaceArt && w.size.width == _fromTable[0].width,
        ),
        findsNothing,
      );
    });

    Future<void> swipeUp(WidgetTester tester) async {
      await tester.fling(find.byType(PageView), const Offset(0, -400), 1500);
      await settleFrames(tester);
    }

    testWidgets('empieza por la primera carta, con su posicion y su texto', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('La Torre'), findsOneWidget);
      expect(find.text('1 · PASADO'), findsOneWidget);
      expect(find.text('Lo que pesa en Pasado.'), findsOneWidget);
      expect(find.text('Lo que tenía que caer.'), findsOneWidget);
      expect(find.text('Invertida'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'1\. Pasado\. La Torre, invertida')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('deslizar pasa a la siguiente y la tirada de arriba la sigue', (
      tester,
    ) async {
      await pump(tester);
      await swipeUp(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Cinco de Copas'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Ir a 2, Presente'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });

    testWidgets('tocar un hueco de la tirada salta a su carta', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Ir a 3, Futuro'));
      await settleFrames(tester);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('El Sol'), findsOneWidget);
    });

    testWidgets('el minimapa acepta el toque cerca del hueco, no solo encima', (
      tester,
    ) async {
      // la caja era de 32 dp: por debajo de los 48 que pide un dedo
      await pump(tester);
      final c = tester.getCenter(find.bySemanticsLabel('Ir a 3, Futuro'));
      await tester.tapAt(c + const Offset(0, 22));
      await settleFrames(tester);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('en el cruce, tocar alterna entre la 1 y la 2', (tester) async {
      // GN2200: «Ir a 1» e «Ir a 2» compartian zona; el toque iba siempre a una
      final cross = SpreadDef.fromJson({
        'slug': 'cross',
        'name': 'Cruce',
        'card_scale': .56,
        'label_mode': 'number',
        'slots': [
          {'x': .3, 'y': .5, 'rotation': 0, 'name': 'Situación', 'meaning': ''},
          {'x': .3, 'y': .5, 'rotation': 90, 'name': 'Desafío', 'meaning': ''},
          {'x': .7, 'y': .5, 'rotation': 0, 'name': 'Raíz', 'meaning': ''},
        ],
      });
      final reading = Interpretation.fromJson({
        'spread': 'cross',
        'spread_name': 'Cruce',
        'read_at': '2026-10-02T21:14:00Z',
        'cards': [
          _card('la-torre', 'La Torre', 0, 'Situación', 'a'),
          _card('el-sol', 'El Sol', 1, 'Desafío', 'b'),
          _card('la-luna', 'La Luna', 2, 'Raíz', 'c'),
        ],
      });
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LecturaRevelada(
            reading: reading,
            spread: cross,
            onCloseCircle: () {},
            onBack: () {},
          ),
        ),
      );
      await settleFrames(tester);
      await tester.tap(find.bySemanticsLabel('Ir a 3, Raíz'));
      await settleFrames(tester);
      expect(find.text('3 / 3'), findsOneWidget);
      final at = tester.getCenter(find.bySemanticsLabel('Ir a 1, Situación'));
      await tester.tapAt(at);
      await settleFrames(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tapAt(at);
      await settleFrames(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tapAt(at);
      await settleFrames(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      // con lector: «Ir a 2» va a la 2 sin pasar por la 1
      await tester.tap(find.bySemanticsLabel('Ir a 3, Raíz'));
      await settleFrames(tester);
      tester.semantics.tap(find.semantics.byLabel('Ir a 2, Desafío'));
      await settleFrames(tester);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('la sintesis cierra el circulo solo manteniendo 1,3 s', (
      tester,
    ) async {
      await pump(tester);
      for (var i = 0; i < 3; i++) {
        await swipeUp(tester);
      }
      expect(find.text('Síntesis'), findsOneWidget);
      expect(find.text('«¿Sigo en este trabajo?»'), findsOneWidget);
      expect(find.textContaining('63 % iluminada'), findsOneWidget);

      final hold = find.byType(HoldToConfirm);
      await tester.tap(hold); // un toque corto no cierra nada
      await tester.pump(const Duration(seconds: 2));
      expect(closed, 0);

      // el anillo arranca cuando el toque se decide (unos 100 ms) y tarda 1,3 s
      Future<void> frames(int ms) async {
        for (var t = 0; t < ms; t += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      final g = await tester.startGesture(tester.getCenter(hold));
      await frames(800);
      expect(closed, 0);
      await frames(800);
      expect(closed, 1);
      await g.up();
    });

    testWidgets('volver a la mesa no cierra el circulo', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Volver a la mesa'));
      expect(back, 1);
      expect(closed, 0);
    });

    testWidgets('con «reducir movimiento» todo se ve sin animar', (
      tester,
    ) async {
      await pump(tester, still: true);
      // sin esperar a ninguna animacion, el texto ya esta del todo
      final opacities = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Lo que tenía que caer.'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity);
      expect(opacities, everyElement(1.0));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'en la mesa: interpretar abre la lectura y reabrirla no vuelve a cobrar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'tarot_table_help_seen': true});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = _Server();
      final c = ProviderContainer(
        overrides: [
          tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
          arcanumApiProvider.overrideWithValue(server),
          authProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(c.dispose);
      await tester.runAsync(() => c.read(tableControllerProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: TarotTableScreen()),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await settle();
      if (find.text('Entendido').evaluate().isNotEmpty) {
        await tester.tap(find.text('Entendido'));
        await settle();
      }
      // una carta en la tirada de una, desvelada: lista para interpretar
      final ops = c.read(tableControllerProvider.notifier);
      await tester.runAsync(() => ops.openDeck('rws'));
      ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
      final card = (await tester.runAsync(() => ops.take('p0', 0)))!;
      ops.arrange(
        (s) => s
            .putInSlot(card.slug, 0)
            .updateCard(card.slug, (k) => k.copyWith(faceUp: true)),
      );
      await settle();
      final dir = tester
          .widget<TarotTableView>(find.byType(TarotTableView))
          .director;
      expect(dir.readyToInterpret, isTrue);

      Future<void> tapEmbroidery() async {
        final at = dir.embroideryScreenRect.center;
        final g = await tester.startGesture(at);
        await g.up();
        // pasada la ventana del doble toque, es un toque
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 420)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await settle();
      }

      await tapEmbroidery();
      expect(find.text('INTERPRETACIÓN'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Interpretar'));
      await settle();
      expect(server.interprets, 1);
      expect(find.byType(LecturaRevelada), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      // GN2200: con la lectura encima, el lector seguia llegando a la mesa
      final deckLabel = RegExp(r'Rider–Waite–Smith, \d+ cartas');
      expect(find.semantics.byLabel(deckLabel), findsNothing);

      // atras vuelve a la mesa; el bordado la reabre sin cobrar otra vez
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LecturaRevelada), findsNothing);
      expect(find.semantics.byLabel(deckLabel), findsOne);
      await tapEmbroidery();
      expect(find.byType(LecturaRevelada), findsOneWidget);
      expect(server.interprets, 1);

      // ir al Oraculo y volver (08-oct): la pantalla se monta de nuevo, sin la
      // lectura en memoria. La mesa la tiene guardada: se abre sin el aviso
      // de cobro y sin volver a pedirla
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: TarotTableScreen()),
        ),
      );
      await settle();
      expect(find.byType(LecturaRevelada), findsNothing);
      await tapEmbroidery();
      expect(find.textContaining('gasta una lectura'), findsNothing);
      expect(find.byType(LecturaRevelada), findsOneWidget);
      expect(server.interprets, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Server extends FakeServer {
  int interprets = 0;

  @override
  Future<List<Map<String, dynamic>>> tarotDecks() async => [
    {
      'slug': 'rws',
      'name': 'Rider–Waite–Smith',
      'description': '',
      'allow_reversed': true,
      'art': 'rws',
      'card_count': 78,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> tarotSpreads() async => [
    {
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
    },
  ];

  @override
  Future<Map<String, dynamic>> tarotInterpret(
    String sessionId, {
    required String spread,
    required List<Map<String, dynamic>> placements,
    String? question,
    String? idempotencyKey,
  }) {
    interprets++;
    return super.tarotInterpret(
      sessionId,
      spread: spread,
      placements: placements,
      question: question,
      idempotencyKey: idempotencyKey,
    );
  }
}
