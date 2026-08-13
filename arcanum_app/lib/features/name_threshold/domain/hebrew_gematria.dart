import 'reading_identity.dart';

class HebrewGematria {
  static const methodVersion = 'mispar-hechrechi-1.0.0';

  static const values = <String, int>{
    'א': 1,
    'ב': 2,
    'ג': 3,
    'ד': 4,
    'ה': 5,
    'ו': 6,
    'ז': 7,
    'ח': 8,
    'ט': 9,
    'י': 10,
    'כ': 20,
    'ך': 20,
    'ל': 30,
    'מ': 40,
    'ם': 40,
    'נ': 50,
    'ן': 50,
    'ס': 60,
    'ע': 70,
    'פ': 80,
    'ף': 80,
    'צ': 90,
    'ץ': 90,
    'ק': 100,
    'ר': 200,
    'ש': 300,
    'ת': 400,
  };

  static List<GematriaLetter> breakdown(String text) => text.runes
      .map(String.fromCharCode)
      .where(values.containsKey)
      .map((glyph) => GematriaLetter(glyph, values[glyph]!))
      .toList(growable: false);

  static int calculate(String text) =>
      breakdown(text).fold(0, (total, letter) => total + letter.value);

  static String normalizeBase(String text) =>
      text.runes.map(String.fromCharCode).where(values.containsKey).join();
}
