import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import 'arcanum_mood.dart';

/// Marco dorado biselado con florituras de esquina, envolvente y reutilizable.
///
/// Destilado del marco de las cartas del Oráculo: inner-glow del filete, bisel
/// (highlight arriba-izq + sombra abajo-der → oro grabado), hilo intermedio,
/// filete interior tintado del [mood], y esquinas ornamentadas opcionales.
/// Se pinta como CAPA SUPERIOR sobre el hijo (no altera su layout).
class ArcanumFrame extends StatelessWidget {
  final Widget child;

  /// Tinte del filete interior. Si es null, oro neutro.
  final ArcanumMood? mood;
  final double radius;

  /// Dibuja las florituras de esquina (desactívalo en marcos pequeños).
  final bool corners;

  const ArcanumFrame({
    super.key,
    required this.child,
    this.mood,
    this.radius = 16,
    this.corners = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _FramePainter(
        accent: mood?.accent ?? ArcanumColors.gold,
        radius: radius,
        corners: corners,
      ),
      child: child,
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color accent;
  final double radius;
  final bool corners;

  const _FramePainter({
    required this.accent,
    required this.radius,
    required this.corners,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = ArcanumColors.gold;
    final unit = w * 0.010; // grosor base relativo al ancho

    RRect inset(double px, double rf) => RRect.fromRectAndRadius(
        Rect.fromLTWH(px, px, w - px * 2, h - px * 2),
        Radius.circular(radius * rf));

    final o = w * 0.035; // filete exterior
    final outer = inset(o, 0.9);

    // Inner-glow del filete exterior.
    canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 1.3
          ..color = gold.withValues(alpha: 0.26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // Bisel: highlight desplazado arriba-izquierda.
    canvas.save();
    canvas.translate(-w * 0.003, -h * 0.002);
    canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.6
          ..color = const Color(0xFFF0DFA0).withValues(alpha: 0.5));
    canvas.restore();
    // Bisel: sombra desplazada abajo-derecha.
    canvas.save();
    canvas.translate(w * 0.003, h * 0.002);
    canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.6
          ..color = Colors.black.withValues(alpha: 0.32));
    canvas.restore();
    // Filete exterior maestro.
    canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit
          ..color = gold.withValues(alpha: 0.70));
    // Hilo intermedio tenue.
    canvas.drawRRect(
        inset(o + unit * 1.6, 0.78),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.4
          ..color = ArcanumColors.goldMuted.withValues(alpha: 0.5));
    // Filete interior tintado del humor.
    canvas.drawRRect(
        inset(o + unit * 3.4, 0.62),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.6
          ..color = accent.withValues(alpha: 0.42));

    if (corners) _paintCorners(canvas, size, gold);
  }

  void _paintCorners(Canvas canvas, Size size, Color gold) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round
      ..color = gold.withValues(alpha: 0.55);
    final dot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.004
      ..color = gold.withValues(alpha: 0.55);
    final m = w * 0.075, len = w * 0.05;
    final cs = <List<double>>[
      [m, m, 1, 1],
      [w - m, m, -1, 1],
      [m, h - m, 1, -1],
      [w - m, h - m, -1, -1],
    ];
    for (final c in cs) {
      final x = c[0], y = c[1], sx = c[2], sy = c[3];
      canvas.drawPath(
          Path()
            ..moveTo(x + sx * len, y)
            ..lineTo(x, y)
            ..lineTo(x, y + sy * len),
          p);
      canvas.drawCircle(Offset(x + sx * len * 0.5, y + sy * len * 0.5), w * 0.008, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.accent != accent || old.radius != radius || old.corners != corners;
}
