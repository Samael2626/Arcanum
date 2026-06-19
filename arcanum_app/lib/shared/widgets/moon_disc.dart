import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

/// Dibuja la fase lunar según la fracción iluminada y si es creciente.
class MoonDisc extends StatelessWidget {
  final double illumination;
  final bool waxing;
  final double size;
  const MoonDisc(
      {super.key,
      required this.illumination,
      required this.waxing,
      this.size = 84});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MoonPainter(illumination, waxing)),
      );
}

class _MoonPainter extends CustomPainter {
  final double illum;
  final bool waxing;
  _MoonPainter(this.illum, this.waxing);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(c, r, Paint()..color = ArcanumColors.surfaceHigh);

    final f = illum.clamp(0.0, 1.0);
    if (f > 0.005) {
      final lit = Paint()..color = ArcanumColors.ivory.withValues(alpha: 0.92);
      final base = Path()..addArc(rect, waxing ? -math.pi / 2 : math.pi / 2, math.pi);
      final tb = r * (1 - 2 * f).abs();
      final term = Path()
        ..addOval(Rect.fromCenter(center: c, width: tb * 2, height: r * 2));
      final shape = f < 0.5
          ? Path.combine(PathOperation.difference, base, term)
          : Path.combine(PathOperation.union, base, term);
      canvas.drawPath(shape, lit);
    }

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ArcanumColors.goldMuted);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.illum != illum || old.waxing != waxing;
}
