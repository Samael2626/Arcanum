// Lienzo del taller: la escena (lo que se exporta) y, encima, las marcas de
// edicion (seleccion, guias, rejilla, puntas elegibles, trazos ocultos), que
// nunca se exportan. Los toques van al CanvasController en coordenadas de
// lienzo 800x800; el mismo orden de gestos que el prototipo.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/geometry.dart';
import '../engine/interaction.dart';
import '../engine/layers.dart';
import '../engine/letter_sigil.dart';
import '../engine/terminals.dart';
import 'scene_painter.dart';

enum GridMode { none, polar, square }

const kLetterColors = [
  '#1f5fa8', '#c77700', '#2e7d32', '#8e44ad', '#b3261e', '#00838f',
  '#6d4c41', '#ad1457', '#558b2f', '#283593', '#e64a19', '#00695c',
];

class SigilCanvas extends StatefulWidget {
  final CanvasController controller;
  final GridMode grid;

  /// Colorea cada letra para ver de donde sale cada trazo (solo pantalla).
  final bool letterColors;

  /// Se llama al tocar y al soltar (para el panel y el historial). Durante el
  /// arrastre no: el lienzo se repinta solo, sin reconstruir widgets.
  final VoidCallback? onChanged;

  /// Aviso externo para repintar tras cambiar el documento por codigo.
  final Listenable? repaint;

  const SigilCanvas({super.key, required this.controller, this.grid = GridMode.none, this.letterColors = false, this.onChanged, this.repaint});

  @override
  State<SigilCanvas> createState() => _SigilCanvasState();
}

class _SigilCanvasState extends State<SigilCanvas> {
  int? _pointer;
  final _tick = ValueNotifier<int>(0);
  final _bg = ScenePictureCache(), _under = ScenePictureCache(), _over = ScenePictureCache();

  @override
  void dispose() {
    _tick.dispose();
    _bg.dispose();
    _under.dispose();
    _over.dispose();
    super.dispose();
  }

  void _repaint() => _tick.value++;

  CanvasController get _c => widget.controller;

  Pt _toCanvas(Offset local, double side) => Pt(local.dx * kSize / side, local.dy * kSize / side);
  bool get _alt => HardwareKeyboard.instance.isAltPressed;

