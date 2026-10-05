// Pinta en el lienzo los mismos grupos de escena que se exportan a SVG.
// Una sola lista de dibujo (engine/scene.dart) y dos emisores: este y
// groupSVG. Texto con las fuentes empaquetadas de la app (el SVG pide Georgia,
// que Android no tiene).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_parsing/path_parsing.dart';

import '../engine/arcane_glyphs.dart';
import '../engine/layers.dart';
import '../engine/scene.dart';

class _PathBuilder extends PathProxy {
  final Path path = Path();
  @override
  void close() => path.close();
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) => path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

final _paths = <String, Path>{};

/// Camino de un `d` de SVG, con cache (los trazos se repiten entre frames).
Path pathOf(String d) {
  final hit = _paths[d];
  if (hit != null) return hit;
  if (_paths.length > 4000) _paths.clear();
  final b = _PathBuilder();
  writeSvgPathDataToPath(d, b);
  return _paths[d] = b.path;
}

Color parseColor(String c, [double op = 1]) {
  final h = c.replaceFirst('#', '');
  final v = int.parse(h.length == 3 ? h.split('').map((x) => '$x$x').join() : h, radix: 16);
  return Color(0xFF000000 | v).withValues(alpha: op.clamp(0, 1));
}

/// Familia de la app para cada fuente pedida por la escena.
const kLatinFamily = 'Crimson Pro';
// el hebreo cae en Noto Serif Hebrew (empaquetada); los simbolos, en ArcanumGlifos
const kGlyphFamilyFallback = ['Noto Serif Hebrew', 'ArcanumGlifos'];

TextStyle _textStyle(TextPrim t, Color color) {
  final italic = t.font.startsWith('italic');
  return TextStyle(
    fontFamily: kLatinFamily,
    fontFamilyFallback: kGlyphFamilyFallback,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontSize: t.size,
    color: color,
    height: 1,
  );
}

// Maquetar texto es caro: el anillo repite las mismas letras en cada frame (y
// tres veces con relieve). Se guarda cada letra ya maquetada.
final _texts = <(String, double, String, int), TextPainter>{};
TextPainter _textPainter(TextPrim t, Color c) {
  final key = (t.ch, t.size, t.font, c.toARGB32());
  final hit = _texts[key];
  if (hit != null) return hit;
  if (_texts.length > 600) _texts.clear();
  return _texts[key] = TextPainter(text: TextSpan(text: t.ch, style: _textStyle(t, c)), textDirection: TextDirection.ltr)..layout();
}

void _paintPrims(Canvas canvas, List<LayerPrim> prims, String color, double gop) {
  for (final p in prims) {
    final c = parseColor(color, p.op * gop);
    switch (p) {
      case CirclePrim q:
        canvas.drawCircle(Offset(q.cx, q.cy), q.r, Paint()..style = PaintingStyle.stroke..strokeWidth = q.w..color = c);
      case PolyPrim q:
        final path = Path()..moveTo(q.pts.first.$1, q.pts.first.$2);
        for (final v in q.pts.skip(1)) {
          path.lineTo(v.$1, v.$2);
        }
        if (q.closed) path.close();
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = q.w
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = c);
      case GlyphLayerPrim g:
        paintGlyph(canvas, g.ch, g.x, g.y, g.size, g.rot, c);
      case TextPrim t:
        final tp = _textPainter(t, c);
        final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        canvas.save();
        canvas.translate(t.x, t.y);
        canvas.rotate(t.rot * math.pi / 180);
        // misma regla que el SVG: centro horizontal y base a TEXT_MID del cuerpo
        tp.paint(canvas, Offset(-tp.width / 2, t.size * kTextMid - base));
        canvas.restore();
    }
  }
}

void paintGlyph(Canvas canvas, String sym, double x, double y, double size, double rot, Color color) {
  final g = kArcaneGlyphs[glyphKey(sym)]!;
  canvas.save();
  canvas.translate(x, y);
  canvas.rotate(rot * math.pi / 180);
  canvas.scale(size / kGlyphBox);
  canvas.translate(-50, -50);
  if (g.s != null) {
    canvas.drawPath(pathOf(g.s!), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kGlyphW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color);
  }
  if (g.f != null) canvas.drawPath(pathOf(g.f!), Paint()..color = color);
  canvas.restore();
}

