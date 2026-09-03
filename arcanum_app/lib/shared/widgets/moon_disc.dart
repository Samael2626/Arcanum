import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

/// Dibuja la fase lunar según la fracción iluminada y si es creciente.
class MoonDisc extends StatelessWidget {
  final double illumination;
  final bool waxing;
  final double size;
  const MoonDisc({
    super.key,
    required this.illumination,
    required this.waxing,
    this.size = 84,
  });

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

  /// Mares, en fraccion del radio: centro y tamano. Son los de siempre, los
  /// mismos que el prototipo aprobado -- no ruido aleatorio, que cambiaria de
  /// sitio en cada repintado.
  static const _maria = [
    (-0.20, -0.32, 0.27),
    (0.20, -0.44, 0.17),
    (-0.32, 0.16, 0.20),
    (0.16, 0.25, 0.27),
    (-0.05, -0.09, 0.12),
    (0.39, -0.02, 0.10),
  ];

  /// Por debajo de esto los mares se emborronan en dos pixeles grises y solo
  /// ensucian: el disco del selector mide 20.
  static const _detailFrom = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final detailed = size.width >= _detailFrom;

    canvas.drawCircle(c, r, Paint()..color = ArcanumColors.background);
    // Luz cenicienta: la cara oscura no es negra, la ilumina la Tierra.
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFF4A5570).withValues(alpha: 0.30),
    );
    if (detailed) _paintMaria(canvas, c, r, const Color(0xFF20263A), 0.14);

    final f = illum.clamp(0.0, 1.0);
    if (f > 0.005) {
      canvas
        ..save()
        ..clipPath(_litShape(rect, c, r, f));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.28, -0.40),
            radius: 0.82,
            colors: [
              Color(0xFFFFFDF7),
              Color(0xFFEFE8D9),
              Color(0xFFCFC7B6),
              Color(0xFFA9A093),
            ],
            stops: [0, 0.58, 0.88, 1],
          ).createShader(rect),
      );
      if (detailed) _paintMaria(canvas, c, r, const Color(0xFF7A776E), 0.19);
      canvas.restore();
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ArcanumColors.goldMuted,
    );
  }

  /// La parte iluminada: media luna mas el ovalo del terminador, unidos o
  /// restados segun se pase o no de la mitad.
  Path _litShape(Rect rect, Offset c, double r, double f) {
    final base = Path()
      ..addArc(rect, waxing ? -math.pi / 2 : math.pi / 2, math.pi);
    final tb = r * (1 - 2 * f).abs();
    final term = Path()
      ..addOval(Rect.fromCenter(center: c, width: tb * 2, height: r * 2));
    return f < 0.5
        ? Path.combine(PathOperation.difference, base, term)
        : Path.combine(PathOperation.union, base, term);
  }

  void _paintMaria(Canvas canvas, Offset c, double r, Color color, double a) {
    final paint = Paint()
      ..color = color.withValues(alpha: a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
    canvas
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    for (final (dx, dy, size) in _maria) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), size * r, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.illum != illum || old.waxing != waxing;
}
