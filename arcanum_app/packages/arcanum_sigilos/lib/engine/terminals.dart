// Remates en las puntas libres de los trazos (terminalShapes, freeEnds y
// terminalList del prototipo). Procedencia en kTerminals.
import 'dart:math' as math;

import 'geometry.dart';
import 'js_num.dart';
import 'letter_sigil.dart';

const double kLineW = 7;

class TerminalDef {
  final String id, name;

  /// HP fuente historica, OM ocultismo moderno, AR decision de ARCANUM.
  final String? tag;
  const TerminalDef(this.id, this.name, [this.tag]);
}

// Anillo: el rasgo mas comun en los sellos de la Goetia. Cruz y cruz patada:
// 17 % de los terminales de los 72 sellos. El resto, repertorio del taller.
const kTerminals = [
  TerminalDef('none', 'Ninguno'),
  TerminalDef('dot', 'Punto', 'OM'),
  TerminalDef('ring', 'Anillo', 'HP'),
  TerminalDef('bar', 'Barra', 'HP'),
  TerminalDef('cross', 'Cruz', 'HP'),
  TerminalDef('pattee', 'Cruz patada', 'HP'),
  TerminalDef('botonnee', 'Cruz botonada', 'AR'),
  TerminalDef('arrow', 'Flecha', 'AR'),
  TerminalDef('point', 'Punta', 'AR'),
  TerminalDef('lance', 'Lanza', 'AR'),
  TerminalDef('trident', 'Tridente', 'AR'),
  TerminalDef('crescent', 'Media luna', 'AR'),
  TerminalDef('star', 'Estrella', 'AR'),
  TerminalDef('hook', 'Gancho', 'AR'),
];

/// Extremo de un trazo con su direccion hacia fuera (ox, oy).
class End extends Pt {
  final double ox, oy;
  final String key;
  End(super.x, super.y, this.ox, this.oy) : key = '${r2(x)},${r2(y)}';
}

List<End> primEnds(Prim p) {
  if (p is LinePrim) {
    final len = hypot(p.b.x - p.a.x, p.b.y - p.a.y);
    final d = len == 0 ? 1.0 : len, ux = (p.b.x - p.a.x) / d, uy = (p.b.y - p.a.y) / d;
    return [End(p.a.x, p.a.y, -ux, -uy), End(p.b.x, p.b.y, ux, uy)];
  }
  final a = p as ArcPrim;
  if (a.a1 - a.a0 >= 359.5) return const [];
  Pt at(double deg) => Pt(a.c.x + cosD(deg) * a.r, a.c.y + sinD(deg) * a.r);
  final s = at(a.a0), e = at(a.a1);
  return [End(s.x, s.y, sinD(a.a0), -cosD(a.a0)), End(e.x, e.y, -sinD(a.a1), cosD(a.a1))];
}

double distToPrim(Pt pt, Prim p) {
  if (p is LinePrim) {
    final dx = p.b.x - p.a.x, dy = p.b.y - p.a.y, l2 = dx * dx + dy * dy;
    final t = l2 != 0 ? math.max(0.0, math.min(1.0, ((pt.x - p.a.x) * dx + (pt.y - p.a.y) * dy) / l2)) : 0.0;
    return hypot(pt.x - p.a.x - t * dx, pt.y - p.a.y - t * dy);
  }
  final a = p as ArcPrim;
  final ang = math.atan2(pt.y - a.c.y, pt.x - a.c.x) * 180 / math.pi;
  if (jsRem(jsRem(ang - a.a0, 360) + 360, 360) <= a.a1 - a.a0) return (hypot(pt.x - a.c.x, pt.y - a.c.y) - a.r).abs();
  return primEnds(a).map((e) => hypot(pt.x - e.x, pt.y - e.y)).reduce(math.min);
}

/// Los brazos de la cruz son composicion: no llevan remates.
List<End> freeEnds(List<Prim> visible) {
  final out = <End>[];
  for (var i = 0; i < visible.length; i++) {
    final p = visible[i];
    if (p.kind == 'cross') continue;
    for (final e in primEnds(p)) {
      var touched = false;
      for (var j = 0; j < visible.length && !touched; j++) {
        if (j != i && distToPrim(e, visible[j]) < .03) touched = true;
      }
      if (!touched) out.add(e);
    }
  }
  return out;
}

class TerminalShape {
  final String d;
  final bool fill;
  const TerminalShape(this.d, this.fill);
}

