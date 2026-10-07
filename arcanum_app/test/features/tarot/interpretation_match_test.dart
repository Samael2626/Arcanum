import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:flutter_test/flutter_test.dart';

Interpretation _reading(List<(String, int?, int?)> cards) =>
    Interpretation.fromJson({
      'spread': 'three_card',
      'spread_name': 'Tres cartas',
      'cards': [
        for (final (slug, slot, clarifies) in cards)
          {
            'slug': slug,
            'reversed': false,
            'slot': slot,
            'clarifies': clarifies,
            'position': 'p',
            'meaning': 'm',
          },
      ],
    });

TableState _table(List<(String, int?)> cards) => TableState(
  spread: 'three_card',
  cards: [
    for (final (slug, slot) in cards)
      TableCard(
        face: CardFace(slug: slug, reversed: false),
        slot: slot,
      ),
  ],
);

void main() {
  // GN2200 / revision 06-oct: tras recoger y hacer otra tirada, el bordado
  // reabria la interpretacion vieja como si fuera de las cartas nuevas
  test(
    'la interpretacion describe la mesa si las cartas siguen en su hueco',
    () {
      final r = _reading([('a', 0, null), ('b', 1, null), ('c', 2, null)]);
      expect(r.describes(_table([('c', 2), ('a', 0), ('b', 1)])), isTrue);
    },
  );

  test('otras cartas, u otros huecos, ya no son esa lectura', () {
    final r = _reading([('a', 0, null), ('b', 1, null), ('c', 2, null)]);
    expect(r.describes(_table([('x', 0), ('y', 1), ('z', 2)])), isFalse);
    expect(r.describes(_table([('b', 0), ('a', 1), ('c', 2)])), isFalse);
    expect(r.describes(_table([('a', 0), ('b', 1)])), isFalse);
  });
}
