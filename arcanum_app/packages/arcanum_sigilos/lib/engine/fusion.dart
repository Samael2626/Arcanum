// Fusion de trazos compartidos, firmas geometricas y letras gemelas.
//
// Dos segmentos colineales que se solapan son un solo trazo; dos arcos del
// mismo circulo que se solapan, tambien. El trazo resultante guarda todas las
// letras que lo usan. Frater U.D.: una M es una W invertida; se comprueba de
// verdad comparando la forma girada o reflejada.
import 'geometry.dart';
import 'glyphs.dart';
import 'js_num.dart';

const double kEps = 0.012;

LinePrim? _mergeLine(LinePrim p, LinePrim q) {
  final dx = q.b.x - q.a.x, dy = q.b.y - q.a.y, len = hypot(dx, dy);
  if (len < 1e-9) return null;
  final ux = dx / len, uy = dy / len;
  double off(Pt pt) => ((pt.x - q.a.x) * uy - (pt.y - q.a.y) * ux).abs();
  if (off(p.a) > kEps || off(p.b) > kEps) return null;
  double t(Pt pt) => (pt.x - q.a.x) * ux + (pt.y - q.a.y) * uy;
  final ta = t(p.a), tb = t(p.b);
  final p0 = ta < tb ? ta : tb, p1 = ta > tb ? ta : tb;
  if ((p1 < len ? p1 : len) - (p0 > 0 ? p0 : 0) < 0.02) return null;
  final t0 = p0 < 0 ? p0 : 0.0, t1 = len > p1 ? len : p1;
  return LinePrim(Pt(q.a.x + ux * t0, q.a.y + uy * t0), Pt(q.a.x + ux * t1, q.a.y + uy * t1), const []);
}

ArcPrim? _mergeArc(ArcPrim p, ArcPrim q) {
  if (hypot(p.c.x - q.c.x, p.c.y - q.c.y) > kEps || (p.r - q.r).abs() > kEps) return null;
  for (final sh in const [-360.0, 0.0, 360.0]) {
    final lo = p.a0 + sh, hi = p.a1 + sh;
    if ((hi < q.a1 ? hi : q.a1) - (lo > q.a0 ? lo : q.a0) >= 2) {
      final a0 = lo < q.a0 ? lo : q.a0;
      final top = hi > q.a1 ? hi : q.a1;
      return normArc(q.c, q.r, a0, top < a0 + 360 ? top : a0 + 360, const []);
    }
  }
  return null;
}

List<Prim> mergeAll(Iterable<Prim> prims) {
  final list = [for (final p in prims) p.copyWith()];
  var changed = true;
  while (changed) {
    changed = false;
    scan:
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final p = list[i], q = list[j];
        final Prim? m = switch ((p, q)) {
          (LinePrim pl, LinePrim ql) => _mergeLine(ql, pl),
          (ArcPrim pa, ArcPrim qa) => _mergeArc(qa, pa),
          _ => null,
        };
        if (m == null) continue;
        final units = <String>{...p.units, ...q.units}.toList();
        list.removeAt(j);
        list[i] = m.copyWith(units: units, kind: p.kind ?? q.kind);
        changed = true;
        break scan;
      }
    }
  }
  return list;
}

/// Firma geometrica estable: clave para ocultar trazos y para comparar formas.
String sig(Prim p) {
  if (p is LinePrim) {
    final ends = [p.a, p.b].map((q) => '${r2(q.x)},${r2(q.y)}').toList()..sort();
    return 'L${ends.join('|')}';
  }
  final a = p as ArcPrim;
  final base = '${r2(a.c.x)},${r2(a.c.y)},${r2(a.r)}';
  if (a.a1 - a.a0 >= 359.5) return 'O$base';
  return 'A$base,${jsNum(jsRem(jsRound(a.a0), 360))},${jsNum(jsRound(a.a1 - a.a0))}';
}

class Dihedral {
  final double rot;
  final bool fx, fy;
  final String how;
  const Dihedral(this.rot, this.fx, this.fy, this.how);
}

const kDihedral = [
  Dihedral(90, false, false, 'giro de 90°'),
  Dihedral(180, false, false, 'giro de 180°'),
  Dihedral(270, false, false, 'giro de 270°'),
  Dihedral(0, true, false, 'reflejo horizontal'),
  Dihedral(0, false, true, 'reflejo vertical'),
  Dihedral(90, true, false, 'giro y reflejo'),
  Dihedral(270, true, false, 'giro y reflejo'),
];

final _shapeCache = <String, String>{};
String shapeSig(String ch, [Dihedral? d]) {
  final k = d == null ? '${ch}id' : '$ch${d.rot}${d.fx}${d.fy}';
  return _shapeCache.putIfAbsent(k, () {
    final t = d == null ? Xf.identity : Xf(rot: d.rot, fx: d.fx, fy: d.fy);
    final sigs = mergeAll(kGlyphs[ch]!.map((p) => placePrim(p, t, [ch]))).map(sig).toList()..sort();
    return sigs.join(';');
  });
}

class Twin {
  final String by, how;
  const Twin(this.by, this.how);
}

Twin? findTwin(String ch, List<String> kept) {
  final own = shapeSig(ch);
  for (final k in kept) {
    for (final d in kDihedral) {
      if (shapeSig(k, d) == own) return Twin(k, d.how);
    }
  }
  return null;
}
