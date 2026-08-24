import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/arcanum_card.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/moon_disc.dart';
import 'today_card.dart';

class NestedSkyInstrument extends StatelessWidget {
  const NestedSkyInstrument({
    super.key,
    required this.moon,
    required this.actions,
    required this.onMoonTap,
    required this.onConfirmPlace,
    this.ruler,
    this.hour,
    this.onRulerTap,
    this.onHourTap,
  });

  final String? ruler;
  final Map<String, dynamic>? hour;
  final Map<String, dynamic> moon;
  final Widget actions;
  final VoidCallback? onRulerTap;
  final VoidCallback? onHourTap;
  final VoidCallback onMoonTap;
  final VoidCallback onConfirmPlace;

  @override
  Widget build(BuildContext context) {
    final hourPlanet = hour?['planet'] as String?;
    final minutes = (hour?['minutes_remaining'] as num?)?.toInt();
    final illumination = (moon['illumination'] as num).toDouble();
    final waxing = moon['is_waxing'] as bool;
    final phase = moon['phase_name'] as String;
    final age = (moon['age_days'] as num?)?.toDouble();
    final hasPlace = ruler != null && hourPlanet != null;
    final mood = ruler == null
        ? ArcanumMood.moon
        : ArcanumMood.forPlanet(ruler!);

    return TodayCard(
      mood: mood,
      radius: 18,
      intensity: 0.58,
      child: Column(
        children: [
          const SectionLabel('INSTRUMENTO DEL DÍA'),
          const SizedBox(height: 14),
          SizedBox.square(
            dimension: 248,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _InstrumentPainter(
                      hourProgress: _hourProgress(hour, minutes),
                      illumination: illumination,
                      hasPlace: hasPlace,
                    ),
                  ),
                ),
                if (ruler != null)
                  Positioned(
                    top: 0,
                    left: 100,
                    child: _InstrumentTarget(
                      key: const Key('hoy-ruler-target'),
                      label: 'Regente del día: ${planetEs[ruler] ?? ruler}',
                      onTap: onRulerTap!,
                      child: Text(
                        planetGlyph[ruler] ?? '✦',
                        style: TextStyle(
                          fontSize: 27,
                          height: 1,
                          color: mood.accent,
                        ),
                      ),
                    ),
                  ),
                if (hourPlanet != null)
                  _InstrumentTarget(
                    key: const Key('hoy-hour-target'),
                    label:
                        'Hora planetaria: ${planetEs[hourPlanet] ?? hourPlanet}',
                    onTap: onHourTap!,
                    child: Text(
                      planetGlyph[hourPlanet] ?? '✦',
                      style: TextStyle(
                        fontSize: 42,
                        height: 1,
                        color: ArcanumMood.forPlanet(hourPlanet).accent,
                      ),
                    ),
                  ),
                Positioned(
                  top: 38,
                  right: 21,
                  child: _InstrumentTarget(
                    key: const Key('hoy-moon-target'),
                    label: 'Luna: $phase',
                    onTap: onMoonTap,
                    child: MoonDisc(
                      illumination: illumination,
                      waxing: waxing,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasPlace) ...[
            Text(
              'Día de ${planetEs[ruler] ?? ruler}',
              style: ArcanumText.heading(26),
            ),
            const SizedBox(height: 5),
            Text(
              planetEs[hourPlanet] ?? hourPlanet,
              style: ArcanumText.heading(22),
            ),
            const SizedBox(height: 4),
            Text(
              '${hour?['is_daytime'] == true ? 'Hora diurna' : 'Hora nocturna'}'
              '${minutes == null ? '' : ' · termina en $minutes min'}',
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivory),
            ),
          ] else ...[
            Text(
              'No disponible sin tu lugar',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(23),
            ),
            const SizedBox(height: 8),
            Text(
              'El regente y la hora dependen del amanecer y el ocaso de un '
              'lugar confirmado. La Luna permanece porque es global.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onConfirmPlace,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                side: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                'Confirmar mi lugar',
                style: ArcanumText.body(14, color: ArcanumColors.gold),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(phase, style: ArcanumText.heading(21)),
          const SizedBox(height: 4),
          Text(
            '${(illumination * 100).round()}% iluminada'
            '${age == null ? '' : ' · ${age.round()} días'}',
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 14),
          actions,
        ],
      ),
    );
  }

  static double _hourProgress(Map<String, dynamic>? hour, int? minutes) {
    final starts = DateTime.tryParse((hour?['starts_at'] as String?) ?? '');
    final ends = DateTime.tryParse((hour?['ends_at'] as String?) ?? '');
    if (starts != null && ends != null) {
      final total = ends.difference(starts).inSeconds;
      final elapsed = DateTime.now()
          .toUtc()
          .difference(starts.toUtc())
          .inSeconds;
      if (total > 0) return (elapsed / total).clamp(0.0, 1.0);
    }
    return (1 - ((minutes ?? 60) / 60)).clamp(0.0, 1.0);
  }
}

class _InstrumentTarget extends StatelessWidget {
  const _InstrumentTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox.square(dimension: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _InstrumentPainter extends CustomPainter {
  const _InstrumentPainter({
    required this.hourProgress,
    required this.illumination,
    required this.hasPlace,
  });

  final double hourProgress;
  final double illumination;
  final bool hasPlace;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * 0.44;
    final hourRadius = size.shortestSide * 0.31;
    final moonRadius = size.shortestSide * 0.20;
    final faint = Paint()
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas
      ..drawCircle(center, outerRadius, faint)
      ..drawCircle(center, hourRadius, faint)
      ..drawCircle(center, moonRadius, faint);

    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12 - math.pi / 2;
      final length = i % 6 == 0 ? 13.0 : 7.0;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * outerRadius;
      final end =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (outerRadius - length);
      canvas.drawLine(start, end, faint);
    }

    if (hasPlace) {
      final hourPaint = Paint()
        ..color = ArcanumColors.moonAccent.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: hourRadius),
        -math.pi / 2,
        math.pi * 2 * hourProgress,
        false,
        hourPaint,
      );
    }

    final moonPaint = Paint()
      ..color = ArcanumColors.ivory.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: moonRadius),
      -math.pi / 2,
      math.pi * 2 * illumination,
      false,
      moonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _InstrumentPainter oldDelegate) {
    return hourProgress != oldDelegate.hourProgress ||
        illumination != oldDelegate.illumination ||
        hasPlace != oldDelegate.hasPlace;
  }
}
