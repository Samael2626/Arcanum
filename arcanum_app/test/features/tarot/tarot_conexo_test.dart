// Oraculo y Mesa enlazados, y las lecturas guardadas con puerta propia.
//
// Estudio de navegacion del 08-oct: el Oraculo y la Mesa no se enlazaban, y
// la mesa decia «La lectura quedo guardada en Lecturas» sin que nadie supiera
// donde estaban. Se prueba que cada enlace lleva a su ruta y que /lecturas
// lista y devuelve una lectura a la mesa.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/oraculo/oraculo_screen.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/reading/lectura_revelada.dart';
import 'package:arcanum_app/features/tarot/reading/readings_history.dart';
import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../apoyo/saldo_falso.dart';
import 'fakes.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

/// Mesa con catalogo, una tirada de una carta y lecturas guardadas.
class _Server extends FakeServer {
  List<Map<String, dynamic>> saved = [];

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
  Future<List<Map<String, dynamic>>> tarotReadings({int limit = 20}) async =>
      saved;

  @override
  Future<List<Map<String, dynamic>>> tarotList({
    String? arcana,
    String? suit,
  }) async => const [];
}

/// Lectura guardada de la mesa: con foto, se puede continuar.
Map<String, dynamic> _savedReading() => {
  'id': 'r1',
  'spread_type': 'one_card',
  'created_at': '2026-10-02T21:14:00Z',
  'question': '¿Sigo en este trabajo?',
  'table_snapshot': TableState(
    spread: 'one_card',
    activePid: 'p0',
    piles: const [PileLayout(pid: 'p0', x: 150, y: 700)],
    cards: [
      const TableCard(
        face: CardFace(slug: 'c3', reversed: false, name: 'c3'),
        x: 300,
        y: 416,
        slot: 0,
        faceUp: true,
      ),
    ],
  ).toJson(),
};

/// La mesa cuenta con relojes reales: se deja correr y luego se pinta.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

