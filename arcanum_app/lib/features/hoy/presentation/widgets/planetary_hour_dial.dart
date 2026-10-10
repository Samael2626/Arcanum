import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/astral_glyph_3d.dart';
import 'bright_star_positions.dart';

enum PlanetaryHourInfo { daytime, nighttime, progress }

/// Dial de hora planetaria inspirado en las capas de un astrolabio.
/// Cada semicirculo contiene doce horas; la joya avanza dentro de la hora viva.
class PlanetaryHourDial extends StatelessWidget {
  final double progress;
  final String glyph;
  final ArcanumMood mood;
  final double size;
  final int hourNumber;
  final bool isDay;
  final VoidCallback onTapCenter;
  final ValueChanged<PlanetaryHourInfo> onExplain;
  final double? latitude;
  final double? longitude;

  const PlanetaryHourDial({
    super.key,
    required this.progress,
    required this.glyph,
    required this.mood,
    required this.hourNumber,
    required this.isDay,
    required this.onTapCenter,
    required this.onExplain,
    this.size = 172,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox.square(
      dimension: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final center = Offset(size / 2, size / 2);
          final touch = details.localPosition;
          final delta = touch - center;
          final radius = size * 0.46;
          final progressRadius = radius * 0.76;
          final start = _DialPainter.hourStart(hourNumber, isDay);
          final tipAngle = start + (math.pi / 12) * clampedProgress;
          final jewel =
              center +
              Offset(math.cos(tipAngle), math.sin(tipAngle)) * progressRadius;

          if ((touch - jewel).distance < size * 0.08) {
            onExplain(PlanetaryHourInfo.progress);
          } else if (delta.distance > radius * 0.82 &&
              delta.distance < radius * 1.08) {
            onExplain(
              delta.dx >= 0
                  ? PlanetaryHourInfo.daytime
                  : PlanetaryHourInfo.nighttime,
            );
          } else {
            onTapCenter();
          }
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DialPainter(
              clampedProgress,
              mood,
              hourNumber,
              isDay,
              latitude == null || longitude == null
                  ? const []
                  : BrightStarPositions.visibleAt(
                      utc: DateTime.now().toUtc(),
                      latitude: latitude!,
                      longitude: longitude!,
                    ),
            ),
            child: Center(
              child: _PulseGlyph(
                glyph: glyph,
                color: mood.accent,
                size: size * 0.28,
                revision: '$hourNumber-$isDay',
              ),
            ),
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
  final List<ApparentStar> stars;

  _DialPainter(
    this.progress,
    this.mood,
    this.hourNumber,
    this.isDay,
    this.stars,
  );

  static double hourStart(int hourNumber, bool isDay) {
    final slot = (hourNumber - 1).clamp(0, 11).toDouble();
    return (isDay ? -math.pi / 2 : math.pi / 2) + slot * math.pi / 12;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final side = size.shortestSide;
    final r = side * 0.46;
    final rim = Rect.fromCircle(center: c, radius: r);
    final phaseTrack = Rect.fromCircle(center: c, radius: r * 0.89);
    final progressRadius = r * 0.76;
    final coreRadius = r * 0.53;
    final coreRect = Rect.fromCircle(center: c, radius: coreRadius);

    canvas.drawCircle(
      c,
      r * 1.06,
      Paint()
        ..shader = RadialGradient(
          colors: [mood.glow.withValues(alpha: 0.10), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.08)),
    );

    // Filete de metal trabajado, doble filo y esmalte de fondo.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.028
        ..shader = SweepGradient(
          colors: [
            ArcanumColors.goldLight,
            ArcanumColors.goldMuted,
            const Color(0xFFE8D091),
            const Color(0xFF594424),
            ArcanumColors.goldLight,
          ],
        ).createShader(rim),
    );
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.006
        ..color = const Color(0xFFFFE8A8).withValues(alpha: 0.72),
    );

    // Dos territorios del ciclo: doce horas diurnas y doce nocturnas.
    final activeDayColors = isDay
        ? const [Color(0xFFE7CD85), Color(0xFF9B7740)]
        : [
            const Color(0xFFE7CD85).withValues(alpha: 0.34),
            const Color(0xFF9B7740).withValues(alpha: 0.34),
          ];
    final activeNightColors = !isDay
        ? const [Color(0xFF9EACC9), Color(0xFF52617D)]
        : [
            const Color(0xFF7D8AA7).withValues(alpha: 0.34),
            const Color(0xFF38445D).withValues(alpha: 0.34),
          ];
    canvas.drawArc(
      phaseTrack,
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.055
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi / 2,
          colors: activeDayColors,
        ).createShader(phaseTrack),
    );
    canvas.drawArc(
      phaseTrack,
      math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.055
        ..shader = SweepGradient(
          startAngle: math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: activeNightColors,
        ).createShader(phaseTrack),
    );

    // Divisiones finas, agrupadas en dos series de doce.
    for (var i = 0; i < 12; i++) {
      final major = i % 3 == 0;
      for (var half = 0; half < 2; half++) {
        final start = half == 0 ? -math.pi / 2 : math.pi / 2;
        final markerColor = half == 0
            ? ArcanumColors.goldLight
            : const Color(0xFFAAB6D0);
        final isActiveHalf = (half == 0) == isDay;
        final angle = start + i * math.pi / 12;
        final outer = c + Offset(math.cos(angle), math.sin(angle)) * (r * 0.88);
        final inner =
            c +
            Offset(math.cos(angle), math.sin(angle)) *
                (r * (major ? 0.73 : 0.80));
        canvas.drawLine(
          inner,
          outer,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = side * (major ? 0.010 : 0.005)
            ..color = markerColor.withValues(
              alpha: isActiveHalf
                  ? (major ? 0.78 : 0.46)
                  : (major ? 0.24 : 0.12),
            ),
        );
      }
    }

    // El sector activo queda anclado a su hora; el progreso no gira por toda
    // la esfera ni se confunde con una aguja civil.
    final start = hourStart(hourNumber, isDay);
    final hourSweep = math.pi / 12;
    final activeRect = Rect.fromCircle(center: c, radius: progressRadius);
    canvas.drawArc(
      activeRect,
      start,
      hourSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = side * 0.030
        ..color = mood.accent.withValues(alpha: 0.22),
    );
    canvas.drawArc(
      activeRect,
      start,
      hourSweep * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = side * 0.016
        ..color = mood.accent.withValues(alpha: 0.92),
    );

    final headAngle = start + hourSweep * progress;
    final head =
        c + Offset(math.cos(headAngle), math.sin(headAngle)) * progressRadius;
    canvas.drawCircle(
      head,
      side * 0.034,
      Paint()..color = mood.glow.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      head,
      side * 0.019,
      Paint()
        ..color = const Color(0xFFFFF0C2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      head,
      side * 0.019,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.006
        ..color = mood.accent,
    );

    // Centro esmaltado: día cálido, noche azul profunda, glifo propio arriba.
    canvas.drawCircle(
      c,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.34, -0.4),
          colors: isDay
              ? const [Color(0xFF5A4B36), Color(0xFF211D21), Color(0xFF101015)]
              : const [Color(0xFF42485A), Color(0xFF1B1D29), Color(0xFF0D1018)],
        ).createShader(coreRect),
    );

