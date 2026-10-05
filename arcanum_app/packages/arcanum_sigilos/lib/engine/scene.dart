// Escena: una sola lista de dibujo para el lienzo y para el SVG (puerto de
// js/escena.js y de los emisores de js/capas.js y js/glifos.js). Lo que se ve
// es lo que se exporta; las marcas de edicion no son obra y no entran aqui.
import 'arcane_glyphs.dart';
import 'js_num.dart';
import 'layers.dart';

/// Centro optico de una linea de texto respecto de su base (fraccion del cuerpo).
const kTextMid = .35;

/// Degradado: lineal (x1..y2) o radial (cx, cy, r). stops: (offset, color, opacidad).
class Grad {
  final String id, type;
  final double x1, y1, x2, y2, cx, cy, r;
  final List<(double, String, double)> stops;
  const Grad.linear(this.id, this.x1, this.y1, this.x2, this.y2, this.stops) : type = 'linear', cx = 0, cy = 0, r = 0;
  const Grad.radial(this.id, this.cx, this.cy, this.r, this.stops) : type = 'radial', x1 = 0, y1 = 0, x2 = 0, y2 = 0;
}

/// Trazo de un grupo de camino: stroke (por defecto), relleno o degradado.
class PathItem {
  final String d;
  final bool fill;
  final double? op;
  final List<String>? units;
  final Grad? grad;

  /// Degradado a lo largo del trazo (Rosa-Cruz con colores). Solo lo pinta el
  /// lienzo: el SVG de esa familia lo escribe su propio emisor.
  final Grad? strokeGrad;
  const PathItem(this.d, {this.fill = false, this.op, this.units, this.grad, this.strokeGrad});
}

/// Grupo de la escena. Lleva caminos (items) o primitivas de capa (prims).
class SceneGroup {
  final String layer, color;
  final double? w, op, dx, dy, scale;

  /// Ancho base de los halos cuando el trazo real no es un `stroke` (la pluma).
  final double? hw;
  final String? cap;
  final bool sigil;
  final List<PathItem> items;
  final List<LayerPrim>? prims;
  const SceneGroup({required this.layer, required this.color, this.w, this.op, this.dx, this.dy, this.scale, this.hw, this.cap, this.sigil = false, this.items = const [], this.prims});

  bool get isEmpty => prims != null ? prims!.isEmpty : items.isEmpty;

  SceneGroup copyWith({String? layer, String? color, double? w, double? op, double? dx, double? dy, double? scale}) => SceneGroup(
      layer: layer ?? this.layer, color: color ?? this.color, w: w ?? this.w, op: op ?? this.op, dx: dx ?? this.dx, dy: dy ?? this.dy, scale: scale ?? this.scale, hw: hw,
      cap: cap, sigil: sigil, items: items, prims: prims);
}

