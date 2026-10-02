/// Movimiento de la luz de un elemento (D7): ascuas que suben en fuego, ondas
/// en agua, polvo de luz en aire, motas que caen en tierra, rayos en el Sol y
/// estrellas que titilan en la Luna. Pocas piezas y dibujo simple: tiene que
/// aguantar 60 fps en un movil modesto. Con «reducir movimiento», no se dibuja.
/// Es la base de la «huella del palo» de la fase 6.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum MotionKind {
  fire,
  water,
  air,
  earth,
  sun,
  moon;

  /// Desde el nombre en español que usan las caras de las cartas.
  static MotionKind? fromName(String? name) => switch (name) {
    'fuego' => fire,
    'agua' => water,
    'aire' => air,
    'tierra' => earth,
    'sol' => sun,
    'luna' => moon,
    _ => null,
  };
}

class ElementMotion extends StatefulWidget {
  const ElementMotion({
    super.key,
    required this.kind,
    required this.glow,
    required this.accent,
    this.reversed = false,
  });

  final MotionKind kind;
  final Color glow;
  final Color accent;

  /// Invertida: lo que sube, cae.
  final bool reversed;

  @override
  State<ElementMotion> createState() => _ElementMotionState();
}

class _ElementMotionState extends State<ElementMotion>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: MotionPainter(
          kind: widget.kind,
          glow: widget.glow,
          accent: widget.accent,
          reversed: widget.reversed,
          time: _time,
        ),
      ),
    );
  }
}

/// Dibuja el movimiento en el instante `time` (segundos). Las piezas salen de
/// una semilla fija: el mismo instante da siempre el mismo dibujo.
class MotionPainter extends CustomPainter {
  MotionPainter({
    required this.kind,
    required this.glow,
    required this.accent,
    required this.time,
    this.reversed = false,
  }) : super(repaint: time);

  final MotionKind kind;
  final Color glow;
  final Color accent;
  final bool reversed;
  final ValueListenable<double> time;

  /// Cuantas piezas dibuja cada elemento.
  static const counts = {
    MotionKind.fire: 36,
    MotionKind.water: 5,
    MotionKind.air: 44,
    MotionKind.earth: 30,
    MotionKind.sun: 10,
    MotionKind.moon: 26,
  };

  static final List<List<double>> _seeds = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < 48; i++) [for (var k = 0; k < 5; k++) r.nextDouble()],
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value, w = size.width, h = size.height;
    final dot = Paint();
    final n = counts[kind]!;
    for (var i = 0; i < n; i++) {
      final s = _seeds[i];
      final phase = s[4] * 2 * math.pi;
      switch (kind) {
        case MotionKind.fire:
          // ascuas: suben (caen si esta invertida), titilan y se mecen
          final speed = 30 + s[1] * 50;
          var y = h - ((t * speed + s[2] * h) % (h + 20));
          if (reversed) y = h - y;
          final x = s[0] * w + math.sin(t * 2 + phase) * 6;
          dot.color = (s[3] > .7 ? accent : glow).withValues(
            alpha: .35 + .55 * math.sin(t * 5 + phase).abs(),
          );
          final at = Offset(x, y), r = 1.2 + s[3] * 2;
          canvas.drawCircle(at, r, dot);
          // halo: la ascua brilla, no es un punto
          dot.color = dot.color.withValues(alpha: dot.color.a * .1);
          canvas.drawCircle(at, r * 2.4, dot);
        case MotionKind.water:
          // ondas: un anillo se abre y se apaga, y renace en otro sitio
          final cycle = t * .25 + s[1];
          final p = cycle % 1;
          final k = _seeds[(i * 7 + cycle.floor()).toInt() % _seeds.length];
          final c = Offset(k[0] * w, k[2] * h);
          final r = 10 + p * 90;
          canvas.drawOval(
            Rect.fromCenter(center: c, width: r * 2, height: r * .7),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = accent.withValues(alpha: .45 * (1 - p)),
          );
        case MotionKind.air:
          // polvo de luz: cruza de lado y destella
          final x = (s[0] * w + t * (15 + s[1] * 30)) % (w + 10) - 5;
          final y = s[2] * h + math.sin(t + phase) * 6;
          dot.color = accent.withValues(
            alpha: .2 + .7 * math.max(0, math.sin(t * 3 + phase * 3)),
          );
          canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 1.6), dot);
        case MotionKind.earth:
          // motas: caen despacio (suben si esta invertida)
          var y = (s[0] * h + t * (9 + s[1] * 20)) % (h + 10) - 5;
          if (reversed) y = h - y;
          final x = s[2] * w + math.sin(t * .6 + phase) * 5;
          dot.color = (s[3] > .6 ? accent : glow).withValues(
            alpha: .25 + s[3] * .45,
          );
          canvas.drawCircle(Offset(x, y), .8 + s[3] * 1.6, dot);
        case MotionKind.sun:
          // rayos que giran despacio desde arriba
          final a = phase + t * .08;
          final o = Offset(w / 2, h * (reversed ? .88 : .12));
          final end = o + Offset(math.cos(a), math.sin(a)) * h;
          canvas.drawLine(
            o,
            end,
            Paint()
              ..strokeWidth = 10 + s[3] * 16
              ..shader = LinearGradient(
                colors: [
                  glow.withValues(
                    alpha: .22 * (.6 + .4 * math.sin(t * .8 + phase)),
                  ),
                  glow.withValues(alpha: 0),
                ],
              ).createShader(Rect.fromPoints(o, end)),
          );
        case MotionKind.moon:
          // estrellas quietas que titilan
          final a = .15 + .6 * math.max(0, math.sin(t * 1.5 + phase));
          final c = Offset(s[0] * w, s[2] * h);
          dot.color = accent.withValues(alpha: a * .35);
          canvas.drawCircle(c, 2.6 + s[3] * 2, dot);
          dot.color = accent.withValues(alpha: a);
          canvas.drawCircle(c, .6 + s[3] * 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(MotionPainter old) =>
      old.kind != kind ||
      old.glow != glow ||
      old.accent != accent ||
      old.reversed != reversed;
}