ProviderContainer _container(WidgetTester tester, _Server server) {
  SharedPreferences.setMockInitialValues({'tarot_table_help_seen': true});
  FlutterSecureStorage.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
      arcanumApiProvider.overrideWithValue(server),
      authProvider.overrideWith(_Auth.new),
      saldoProvider.overrideWith(() => SaldoFalso(creditos: 3)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<GoRouter> _app(
  WidgetTester tester,
  ProviderContainer c,
  String at,
  List<RouteBase> routes,
) async {
  final router = GoRouter(initialLocation: at, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return router;
}

GoRoute _stub(String path) => GoRoute(
  path: path,
  builder: (c, s) => Scaffold(body: Text('pantalla $path')),
);

void main() {
  testWidgets('el Oraculo ofrece «Tirar en la mesa» y abre /tarot', (
    tester,
  ) async {
    final c = _container(tester, _Server());
    final router = await _app(tester, c, '/oraculo', [
      GoRoute(
        path: '/oraculo',
        builder: (c, s) => const Scaffold(body: OraculoScreen()),
      ),
      _stub('/tarot'),
    ]);
    // debajo de «Consultar al oráculo»: la lista lo construye al llegar
    await tester.scrollUntilVisible(
      find.text('Tirar en la mesa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final link = find.widgetWithText(TextButton, 'Tirar en la mesa');
    expect(link, findsOneWidget);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(48));

    await tester.ensureVisible(link);
    await tester.tap(link);
    await _settle(tester);
    expect(find.text('pantalla /tarot'), findsOneWidget);
    // apilada: atras vuelve al Oraculo
    expect(router.canPop(), isTrue);
  });

  testWidgets('la sintesis de la lectura ofrece «Pregúntale al Oráculo»', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var asked = 0;
    final reading = Interpretation.fromJson({
      'spread': 'one_card',
      'spread_name': 'Una carta',
      'question': '¿Sigo?',
      'cards': [
        {
          'slug': 'el-sol',
          'name_es': 'El Sol',
          'arcana': 'major',
          'reversed': false,
          'slot': 0,
          'position': 'Mensaje',
          'meaning': 'Claridad sencilla.',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LecturaRevelada(
          reading: reading,
          spread: null,
          onCloseCircle: () {},
          onBack: () {},
          onAskOracle: () => asked++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Pregúntale al Oráculo'), findsNothing);
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1500);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final link = find.widgetWithText(TextButton, 'Pregúntale al Oráculo');
    expect(link, findsOneWidget);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
    await tester.tap(link);
    expect(asked, 1);
  });

  testWidgets('en la mesa, la lectura revelada lleva al Oraculo', (
    tester,
  ) async {
    final c = _container(tester, _Server());
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    await _app(tester, c, '/tarot', [
      GoRoute(path: '/tarot', builder: (c, s) => const TarotTableScreen()),
      _stub('/oraculo'),
    ]);
    // la ayuda de gestos sale la primera vez y tapa la mesa
    if (find.text('Entendido').evaluate().isNotEmpty) {
      await tester.tap(find.text('Entendido'));
      await _settle(tester);
    }
    final ops = c.read(tableControllerProvider.notifier);
    await tester.runAsync(() => ops.openDeck('rws'));
    ops.arrange((s) => s.copyWith(spread: () => 'one_card'));
    final card = (await tester.runAsync(() => ops.take('p0', 0)))!;
    ops.arrange(
      (s) => s
          .putInSlot(card.slug, 0)
          .updateCard(card.slug, (k) => k.copyWith(faceUp: true)),
    );
    await _settle(tester);
    final dir = tester
        .widget<TarotTableView>(find.byType(TarotTableView))
        .director;
    expect(dir.readyToInterpret, isTrue);
    final g = await tester.startGesture(dir.embroideryScreenRect.center);
    await g.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 420)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Interpretar'));
    await _settle(tester);
    expect(find.byType(LecturaRevelada), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1500);
    // el fondo no para nunca: se dejan pasar los fotogramas del pase de pagina
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.widgetWithText(TextButton, 'Pregúntale al Oráculo'));
    await _settle(tester);
    expect(find.text('pantalla /oraculo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('/lecturas', () {
    testWidgets('lista las lecturas guardadas con su tirada y pregunta', (
      tester,
    ) async {
      final server = _Server()..saved = [_savedReading()];
      final c = _container(tester, server);
      await _app(tester, c, '/lecturas', [
        GoRoute(
          path: '/lecturas',
          builder: (c, s) => const TarotReadingsScreen(),
        ),
      ]);
      expect(find.text('Tus lecturas'), findsOneWidget);
      expect(find.text('Una carta'), findsOneWidget);
      expect(find.textContaining('«¿Sigo en este trabajo?»'), findsOneWidget);
      final more = find.widgetWithText(TextButton, 'Continuar');
      expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
    });

    testWidgets('sin lecturas lo dice', (tester) async {
      final c = _container(tester, _Server());
      await _app(tester, c, '/lecturas', [
        GoRoute(
          path: '/lecturas',
          builder: (c, s) => const TarotReadingsScreen(),
        ),
      ]);
      expect(
        find.text('Todavía no has cerrado ningún círculo.'),
        findsOneWidget,
      );
    });

    testWidgets('«Continuar» abre la lectura en la mesa', (tester) async {
      final server = _Server()..saved = [_savedReading()];
      server.readings['r1'] = [('c3', true)];
      final c = _container(tester, server);
      await tester.runAsync(() => c.read(tableControllerProvider.future));
      final router = await _app(tester, c, '/lecturas', [
        GoRoute(
          path: '/lecturas',
          builder: (c, s) => const TarotReadingsScreen(),
        ),
        GoRoute(
          path: '/tarot',
          builder: (c, s) => TarotTableScreen(
            continueFrom: s.extra is Map<String, dynamic>
                ? s.extra! as Map<String, dynamic>
                : null,
          ),
        ),
      ]);
      await tester.tap(find.widgetWithText(TextButton, 'Continuar'));
      await _settle(tester);
      await _settle(tester);
      expect(find.byType(TarotTableScreen), findsOneWidget);
      expect(server.opened, 1, reason: 'abre mesa nueva desde la lectura');
      final table = c.read(tableControllerProvider).value!;
      expect(table.card('c3')?.slot, 0);
      expect(router.canPop(), isTrue, reason: 'atras vuelve a Lecturas');
      expect(tester.takeException(), isNull);
    });
  });
}