  void _changed() {
    _repaint();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final side = box.maxWidth, pxScale = kSize / side;
        return Listener(
          behavior: HitTestBehavior.opaque,
          // solo el primer dedo: un segundo dedo no debe arrastrar otra cosa
          onPointerDown: (e) {
            if (_pointer != null) return;
            _pointer = e.pointer;
            _c.pointerDown(_toCanvas(e.localPosition, side), pxScale: pxScale, alt: _alt);
            _changed();
          },
          onPointerMove: (e) {
            if (e.pointer != _pointer || !_c.dragging) return;
            _c.pointerMove(_toCanvas(e.localPosition, side), pxScale: pxScale, alt: _alt);
            _repaint();
          },
          onPointerUp: (e) {
            if (e.pointer != _pointer) return;
            _pointer = null;
            _c.pointerUp();
            _changed();
          },
          onPointerCancel: (e) {
            if (e.pointer != _pointer) return;
            _pointer = null;
            _c.pointerUp();
            _changed();
          },
          child: CustomPaint(
            size: Size.square(side),
            painter: _LivePainter(this, widget.repaint == null ? _tick : Listenable.merge([_tick, widget.repaint])),
          ),
        );
      }),
    );
  }

  /// Pinta el frame: lo quieto sale de grabaciones guardadas y solo el sigilo
  /// (y las marcas de edicion) se graba de nuevo.
  void _paintFrame(Canvas canvas, Size size) {
    final doc = _c.doc, sg = doc.sigil, hl = _c.sel;
    final scene = doc.scene();
    final (under, mid, over) = splitAroundSigil(scene.fg);
    final sk = doc.styleKey, lk = doc.layoutKey;
    canvas.save();
    canvas.scale(size.width / kSize);
    canvas.drawPicture(_bg.get(sk, (c) => paintScene(c, scene.bg)));
    canvas.drawPicture(_under.get('$sk|$lk', (c) => paintScene(c, under)));
    paintScene(canvas, mid, minW: 2 * kSize / size.width, dim: hl == null ? null : (it) => it.units != null && !it.units!.contains(hl) ? .28 : 1);
    canvas.drawPicture(_over.get('$sk|$lk', (c) => paintScene(c, over)));
    _paintOverlay(canvas, sg);
    canvas.restore();
  }

  // ── Marcas de edicion (solo pantalla) ──────────────────────────
  void _paintOverlay(Canvas canvas, LetterSigil sg) {
    final doc = _c.doc, th = doc.theme, ui = parseColor(th.ui);
    final lw = kLineW * doc.style.width / 100;
    if (widget.grid != GridMode.none) _paintGrid(canvas, parseColor(th.ink, .16 * .7));
    if (sg.view == null) return;
    if (_c.hideMode) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw * .6
        ..strokeCap = StrokeCap.round
        ..color = parseColor(th.ink, .16);
      for (final q in sg.prims.where((q) => q.hidden)) {
        _dashed(canvas, pathOf(sg.primPath(q)), p, const [10, 10]);
      }
    }
    if (widget.letterColors) {
      var i = 0;
      for (final l in sg.active) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw * .42
          ..strokeCap = StrokeCap.round
          ..color = parseColor(kLetterColors[i++ % kLetterColors.length]);
        for (final q in l.own) {
          canvas.drawPath(pathOf(sg.primPath(q)), p);
        }
      }
    }
    final hl = _c.sel;
    if (hl != null) {
      final l = sg.active.where((x) => x.ch == hl).firstOrNull;
      if (l != null) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw * 1.15
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ui;
        for (final q in l.own) {
          canvas.drawPath(pathOf(sg.primPath(q)), p);
        }
      }
    }
    if (_c.termPick) {
      // en modo uno a uno se marcan las puntas libres que se pueden tocar
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ui;
      for (final e in freeEnds(sg.visible)) {
        final q = sg.view!.toCanvas(e);
        _dashed(canvas, Path()..addOval(Rect.fromCircle(center: Offset(q.x, q.y), radius: 14)), p, const [4, 4]);
      }
    }
    _paintLayerSelection(canvas, ui);
    _paintGuides(canvas, ui);
  }

  void _paintLayerSelection(Canvas canvas, Color ui) {
    final id = _c.layerSel;
    if (id == null) return;
    final part = _c.doc.layout.parts.where((p) => p.layer.id == id).firstOrNull;
    if (part == null || !part.layer.visible) return;
    final l = part.layer;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ui;
    Path? ring;
    if (l.type == LayerType.symbol) {
      ring = Path()..addOval(Rect.fromCircle(center: Offset(l.x, l.y), radius: l.size * .72));
    } else if (part.r != null) {
      ring = Path()..addOval(Rect.fromCircle(center: Offset(part.g.center.$1, part.g.center.$2), radius: part.r! + 6));
    }
    if (ring != null) _dashed(canvas, ring, p, const [4, 5]);
  }

  void _paintGuides(Canvas canvas, Color ui) {
    if (_c.guides.isEmpty) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ui.withValues(alpha: .9);
    for (final g in _c.guides) {
      switch (g.kind) {
        case GuideKind.v:
          _dashed(canvas, Path()..moveTo(g.x, 0)..lineTo(g.x, kSize), p, const [7, 6]);
        case GuideKind.h:
          _dashed(canvas, Path()..moveTo(0, g.y)..lineTo(kSize, g.y), p, const [7, 6]);
        case GuideKind.ray:
          final a = g.a * math.pi / 180;
          _dashed(canvas, Path()..moveTo(kC, kC)..lineTo(kC + math.cos(a) * 400, kC + math.sin(a) * 400), p, const [7, 6]);
        case GuideKind.circle:
          _dashed(canvas, Path()..addOval(Rect.fromCircle(center: const Offset(kC, kC), radius: g.r)), p, const [7, 6]);
        case GuideKind.point:
          canvas.drawCircle(Offset(g.x, g.y), 7, p);
      }
    }
  }

  void _paintGrid(Canvas canvas, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    if (widget.grid == GridMode.polar) {
      for (var r = 50.0; r <= 350; r += 50) {
        canvas.drawCircle(const Offset(kC, kC), r, p);
      }
      for (var a = 0; a < 360; a += 15) {
        final t = a * math.pi / 180;
        canvas.drawLine(const Offset(kC, kC), Offset(kC + math.cos(t) * 350, kC + math.sin(t) * 350), p);
      }
    } else {
      for (var v = 0.0; v <= kSize; v += 50) {
        canvas.drawLine(Offset(v, 0), Offset(v, kSize), p);
        canvas.drawLine(Offset(0, v), Offset(kSize, v), p);
      }
    }
  }
}

/// Trazo discontinuo (Flutter no tiene setLineDash).
void _dashed(Canvas canvas, Path path, Paint paint, List<double> pattern) {
  for (final m in path.computeMetrics()) {
    var d = 0.0, i = 0;
    while (d < m.length) {
      final seg = pattern[i % pattern.length];
      if (i.isEven) canvas.drawPath(m.extractPath(d, math.min(d + seg, m.length)), paint);
      d += seg;
      i++;
    }
  }
}

class _LivePainter extends CustomPainter {
  final _SigilCanvasState state;
  _LivePainter(this.state, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) => state._paintFrame(canvas, size);

  // el aviso de repintado manda; si el widget se reconstruye, se repinta
  @override
  bool shouldRepaint(_LivePainter old) => true;
}
