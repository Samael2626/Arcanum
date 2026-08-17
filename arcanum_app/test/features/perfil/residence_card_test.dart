import 'package:arcanum_app/features/perfil/residence_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('qué lugar se muestra en el perfil', () {
    test('con residencia declarada se muestra esa', () {
      expect(
        residenceLabelOf({'current_city': 'Madrid, España'}),
        'Madrid, España',
      );
    });

    test('sin residencia no se inventa una', () {
      // El hueco vacío significa "vivo donde nací", y la tarjeta lo dice con
      // esas palabras. Rellenarlo con la ciudad de nacimiento aquí haría creer
      // que la persona la declaró como residencia.
      for (final user in <Map<String, dynamic>?>[
        null,
        {},
        {'current_city': null},
        {'current_city': ''},
        {'current_city': '   '},
      ]) {
        expect(residenceLabelOf(user), isNull, reason: '$user');
      }
    });

    test('la ciudad de nacimiento se lee aparte, para poder explicarla', () {
      expect(birthLabelOf({'birth_city': 'Bogotá'}), 'Bogotá');
      expect(birthLabelOf({'birth_city': ''}), isNull);
      expect(birthLabelOf(null), isNull);
    });

    test('residencia y nacimiento son campos independientes', () {
      // El bug que esto previene: que declarar residencia pisara el lugar de
      // nacimiento y con él la carta natal.
      final user = {'birth_city': 'Bogotá', 'current_city': 'Madrid, España'};
      expect(birthLabelOf(user), 'Bogotá');
      expect(residenceLabelOf(user), 'Madrid, España');
    });
  });
}
