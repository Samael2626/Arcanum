import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../shared/widgets/arcanum_mood.dart';

/// Dial de la hora planetaria: un anillo que se llena con el AVANCE de la hora
/// vigente (se entiende de un vistazo cuánto queda), con 24 marcas de las horas
/// del día mágico, el glifo del planeta regente pulsando en el centro y un halo
/// teñido de su atmósfera. El progreso anima al cambiar de dato.
class PlanetaryHourDial extends StatelessWidget {
  /// Avance de la hora actual, 0 (recién empezó) → 1 (por terminar).
  final double progress;
  final String glyph;
  final ArcanumMood mood;
  final double size;

  /// Índice de hora (1..12) para resaltar la marca vigente.
  final int hourNumber;
  final bool isDay;

  const PlanetaryHourDial({
    super.key,
    required this.progress,
    required this.glyph,
    required this.mood,
    required this.hourNumber,
    required this.isDay,
    this.size = 172,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => CustomPaint(
          painter: _DialPainter(p, mood, hourNumber, isDay),
          child: Center(
            child: _PulseGlyph(glyph: glyph, color: mood.accent, size: size * 0.30),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final ArcanumMood mood;
  final int hourNumber;
  final bool isDay;

  _DialPainter(this.progress, this.mood, this.hourNumber, this.isDay);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Halo atmosférico difuso tras el dial.
    canvas.drawCircle(
        c,
        r * 1.02,
        Paint()
          ..shader = RadialGradient(colors: [
            mood.glow.withValues(alpha: 0.15),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: c, radius: r * 1.15)));

    // Riel base (círculo completo tenue).
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.028
          ..color = ArcanumColors.goldMuted.withValues(alpha: 0.22));

    // 24 marcas (las horas mágicas). La vigente, resaltada.
    final markBase = 12 * (isDay ? 0 : 1); // 0 diurnas 1..12, nocturnas 13..24
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 24;
      final outer = c + Offset(math.cos(a), math.sin(a)) * (r + size.width * 0.02);
      final inner = c + Offset(math.cos(a), math.sin(a)) * (r - size.width * 0.008);
      final isCurrent = i == (markBase + hourNumber - 1) % 24;
      canvas.drawLine(
          inner,
          outer,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = isCurrent ? size.width * 0.02 : size.width * 0.008
            ..color = isCurrent
                ? mood.accent.withValues(alpha: 0.95)
                : ArcanumColors.goldMuted.withValues(alpha: 0.35));
    }

    // Arco de progreso de la hora (glow + trazo maestro).
    final sweep = (2 * math.pi) * progress.clamp(0.0, 1.0);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.030
          ..color = mood.glow.withValues(alpha: 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.020
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: -math.pi / 2 + 2 * math.pi,
            colors: [mood.accent, mood.glow, mood.accent],
          ).createShader(rect));

    // Cabeza luminosa al final del arco.
    if (progress > 0.01) {
      final ha = -math.pi / 2 + sweep;
      final head = c + Offset(math.cos(ha), math.sin(ha)) * r;
      canvas.drawCircle(head, size.width * 0.018,
          Paint()..color = const Color(0xFFFFF3D6).withValues(alpha: 0.95));
      canvas.drawCircle(
          head,
          size.width * 0.032,
          Paint()
            ..color = mood.accent.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // Aro interior fino que asienta el glifo central.
    canvas.drawCircle(
        c,
        r * 0.72,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: 0.30));
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress ||
      old.mood.accent != mood.accent ||
      old.hourNumber != hourNumber ||
      old.isDay != isDay;
}

/// Glifo central con pulso suave teñido del planeta.
class _PulseGlyph extends StatefulWidget {
  final String glyph;
  final Color color;
  final double size;
  const _PulseGlyph({required this.glyph, required this.color, required this.size});

  @override
  State<_PulseGlyph> createState() => _PulseGlyphState();
}

class _PulseGlyphState extends State<_PulseGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.20 + 0.28 * t),
                blurRadius: 12 + 20 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Text(widget.glyph,
          style: TextStyle(fontSize: widget.size, color: widget.color, height: 1)),
    );
  }
}
