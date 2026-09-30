import 'dart:convert';

import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:flutter_test/flutter_test.dart';

ServerView view({
  Map<String, List<int>> piles = const {
    'p0': [0, 1, 2],
  },
  List<String> drawn = const [],
  String status = 'open',
}) => ServerView.fromJson({
  'id': 's1',
  'status': status,
  'deck': 'rws',
  'state': 'barajado · cascada',
  'total': piles.values.fold<int>(0, (a, p) => a + p.length),
  'piles': {
    for (final e in piles.entries)
      e.key: {'count': e.value.length, 'positions': e.value},
  },
  'drawn': [
    for (final s in drawn) {'slug': s, 'reversed': s.endsWith('r')},
  ],
  'expires_at': '2026-09-30T12:00:00Z',
});

TableCard card(String slug, {int? slot, String? host, bool up = true}) =>
    TableCard(
      face: CardFace(slug: slug, reversed: slug.endsWith('r')),
      slot: slot,
      host: host,
      faceUp: up,
    );

const three = SpreadDef(
  slug: 'three_card',
  name: 'Tres cartas',
  description: '',
  cardScale: .9,
  labelByName: true,
  slots: [
    SpreadSlotDef(x: .2, y: .5, rotation: 0, name: 'Pasado', meaning: 'a.'),
    SpreadSlotDef(x: .5, y: .5, rotation: 0, name: 'Presente', meaning: 'b.'),
    SpreadSlotDef(x: .8, y: .5, rotation: 0, name: 'Futuro', meaning: 'c.'),
  ],
);

