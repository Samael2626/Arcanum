// Interaccion con el lienzo: guias con iman, que hay bajo el dedo y gestos
// (puerto de snapPoint, snapAngle, layerAt, primAt y del manejador de puntero
// del prototipo). Coordenadas de lienzo 800x800. Sin Flutter: se prueba con
// los mismos casos que el prototipo.
import 'dart:math' as math;

import 'geometry.dart';
import 'js_num.dart';
import 'layers.dart';
import 'letter_sigil.dart';
import 'sigil_doc.dart';
import 'terminals.dart';

enum GuideKind { point, v, h, circle, ray }

/// Guia que se dibuja mientras actua (nunca se exporta).
class Guide {
  final GuideKind kind;
  final double x, y, r, a;
  const Guide(this.kind, {this.x = 0, this.y = 0, this.r = 0, this.a = 0});
}

class SnapResult {
  final Pt p;
  final List<Guide> guides;
  const SnapResult(this.p, this.guides);
}

double _distToSegment(Pt p, Pt a, Pt b) {
  final dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
  final t = l2 != 0 ? math.max(0.0, math.min(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0.0;
  return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy);
}

/// Puntos y radios a los que se pega lo que se arrastra.
({List<Pt> pts, List<(double, double, double)> radii}) snapTargets(SigilDoc doc, String? excludeId) {
  final pts = <Pt>[const Pt(kC, kC)];
  final radii = <(double, double, double)>[];
  for (final p in doc.layout.parts) {
    if (p.layer.id == excludeId) continue;
    pts.add(Pt(p.g.center.$1, p.g.center.$2));
    pts.addAll(p.g.vertices.map((v) => Pt(v.$1, v.$2)));
    radii.addAll(p.g.radii);
  }
  final sg = doc.sigil, view = sg.view;
  if (view != null) {
    for (final l in sg.active) {
      if (l.base != null && excludeId != 'letter:${l.ch}') pts.add(view.toCanvas(Pt(l.base!.tx + l.user.dx, l.base!.ty + l.user.dy)));
    }
    for (final e in freeEnds(sg.visible)) {
      pts.add(view.toCanvas(e));
    }
  }
  return (pts: pts, radii: radii);
}

/// Iman: punto (vertice, centro) > vertical/horizontal > angulo de 15 grados y
/// radio de anillo. Pocas guias a la vez (una o dos): nada fijo que sature.
/// [pxScale]: unidades de lienzo por pixel de pantalla (800 / ancho del lienzo).
SnapResult snapPoint(SigilDoc doc, Pt pt, String? excludeId, {required double pxScale, bool magnet = true}) {
  if (!magnet) return SnapResult(pt, const []);
  final t = 9 * pxScale;
  final (:pts, :radii) = snapTargets(doc, excludeId);
  Pt? best;
  var bd = 0.0;
  for (final q in pts) {
    final d = hypot(q.x - pt.x, q.y - pt.y);
    if (d < t && (best == null || d < bd)) { best = q; bd = d; }
  }
  if (best != null) return SnapResult(Pt(best.x, best.y), [Guide(GuideKind.point, x: best.x, y: best.y)]);
  double? bx, by, bxd, byd;
  for (final q in pts) {
    final ddx = (q.x - pt.x).abs(), ddy = (q.y - pt.y).abs();
    if (ddx < t && (bx == null || ddx < bxd!)) { bx = q.x; bxd = ddx; }
    if (ddy < t && (by == null || ddy < byd!)) { by = q.y; byd = ddy; }
  }
  final guides = <Guide>[if (bx != null) Guide(GuideKind.v, x: bx), if (by != null) Guide(GuideKind.h, y: by)];
  if (bx != null || by != null) return SnapResult(Pt(bx ?? pt.x, by ?? pt.y), guides);
  final dx = pt.x - kC, dy = pt.y - kC, rr = hypot(dx, dy);
  if (rr > 40) {
    var a = math.atan2(dy, dx) * 180 / math.pi;
    final as = jsRound(a / 15) * 15;
    var r = rr;
    double? rs;
    for (final (cx, cy, q) in radii) {
      if (hypot(cx - kC, cy - kC) >= 1) continue;
      if ((q - rr).abs() < t && (rs == null || (q - rr).abs() < (rs - rr).abs())) rs = q;
    }
    if (rs != null) { r = rs; guides.add(Guide(GuideKind.circle, r: rs)); }
    if (rad(as - a).abs() * rr < t) { a = as; guides.add(Guide(GuideKind.ray, a: as)); }
    if (guides.isNotEmpty) return SnapResult(Pt(kC + cosD(a) * r, kC + sinD(a) * r), guides);
  }
  return SnapResult(pt, const []);
}

/// Giro con iman: se pega a multiplos de 15 grados si esta a 4 o menos.
double snapAngle(double deg, {bool magnet = true}) {
  if (!magnet) return deg;
  final s = jsRound(deg / 15) * 15;
  return (deg - s).abs() <= 4 ? s : deg;
}

/// Capa bajo el dedo: primero los simbolos (van encima), luego los marcos.
Layer? layerAt(SigilDoc doc, Pt pt) {
  final parts = doc.layout.parts.reversed.toList();
  for (final p in parts) {
    final l = p.layer;
    if (l.type == LayerType.symbol && hypot(pt.x - l.x, pt.y - l.y) < math.max(24, l.size * .7)) return l;
  }
  for (final p in parts) {
    if (p.layer.type == LayerType.symbol) continue;
    final near = p.g.radii.any((c) => (hypot(pt.x - c.$1, pt.y - c.$2) - c.$3).abs() < 12) ||
        p.g.prims.any((q) {
          if (q is! PolyPrim) return false;
          for (var i = 0; i < q.pts.length; i++) {
            if (!q.closed && i == q.pts.length - 1) continue;
            final a = q.pts[i], b = q.pts[(i + 1) % q.pts.length];
            if (_distToSegment(pt, Pt(a.$1, a.$2), Pt(b.$1, b.$2)) < 10) return true;
          }
          return false;
        }) ||
        p.g.prims.any((q) => q is TextPrim && hypot(pt.x - q.x, pt.y - q.y) < q.size * .6);
    if (near) return p.layer;
  }
  return null;
}

/// Trazo del sigilo bajo el dedo (tolerancia de 16 px de lienzo).
Prim? primAt(SigilDoc doc, Pt pt, Iterable<Prim> pool) {
  final view = doc.sigil.view!;
  final w = view.toWorld(pt.x, pt.y), tol = 16 / view.k;
  Prim? best;
  var bd = tol;
  for (final p in pool) {
    final d = distToPrim(w, p);
    if (d < bd) { bd = d; best = p; }
  }
  return best;
}

class _LetterDrag {
  final SigilLetter l;
  final Pt p0, c0;
  final double dx0, dy0;
  bool moved = false;
  _LetterDrag(this.l, this.p0, this.c0, this.dx0, this.dy0);
}

class _LayerDrag {
  final Layer l;
  final double ox, oy;
  bool moved = false;
  _LayerDrag(this.l, this.ox, this.oy);
}

/// Gestos sobre el lienzo, en el mismo orden que el prototipo:
/// remate por punta > ocultar trazos > simbolo (siempre se toca antes) >
/// colocar simbolo > letra > capa > deseleccionar.
class CanvasController {
  final SigilDoc doc;
  String? sel, layerSel;
  bool termPick = false, hideMode = false, stampMode = false, magnet = true;
  String termBrush = 'dot', stampSym = '♄${String.fromCharCode(0xfe0e)}';
  List<Guide> guides = const [];
  Pt? tap;
  String? tapFor;
  _LetterDrag? _letterDrag;
  _LayerDrag? _layerDrag;

  /// Decisiones del usuario (para la procedencia).
  final List<String> decisions = [];

  CanvasController(this.doc);

  bool get dragging => _letterDrag != null || _layerDrag != null;

  void pointerDown(Pt pt, {required double pxScale, bool alt = false}) {
    final sg = doc.sigil;
    if (sg.prims.isEmpty || sg.view == null) return;
    if (termPick) {
      final w = sg.view!.toWorld(pt.x, pt.y), tol = 22 / sg.view!.k;
      End? best;
      var bd = 0.0;
      for (final e in freeEnds(sg.visible)) {
        final d = hypot(e.x - w.x, e.y - w.y);
        if (d < tol && (best == null || d < bd)) { best = e; bd = d; }
      }
      if (best != null) {
        final cur = doc.endStyles[best.key] ?? doc.terminals;
        doc.endStyles[best.key] = cur == termBrush ? 'none' : termBrush;
        decisions.add('remate: ${kTerminals.firstWhere((t) => t.id == doc.endStyles[best!.key]).name.toLowerCase()}');
      }
      return;
    }
    if (hideMode) {
      final p = primAt(doc, pt, sg.prims);
      if (p != null) toggleHidden(p.key);
      return;
    }
    // un simbolo ya puesto se toca antes que nada: se selecciona y se arrastra,
    // aunque «colocar» este activo (si no, cada intento de moverlo crea otro)
    final hit = layerAt(doc, pt);
    if (hit != null && hit.type == LayerType.symbol) {
      stampMode = false;
      _startLayerDrag(hit, pt);
      return;
    }
    if (stampMode) {
      final q = snapPoint(doc, pt, null, pxScale: pxScale, magnet: magnet && !alt);
      addLayer(LayerType.symbol, (l) => l
        ..sym = stampSym
        ..x = q.p.x
        ..y = q.p.y);
      stampMode = false;
      guides = const [];
      return;
    }
    final p = primAt(doc, pt, sg.visible);
    if (p != null && p.units.isNotEmpty) {
      if (!p.units.contains(sel)) sel = p.units.first;
      final l = sg.letters.firstWhere((x) => x.ch == sel);
      layerSel = null;
      tap = pt;
      tapFor = 'L:$sel';
      _letterDrag = _LetterDrag(l, pt, sg.view!.toCanvas(Pt(l.base!.tx + l.user.dx, l.base!.ty + l.user.dy)), l.user.dx, l.user.dy);
      return;
    }
    if (hit != null) {
      _startLayerDrag(hit, pt);
      return;
    }
    sel = null;
    layerSel = null;
  }

  void _startLayerDrag(Layer l, Pt pt) {
    layerSel = l.id;
    sel = null;
    tap = pt;
    tapFor = l.id;
    final c = l.type == LayerType.symbol ? Pt(l.x, l.y) : Pt(kC + l.dx, kC + l.dy);
    _layerDrag = _LayerDrag(l, pt.x - c.x, pt.y - c.y);
  }

  void pointerMove(Pt pt, {required double pxScale, bool alt = false}) {
    final ld = _layerDrag;
    if (ld != null) {
      final q = snapPoint(doc, Pt(pt.x - ld.ox, pt.y - ld.oy), ld.l.id, pxScale: pxScale, magnet: magnet && !alt);
      guides = q.guides;
      if (ld.l.type == LayerType.symbol) {
        ld.l
          ..x = q.p.x
          ..y = q.p.y;
      } else {
        ld.l
          ..dx = q.p.x - kC
          ..dy = q.p.y - kC;
      }
      ld.moved = true;
      return;
    }
    final d = _letterDrag;
    if (d == null) return;
    // se mueve el centro de la letra y se alinea con guias; el encuadre queda quieto
    final want = Pt(d.c0.x + pt.x - d.p0.x, d.c0.y + pt.y - d.p0.y);
    final q = snapPoint(doc, want, 'letter:${d.l.ch}', pxScale: pxScale, magnet: magnet && !alt);
    guides = q.guides;
    final k = doc.sigil.view!.k;
    d.l.user
      ..dx = d.dx0 + (q.p.x - d.c0.x) / k
      ..dy = d.dy0 + (q.p.y - d.c0.y) / k;
    d.moved = true;
    doc.sigil.rebuild(keepView: true);
  }

  void pointerUp() {
    guides = const [];
    final ld = _layerDrag;
    if (ld != null) {
      if (ld.moved) {
        decisions.add('mover capa');
        tap = null;
      }
      _layerDrag = null;
      doc.refit();
      return;
    }
    final d = _letterDrag;
    if (d == null) return;
    _letterDrag = null;
    if (d.moved) {
      decisions.add('mover ${d.l.ch}');
      tap = null;
    }
    doc.rebuild();
  }

  void toggleHidden(String key) {
    final h = doc.sigil.hidden;
    final had = h.remove(key);
    if (!had) h.add(key);
    decisions.add(had ? 'recuperar trazo' : 'ocultar trazo');
    doc.rebuild();
  }

  // ── Radial: donde se ancla y que hace cada boton ──────────────
  /// Elemento elegido y su caja en el lienzo (ctxTarget del prototipo), o null
  /// si no hay nada elegido o hay un modo activo.
  SelectionAnchor? anchor() {
    if (dragging || pinching || termPick || hideMode || stampMode) return null;
    final sg = doc.sigil, view = sg.view;
    if (sel != null && sg.prims.isNotEmpty && view != null) {
      final l = sg.active.where((x) => x.ch == sel).firstOrNull;
      if (l != null) {
        final xs = <double>[], ys = <double>[];
        for (final p in sg.prims) {
          if (p.hidden || !p.units.contains(l.ch)) continue;
          if (p is LinePrim) {
            for (final q in [view.toCanvas(p.a), view.toCanvas(p.b)]) {
              xs.add(q.x);
              ys.add(q.y);
            }
          } else if (p is ArcPrim) {
            final c = view.toCanvas(p.c), r = p.r * view.k;
            xs.addAll([c.x - r, c.x + r]);
            ys.addAll([c.y - r, c.y + r]);
          }
        }
        if (xs.isNotEmpty) return SelectionAnchor.letter(l.ch, (xs.reduce(math.min) + xs.reduce(math.max)) / 2, ys.reduce(math.min), ys.reduce(math.max));
      }
    }
    final id = layerSel;
    if (id == null) return null;
    final part = doc.layout.parts.where((p) => p.layer.id == id).firstOrNull;
    if (part == null || !part.layer.visible) return null;
    final l = part.layer;
    if (l.type == LayerType.symbol) return SelectionAnchor.layer(l, l.x, l.y - l.size * .75, l.y + l.size * .75);
    if (part.r != null) return SelectionAnchor.layer(l, part.g.center.$1, part.g.center.$2 - part.r!, part.g.center.$2 + part.r!);
    final ys = [
      for (final q in part.g.prims)
        if (q is TextPrim) ...[q.y - q.size, q.y] else if (q is PolyPrim) ...q.pts.map((v) => v.$2),
    ];
    return SelectionAnchor.layer(l, kC, ys.isEmpty ? kC : ys.reduce(math.min), ys.isEmpty ? kC : ys.reduce(math.max));
  }

  SigilLetter? get _selLetter => doc.sigil.active.where((x) => x.ch == sel).firstOrNull;

  void _editLetter(void Function(LetterEdit u) fn, String what) {
    final l = _selLetter;
    if (l == null) return;
    fn(l.user);
    decisions.add('$what ${l.ch}');
    doc.rebuild();
  }

  void rotateLetter(double deg) => _editLetter((u) => u.drot += deg, 'girar');
  void flipLetterH() => _editLetter((u) => u.fx = !u.fx, 'reflejar');
  void flipLetterV() => _editLetter((u) => u.fy = !u.fy, 'reflejar');
  void scaleLetter(bool bigger) => _editLetter((u) => u.ds = bigger ? math.min(2, u.ds * 1.15) : math.max(.4, u.ds / 1.15), 'escalar');
  void resetLetter() => _editLetter((u) => u
    ..dx = 0
    ..dy = 0
    ..ds = 1
    ..drot = 0
    ..fx = false
    ..fy = false, 'restaurar');

  Layer? get selectedLayer => doc.layers.where((l) => l.id == layerSel).firstOrNull;

  /// Solo se escalan los simbolos, los marcos anidados y las inscripciones.
  bool get selectedLayerScales {
    final l = selectedLayer;
    return l != null && (l.type == LayerType.symbol || l.isNested || l.type == LayerType.inscription);
  }

  void scaleLayer(bool bigger) {
    final l = selectedLayer;
    if (l == null) return;
    if (l.type == LayerType.symbol) {
      l.size = bigger ? math.min(160, jsRound(l.size * 1.2)) : math.max(18, jsRound(l.size / 1.2));
    } else if (l.isNested) {
      l.scale = bigger ? math.min(160, l.scale + 10) : math.max(40, l.scale - 10);
    } else {
      l.size = bigger ? math.min(40, l.size + 3) : math.max(12, l.size - 3);
    }
    doc.refit();
  }

  void rotateLayer(double deg) {
    final l = selectedLayer;
    if (l == null) return;
    l.rot = (l.rot + deg + 360) % 360;
    doc.refit();
  }

  void deleteSelectedLayer() {
    final id = layerSel;
    if (id != null) removeLayer(id);
  }

  // ── Pellizco con dos dedos: escala y giro del elemento elegido ──
  // Los limites son los mismos que los botones del radial; el giro se pega a
  // multiplos de 15 grados con el iman.
  ({double ds, double drot})? _pinchLetter;
  ({double size, double scale, double rot})? _pinchLayer;

  bool get pinching => _pinchLetter != null || _pinchLayer != null;

  /// Empieza el pellizco si hay algo elegido. Corta un arrastre en curso.
  bool beginPinch() {
    if (dragging) pointerUp();
    final l = _selLetter;
    if (l != null) {
      _pinchLetter = (ds: l.user.ds, drot: l.user.drot);
      return true;
    }
    final layer = selectedLayer;
    if (layer != null) {
      _pinchLayer = (size: layer.size, scale: layer.scale, rot: layer.rot);
      return true;
    }
    return false;
  }

  /// [ratio]: distancia entre dedos / distancia inicial. [deg]: giro de la
  /// linea entre dedos desde el inicio (horario).
  void updatePinch(double ratio, double deg, {bool alt = false}) {
    final mag = magnet && !alt;
    final pl = _pinchLetter, pg = _pinchLayer;
    if (pl != null) {
      final u = _selLetter?.user;
      if (u == null) return;
      u
        ..ds = (pl.ds * ratio).clamp(.4, 2.0)
        ..drot = snapAngle(pl.drot + deg, magnet: mag);
      doc.sigil.rebuild(keepView: true);
      return;
    }
    final layer = selectedLayer;
    if (pg == null || layer == null) return;
    if (layer.type == LayerType.symbol) {
      layer.size = (pg.size * ratio).clamp(18.0, 160.0);
    } else if (layer.isNested) {
      layer.scale = (pg.scale * ratio).clamp(40.0, 160.0);
    } else if (layer.type == LayerType.inscription) {
      layer.size = (pg.size * ratio).clamp(12.0, 40.0);
    }
    layer.rot = (snapAngle(pg.rot + deg, magnet: mag) % 360 + 360) % 360;
  }

  void endPinch() {
    if (_pinchLetter != null) {
      decisions.add('escalar y girar ${sel ?? ''}');
      doc.rebuild();
    } else if (_pinchLayer != null) {
      decisions.add('escalar y girar capa');
      doc.refit();
    }
    _pinchLetter = null;
    _pinchLayer = null;
  }

  // ── Capas ─────────────────────────────────────────────────────
  int _seq = 0;
  String _newId() {
    String id;
    do {
      id = 'c${++_seq}';
    } while (doc.layers.any((l) => l.id == id));
    return id;
  }

  /// Los marcos nuevos entran por dentro de los que ya hay (antes de rotulos
  /// y simbolos); lo nuevo queda seleccionado.
  Layer addLayer(LayerType type, [void Function(Layer)? init]) {
    final l = Layer.create(_newId(), type);
    init?.call(l);
    final list = doc.layers;
    if (type.nested) {
      final idx = list.where((q) => q.isNested).length;
      var pos = -1;
      for (var i = 0; i < list.length; i++) {
        if (!list[i].isNested && list.sublist(0, i).where((q) => q.isNested).length >= idx) {
          pos = i;
          break;
        }
      }
      if (pos >= 0) {
        list.insert(pos, l);
      } else {
        list.add(l);
      }
    } else {
      list.add(l);
    }
    layerSel = l.id;
    sel = null;
    doc.refit();
    return l;
  }

  void removeLayer(String id) {
    doc.layers.removeWhere((l) => l.id == id);
    if (layerSel == id) layerSel = null;
    doc.refit();
  }

  void moveLayer(String id, int d) {
    final list = doc.layers, i = list.indexWhere((l) => l.id == id), j = i + d;
    if (i < 0 || j < 0 || j >= list.length) return;
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
    doc.refit();
  }
}

/// Elemento elegido y su caja vertical en el lienzo: el radial se ancla ahi.
class SelectionAnchor {
  final String? letter;
  final Layer? layer;
  final double x, top, bottom;
  const SelectionAnchor.letter(String ch, this.x, this.top, this.bottom)
      : letter = ch,
        layer = null;
  const SelectionAnchor.layer(Layer l, this.x, this.top, this.bottom)
      : letter = null,
        layer = l;
  bool get isLetter => letter != null;
  double get cy => (top + bottom) / 2;

  /// Clave para saber si el punto tocado es de este elemento.
  String get key => letter != null ? 'L:$letter' : layer!.id;
}
