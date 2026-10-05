// Primitivas del sigilo de letras: segmentos y arcos en coordenadas de mundo
// (caja de letra 1x1, y hacia abajo). Cada trazo guarda de que letras sale.
import 'js_num.dart';

class Pt {
  final double x, y;
  const Pt(this.x, this.y);
}

/// Primitiva de un glifo en su caja 1x1 (antes de colocarlo).
sealed class GlyphPrim {
  const GlyphPrim();
}

final class GLine extends GlyphPrim {
  final double x1, y1, x2, y2;
  const GLine(this.x1, this.y1, this.x2, this.y2);
}

/// Arco con angulos en grados, en sentido horario (convencion canvas/SVG).
final class GArc extends GlyphPrim {
  final double cx, cy, r, a0, a1;
  const GArc(this.cx, this.cy, this.r, this.a0, this.a1);
}

/// Trazo colocado en el mundo.
sealed class Prim {
  final List<String> units;

  /// 'cross' para los brazos de la cruz (composicion, no letra).
  final String? kind;
  String key = '';
  bool hidden = false;
  Prim(this.units, this.kind);

  Prim copyWith({List<String>? units, String? kind});
}

final class LinePrim extends Prim {
  final Pt a, b;
  LinePrim(this.a, this.b, super.units, [super.kind]);

  @override
  LinePrim copyWith({List<String>? units, String? kind}) =>
      LinePrim(a, b, units ?? [...this.units], kind ?? this.kind);
}

final class ArcPrim extends Prim {
  final Pt c;
  final double r, a0, a1;
  ArcPrim(this.c, this.r, this.a0, this.a1, super.units, [super.kind]);

  @override
  ArcPrim copyWith({List<String>? units, String? kind}) =>
      ArcPrim(c, r, a0, a1, units ?? [...this.units], kind ?? this.kind);

  bool get full => a1 - a0 >= 359.5;
}

/// Transformacion de una letra: reflejo, giro (horario) y escala alrededor del
/// centro de la caja; luego traslacion a (tx, ty).
class Xf {
  final double tx, ty, s, rot;
  final bool fx, fy;
  const Xf({this.tx = .5, this.ty = .5, this.s = 1, this.rot = 0, this.fx = false, this.fy = false});

  static const identity = Xf();
}

Pt xform(double x, double y, Xf t) {
  var u = x - .5, v = y - .5;
  if (t.fx) u = -u;
  if (t.fy) v = -v;
  final c = cosD(t.rot), s = sinD(t.rot);
  return Pt(t.tx + (u * c - v * s) * t.s, t.ty + (u * s + v * c) * t.s);
}

double xformAngle(double a, Xf t) {
  if (t.fx) a = 180 - a;
  if (t.fy) a = -a;
  return a + t.rot;
}

ArcPrim normArc(Pt c, double r, double a0, double a1, List<String> units, [String? kind]) {
  final span = (a1 - a0).abs() < 360 ? (a1 - a0).abs() : 360.0;
  final lo = jsRem(jsRem(a0 < a1 ? a0 : a1, 360) + 360, 360);
  return ArcPrim(c, r, lo, lo + span, units, kind);
}

Prim placePrim(GlyphPrim pr, Xf t, List<String> units) => switch (pr) {
      GLine l => LinePrim(xform(l.x1, l.y1, t), xform(l.x2, l.y2, t), [...units]),
      GArc a => normArc(xform(a.cx, a.cy, t), a.r * t.s, xformAngle(a.a0, t), xformAngle(a.a1, t), [...units]),
    };

double primLength(Prim p) => switch (p) {
      LinePrim l => hypot(l.b.x - l.a.x, l.b.y - l.a.y),
      ArcPrim a => a.r * rad(a.a1 - a.a0),
    };

double totalLength(Iterable<Prim> ps) => ps.fold(0.0, (acc, p) => acc + primLength(p));

List<Pt> primPoints(Prim p) {
  if (p is LinePrim) return [p.a, p.b];
  final a = p as ArcPrim;
  return [
    for (var i = 0; i <= 24; i++)
      Pt(a.c.x + cosD(a.a0 + (a.a1 - a.a0) * i / 24) * a.r, a.c.y + sinD(a.a0 + (a.a1 - a.a0) * i / 24) * a.r),
  ];
}
