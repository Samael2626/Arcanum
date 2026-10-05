// Iconos del taller dibujados con la misma geometria que el sigilo: glifos
// arcanos y remates. No dependen de ninguna fuente del telefono.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/geometry.dart';
import '../engine/terminals.dart';
import 'scene_painter.dart';

class GlyphIcon extends StatelessWidget {
  final String sym;
  final double size;
  final Color color;
  const GlyphIcon(this.sym, {super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlyphPainter(sym, color));
}

class _GlyphPainter extends CustomPainter {
  final String sym;
  final Color color;
  _GlyphPainter(this.sym, this.color);
  @override
  void paint(Canvas canvas, Size size) => paintGlyph(canvas, sym, size.width / 2, size.height / 2, size.width, 0, color);
  @override
  bool shouldRepaint(_GlyphPainter old) => old.sym != sym || old.color != color;
}

/// Remate al final de un trazo corto, como en el boton del prototipo.
class TerminalIcon extends StatelessWidget {
  final String style;
  final double size;
  final Color color;
  const TerminalIcon(this.style, {super.key, this.size = 34, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _TerminalPainter(style, color));
}

class _TerminalPainter extends CustomPainter {
  final String style;
  final Color color;
  _TerminalPainter(this.style, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(const Offset(1, 20), const Offset(8, 20), stroke);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final sh in terminalShapes(const Pt(8, 20), const Pt(1, 0), style, 7.5)) {
      canvas.drawPath(pathOf(sh.d), sh.fill ? (Paint()..color = color) : thin);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TerminalPainter old) => old.style != style || old.color != color;
}

/// Circulo de 48 px con un icono, para radiales y paletas.
double radialRadius(int n) => n >= 6 ? 68 : 58;
double angleFor(int i, int n) => (-90 + i * 360 / n) * math.pi / 180;
