// Texto de las capas en trazos para el SVG exportado. Misma cadena de fuentes
// que el lienzo (Crimson Pro -> Noto Serif Hebrew -> ArcanumGlifos) y misma
// colocacion: centrado por el avance y base a kTextMid del cuerpo. Asi el SVG
// se ve igual que la app en cualquier programa, sin fuentes instaladas.
import 'js_num.dart';
import 'layers.dart';
import 'scene.dart';
import 'text_outlines.g.dart';

// selectores de variante (texto/emoji): no dibujan nada
const _invisible = {'\u{FE0E}', '\u{FE0F}'};

(OutlineFace, int, String)? _resolve(String ch, OutlineFace primary) {
  for (final f in [primary, kOutlineHeb, kOutlineSym]) {
    final g = f.glyphs[ch];
    if (g != null) return (f, g.$1, g.$2);
  }
  return null;
}

/// El texto como caminos, o null si algun caracter no esta en las fuentes
/// empaquetadas (entonces se deja como texto: mejor eso que un hueco).
String? textOutlineSVG(TextPrim t, String color, String opAttr) {
  final primary = t.font.startsWith('italic') ? kOutlineLatIt : kOutlineLat;
  final glyphs = <(OutlineFace, int, String)>[];
  for (final r in t.ch.runes) {
    final ch = String.fromCharCode(r);
    if (_invisible.contains(ch)) continue;
    final g = _resolve(ch, primary);
    if (g == null) return null;
    glyphs.add(g);
  }
  var width = 0.0;
  for (final (f, adv, _) in glyphs) {
    width += adv * t.size / f.upm;
  }
  final out = StringBuffer('<g transform="translate(${f2(t.x)} ${f2(t.y)}) rotate(${f2(t.rot)})" fill="$color"$opAttr>');
  var x = -width / 2;
  for (final (f, adv, d) in glyphs) {
    final s = t.size / f.upm;
    if (d.isNotEmpty) {
      out.write('<path transform="translate(${f2(x)} ${f2(t.size * kTextMid)}) scale(${s.toStringAsFixed(5)} ${(-s).toStringAsFixed(5)})" d="$d"/>');
    }
    x += adv * s;
  }
  out.write('</g>');
  return out.toString();
}
