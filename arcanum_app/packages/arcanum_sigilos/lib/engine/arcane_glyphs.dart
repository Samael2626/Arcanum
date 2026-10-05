// Glifos arcanos dibujados a trazo propio (puerto de js/glifos.js).
// No dependen de la fuente del sistema: Segoe UI Symbol no existe en Android.
// Caja 100x100, centro (50, 50). s = trazo, f = relleno. Dibujos de ARCANUM
// de simbolos estandar, no calcos de una fuente historica concreta.
import 'js_num.dart';

const double kGlyphBox = 100, kGlyphW = 7;

class ArcaneGlyph {
  final String? s, f;
  const ArcaneGlyph({this.s, this.f});
}

String _gc(int cx, int cy, int r) => 'M ${cx - r} $cy A $r $r 0 1 0 ${cx + r} $cy A $r $r 0 1 0 ${cx - r} $cy Z';

// brazo de la cruz patada, girado sobre el centro
String _patteeArm(double a) {
  String rt(double x, double y) {
    final c = cosD(a), s = sinD(a), u = x - 50, v = y - 50;
    return '${f2(50 + u * c - v * s)} ${f2(50 + u * s + v * c)}';
  }
  return 'M ${rt(50, 50)} L ${rt(33, 8)} Q ${rt(50, 16)} ${rt(67, 8)} Z';
}

const _triUp = 'M 50 12 L 90 82 L 10 82 Z', _triDown = 'M 10 18 L 90 18 L 50 88 Z';
final _mercury = ArcaneGlyph(s: 'M 34 10 C 36 26, 64 26, 66 10 ${_gc(50, 42, 17)} M 50 59 L 50 94 M 35 78 L 65 78');
final _pattee = [0.0, 90.0, 180.0, 270.0].map(_patteeArm).join(' ');

final Map<String, ArcaneGlyph> kArcaneGlyphs = {
  // planetas
  '♄': ArcaneGlyph(s: 'M 40 8 L 40 70 M 26 22 L 56 22 M 40 52 C 46 36, 70 36, 70 52 C 70 64, 58 70, 62 84 C 64 92, 72 92, 76 86'),
  '♃': ArcaneGlyph(s: 'M 22 32 C 26 14, 52 14, 50 32 C 48 46, 32 56, 22 66 L 84 66 M 66 14 L 66 92'),
  '♂': ArcaneGlyph(s: '${_gc(40, 60, 25)} M 58 42 L 86 14 M 62 14 L 86 14 L 86 38'),
  '☉': ArcaneGlyph(s: _gc(50, 50, 38), f: _gc(50, 50, 7)),
  '♀': ArcaneGlyph(s: '${_gc(50, 34, 24)} M 50 58 L 50 94 M 32 78 L 68 78'),
  '☿': _mercury,
  '☽': ArcaneGlyph(s: 'M 40 12 A 38 38 0 1 1 40 88 A 46 46 0 0 0 40 12 Z'),
  // zodiaco
  '♈': ArcaneGlyph(s: 'M 50 90 L 50 38 C 50 14, 16 10, 14 32 C 13 44, 26 48, 32 40 M 50 38 C 50 14, 84 10, 86 32 C 87 44, 74 48, 68 40'),
  '♉': ArcaneGlyph(s: '${_gc(50, 62, 24)} M 14 16 C 22 42, 78 42, 86 16'),
  '♊': ArcaneGlyph(s: 'M 36 24 L 36 76 M 64 24 L 64 76 M 16 16 Q 50 32 84 16 M 16 84 Q 50 68 84 84'),
  '♋': ArcaneGlyph(s: '${_gc(28, 38, 11)} M 28 27 C 48 18, 72 20, 88 32 ${_gc(72, 62, 11)} M 72 73 C 52 82, 28 80, 12 68'),
  '♌': ArcaneGlyph(s: '${_gc(28, 66, 13)} M 38 58 C 28 36, 40 14, 60 16 C 80 18, 78 40, 66 58 C 56 72, 60 88, 76 86 C 82 85, 86 80, 86 76'),
  '♍': ArcaneGlyph(s: 'M 12 26 L 12 80 M 12 36 C 14 22, 32 22, 32 36 L 32 80 M 32 36 C 34 22, 52 22, 52 36 L 52 70 C 52 86, 70 90, 80 76 C 88 62, 72 50, 62 62 C 54 72, 60 86, 70 94'),
  '♎': ArcaneGlyph(s: 'M 12 80 L 88 80 M 12 64 L 34 64 C 24 52, 28 30, 50 30 C 72 30, 76 52, 66 64 L 88 64'),
  '♏': ArcaneGlyph(s: 'M 10 26 L 10 78 M 10 36 C 12 22, 30 22, 30 36 L 30 78 M 30 36 C 32 22, 50 22, 50 36 L 50 70 C 50 82, 60 86, 72 80 L 88 72 M 76 64 L 88 72 L 82 84'),
  '♐': ArcaneGlyph(s: 'M 16 84 L 84 16 M 56 16 L 84 16 L 84 44 M 30 46 L 54 70'),
  '♑': ArcaneGlyph(s: 'M 10 24 L 26 70 L 38 26 C 44 20, 50 40, 52 60 C 54 78, 76 84, 82 68 C 88 52, 68 46, 60 60 C 54 72, 50 86, 38 92'),
  '♒': ArcaneGlyph(s: 'M 10 42 L 26 30 L 42 42 L 58 30 L 74 42 L 90 30 M 10 70 L 26 58 L 42 70 L 58 58 L 74 70 L 90 58'),
  '♓': ArcaneGlyph(s: 'M 22 12 C 44 32, 44 68, 22 88 M 78 12 C 56 32, 56 68, 78 88 M 24 50 L 76 50'),
  // elementos (triangulos alquimicos)
  '🜂': ArcaneGlyph(s: _triUp),
  '🜄': ArcaneGlyph(s: _triDown),
  '🜁': ArcaneGlyph(s: '$_triUp M 26 58 L 74 58'),
  '🜃': ArcaneGlyph(s: '$_triDown M 26 42 L 74 42'),
  // principios alquimicos
  '🜍': ArcaneGlyph(s: 'M 50 8 L 78 56 L 22 56 Z M 50 56 L 50 94 M 32 76 L 68 76'),
  '🜔': ArcaneGlyph(s: '${_gc(50, 50, 38)} M 12 50 L 88 50'),
  // nodos y aspectos
  '☊': ArcaneGlyph(s: 'M 28 74 L 28 48 C 28 18, 72 18, 72 48 L 72 74 ${_gc(22, 82, 9)} ${_gc(78, 82, 9)}'),
  '☋': ArcaneGlyph(s: 'M 28 26 L 28 52 C 28 82, 72 82, 72 52 L 72 26 ${_gc(22, 18, 9)} ${_gc(78, 18, 9)}'),
  '☌': ArcaneGlyph(s: '${_gc(38, 62, 22)} M 54 46 L 84 16'),
  '☍': ArcaneGlyph(s: '${_gc(24, 76, 13)} ${_gc(76, 24, 13)} M 33 67 L 67 33'),
  '△': ArcaneGlyph(s: 'M 50 16 L 86 80 L 14 80 Z'),
  '□': ArcaneGlyph(s: 'M 18 18 L 82 18 L 82 82 L 18 82 Z'),
  '⚹': ArcaneGlyph(s: 'M 50 10 L 50 90 M 15 30 L 85 70 M 15 70 L 85 30'),
  // signos
  '✦': ArcaneGlyph(f: 'M 50 6 C 54 40, 60 46, 94 50 C 60 54, 54 60, 50 94 C 46 60, 40 54, 6 50 C 40 46, 46 40, 50 6 Z'),
  '✧': ArcaneGlyph(s: 'M 50 8 C 54 40, 60 46, 92 50 C 60 54, 54 60, 50 92 C 46 60, 40 54, 8 50 C 40 46, 46 40, 50 8 Z'),
  '◎': ArcaneGlyph(s: '${_gc(50, 50, 38)} ${_gc(50, 50, 20)}'),
  '⊕': ArcaneGlyph(s: '${_gc(50, 50, 38)} M 50 12 L 50 88 M 12 50 L 88 50'),
  '✠': ArcaneGlyph(f: _pattee),
  '☥': ArcaneGlyph(s: 'M 50 46 C 32 36, 34 8, 50 8 C 66 8, 68 36, 50 46 Z M 50 46 L 50 94 M 24 54 L 76 54'),
};

