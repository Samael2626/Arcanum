// Reduccion de la intencion a letras (metodo de la palabra).
// Procedencia de cada regla en el prototipo (REDUCTIONS, js/letras.js).

enum ReductionMethod { cooper, novowels, unique }

class Reduction {
  final String original, cleaned;
  final List<String> units;
  final ReductionMethod method;
  const Reduction(this.original, this.cleaned, this.units, this.method);

  String get label => switch (method) {
        ReductionMethod.cooper => 'Cooper — iniciales únicas',
        ReductionMethod.novowels => 'Únicas sin vocales',
        ReductionMethod.unique => 'Letras únicas',
      };
  String get rule => switch (method) {
        ReductionMethod.cooper => 'Inicial de cada palabra, sin repetir. Si quedan menos de 3, se completa con las letras únicas del texto [AR].',
        ReductionMethod.novowels => 'Se quitan vocales y repeticiones. Variante moderna, no receta exclusiva de Spare.',
        ReductionMethod.unique => 'Se tacha toda letra repetida (Spare; Frater U∴D∴, método de la palabra).',
      };
}

// Equivalente de normalize('NFD') + quitar marcas: solo las letras latinas que
// se descomponen. Las que no (Æ, Ø, ß) se quedan como en JS.
const _strip = {
  'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A', 'Ā': 'A', 'Ă': 'A', 'Ą': 'A',
  'Ç': 'C', 'Ć': 'C', 'Ĉ': 'C', 'Ċ': 'C', 'Č': 'C', 'Ď': 'D',
  'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E', 'Ē': 'E', 'Ĕ': 'E', 'Ė': 'E', 'Ę': 'E', 'Ě': 'E',
  'Ĝ': 'G', 'Ğ': 'G', 'Ġ': 'G', 'Ģ': 'G', 'Ĥ': 'H',
  'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I', 'Ĩ': 'I', 'Ī': 'I', 'Ĭ': 'I', 'Į': 'I', 'İ': 'I',
  'Ĵ': 'J', 'Ķ': 'K', 'Ĺ': 'L', 'Ļ': 'L', 'Ľ': 'L',
  'Ñ': 'N', 'Ń': 'N', 'Ņ': 'N', 'Ň': 'N',
  'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'Ō': 'O', 'Ŏ': 'O', 'Ő': 'O',
  'Ŕ': 'R', 'Ŗ': 'R', 'Ř': 'R', 'Ś': 'S', 'Ŝ': 'S', 'Ş': 'S', 'Š': 'S', 'Ţ': 'T', 'Ť': 'T',
  'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U', 'Ũ': 'U', 'Ū': 'U', 'Ŭ': 'U', 'Ů': 'U', 'Ű': 'U', 'Ų': 'U',
  'Ŵ': 'W', 'Ý': 'Y', 'Ŷ': 'Y', 'Ÿ': 'Y', 'Ź': 'Z', 'Ż': 'Z', 'Ž': 'Z',
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c', 'ď': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g', 'ĥ': 'h',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
  'ĵ': 'j', 'ķ': 'k', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ţ': 't', 'ť': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ŵ': 'w', 'ý': 'y', 'ÿ': 'y', 'ŷ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};
// toUpperCase de JS expande estas; el de Dart no (toLowerCase no las toca)
const _upperExpand = {'ß': 'SS', 'ﬀ': 'FF', 'ﬁ': 'FI', 'ﬂ': 'FL', 'ﬃ': 'FFI', 'ﬄ': 'FFL', 'ﬅ': 'ST', 'ﬆ': 'ST'};
final _combining = RegExp('[\u0300-\u036f]');
final _nonLetters = RegExp('[^A-Z]+');

/// normalize('NFD') + quitar marcas combinantes.
String stripMarks(String text) => text.split('').map((c) => _strip[c] ?? c).join().replaceAll(_combining, '');

/// toUpperCase con la semantica de JS.
String jsUpper(String text) => text.split('').map((c) => _upperExpand[c] ?? c).join().toUpperCase();

String foldLatin(String text) => jsUpper(stripMarks(text));

List<String> _uniq(Iterable<String> s) => <String>{...s}.toList();

Reduction reduce(String text, ReductionMethod method) {
  final words = foldLatin(text).split(_nonLetters).where((w) => w.isNotEmpty).toList();
  final cleaned = words.join();
  final chars = cleaned.split('');
  final List<String> units;
  switch (method) {
    case ReductionMethod.cooper:
      final initials = _uniq(words.map((w) => w[0]));
      units = initials.length < 3 ? _uniq([...initials, ...chars]) : initials;
    case ReductionMethod.novowels:
      units = _uniq(chars.where((c) => !'AEIOU'.contains(c)));
    case ReductionMethod.unique:
      units = _uniq(chars);
  }
  return Reduction(text, cleaned, units, method);
}
