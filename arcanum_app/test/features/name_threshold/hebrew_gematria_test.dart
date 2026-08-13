import 'package:arcanum_app/features/name_threshold/domain/hebrew_gematria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula valores hebreos conocidos con finales regulares', () {
    expect(HebrewGematria.calculate('דוד'), 14);
    expect(HebrewGematria.calculate('אברהם'), 248);
    expect(HebrewGematria.calculate('ךםןףץ'), 280);
  });

  test('ignora niqqud, geresh y puntuacion', () {
    expect(HebrewGematria.calculate('צ׳ָאבֶס'), 153);
  });

  test('misma forma produce mismo valor', () {
    const form = 'שמואל';
    expect(HebrewGematria.calculate(form), HebrewGematria.calculate(form));
    expect(HebrewGematria.calculate(form), 377);
  });
}
