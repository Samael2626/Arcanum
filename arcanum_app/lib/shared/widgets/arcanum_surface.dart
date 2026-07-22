import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arcanum_mood.dart';

/// Atmósfera de fondo viva para cualquier panel o pantalla de ARCANUM.
///
/// Destilada de la cara de las cartas del Oráculo: gradiente radial desde una
/// fuente de luz (core→edge), fuga de luz asimétrica, bloom del elemento/
/// planeta, grano de material (pergamino/textil) y viñeta de profundidad.
/// Parametrizable por [ArcanumMood] (fuego/agua/aire/tierra/luna/sol/planetas).
///
/// El grano se pinta una sola vez (semilla fija) y `shouldRepaint` sólo
/// dispara cuando cambian humor/parámetros → seguro para 60fps. Para un cielo
/// que respira, pasa [drift] animado (0..1); sin él, la superficie es estática.
class ArcanumSurface extends StatelessWidget {
  final ArcanumMood mood;
  final Widget? child;
  final BorderRadius? borderRadius;

  /// Intensidad global de la atmósfera (0 apagada → 1 plena). Útil para
  /// atenuar un fondo de pantalla completo y no competir con el contenido.
  final double intensity;

  /// Grano de material. Desactívalo en fondos de pantalla completa (coste).
  final bool grain;

  /// Deriva animada de la luz (0..1). Si es null, superficie estática.
  final double? drift;

  const ArcanumSurface({
    super.key,
    required this.mood,
    this.child,
    this.borderRadius,
    this.intensity = 1.0,
    this.grain = true,
    this.drift,
  });

  @override
  Widget build(BuildContext context) {
    Widget painted = CustomPaint(
      painter: _SurfacePainter(
        mood: mood,
        intensity: intensity.clamp(0.0, 1.0),
        grain: grain,
        drift: drift,
      ),
      child: child,
    );
    if (borderRadius != null) {
      painted = ClipRRect(borderRadius: borderRadius!, child: painted);
    }
    return painted;
  }
}

class _SurfacePainter extends CustomPainter {
  final ArcanumMood mood;
  final double intensity;
  final bool grain;
  final double? drift;

  const _SurfacePainter({
    required this.mood,
    required this.intensity,
    required this.grain,
    required this.drift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bounds = Offset.zero & size;
    // Deriva sutil de la luz para el "cielo que respira".
    final dx = drift == null ? 0.0 : (0.06 * math.sin(drift! * 6.283)) * w;
    final dy = drift == null ? 0.0 : (0.05 * math.sin(drift! * 4.11 + 1.3)) * h;
    final cx = w * 0.5 + dx, cy = h * mood.lightY + dy;

    // 1 · Atmósfera base: radial core→edge desde la luz.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((cx / w) * 2 - 1, (cy / h) * 2 - 1),
          radius: 1.05,
          colors: [Color.lerp(mood.edge, mood.core, intensity)!, mood.edge],
        ).createShader(bounds),
    );

    // 2 · Fuga de luz asimétrica (esquina superior-izquierda).
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.8),
          radius: 1.2,
          colors: [
            mood.accent.withValues(alpha: 0.12 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62],
        ).createShader(bounds),
    );

    // 3 · Bloom del elemento/planeta en el foco.
    final bloomR = w * 0.72;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [
            mood.glow.withValues(alpha: 0.30 * intensity),
            mood.glow.withValues(alpha: 0.10 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: bloomR)),
    );

    // 4 · Grano de material (motas deterministas claro/oscuro).
    if (grain) _paintGrain(canvas, size);

    // 5 · Viñeta de profundidad: sólo el borde exterior cae a sombra.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            RadialGradient(
              colors: const [Colors.transparent, Color(0x5C000000)],
              stops: const [0.60, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.5, h * 0.5),
                radius: h * 0.74,
              ),
            ),
    );
  }

  void _paintGrain(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = (w * h / 260).clamp(80, 520).toInt();
    var seed = 1327;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final light = Paint();
    final dark = Paint();
    for (var i = 0; i < n; i++) {
      final px = rnd() * w, py = rnd() * h, br = rnd();
      if (br > 0.5) {
        light.color = const Color(
          0xFFFFF0D6,
        ).withValues(alpha: 0.018 * br * intensity);
        canvas.drawRect(Rect.fromLTWH(px, py, 1, 1), light);
      } else {
        dark.color = Colors.black.withValues(
          alpha: 0.030 * (1 - br) * intensity,
        );
        canvas.drawRect(Rect.fromLTWH(px, py, 1, 1), dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter old) =>
      old.mood.core != mood.core ||
      old.mood.glow != mood.glow ||
      old.mood.edge != mood.edge ||
      old.mood.accent != mood.accent ||
      old.intensity != intensity ||
      old.grain != grain ||
      old.drift != drift;
}