    // Rete calada: proyeccion celeste del astrolabio sobre la mater.
    // Queda en el anillo intermedio para no cruzar el glifo ni la joya horaria.
    _drawRete(canvas, c, side, coreRadius, progressRadius);

    canvas.drawCircle(
      c,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.008
        ..color = ArcanumColors.goldLight.withValues(alpha: 0.58),
    );
  }

  void _drawRete(
    Canvas canvas,
    Offset center,
    double side,
    double innerRadius,
    double outerRadius,
  ) {
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius * 0.96))
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius * 1.06));
    canvas.save();
    canvas.clipPath(cutout);

    final engraving = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.0035
      ..color = const Color(0xFFD8BE7D).withValues(alpha: 0.32);

    // Eclíptica ligeramente inclinada, suspendida dentro de la placa.
    // Brazos curvos abiertos y punteros estelares: silueta propia de la rete.
    final inner = innerRadius * 1.12;
    final outer = outerRadius * 0.89;
    for (final apparent in stars) {
      final angle = apparent.azimuth * math.pi / 180 - math.pi / 2;
      final height = (apparent.altitude / 90).clamp(0.0, 1.0).toDouble();
      final radius = outer - (outer - inner) * height;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final tip = center + direction * radius;
      final tangent = Offset(-direction.dy, direction.dx);
      final control =
          center +
          direction * ((inner + radius) * 0.52) +
          tangent * side * 0.025;
      final arm = Path()
        ..moveTo(
          center.dx + direction.dx * inner,
          center.dy + direction.dy * inner,
        )
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
      canvas.drawPath(arm, engraving);
      final nodeRadius =
          side *
          (0.0048 +
              (1.5 - apparent.star.magnitude).clamp(0.0, 3.0).toDouble() *
                  0.0012);
      canvas.drawCircle(
        tip,
        nodeRadius,
        Paint()..color = const Color(0xFFE7D29B).withValues(alpha: 0.78),
      );
      canvas.drawCircle(
        tip,
        nodeRadius * 1.9,
        Paint()..color = const Color(0xFFE7D29B).withValues(alpha: 0.10),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress ||
      old.mood.accent != mood.accent ||
      old.hourNumber != hourNumber ||
      old.isDay != isDay ||
      old.stars != stars;
}

class _PulseGlyph extends StatelessWidget {
  final String glyph;
  final Color color;
  final double size;
  final String revision;

  const _PulseGlyph({
    required this.glyph,
    required this.color,
    required this.size,
    required this.revision,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final angle = -0.12 * (1 - animation.value);
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle);
          return Opacity(
            opacity: animation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: child,
            ),
          );
        },
        child: child,
      ),
      child: AstralGlyph3D(
        key: ValueKey('$revision-$glyph'),
        glyph: glyph,
        color: color,
        size: size,
      ),
    );
  }
}
