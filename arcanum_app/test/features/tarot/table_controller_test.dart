import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/data/table_store.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
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
    expect(ctl().undo(), isTrue);
    expect(st().card('c0')!.x, isNot(42));
    expect(ctl().undo(), isFalse); // una sola vez

    ctl().arrange(
      (s) => s.updateCard('c0', (k) => k.copyWith(x: 7)),
      undoable: true,
    );
    t = t.add(const Duration(seconds: 6));
    expect(ctl().canUndo, isFalse);
    expect(ctl().undo(), isFalse);
  });

  test('deshacer no resucita una carta que ya volvio al mazo', () async {
    await c.read(tableControllerProvider.future);
    await ctl().openDeck('rws');
    await ctl().take('p0', 0);
    ctl().arrange((s) => s.putInSlot('c0', 0), undoable: true);
    await ctl().giveBack('c0', 'p0');
    expect(ctl().undo(), isTrue);
    expect(st().card('c0'), isNull);
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