// selectores de variante (texto o emoji) que acompañan a los simbolos
final _variation = RegExp('[${String.fromCharCode(0xfe0e)}${String.fromCharCode(0xfe0f)}]');
String glyphKey(String sym) => sym.replaceAll(_variation, '');
bool hasGlyph(String sym) => kArcaneGlyphs.containsKey(glyphKey(sym));

/// Simbolos arcanos del catalogo, por grupos, con su nombre (STAMP_CATALOG
/// del prototipo). Solo los 7 planetas clasicos, como el resto de ARCANUM.
const kStampCatalog = <(String, List<(String, String)>)>[
  ('Planetas', [('♄', 'Saturno'), ('♃', 'Júpiter'), ('♂', 'Marte'), ('☉', 'Sol'), ('♀', 'Venus'), ('☿', 'Mercurio'), ('☽', 'Luna')]),
  ('Zodiaco', [('♈', 'Aries'), ('♉', 'Tauro'), ('♊', 'Géminis'), ('♋', 'Cáncer'), ('♌', 'Leo'), ('♍', 'Virgo'), ('♎', 'Libra'), ('♏', 'Escorpio'), ('♐', 'Sagitario'), ('♑', 'Capricornio'), ('♒', 'Acuario'), ('♓', 'Piscis')]),
  ('Elementos', [('🜂', 'Fuego'), ('🜄', 'Agua'), ('🜁', 'Aire'), ('🜃', 'Tierra')]),
  ('Principios alquímicos', [('🜍', 'Azufre'), ('☿', 'Mercurio'), ('🜔', 'Sal')]),
  ('Nodos y aspectos', [('☊', 'Nodo norte'), ('☋', 'Nodo sur'), ('☌', 'Conjunción'), ('☍', 'Oposición'), ('△', 'Trígono'), ('□', 'Cuadratura'), ('⚹', 'Sextil')]),
  ('Signos', [('✦', 'Estrella'), ('✧', 'Estrella abierta'), ('◎', 'Círculo doble'), ('⊕', 'Cruz en círculo'), ('✠', 'Cruz patada'), ('☥', 'Anj')]),
];

String? stampName(String sym) {
  final k = glyphKey(sym);
  for (final (_, items) in kStampCatalog) {
    for (final (s, n) in items) {
      if (s == k) return n;
    }
  }
  return null;
}