/// Geometria de un remate en coordenadas de lienzo: q punta, o hacia fuera,
/// s tamano. Devuelve paths SVG (el lienzo los pinta con los mismos paths).
List<TerminalShape> terminalShapes(Pt q, Pt o, String style, double s) {
  final n = Pt(-o.y, o.x);
  List<double> P(double a, [double b = 0]) => [q.x + o.x * a + n.x * b, q.y + o.y * a + n.y * b];
  String pt(List<double> v) => '${f2(v[0])} ${f2(v[1])}';
  String poly(List<List<double>> pts, [bool close = true]) => 'M ${pts.map(pt).join(' L ')}${close ? ' Z' : ''}';
  String circle(List<double> c, double r) =>
      'M ${f2(c[0] + r)} ${f2(c[1])} A ${f2(r)} ${f2(r)} 0 1 0 ${f2(c[0] - r)} ${f2(c[1])} A ${f2(r)} ${f2(r)} 0 1 0 ${f2(c[0] + r)} ${f2(c[1])} Z';
  TerminalShape line(List<double> a, List<double> b) => TerminalShape(poly([a, b], false), false);
  switch (style) {
    case 'dot':
      return [TerminalShape(circle(P(0), s * .55), true)];
    case 'ring':
      return [TerminalShape(circle(P(s * .6), s * .6), false)];
    case 'bar':
      return [line(P(0, -s), P(0, s))];
    case 'cross':
      return [line(P(0), P(s * 1.8)), line(P(s * .9, -s * .9), P(s * .9, s * .9))];
    case 'pattee':
      // cuatro brazos que se ensanchan hacia fuera; el trasero toca la punta
      final len = s * 1.05, c = s * 1.05, w0 = s * .14, w1 = s * .95;
      return [
        for (final (a, b) in const [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)])
          () {
            List<double> Q(double t, double w) => P(c + a * t - b * w, b * t + a * w);
            return TerminalShape(poly([Q(0, -w0), Q(len, -w1 / 2), Q(len, w1 / 2), Q(0, w0)]), true);
          }(),
      ];
    case 'botonnee':
      return [
        line(P(0), P(s * 1.6)), line(P(s * .8, -s * .8), P(s * .8, s * .8)),
        TerminalShape(circle(P(s * 1.75), s * .28), true), TerminalShape(circle(P(s * .8, -s * .95), s * .28), true),
        TerminalShape(circle(P(s * .8, s * .95), s * .28), true),
      ];
    case 'arrow':
      return [line(P(0), P(s * 1.2)), TerminalShape(poly([P(s * .35, -s * .75), P(s * 1.2), P(s * .35, s * .75)], false), false)];
    case 'point':
      return [TerminalShape(poly([P(-s * .1, -s * .7), P(s * 1.2), P(-s * .1, s * .7)]), true)];
    case 'lance':
      return [TerminalShape(poly([P(0), P(s * .7, -s * .45), P(s * 1.7), P(s * .7, s * .45)]), true)];
    case 'trident':
      return [
        line(P(0), P(s * 1.5)),
        TerminalShape(poly([P(s * 1.3, -s * .85), P(s * .45, -s * .85), P(s * .45, s * .85), P(s * 1.3, s * .85)], false), false),
      ];
    case 'crescent':
      return [TerminalShape('M ${pt(P(s * .9, s * .9))} C ${pt(P(-s * .3, s * .9))} ${pt(P(-s * .3, -s * .9))} ${pt(P(s * .9, -s * .9))}', false)];
    case 'star':
      // estrella de 5 puntas con una punta hacia el trazo
      final c = P(s * 1.05), base = math.atan2(-o.y, -o.x);
      return [
        TerminalShape(poly([
          for (var i = 0; i < 10; i++)
            [c[0] + math.cos(base + i * math.pi / 5) * (i.isOdd ? s * .42 : s * 1.05), c[1] + math.sin(base + i * math.pi / 5) * (i.isOdd ? s * .42 : s * 1.05)],
        ]), true),
      ];
    case 'hook':
      return [TerminalShape('M ${pt(P(0))} C ${pt(P(s * 1.3))} ${pt(P(s * 1.5, s * 1.2))} ${pt(P(s * .5, s * 1.1))}', false)];
    default:
      return const [];
  }
}

class TerminalMark {
  final End e;
  final String style;
  final List<TerminalShape> shapes;
  const TerminalMark(this.e, this.style, this.shapes);
}

/// Remates de todos los extremos libres: estilo por extremo o el general.
List<TerminalMark> terminalList(LetterSigil sg, List<Prim> visible, {required String general, Map<String, String> perEnd = const {}, double scale = 100}) {
  final s = kLineW * 3 * scale / 100;
  return [
    for (final e in freeEnds(visible))
      if ((perEnd[e.key] ?? general) != 'none')
        TerminalMark(e, perEnd[e.key] ?? general, terminalShapes(sg.view!.toCanvas(e), Pt(e.ox, e.oy), perEnd[e.key] ?? general, s)),
  ];
}
