// Sigilo de letras: estado, composicion, fusion y encuadre.
// Puerto de layoutLetters / applyLayout / rebuild / fitView (js/letras.js).
// Determinista: la misma intencion con las mismas decisiones da el mismo
// signo en el prototipo y en la app.
import 'dart:math' as math;

import 'fusion.dart';
import 'geometry.dart';
import 'glyphs.dart';
import 'js_num.dart';
import 'reduction.dart';

enum ComposeMode { fusion, block, cross }

const double kSize = 800, kC = kSize / 2, kCoreR = 250;

/// Hueco disponible sin capas de marco (layoutLayers con lista vacia).
const double kDefaultContentR = 345;

/// Ediciones del usuario sobre una letra.
class LetterEdit {
  double dx, dy, ds, drot;
  bool fx, fy;
  LetterEdit({this.dx = 0, this.dy = 0, this.ds = 1, this.drot = 0, this.fx = false, this.fy = false});

  LetterEdit copy() => LetterEdit(dx: dx, dy: dy, ds: ds, drot: drot, fx: fx, fy: fy);
  Map<String, Object> toJson() => {'dx': dx, 'dy': dy, 'ds': ds, 'drot': drot, 'fx': fx, 'fy': fy};
  factory LetterEdit.fromJson(Map<String, dynamic> j) => LetterEdit(
        dx: (j['dx'] as num).toDouble(), dy: (j['dy'] as num).toDouble(), ds: (j['ds'] as num).toDouble(),
        drot: (j['drot'] as num).toDouble(), fx: j['fx'] as bool, fy: j['fy'] as bool);
}

class SigilLetter {
  final String ch;
  LetterEdit user;
  Twin? twin;
  Xf? base;
  List<Prim> own = const [];
  double legible = 0;
  List<String> shares = const [];
  SigilLetter(this.ch, [LetterEdit? user]) : user = user ?? LetterEdit();

  Xf get effective {
    final b = base!, u = user;
    return Xf(tx: b.tx + u.dx, ty: b.ty + u.dy, s: b.s * u.ds, rot: b.rot + u.drot, fx: b.fx != u.fx, fy: b.fy != u.fy);
  }
}

class SigilView {
  final double cx, cy, k, oy;
  const SigilView(this.cx, this.cy, this.k, [this.oy = 0]);
  Pt toCanvas(Pt p) => Pt(kC + (p.x - cx) * k, kC + oy + (p.y - cy) * k);
  Pt toWorld(double x, double y) => Pt((x - kC) / k + cx, (y - kC - oy) / k + cy);
}

// Orden del monograma KAROLVS: K izquierda, R arriba, L abajo, S derecha
const _arms = [(-1.0, 0.0), (0.0, -1.0), (0.0, 1.0), (1.0, 0.0)];
const _compactShifts = [0.0, -0.5, 0.5];

double _bboxArea(Iterable<Prim> ps) {
  var x0 = double.infinity, x1 = double.negativeInfinity, y0 = double.infinity, y1 = double.negativeInfinity;
  for (final p in ps) {
    for (final q in primPoints(p)) {
      x0 = math.min(x0, q.x); x1 = math.max(x1, q.x); y0 = math.min(y0, q.y); y1 = math.max(y1, q.y);
    }
  }
  return (x1 - x0) * (y1 - y0);
}

List<Prim> _placeGlyph(String ch, Xf t) => [for (final p in kGlyphs[ch]!) placePrim(p, t, [ch])];

// Encaje compacto: la letra prueba a desplazarse media caja y se queda donde
// comparte mas trazo, sin agrandar el signo (Cooper: la I es el asta de la D)
double _compactShift(String ch, List<Prim> placed) {
  final baseLen = totalLength(mergeAll(placed));
  List<Prim> at(double dx) => mergeAll(_placeGlyph(ch, Xf(tx: dx, ty: 0)));
  final maxArea = _bboxArea([...placed, ...at(0)]) + 1e-6;
  var bestDx = 0.0, bestGain = 0.0;
  for (final dx in _compactShifts) {
    final own = at(dx);
    if (_bboxArea([...placed, ...own]) > maxArea) continue;
    final gain = baseLen + totalLength(own) - totalLength(mergeAll([...placed, ...own]));
    if (gain > bestGain + 1e-6) { bestDx = dx; bestGain = gain; }
  }
  return bestDx;
}

class LetterSigil {
  String intention = '';
  ReductionMethod method = ReductionMethod.cooper;
  ComposeMode mode = ComposeMode.fusion;
  double overlap = 0;
  bool absorb = true, compact = true;
  Reduction? reduction;
  List<SigilLetter> letters = [];
  List<Prim> extra = [];
  List<Prim> prims = [];
  List<String> hidden = [];
  SigilView? view;

  Iterable<SigilLetter> get active => letters.where((l) => l.twin == null);

  /// Reduce la intencion y compone. Conserva las ediciones si el texto no cambia.
  /// Devuelve false si no queda ninguna letra dibujable.
  bool generate(String text, {double contentR = kDefaultContentR}) {
    final r = reduce(text, method);
    final units = r.units.where(kGlyphs.containsKey).toList();
    final prev = intention == text ? {for (final l in letters) l.ch: l.user} : <String, LetterEdit>{};
    if (intention != text) hidden = [];
    intention = text;
    reduction = r;
    letters = [for (final ch in units) SigilLetter(ch, prev[ch])];
    if (letters.isEmpty) { prims = []; extra = []; view = null; return false; }
    applyLayout(contentR: contentR);
    return true;
  }

