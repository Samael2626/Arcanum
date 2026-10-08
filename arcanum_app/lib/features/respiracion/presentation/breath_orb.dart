import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../domain/breath_pattern.dart';
import '../domain/breath_phase.dart';
import 'breath_texts.dart';

/// Orbe que crece al llenarse y mengua al vaciarse. Al retener aparece un
/// halo que late; quedarse vacio lo apaga un poco.
class BreathOrbPainter extends CustomPainter {
  const BreathOrbPainter({
    required this.level,
    required this.kind,
    required this.time,
  });

  /// Llenado 0..1.
  final double level;
  final BreathKind kind;

  /// Segundos de practica, para el latido del halo.
  final double time;

  // colores del prototipo: oro calido con sombra terrosa
  static const _stops = [
    Color(0xFFF0DBA8),
    Color(0xFFC9A866),
    Color(0xFF8A6A35),
    Color(0xFF3A2A16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final full = size.shortestSide / 2 * (260 / 300);
    final r = full * (0.42 + 0.58 * level.clamp(0.0, 1.0));

    // resplandor exterior
    canvas.drawCircle(
      c,
      r * 1.04,
      Paint()
        ..color = const Color(0x40C9A866)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.16, -0.24),
          radius: 0.95,
          colors: _stops,
          stops: [0, .28, .62, 1],
        ).createShader(rect),
    );

    if (kind == BreathKind.empty) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0x66000000));
    }

    if (kind == BreathKind.hold) {
      final a = (0.35 + 0.25 * math.sin(time * 2.4)).clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        full * (290 / 260),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFD6BB82).withValues(alpha: 0.5 * a),
      );
    }
  }

  @override
  bool shouldRepaint(BreathOrbPainter old) =>
      old.level != level || old.kind != kind || old.time != time;
}

/// Indicador fijo de fases para movimiento reducido: nada escala, solo se
/// marca la fase en curso.
class BreathStaticIndicator extends StatelessWidget {
  const BreathStaticIndicator({
    super.key,
    required this.phases,
    required this.current,
  });

  final List<BreathPhase> phases;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < phases.length; i++)
              Container(
                key: ValueKey('breath_static_$i'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i == current ? ArcanumColors.goldLight : null,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: i == current
                        ? ArcanumColors.gold
                        : ArcanumColors.surfaceHigh,
                  ),
                ),
                child: Text(
                  '${phaseLabel[phases[i].kind]}'
                  '${phases[i].side == null ? '' : ' · ${phases[i].side}'}'
                  ' ${phases[i].count}',
                  style: ArcanumText.body(
                    15,
                    color: i == current
                        ? ArcanumColors.background
                        : ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
