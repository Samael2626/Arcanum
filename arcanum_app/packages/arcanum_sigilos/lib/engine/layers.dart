// Capas de presentacion: marcos, anillos con nombre, estrellas, inscripciones,
// rotulos y simbolos, apilados (puerto de js/capas.js). Los marcos se anidan
// solos: cada uno entra en el hueco del anterior y el sigilo va en el hueco
// final. Una sola geometria (lista de primitivas) sirve al lienzo y al SVG.
import 'dart:math' as math;

import 'arcane_glyphs.dart';
import 'hebrew.dart';
import 'js_num.dart';
import 'letter_sigil.dart' show kC, kDefaultContentR, kSize;
import 'reduction.dart';

enum LayerType {
  circle('Círculo', true),
  square('Cuadrado', true),
  triangle('Triángulo', true),
  ringLatin('Anillo latino', true),
  ringHebrew('Anillo hebreo', true),
  star('Estrella', true),
  inscription('Inscripción', true),
  caption('Rótulo', false),
  symbol('Símbolo', false);

  final String label;
  final bool nested;
  const LayerType(this.label, this.nested);
}

const kStampSize = 56.0;
const _ringSeps = {'dot': '·', 'cross': '✠'};
const kPlanetGlyph = {'saturn': '♄', 'jupiter': '♃', 'mars': '♂', 'sun': '☉', 'venus': '♀', 'mercury': '☿', 'moon': '☽'};
const _starStep = {5: 2, 6: 2, 7: 3, 8: 3, 9: 4};
final _vs15 = String.fromCharCode(0xfe0e);

/// Radio interior de la estrella {n/k} exacta (pentagrama 0,382...).
double starRatio(int n, int k) => math.cos(math.pi * k / n) / math.cos(math.pi * (k - 1) / n);

/// Una capa. Los campos que no usa su tipo se ignoran (como en el prototipo).
class Layer {
  final String id;
  final LayerType type;
  bool visible;
  double scale, rot, dx, dy, width, opacity;
  // anillos
  String text, sep, symbol;
  // estrella
  int points;
  String shape;
  double inner;
  bool chords, contain;
  // inscripcion
  String pos;
  double size, spacing;
  // rotulo
  String title, sub;
  // simbolo
  String sym;
  double x, y;

  Layer(this.id, this.type, {this.visible = true, this.scale = 100, this.rot = 0, this.dx = 0, this.dy = 0, this.width = 3,
      this.opacity = 100, this.text = '', this.sep = 'none', this.symbol = '', this.points = 5, this.shape = 'sharp',
      this.inner = 50, this.chords = true, this.contain = false, this.pos = 'upperArc', this.size = 22, this.spacing = 4,
      this.title = '', this.sub = '', String? sym, this.x = kC, this.y = 120})
      : sym = sym ?? '♄$_vs15';

  /// Valores por defecto de cada tipo (LAYER_DEFAULTS de newLayer).
  factory Layer.create(String id, LayerType type) => switch (type) {
        LayerType.circle || LayerType.square || LayerType.triangle => Layer(id, type, opacity: 70),
        LayerType.ringHebrew => Layer(id, type, sep: 'dot'),
        LayerType.star => Layer(id, type, width: 2.5, opacity: 70),
        LayerType.inscription => Layer(id, type, opacity: 90),
        LayerType.symbol => Layer(id, type, size: kStampSize),
        _ => Layer(id, type),
      };

  bool get isNested => type.nested && !(type == LayerType.inscription && (pos == 'top' || pos == 'bottom'));
  String get name => type.label + (type == LayerType.star ? ' $points' : type == LayerType.symbol ? ' $sym' : '');

  Map<String, Object> toJson() => {
        'id': id, 'type': type.name, 'visible': visible, 'scale': scale, 'rot': rot, 'dx': dx, 'dy': dy, 'width': width,
        'opacity': opacity, 'text': text, 'sep': sep, 'symbol': symbol, 'points': points, 'shape': shape, 'inner': inner,
        'chords': chords, 'contain': contain, 'pos': pos, 'size': size, 'spacing': spacing, 'title': title, 'sub': sub,
        'sym': sym, 'x': x, 'y': y,
      };