  void applyLayout({double contentR = kDefaultContentR}) {
    final kept = <String>[];
    for (final l in letters) {
      l.twin = absorb ? findTwin(l.ch, kept) : null;
      if (l.twin == null) kept.add(l.ch);
    }
    final act = active.toList();
    final base = <String, Xf>{};
    extra = [];
    switch (mode) {
      case ComposeMode.fusion:
        final placed = <Prim>[];
        double glyphLen(String ch) => totalLength(mergeAll(_placeGlyph(ch, Xf.identity)));
        final order = [...act];
        if (compact) {
          order.sort((a, b) {
            final d = glyphLen(b.ch) - glyphLen(a.ch);
            return d != 0 ? d.sign.toInt() : act.indexOf(a) - act.indexOf(b);
          });
        }
        for (final l in order) {
          final dx = compact && placed.isNotEmpty ? _compactShift(l.ch, placed) : 0.0;
          base[l.ch] = Xf(tx: dx, ty: 0);
          placed.addAll(_placeGlyph(l.ch, base[l.ch]!));
        }
      case ComposeMode.block:
        final n = act.length, cols = math.sqrt(n).ceil(), rows = (n / cols).ceil();
        final step = 1 - overlap;
        for (var i = 0; i < n; i++) {
          final r = i ~/ cols, c = i % cols;
          final inRow = r == rows - 1 ? n - cols * (rows - 1) : cols;
          base[act[i].ch] = Xf(tx: (c - (inRow - 1) / 2) * step, ty: (r - (rows - 1) / 2) * step);
        }
      case ComposeMode.cross:
        var center = act.where((l) => kVowels.contains(l.ch)).toList();
        if (center.isEmpty && act.isNotEmpty) center = [act.first];
        final arms = act.where((l) => !center.contains(l)).toList();
        for (final l in center) { base[l.ch] = const Xf(tx: 0, ty: 0); }
        const s = .8, d0 = 1.55, dk = 1.3;
        final lastReach = [.5, .5, .5, .5];
        for (var i = 0; i < arms.length; i++) {
          final arm = i % 4, ring = i ~/ 4, d = d0 + ring * dk;
          final (dx, dy) = _arms[arm];
          base[arms[i].ch] = Xf(tx: dx * d, ty: dy * d, s: s);
          final from = lastReach[arm] + .1, to = d - s / 2 - .1;
          extra.add(LinePrim(Pt(dx * from, dy * from), Pt(dx * to, dy * to), const [], 'cross'));
          lastReach[arm] = d + s / 2;
        }
    }
    for (final l in act) { l.base = base[l.ch]; }
    rebuild(contentR: contentR);
  }

  /// Coloca las letras, funde trazos compartidos y mide legibilidad.
  void rebuild({double contentR = kDefaultContentR, bool keepView = false}) {
    final raw = <Prim>[];
    for (final l in active) {
      l.own = _placeGlyph(l.ch, l.effective);
      raw.addAll(l.own);
    }
    raw.addAll(extra.map((e) => e.copyWith()));
    prims = mergeAll(raw);
    final hid = hidden.toSet();
    for (final p in prims) { p.key = sig(p); p.hidden = hid.contains(p.key); }
    for (final l in active) {
      final mine = prims.where((p) => p.units.contains(l.ch)).toList();
      l.legible = mine.isEmpty ? 0 : mine.where((p) => !p.hidden).length / mine.length;
      l.shares = <String>{for (final p in mine) ...p.units}.where((u) => u != l.ch).toList();
    }
    if (!keepView) view = fitView(contentR);
  }

  /// Encuadre: el cuadro del sigilo cabe en el hueco que dejan los marcos.
  SigilView fitView(double contentR) {
    var x0 = double.infinity, x1 = double.negativeInfinity, y0 = double.infinity, y1 = double.negativeInfinity;
    for (final p in prims) {
      for (final q in primPoints(p)) {
        x0 = math.min(x0, q.x); x1 = math.max(x1, q.x); y0 = math.min(y0, q.y); y1 = math.max(y1, q.y);
      }
    }
    if (!x0.isFinite) return const SigilView(0, 0, kCoreR);
    final kf = math.min(1.0, contentR * .99 / math.sqrt2 / kCoreR);
    return SigilView((x0 + x1) / 2, (y0 + y1) / 2, kCoreR * kf / (math.max(math.max(x1 - x0, y1 - y0), .5) / 2));
  }

  List<Prim> get visible => prims.where((p) => !p.hidden).toList();

  /// Trazo en coordenadas de lienzo, como `d` de SVG (primPath del prototipo).
  String primPath(Prim p) {
    final v = view!;
    if (p is LinePrim) {
      final a = v.toCanvas(p.a), b = v.toCanvas(p.b);
      return 'M ${f2(a.x)} ${f2(a.y)} L ${f2(b.x)} ${f2(b.y)}';
    }
    final arc = p as ArcPrim;
    final c = v.toCanvas(arc.c), r = arc.r * v.k;
    Pt at(double a) => Pt(c.x + cosD(a) * r, c.y + sinD(a) * r);
    final s = at(arc.a0), span = arc.a1 - arc.a0;
    if (span >= 359.5) {
      final m = at(arc.a0 + 180);
      return 'M ${f2(s.x)} ${f2(s.y)} A ${f2(r)} ${f2(r)} 0 0 1 ${f2(m.x)} ${f2(m.y)} A ${f2(r)} ${f2(r)} 0 0 1 ${f2(s.x)} ${f2(s.y)}';
    }
    final e = at(arc.a1);
    return 'M ${f2(s.x)} ${f2(s.y)} A ${f2(r)} ${f2(r)} 0 ${span > 180 ? 1 : 0} 1 ${f2(e.x)} ${f2(e.y)}';
  }
}