ui.Gradient _gradient(Grad gr) {
  final colors = [for (final s in gr.stops) parseColor(s.$2, s.$3)];
  final stops = [for (final s in gr.stops) s.$1];
  return gr.type == 'radial'
      ? ui.Gradient.radial(Offset(gr.cx, gr.cy), gr.r, colors, stops)
      : ui.Gradient.linear(Offset(gr.x1, gr.y1), Offset(gr.x2, gr.y2), colors, stops);
}

/// Pinta grupos de escena en coordenadas de 800x800.
/// [minW]: grosor minimo de los trazos del sigilo (miniaturas).
/// [dim]: factor de opacidad por trazo (resaltar la letra elegida).
void paintScene(Canvas canvas, List<SceneGroup> groups, {double? minW, double Function(PathItem)? dim}) {
  for (final g in groups) {
    canvas.save();
    if ((g.dx ?? 0) != 0 || (g.dy ?? 0) != 0) canvas.translate(g.dx ?? 0, g.dy ?? 0);
    final gop = g.op ?? 1;
    if (g.prims != null) {
      _paintPrims(canvas, g.prims!, g.color, gop);
      canvas.restore();
      continue;
    }
    final sq = g.cap == 'square';
    final w = g.w == null ? 0.0 : (g.sigil && minW != null ? math.max(g.w!, minW) : g.w!);
    for (final it in g.items) {
      final a = gop * (it.op ?? 1) * (dim?.call(it) ?? 1);
      final paint = Paint()..color = parseColor(g.color, a);
      if (it.grad != null) {
        paint.shader = _gradient(it.grad!);
        if (a < 1) paint.color = Color.fromRGBO(0, 0, 0, a);
      } else if (!it.fill) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = sq ? StrokeCap.square : StrokeCap.round
          ..strokeJoin = sq ? StrokeJoin.miter : StrokeJoin.round;
      }
      canvas.drawPath(pathOf(it.d), paint);
    }
    canvas.restore();
  }
}

/// Grabacion guardada de una parte de la escena que no cambia en cada frame
/// (soporte, marcos, simbolos): se regraba solo cuando cambia su clave.
class ScenePictureCache {
  String? _key;
  ui.Picture? _pic;

  ui.Picture get(String key, void Function(Canvas canvas) draw) {
    if (key != _key || _pic == null) {
      _pic?.dispose();
      final rec = ui.PictureRecorder();
      draw(Canvas(rec));
      _pic = rec.endRecording();
      _key = key;
    }
    return _pic!;
  }

  void dispose() {
    _pic?.dispose();
    _pic = null;
    _key = null;
  }
}

/// Parte la escena en lo de debajo del sigilo, el sigilo (con sus efectos) y
/// lo de encima. Solo el sigilo cambia al arrastrar una letra.
(List<SceneGroup>, List<SceneGroup>, List<SceneGroup>) splitAroundSigil(List<SceneGroup> fg) {
  final i0 = fg.indexWhere((g) => g.sigil), i1 = fg.lastIndexWhere((g) => g.sigil);
  if (i0 < 0) return (fg, const [], const []);
  return (fg.sublist(0, i0), fg.sublist(i0, i1 + 1), fg.sublist(i1 + 1));
}

/// CustomPainter del lienzo: escena y, encima, lo que pinte [overlay].
class SigilScenePainter extends CustomPainter {
  final List<SceneGroup> bg, fg;
  final double Function(PathItem)? dim;
  final void Function(Canvas canvas)? overlay;
  final Object? version;
  const SigilScenePainter({required this.bg, required this.fg, this.dim, this.overlay, this.version});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 800);
    paintScene(canvas, bg);
    paintScene(canvas, fg, minW: 2 * 800 / size.width, dim: dim);
    overlay?.call(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SigilScenePainter old) => old.version != version || old.dim != dim || !identical(old.fg, fg) || !identical(old.bg, bg);
}