  /// Lee una capa del prototipo o de un guardado: lo que falta toma el defecto del tipo.
  factory Layer.fromJson(Map<String, dynamic> j) {
    final l = Layer.create(j['id'] as String, LayerType.values.byName(j['type'] as String));
    double d(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    return l
      ..visible = j['visible'] as bool? ?? l.visible
      ..scale = d('scale', l.scale)
      ..rot = d('rot', l.rot)
      ..dx = d('dx', l.dx)
      ..dy = d('dy', l.dy)
      ..width = d('width', l.width)
      ..opacity = d('opacity', l.opacity)
      ..text = j['text'] as String? ?? l.text
      ..sep = j['sep'] as String? ?? l.sep
      ..symbol = j['symbol'] as String? ?? l.symbol
      ..points = (j['points'] as num?)?.toInt() ?? l.points
      ..shape = j['shape'] as String? ?? l.shape
      ..inner = d('inner', l.inner)
      ..chords = j['chords'] as bool? ?? l.chords
      ..contain = j['contain'] as bool? ?? l.contain
      ..pos = j['pos'] as String? ?? l.pos
      ..size = d('size', l.size)
      ..spacing = d('spacing', l.spacing)
      ..title = j['title'] as String? ?? l.title
      ..sub = j['sub'] as String? ?? l.sub
      ..sym = j['sym'] as String? ?? l.sym
      ..x = d('x', l.x)
      ..y = d('y', l.y);
  }
}

/// Texto por defecto de las capas: la intencion (letras) o el nombre (sello).
class LayerCtx {
  final String text, title, sub;
  final String? planet;
  const LayerCtx({this.text = '', this.planet, this.title = '', this.sub = ''});
  /// Sigilo de letras: el texto por defecto son las letras reducidas, nunca la
  /// intencion (el dibujo se comparte y la intencion es privada).
  factory LayerCtx.letters(String letters) => LayerCtx(text: letters, title: letters);
}

// ── Primitivas de capa ──────────────────────────────────────────
sealed class LayerPrim {
  final double op;
  const LayerPrim(this.op);
}

final class CirclePrim extends LayerPrim {
  final double cx, cy, r, w;
  const CirclePrim(this.cx, this.cy, this.r, this.w, super.op);
}

final class PolyPrim extends LayerPrim {
  final List<(double, double)> pts;
  final bool closed;
  final double w;
  const PolyPrim(this.pts, this.closed, this.w, super.op);
}

final class TextPrim extends LayerPrim {
  final double x, y, rot, size;
  final String ch, font;
  final bool alignStart;
  const TextPrim(this.x, this.y, this.rot, this.size, this.ch, this.font, super.op, {this.alignStart = false});
}

final class GlyphLayerPrim extends LayerPrim {
  final double x, y, rot, size;
  final String ch;
  const GlyphLayerPrim(this.x, this.y, this.rot, this.size, this.ch, super.op);
}

class LayerGeom {
  final List<LayerPrim> prims = [];
  double inner;
  (double, double) center;
  final List<(double, double)> vertices = [];
  final List<(double, double, double)> radii = [];
  LayerGeom(this.inner, this.center);
}

const kSymbolFont = 'Segoe UI Symbol, serif';
const kLatFont = 'Georgia, serif', kHebFont = 'Arial Hebrew, Segoe UI, serif';

(double, double) _rotPt(double x, double y, double cx, double cy, double deg) {
  final c = cosD(deg), s = sinD(deg), u = x - cx, v = y - cy;
  return (cx + u * c - v * s, cy + u * s + v * c);
}

String? _ringSymbol(Layer l, LayerCtx ctx) {
  if (l.symbol.isEmpty) return null;
  final pid = l.symbol == 'auto' ? ctx.planet : l.symbol;
  final g = pid == null ? null : kPlanetGlyph[pid];
  return g == null ? null : '$g$_vs15';
}

final _hebChar = RegExp('[א-ת]');

// Letras repartidas por un circulo, empezando arriba (giro incluido); el hebreo
// avanza en sentido antihorario porque se lee de derecha a izquierda
List<LayerPrim> _circleText(List<String> items, double cx, double cy, double r, double size, int dir, double rot, double op) {
  final n = items.isEmpty ? 1 : items.length;
  return [
    for (var i = 0; i < items.length; i++)
      () {
        final a = -90 + rot + dir * i * 360 / n;
        final x = cx + cosD(a) * r, y = cy + sinD(a) * r, ch = items[i];
        if (hasGlyph(ch)) return GlyphLayerPrim(x, y, a + 90, size * 1.05, ch, op);
        return TextPrim(x, y, a + 90, size, ch, _hebChar.hasMatch(ch) ? kHebFont : kLatFont, op);
      }(),
  ];
}

final _notAZ = RegExp('[^A-Z]');

/// Geometria de una capa: primitivas, hueco interior y puntos para las guias.
LayerGeom layerGeom(Layer l, double big, LayerCtx ctx) {
  final cx = kC + l.dx, cy = kC + l.dy, op = l.opacity / 100, w = l.width;
  final out = LayerGeom(big, (cx, cy));
  final r0 = big;
  switch (l.type) {
    case LayerType.circle:
      out.prims.add(CirclePrim(cx, cy, r0, w, op));
      out.inner = r0 - 14;
      out.radii.add((cx, cy, r0));
    case LayerType.square:
      final h = r0 / math.sqrt2;
      final pts = [(-h, -h), (h, -h), (h, h), (-h, h)].map((p) => _rotPt(cx + p.$1, cy + p.$2, cx, cy, l.rot)).toList();
      out.prims.add(PolyPrim(pts, true, w, op));
      out.vertices.addAll(pts);
      out.inner = h - 12;
    case LayerType.triangle:
      final pts = [-90.0, 30.0, 150.0].map((a) => _rotPt(cx + cosD(a) * r0, cy + sinD(a) * r0, cx, cy, l.rot)).toList();
      out.prims.add(PolyPrim(pts, true, w, op));
      out.vertices.addAll(pts);
      out.inner = r0 / 2 - 10;
    case LayerType.ringLatin || LayerType.ringHebrew:
      final heb = l.type == LayerType.ringHebrew, s = r0 / (heb ? 338 : 334), wf = w / 3;
      final rings = heb ? const [(338.0, 3.0), (328.0, 1.5), (258.0, 3.0)] : const [(334.0, 4.0), (262.0, 4.0)];
      for (final (r, ww) in rings) {
        out.prims.add(CirclePrim(cx, cy, r * s, ww * wf, op));
        out.radii.add((cx, cy, r * s));
      }
      final t = l.text.trim().isNotEmpty ? l.text.trim() : ctx.text;
      List<String> items;
      if (heb) {
        final hw = (hasHebrew(t) ? cleanHebrew(t) : transliterate(t, TranslitMethod.consonantal).hebrew).split(' ').where((x) => x.isNotEmpty).toList();
        final sep = _ringSeps[l.sep] ?? '·';
        items = [for (var i = 0; i < hw.length; i++) ...[if (i > 0) sep, ...hw[i].split('')]];
      } else {
        final letters = foldLatin(t).replaceAll(_notAZ, '').split('');
        final sep = _ringSeps[l.sep];
        items = sep == null ? letters : [for (var i = 0; i < letters.length; i++) ...[if (i > 0) sep, letters[i]]];
      }
      final sym = _ringSymbol(l, ctx);
      if (sym != null) items = [sym, ...items];
      final size = math.max(18.0, math.min(heb ? 34.0 : 40.0, (heb ? 620 : 700) / (items.isEmpty ? 1 : items.length))) * s;
      final tr = (heb ? 293 : 298) * s;
      out.prims.addAll(_circleText(items, cx, cy, tr, size, heb ? -1 : 1, l.rot, op));
      out.radii.add((cx, cy, tr));
      out.inner = (heb ? 258 : 262) * s - 14;
    case LayerType.star:
      final n = l.points, k = _starStep[n]!;
      final rIn = l.shape == 'wide' ? r0 * l.inner / 100 : r0 * starRatio(n, k);
      final a0 = rad(l.rot) - math.pi / 2;
      final pts = [
        for (var i = 0; i < n * 2; i++)
          (cx + math.cos(a0 + i * math.pi / n) * (i.isOdd ? rIn : r0), cy + math.sin(a0 + i * math.pi / n) * (i.isOdd ? rIn : r0)),
      ];
      out.prims.add(PolyPrim(pts, true, w, op));
      final tips = [for (var i = 0; i < pts.length; i += 2) pts[i]];
      if (l.chords) {
        for (var j = 0; j < tips.length; j++) {
          out.prims.add(PolyPrim([tips[j], tips[(j + k) % n]], false, w / 2, op * .6));
        }
      }
      out.vertices.addAll(pts);
      out.radii.add((cx, cy, r0));
      // si contiene, lo de dentro cabe en el poligono central; si no, se cruza
      out.inner = l.contain ? rIn * math.cos(math.pi / n) - 6 : r0 * .72;
    case LayerType.inscription:
      final txt = jsUpper(l.text.trim().isNotEmpty ? l.text.trim() : ctx.text).runes.map(String.fromCharCode).toList();
      final adv = l.size * .62 + l.spacing;
      if (l.pos == 'top' || l.pos == 'bottom') {
        final y = (l.pos == 'top' ? l.size * 1.1 : kSize - l.size * 1.1) + l.dy, x0 = kC + l.dx - (txt.length - 1) * adv / 2;
        for (var i = 0; i < txt.length; i++) { out.prims.add(TextPrim(x0 + i * adv, y, 0, l.size, txt[i], kLatFont, op)); }
        out.center = (kC + l.dx, y);
        break;
      }
      final r = r0 - l.size * .6, arc = math.min(2.4, txt.length * adv / math.max(r, 1)), lower = l.pos == 'lowerArc';
      for (var i = 0; i < txt.length; i++) {
        final t = txt.length == 1 ? .5 : i / (txt.length - 1);
        final a = (lower ? math.pi / 2 + arc / 2 - arc * t : -math.pi / 2 - arc / 2 + arc * t) + rad(l.rot);
        out.prims.add(TextPrim(cx + math.cos(a) * r, cy + math.sin(a) * r, (lower ? a - math.pi / 2 : a + math.pi / 2) * 180 / math.pi, l.size, txt[i], kLatFont, op));
      }
      out.radii.add((cx, cy, r));
      out.inner = r0 - l.size * 1.4;
    case LayerType.caption:
      final title = l.title.trim().isNotEmpty ? l.title.trim() : ctx.title, sub = l.sub.trim().isNotEmpty ? l.sub.trim() : ctx.sub;
      if (title.isNotEmpty) out.prims.add(TextPrim(kC + l.dx, 64 + l.dy, 0, 28, title, 'italic', op));
      if (sub.isNotEmpty) out.prims.add(TextPrim(kC + l.dx, kSize - 42 + l.dy, 0, 17, sub, kSymbolFont, op * .8));
      out.center = (kC + l.dx, 64 + l.dy);
    case LayerType.symbol:
      out.prims.add(hasGlyph(l.sym) ? GlyphLayerPrim(l.x, l.y, l.rot, l.size, l.sym, op) : TextPrim(l.x, l.y, l.rot, l.size, l.sym, kSymbolFont, op));
      out.center = (l.x, l.y);
  }
  return out;
}

class LayerPart {
  final Layer layer;
  final LayerGeom g;
  final double? r;
  const LayerPart(this.layer, this.g, this.r);
}

class LayerLayout {
  final List<LayerPart> parts;
  final double contentR;
  const LayerLayout(this.parts, this.contentR);
}

/// Pila completa: cada marco se encaja en el hueco del anterior.
LayerLayout layoutLayers(List<Layer> layers, LayerCtx ctx) {
  var avail = kDefaultContentR;
  final parts = <LayerPart>[];
  for (final l in layers) {
    if (!l.visible) continue;
    if (l.isNested) {
      final r = avail * l.scale / 100, g = layerGeom(l, r, ctx);
      parts.add(LayerPart(l, g, r));
      avail = math.max(24, g.inner);
    } else {
      parts.add(LayerPart(l, layerGeom(l, 0, ctx), null));
    }
  }
  // con rotulo, el sigilo deja sitio arriba y abajo
  if (parts.any((p) => p.layer.type == LayerType.caption)) avail = math.min(avail, 285);
  return LayerLayout(parts, avail);
}
