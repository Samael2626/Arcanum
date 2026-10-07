import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/data/table_store.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeServer server;
  late ProviderContainer c;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(server),
      authProvider.overrideWith(_Auth.new),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeServer();
    c = container();
  });
  tearDown(() => c.dispose());

  TableController ctl() => c.read(tableControllerProvider.notifier);
  TableState st() => c.read(tableControllerProvider).value!;

  test('sin mesa en el servidor, la mesa arranca vacia', () async {
    final s = await c.read(tableControllerProvider.future);
    expect(s.hasTable, isFalse);
  });

  test(
    'abrir, cortar, sacar y devolver siguen la vista del servidor',
    () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      expect(st().server!.total, 6);
      expect(st().activePid, 'p0');

      final top = await ctl().cut('p0', 2);
      expect(top, 'p1');
      expect(st().piles.map((p) => p.pid), ['p0', 'p1']);

      final taken = await ctl().take('p0', 1);
      expect(taken.slug, 'c3');
      expect(st().card('c3'), isNotNull);
      expect(st().server!.piles['p0']!.positions, [0, 2, 3]);

      await ctl().giveBack('c3', 'p0');
      expect(st().card('c3'), isNull);
      expect(st().server!.total, 6);
    },
  );

  test('dos toques seguidos se aplican en orden', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    final results = await Future.wait([
      ctl().take('p0', 0),
      ctl().take('p0', 1),
      ctl().take('p0', 2),
    ]);
    expect(results.map((r) => r.slug), ['c0', 'c1', 'c2']);
    expect(st().cards.map((k) => k.slug), ['c0', 'c1', 'c2']);
    expect(st().card('c2')!.face.reversed, isTrue); // lo decide el servidor
  });

  test('deshacer vuelve a la disposicion anterior durante 5 s', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().take('p0', 0);
    var t = DateTime(2026, 9, 29, 12);
    ctl().now = () => t;

    ctl().arrange(
      (s) => s.updateCard('c0', (k) => k.copyWith(x: 42)),
      undoable: true,
    );
    expect(st().card('c0')!.x, 42);
    expect(ctl().canUndo, isTrue);
    expect(await ctl().undo(), isTrue);
    expect(st().card('c0')!.x, isNot(42));
    expect(await ctl().undo(), isFalse); // una sola vez

    ctl().arrange(
      (s) => s.updateCard('c0', (k) => k.copyWith(x: 7)),
      undoable: true,
    );
    t = t.add(const Duration(seconds: 6));
    expect(ctl().canUndo, isFalse);
    expect(await ctl().undo(), isFalse);
  });

  test('deshacer no resucita una carta que ya volvio al mazo', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().take('p0', 0);
    ctl().arrange((s) => s.putInSlot('c0', 0), undoable: true);
    await ctl().giveBack('c0', 'p0');
    // devolverla al mazo retira el deshacer local: ya no describe la mesa
    // (revision 06-oct). Y la carta, desde luego, no vuelve
    expect(await ctl().undo(), isFalse);
    expect(st().card('c0'), isNull);
  });

  group('deshacer en el servidor', () {
    test('un fallo no consume el checkpoint del gesto', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      ctl().beginUndoable();
      server.failNext = StateError('red');
      await expectLater(ctl().cut('p0', 2), throwsStateError);
      await ctl().take('p0', 0);
      ctl().commitUndoable();
      await ctl().flush();
      expect(server.checkpoints, [true]);
      expect(await ctl().undo(), isTrue);
      expect(st().server!.piles['p0']!.count, 6);
    });

    test(
      'un gesto con varias operaciones vuelve entero al mazo de antes',
      () async {
        await c.read(tableControllerProvider.future);
        await ctl().openDeck('rws');
        ctl().beginUndoable();
        final top = await ctl().cut('p0', 2);
        await ctl().merge(['p0', top], 'p0');
        ctl().commitUndoable();
        await ctl().flush();
        expect(server.checkpoints, [
          true,
          false,
        ]); // solo la primera marca punto
        expect(ctl().canUndo, isTrue);
        expect(await ctl().undo(), isTrue);
        expect(server.undos, 1);
        expect(st().piles.map((p) => p.pid), ['p0']);
        expect(st().server!.piles['p0']!.count, 6);
      },
    );

    test(
      'si el servidor avanza fuera del gesto, ese deshacer se retira',
      () async {
        await c.read(tableControllerProvider.future);
        await ctl().openDeck('rws');
        ctl().beginUndoable();
        await ctl().cut('p0', 2);
        ctl().commitUndoable();
        await ctl().shuffle('p0');
        expect(ctl().canUndo, isFalse);
        expect(server.undos, 0);
      },
    );

    test('un fallo fuera del gesto conserva el deshacer ofrecido', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      ctl().beginUndoable();
      await ctl().take('p0', 0);
      ctl().commitUndoable();
      await ctl().flush();
      server.failNext = StateError('red');
      await expectLater(ctl().shuffle('p0'), throwsStateError);
      expect(ctl().canUndo, isTrue);
      expect(await ctl().undo(), isTrue);
      expect(st().server!.piles['p0']!.count, 6);
    });

    test('un fallo al deshacer permite reintentar', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      ctl().beginUndoable();
      await ctl().take('p0', 0);
      ctl().commitUndoable();
      await ctl().flush();
      server.failUndo = StateError('red');
      await expectLater(ctl().undo(), throwsStateError);
      expect(ctl().canUndo, isTrue);
      expect(await ctl().undo(), isTrue);
      expect(st().server!.piles['p0']!.count, 6);
    });

    test('un gesto solo local no molesta al servidor al deshacerse', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      await ctl().take('p0', 0);
      ctl().arrange((s) => s.putInSlot('c0', 0), undoable: true);
      expect(await ctl().undo(), isTrue);
      expect(server.undos, 0);
    });
  });

  group('cerrar sin interpretar', () {
    test('manda la tirada, la pregunta y donde esta cada carta', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      await ctl().take('p0', 0);
      await ctl().take('p0', 2);
      ctl().arrange(
        (s) => s
            .copyWith(
              spread: () => 'three_card',
              seal: () => const Seal(text: '¿Y ahora?'),
            )
            .putInSlot('c0', 0)
            .putInSlot('c2', 1)
            .updateCard('c2', (k) => k.copyWith(turned: true)),
      );
      await ctl().closeCircle();
      expect(server.closedArgs, {
        'spread': 'three_card',
        'question': '¿Y ahora?',
        'placements': [
          {'slug': 'c0', 'slot': 0},
          {'slug': 'c2', 'slot': 1, 'turned': true},
        ],
      });
      // en la foto guardada el sello ya va abierto
      expect((server.closedWith!['seal'] as Map)['open'], isTrue);
      expect(st().hasTable, isFalse);
    });

    test(
      'sin tirada guarda las cartas sueltas y deja fuera las apartadas',
      () async {
        await c.read(tableControllerProvider.future);
        await ctl().openDeck('rws');
        await ctl().take('p0', 0);
        await ctl().take('p0', 1);
        ctl().arrange(
          (s) => s.updateCard('c1', (k) => k.copyWith(aside: true)),
        );
        await ctl().closeCircle();
        expect(server.closedArgs!['spread'], isNull);
        expect(server.closedArgs!['placements'], [
          {'slug': 'c0'},
        ]);
      },
    );
  });

  test(
    'continuar recoloca la mesa guardada con el sentido del servidor',
    () async {
      await c.read(tableControllerProvider.future);
      server.readings['r1'] = [('c3', true)];
      final saved = TableState(
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
            turned: true, // se giro al leerla: el servidor ya lo sabe
          ),
        ],
      ).toJson();
      await ctl().continueReading({'id': 'r1', 'table_snapshot': saved});
      final card = st().card('c3')!;
      expect(card.slot, 0);
      expect(card.faceUp, isTrue);
      expect(card.turned, isFalse);
      expect(card.face.reversed, isTrue);
      expect(card.reversed, isTrue); // se lee igual que cuando se guardo
      expect(st().spread, 'one_card');
      expect(st().server!.total, 5);
      expect(st().piles.single.x, 150);
    },
  );

  test('una lectura sin foto de mesa no se puede continuar', () async {
    await c.read(tableControllerProvider.future);
    expect(
      () => ctl().continueReading({'id': 'r9', 'table_snapshot': null}),
      throwsStateError,
    );
  });

  test(
    'interpretar manda huecos y pregunta sellada; cerrar deja la mesa vacia',
    () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      await ctl().take('p0', 0);
      ctl().arrange(
        (s) => s
            .copyWith(
              spread: () => 'one_card',
              seal: () => const Seal(text: '¿Qué viene?'),
            )
            .putInSlot('c0', 0)
            .updateCard('c0', (k) => k.copyWith(faceUp: true)),
      );
      final reading = await ctl().interpret();
      expect(reading.cards.single.position, 'Mensaje');
      expect(server.lastInterpret, {
        'spread': 'one_card',
        'placements': [
          {'slug': 'c0', 'slot': 0},
        ],
        'question': '¿Qué viene?',
      });
      expect(st().server!.status, 'interpreted');
      expect(st().seal!.open, isTrue);

      final saved = await ctl().closeCircle();
      expect(saved['id'], 'lectura-1');
      expect(server.closedWith!['spread'], 'one_card');
      expect(st().hasTable, isFalse);
    },
  );

  group('revision de codigo del 06-oct', () {
    Future<void> oneCardRead() async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      ctl().arrange((s) => s.copyWith(spread: () => 'one_card'));
      final card = await ctl().take('p0', 0);
      ctl().arrange((s) => s.putInSlot(card.slug, 0));
    }

    test(
      'interpretar no hace una llamada extra que pueda fallar tras cobrar',
      () async {
        await oneCardRead();
        final before = server.currentCalls;
        server.failCurrent = StateError('red');
        final r = await ctl().interpret();
        expect(r.cards, isNotEmpty);
        expect(server.currentCalls, before);
        expect(st().server!.status, 'interpreted');
        expect(st().server!.interpretation, isNotNull);
      },
    );

    test(
      'la foto del cierre no repite la interpretacion y lleva las posiciones',
      () async {
        await oneCardRead();
        await ctl().interpret();
        await ctl().closeCircle();
        final server0 = server.closedWith!['server'] as Map<String, dynamic>;
        expect(server0['interpretation'], isNull);
        expect(server.closedArgs!['spread'], 'one_card');
        expect(server.closedArgs!['placements'], isNotEmpty);
      },
    );

    test('sacar fuera de un gesto retira el deshacer local ofrecido', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      // extender el abanico ofrece deshacer (solo local)
      ctl().arrange(
        (s) => s.copyWith(
          fan: () => const FanLayout(
            pid: 'p0',
            start: Offset(470, 782),
            end: Offset(80, 782),
          ),
        ),
        undoable: true,
      );
      expect(ctl().canUndo, isTrue);
      await ctl().take('p0', 0);
      // deshacer ahora quitaria una carta que el servidor sigue contando fuera
      expect(ctl().canUndo, isFalse);
    });

    test('interpretar retira el deshacer del servidor', () async {
      await oneCardRead();
      ctl().beginUndoable();
      await ctl().shuffle('p0');
      ctl().commitUndoable();
      await ctl().interpret();
      expect(ctl().canUndo, isFalse);
    });

    test('un 409 al deshacer retira la oferta', () async {
      await oneCardRead();
      ctl().beginUndoable();
      await ctl().shuffle('p0');
      ctl().commitUndoable();
      await Future<void>.delayed(Duration.zero);
      server.previous = null; // el servidor ya no tiene a donde volver
      await expectLater(ctl().undo(), throwsA(isA<DioException>()));
      expect(ctl().canUndo, isFalse);
    });

    test('sin la foto local, las cartas sacadas se ven al volver', () async {
      await c.read(tableControllerProvider.future);
      await ctl().openDeck('rws');
      await ctl().take('p0', 0);
      await ctl().take('p0', 1);
      // la app murio antes de guardar: otro arranque sin foto local
      c.dispose();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      c = container();
      final s = await c.read(tableControllerProvider.future);
      expect({for (final k in s.cards) k.slug}, {'c0', 'c1'});
      expect(s.cards.first.face.nameEs, startsWith('Carta'));
    });
  });

  test('la mesa se guarda cifrada y se recupera al volver', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().take('p0', 4);
    ctl().arrange(
      (s) => s.copyWith(seal: () => const Seal(text: 'secreto de la mesa')),
    );
    await ctl().flush();

    final raw = (await SharedPreferences.getInstance()).getString(
      'tarot_table_v1_u1',
    )!;
    expect(raw, isNot(contains('secreto de la mesa')));
    // con comillas: el base64 del cifrado no las lleva, asi que no puede coincidir por azar
    expect(raw, isNot(contains('"slug":"c4"')));
    expect(jsonDecode(raw), containsPair('ciphertext', startsWith('v2:')));

    c.dispose();
    c = container();
    final back = await c.read(tableControllerProvider.future);
    expect(back.seal!.text, 'secreto de la mesa');
    expect(back.card('c4'), isNotNull);
  });

  test('si la mesa del servidor ya no es la guardada, no se mezclan', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().take('p0', 0);
    await ctl().flush();
    await server.tarotOpenTable('rws'); // otra mesa abierta desde otro sitio

    c.dispose();
    c = container();
    final back = await c.read(tableControllerProvider.future);
    expect(back.sessionId, 'mesa-2');
    expect(back.cards, isEmpty);
  });

  test('una mesa guardada que el servidor ya cerro se olvida', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().flush();
    server.status = 'closed';

    c.dispose();
    c = container();
    expect((await c.read(tableControllerProvider.future)).hasTable, isFalse);
    expect(await c.read(tableStoreProvider).load('u1'), isNull);
  });

  test('una foto que no se puede descifrar se descarta sin romper', () async {
    SharedPreferences.setMockInitialValues({
      'tarot_table_v1_u1': jsonEncode({
        'ciphertext': 'v2:basura',
        'iv': 'AAAAAAAAAAAAAAAA',
      }),
    });
    expect(await c.read(tableStoreProvider).load('u1'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tarot_table_v1_u1'), isNull);
  });

  test('borrar datos locales quita las mesas de todos los usuarios', () async {
    SharedPreferences.setMockInitialValues({
      'tarot_table_v1_u1': 'x',
      'tarot_table_v1_u2': 'y',
      'otra_cosa': 'z',
    });
    await clearTarotLocalData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'otra_cosa'});
  });
}
