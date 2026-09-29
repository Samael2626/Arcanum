// Transliteracion latin -> hebreo (puerto de js/rosa.js).
// Reconstruccion [RC]: la Golden Dawn trabaja con nombres ya escritos en
// hebreo; por eso el resultado siempre se puede corregir a mano. Los nombres
// de origen hebreo usan su grafia biblica (Samuel = שמואל, 1 S 1:20).
import 'reduction.dart';

enum TranslitMethod { consonantal, full }

const _latCons = {
  'sh': 'ש', 'ch': 'ח', 'th': 'ת', 'tz': 'צ', 'ts': 'צ', 'ph': 'פ', 'b': 'ב', 'c': 'כ', 'd': 'ד', 'f': 'פ', 'g': 'ג',
  'h': 'ה', 'j': 'י', 'k': 'כ', 'l': 'ל', 'm': 'מ', 'n': 'נ', 'p': 'פ', 'q': 'ק', 'r': 'ר', 's': 'ס', 't': 'ט',
  'v': 'ו', 'w': 'ו', 'x': 'כס', 'z': 'ז',
};
const _latFullVowels = {'a': 'א', 'e': 'י', 'i': 'י', 'y': 'י', 'o': 'ע', 'u': 'ו'};
// las claves largas primero (sh antes que s)
final _latKeys = _latCons.keys.toList()..sort((a, b) => b.length - a.length);
const _baseToFinal = {'כ': 'ך', 'מ': 'ם', 'נ': 'ן', 'פ': 'ף', 'צ': 'ץ'};

const kHebrewNames = {
  'samuel': 'שמואל', 'miguel': 'מיכאל', 'gabriel': 'גבריאל', 'rafael': 'רפאל', 'daniel': 'דניאל', 'david': 'דוד',
  'jose': 'יוסף', 'maria': 'מרים', 'miriam': 'מרים', 'juan': 'יוחנן', 'ana': 'חנה', 'sara': 'שרה', 'elias': 'אליהו',
  'adan': 'אדם', 'eva': 'חוה', 'isabel': 'אלישבע', 'elisabet': 'אלישבע', 'jacob': 'יעקב', 'jacobo': 'יעקב',
  'isaias': 'ישעיהו', 'jeremias': 'ירמיהו', 'salomon': 'שלמה', 'abraham': 'אברהם', 'isaac': 'יצחק', 'moises': 'משה',
  'josue': 'יהושע', 'natanael': 'נתנאל', 'manuel': 'עמנואל', 'emanuel': 'עמנואל', 'matias': 'מתתיהו', 'mateo': 'מתתיהו',
  'rut': 'רות', 'ester': 'אסתר', 'debora': 'דבורה', 'judit': 'יהודית', 'simon': 'שמעון', 'benjamin': 'בנימין', 'jonas': 'יונה',
};

class TranslitToken {
  final String latin;
  String he, note;
  TranslitToken(this.latin, this.he, [this.note = '']);
}

bool _isVowel(String c) => 'aeiouy'.contains(c);
final _doubled = RegExp(r'([b-df-hj-np-tv-z])\1+');

List<TranslitToken> _translitWord(String word, TranslitMethod method) {
  final w = method == TranslitMethod.consonantal ? word.replaceAllMapped(_doubled, (m) => m[1]!) : word;
  final out = <TranslitToken>[];
  var i = 0;
  while (i < w.length) {
    final c = w[i], first = i == 0, last = i == w.length - 1;
    if (_isVowel(c)) {
      var he = '', note = '';
      if (method == TranslitMethod.full) {
        he = _latFullVowels[c]!;
      } else if (first) {
        he = c == 'i' || c == 'y' ? 'י' : 'א';
        note = 'vocal inicial';
      } else if (c == 'i' || c == 'y') {
        he = 'י';
      } else if (c == 'o' || c == 'u') {
        he = 'ו';
      } else if (c == 'a' && last) {
        he = 'ה';
        note = 'a final';
      } else {
        note = 'vocal no escrita';
      }
      out.add(TranslitToken(c, he, note));
      i++;
      continue;
    }
    final k = _latKeys.where((k0) => w.startsWith(k0, i)).firstOrNull;
    if (k == null) {
      out.add(TranslitToken(c, '', 'sin correspondencia'));
      i++;
      continue;
    }
    var he = _latCons[k]!;
    // c suave ante e/i suena s. Como en el prototipo, una c final tambien da
    // ס ('ei'.includes('') es true en JS): rareza pendiente de revisar alli
    if (k == 'c' && method == TranslitMethod.consonantal && (i + 1 >= w.length || 'ei'.contains(w[i + 1]))) he = 'ס';
    out.add(TranslitToken(k, he));
    i += k.length;
  }
  // forma final en la ultima letra escrita
  for (var j = out.length - 1; j >= 0; j--) {
    if (out[j].he.isEmpty) continue;
    final hs = out[j].he.split(''), lastHe = hs.last;
    final fin = _baseToFinal[lastHe];
    if (fin != null) {
      hs[hs.length - 1] = fin;
      out[j].he = hs.join();
      out[j].note = '${out[j].note.isNotEmpty ? '${out[j].note}, ' : ''}forma final';
    }
    break;
  }
  return out;
}

class Transliteration {
  final List<TranslitToken> tokens;
  final String hebrew;
  const Transliteration(this.tokens, this.hebrew);
}

final _nonAz = RegExp('[^a-z]+');

Transliteration transliterate(String name, TranslitMethod method) {
  final words = stripMarks(name).toLowerCase().split(_nonAz).where((w) => w.isNotEmpty).toList();
  final tokens = <TranslitToken>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (i > 0) tokens.add(TranslitToken(' ', ' '));
    final bib = method == TranslitMethod.consonantal ? kHebrewNames[w] : null;
    if (bib != null) {
      tokens.add(TranslitToken(w, bib, 'nombre bíblico: grafía hebrea original'));
    } else {
      tokens.addAll(_translitWord(w, method));
    }
  }
  return Transliteration(tokens, tokens.map((t) => t.he).join());
}

final _hebLetter = RegExp('[א-ת]');
// puntos vocalicos y cantilacion (U+0591..U+05C7)
final _hebMarks = RegExp('[${String.fromCharCode(0x591)}-${String.fromCharCode(0x5c7)}]');
final _notHeb = RegExp('[^א-ת ]');
final _spaces = RegExp(r'\s+');

bool hasHebrew(String s) => _hebLetter.hasMatch(s);
String cleanHebrew(String s) => s.replaceAll(_hebMarks, '').replaceAll(_notHeb, '').replaceAll(_spaces, ' ').trim();
