import 'package:arcanum_app/features/oraculo/tarot_learn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tarotCardName', () {
    test('capitaliza el nombre desde el slug', () {
      expect(tarotCardName('el-sol'), 'El Sol');
      expect(tarotCardName('la-sacerdotisa'), 'La Sacerdotisa');
      expect(tarotCardName('la-rueda'), 'La Rueda');
    });

    test('deja los conectores en minúscula, salvo si abren', () {
      expect(tarotCardName('dos-de-copas'), 'Dos de Copas');
      expect(tarotCardName('as-de-oros'), 'As de Oros');
      expect(tarotCardName('caballero-de-espadas'), 'Caballero de Espadas');
    });

    test('un slug de una sola palabra se capitaliza', () {
      expect(tarotCardName('templanza'), 'Templanza');
    });
  });
}