void main() {
  group('foto de la mesa', () {
    final full = TableState(
      activePid: 'p0',
      piles: const [PileLayout(pid: 'p0', x: 300, y: 720)],
      fan: const FanLayout(
        pid: 'p0',
        start: Offset(300, 700),
        end: Offset(60, 700),
      ),
      cards: [
        card('a', slot: 0),
        card('b', host: 'a'),
        card('cr', up: false),
      ],
      spread: 'three_card',
      seal: const Seal(text: '¿Qué viene?'),
      camera: const TableCameraState(theta: 42, yaw: -12, zoom: 1.3),
    ).withServer(view(drawn: ['a', 'b', 'cr']));

    test('ida y vuelta por JSON sin perder nada', () {
      final json =
          jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>;
      final back = TableState.fromJson(json)!;
      expect(back.toJson(), full.toJson());
      expect(back.card('cr')!.face.reversed, isTrue);
      expect(back.card('b')!.host, 'a');
    });

    test('otra version o una foto rota se descartan', () {
      expect(TableState.fromJson({...full.toJson(), 'v': 99}), isNull);
      expect(
        TableState.fromJson({'v': TableState.version, 'cards': 3}),
        isNull,
      );
    });

    test(
      'la foto no comparte listas con la mesa viva (el fallo del prototipo)',
      () {
        final snap = full;
        final before = jsonEncode(snap.toJson());
        final after = full
            .putInSlot('cr', 2)
            .updateCard('a', (c) => c.copyWith(x: 10))
            .withServer(
              view(
                piles: {
                  'p0': [0],
                },
                drawn: ['a', 'cr'],
              ),
            );
        expect(jsonEncode(snap.toJson()), before);
        expect(after.card('b'), isNull);
        expect(() => snap.cards.add(card('z')), throwsUnsupportedError);
        expect(
          () => snap.server!.piles['p0']!.positions.add(9),
          throwsUnsupportedError,
        );
      },
    );
  });

  group('reconciliar con el servidor', () {
    final base = TableState(
      activePid: 'p0',
      piles: const [PileLayout(pid: 'p0', x: 300, y: 720)],
    ).withServer(view());

    test('un corte trae un monton nuevo junto al principal', () {
      final cut = base.withServer(
        view(
          piles: {
            'p0': [0],
            'p1': [0, 1],
          },
        ),
      );
      expect(cut.piles.map((p) => p.pid), ['p0', 'p1']);
      expect(cut.piles[1].x, greaterThan(cut.piles[0].x));
      expect(cut.piles[1].y, cut.piles[0].y);
    });

    test('al unir, el monton que desaparece se va y el abanico con el', () {
      final s = base
          .withServer(
            view(
              piles: {
                'p0': [0],
                'p1': [0, 1],
              },
            ),
          )
          .copyWith(
            fan: () => const FanLayout(
              pid: 'p1',
              start: Offset(300, 700),
              end: Offset(500, 700),
            ),
          )
          .withServer(
            view(
              piles: {
                'p0': [0, 1, 2],
              },
            ),
          );
      expect(s.piles.map((p) => p.pid), ['p0']);
      expect(s.fan, isNull);
    });

    test('si el monton principal desaparece, pasa a serlo el que queda', () {
      final s = base.withServer(
        view(
          piles: {
            'p1': [0],
          },
        ),
      );
      expect(s.activePid, 'p1');
    });

    test(
      'cartas devueltas al mazo salen de la mesa y sueltan sus aclaratorias',
      () {
        final s = base
            .withServer(view(drawn: ['a', 'b']))
            .addCard(card('a', slot: 0))
            .addCard(card('b', host: 'a'))
            .withServer(view(drawn: ['b']));
        expect(s.card('a'), isNull);
        expect(s.card('b')!.host, isNull);
      },
    );
  });

  group('tirada', () {
    final s = TableState(spread: 'three_card')
        .withServer(view(drawn: ['a', 'b', 'cr', 'd']))
        .addCard(card('a'))
        .addCard(card('b'))
        .addCard(card('cr'))
        .addCard(card('d'));

    test('poner en un hueco ocupado intercambia las cartas', () {
      final t = s.putInSlot('a', 0).putInSlot('b', 1).putInSlot('a', 1);
      expect(t.cardInSlot(1)!.slug, 'a');
      expect(t.cardInSlot(0)!.slug, 'b');
    });

    test(
      'lo que se manda a interpretar: huecos y aclaratorias, sin el sentido',
      () {
        final t = s
            .putInSlot('a', 0)
            .putInSlot('b', 1)
            .putInSlot('cr', 2)
            .clarify('d', 'b');
        expect(t.placements(), [
          {'slug': 'a', 'slot': 0},
          {'slug': 'b', 'slot': 1},
          {'slug': 'cr', 'slot': 2},
          {'slug': 'd', 'clarifies': 1},
        ]);
        expect(t.readyToInterpret(three), isTrue);
        final hidden = t.updateCard('cr', (c) => c.copyWith(faceUp: false));
        expect(hidden.readyToInterpret(three), isFalse);
        expect(t.putInSlot('d', 2).readyToInterpret(three), isTrue);
      },
    );

    test('girar una carta invierte su sentido y viaja al interpretar', () {
      final t = s
          .putInSlot('a', 0)
          .putInSlot('cr', 1)
          .updateCard('cr', (c) => c.copyWith(turned: true));
      expect(t.card('cr')!.face.reversed, isTrue);
      expect(t.card('cr')!.reversed, isFalse);
      expect(t.placements(), [
        {'slug': 'a', 'slot': 0},
        {'slug': 'cr', 'slot': 1, 'turned': true},
      ]);
      final back = TableState.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
      )!;
      expect(back.card('cr')!.turned, isTrue);
    });

    test('solo aclara a una carta que esta en un hueco', () {
      expect(s.clarify('d', 'a').card('d')!.host, isNull);
      expect(s.putInSlot('a', 0).clarify('a', 'a').card('a')!.host, isNull);
    });

    test('una aclaratoria que se pone en un hueco deja de aclarar', () {
      final t = s.putInSlot('a', 0).clarify('d', 'a').putInSlot('d', 1);
      expect(t.card('d')!.host, isNull);
      expect(t.card('d')!.slot, 1);
    });
  });
}