String esc(String s) => s.replaceAllMapped(RegExp('[&<>"\']'), (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'}[m[0]]!);

/// `+x.toFixed(n)` de JS: redondea y luego escribe el numero sin ceros sobrantes.
String jsFixedNum(double v, int n) => jsNum(double.parse((v == 0 ? 0.0 : v).toStringAsFixed(n)));

String glyphSVG(String sym, double x, double y, double size, double rot, String color, [double op = 1, String attrs = '']) {
  final g = kArcaneGlyphs[glyphKey(sym)]!, k = size / kGlyphBox;
  // toFixed de JS: -0 se escribe 0 (f2 lo respeta)
  final o = op < 1 ? ' opacity="${f2(op)}"' : '';
  return '<g data-glyph="${glyphKey(sym)}" transform="translate(${f2(x)} ${f2(y)}) rotate(${f2(rot)}) scale(${(k == 0 ? 0.0 : k).toStringAsFixed(4)}) translate(-50 -50)"$o$attrs>'
      '${g.s != null ? '<path d="${g.s}" fill="none" stroke="$color" stroke-width="${jsNum(kGlyphW)}" stroke-linecap="round" stroke-linejoin="round"/>' : ''}'
      '${g.f != null ? '<path d="${g.f}" fill="$color" stroke="none"/>' : ''}</g>';
}

String primsSVG(List<LayerPrim> prims, String color) => prims.map((p) {
      final o = p.op < 1 ? ' opacity="${f2(p.op)}"' : '';
      return switch (p) {
        CirclePrim c => '<circle cx="${f2(c.cx)}" cy="${f2(c.cy)}" r="${f2(c.r)}" fill="none" stroke="$color" stroke-width="${f2(c.w)}"$o/>',
        PolyPrim q => '<path d="M ${q.pts.map((v) => '${f2(v.$1)} ${f2(v.$2)}').join(' L ')}${q.closed ? ' Z' : ''}" fill="none" stroke="$color" stroke-width="${f2(q.w)}" stroke-linejoin="round" stroke-linecap="round"$o/>',
        GlyphLayerPrim g => glyphSVG(g.ch, g.x, g.y, g.size, g.rot, color, g.op),
        TextPrim t => () {
            final italic = t.font.startsWith('italic');
            return '<text transform="translate(${f2(t.x)} ${f2(t.y)}) rotate(${f2(t.rot)})" y="${f2(t.size * kTextMid)}" text-anchor="middle" font-family="${italic ? 'Georgia, serif' : t.font}"${italic ? ' font-style="italic"' : ''} font-size="${f2(t.size)}" fill="$color"$o>${esc(t.ch)}</text>';
          }(),
      };
    }).join();

LayerPrim _withOp(LayerPrim p, double k) => switch (p) {
      CirclePrim c => CirclePrim(c.cx, c.cy, c.r, c.w, c.op * k),
      PolyPrim q => PolyPrim(q.pts, q.closed, q.w, q.op * k),
      TextPrim t => TextPrim(t.x, t.y, t.rot, t.size, t.ch, t.font, t.op * k),
      GlyphLayerPrim g => GlyphLayerPrim(g.x, g.y, g.rot, g.size, g.ch, g.op * k),
    };

String _stopNum(double v) => jsNum(v);

String _gradSVG(Grad gr) {
  final stops = gr.stops.map((s) => '<stop offset="${_stopNum(s.$1)}" stop-color="${s.$2}"${s.$3 < 1 ? ' stop-opacity="${_stopNum(s.$3)}"' : ''}/>').join();
  return gr.type == 'radial'
      ? '<radialGradient id="${gr.id}" gradientUnits="userSpaceOnUse" cx="${jsNum(gr.cx)}" cy="${jsNum(gr.cy)}" r="${jsNum(gr.r)}">$stops</radialGradient>'
      : '<linearGradient id="${gr.id}" gradientUnits="userSpaceOnUse" x1="${jsNum(gr.x1)}" y1="${jsNum(gr.y1)}" x2="${jsNum(gr.x2)}" y2="${jsNum(gr.y2)}">$stops</linearGradient>';
}

String _opAttr(double? op) => op != null && op < 1 ? ' opacity="${jsFixedNum(op, 3)}"' : '';

String groupSVG(SceneGroup g) {
  final dx = g.dx ?? 0, dy = g.dy ?? 0;
  final tf = dx != 0 || dy != 0 || g.scale != null ? ' transform="translate(${jsNum(dx)} ${jsNum(dy)})${g.scale == null ? '' : ' scale(${g.scale!.toStringAsFixed(4)})'}"' : '';
  final gop = g.op ?? 1;
  if (g.prims != null) {
    return '<g data-layer="${g.layer}"$tf>${primsSVG(gop < 1 ? g.prims!.map((p) => _withOp(p, gop)).toList() : g.prims!, g.color)}</g>';
  }
  final sq = g.cap == 'square', defs = <String>[];
  final body = g.items.map((it) {
    final op = _opAttr(gop * (it.op ?? 1));
    if (it.grad != null) {
      defs.add(_gradSVG(it.grad!));
      return '<path d="${it.d}" fill="url(#${it.grad!.id})" stroke="none"$op/>';
    }
    return it.fill ? '<path d="${it.d}" fill="${g.color}" stroke="none"$op/>' : '<path d="${it.d}"$op/>';
  }).join();
  final w = g.w;
  final stroke = w != null && w != 0
      ? ' fill="none" stroke="${g.color}" stroke-width="${jsFixedNum(w, 2)}" stroke-linecap="${sq ? 'square' : 'round'}" stroke-linejoin="${sq ? 'miter' : 'round'}"'
      : '';
  return '<g data-layer="${g.layer}"$stroke$tf>${defs.isNotEmpty ? '<defs>${defs.join()}</defs>' : ''}$body</g>';
}

String sceneSVG(List<SceneGroup> groups) => groups.map(groupSVG).join();
