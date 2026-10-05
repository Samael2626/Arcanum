/// Huellas de la mesa: lo que deja una carta al desvelarse. Un Menor suelta una
/// rafaga breve de su elemento (ascuas, ondas, polvo de luz, motas); un Mayor
/// llega con un destello dorado y su glifo planetario un instante. Duran poco y
/// se van solas. Con «reducir movimiento» no se dibujan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/revelado/element_motion.dart';
import '../../oraculo/widgets/tarot_card.dart';
import 'table_geometry.dart';
import 'table_quality.dart';

class SealFlightEmitter extends ChangeNotifier {
  ({String text, Rect from, Rect to})? flight;

  void fly(String text, Rect from, Rect to) {
    flight = (text: text, from: from, to: to);
    notifyListeners();
  }
}

class SealFlightLayer extends StatefulWidget {
  const SealFlightLayer({super.key, required this.emitter});

  final SealFlightEmitter emitter;

  @override
  State<SealFlightLayer> createState() => _SealFlightLayerState();
}

class _SealFlightLayerState extends State<SealFlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  ({String text, Rect from, Rect to})? _flight;

  @override
  void initState() {
    super.initState();
    _progress =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 760),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _flight = null);
          }
        });
    widget.emitter.addListener(_fly);
  }

  @override
  void didUpdateWidget(SealFlightLayer old) {
    super.didUpdateWidget(old);
    if (old.emitter != widget.emitter) {
      old.emitter.removeListener(_fly);
      widget.emitter.addListener(_fly);
    }
  }

  void _fly() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _flight = widget.emitter.flight);
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    widget.emitter.removeListener(_fly);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final flight = _flight;
            if (flight == null || _progress.value >= 1) {
              return const SizedBox.shrink();
            }
            final raw = TableQualityScope.levelOf(context) >= 2
                ? halfRate(_progress.value, _progress.duration!)
                : _progress.value;
            final t = const Cubic(.5, 0, .2, 1).transform(raw);
            final rect = Rect.lerp(flight.from, flight.to, t)!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Opacity(
                    opacity: 1 - t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A0E1A),
                        border: Border.all(
                          color: const Color(0xFFB8960C),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14 + t * 28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          flight.text,
                          maxLines: 3,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(color: Color(0xFFF5F0E8)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// Dispara el anillo al cerrar una lectura.
class CircleMarkEmitter extends ChangeNotifier {
  int epoch = 0;

  void mark() {
    epoch++;
    notifyListeners();
  }
}

class CircleMarkLayer extends StatefulWidget {
  const CircleMarkLayer({super.key, required this.emitter});

  final CircleMarkEmitter emitter;

  @override
  State<CircleMarkLayer> createState() => _CircleMarkLayerState();
}

class _CircleMarkLayerState extends State<CircleMarkLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    widget.emitter.addListener(_mark);
  }

  @override
  void didUpdateWidget(CircleMarkLayer old) {
    super.didUpdateWidget(old);
    if (old.emitter != widget.emitter) {
      old.emitter.removeListener(_mark);
      widget.emitter.addListener(_mark);
    }
  }

  void _mark() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    widget.emitter.removeListener(_mark);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => CustomPaint(
            size: const Size(TableGeometry.width, TableGeometry.height),
            painter: CircleMarkPainter(
              TableQualityScope.levelOf(context) >= 2
                  ? halfRate(_progress.value, _progress.duration!)
                  : _progress.value,
              glow: TableQualityScope.levelOf(context) == 0,
            ),
          ),
        ),
      ),
    ),
  );
}

class CircleMarkPainter extends CustomPainter {
  const CircleMarkPainter(this.progress, {required this.glow});

  final double progress;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final opacity = progress < .3
        ? .9 * progress / .3
        : .9 * (1 - progress) / .7;
    final radius = 220 * (.7 + .38 * Curves.easeOut.transform(progress));
    final center = const Offset(300, 484);
    if (glow) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.fromRGBO(237, 174, 48, .7 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(236, 215, 154, opacity),
    );
  }

  @override
  bool shouldRepaint(CircleMarkPainter old) =>
      old.progress != progress || old.glow != glow;
}

/// Lo que hay que dibujar de una huella: donde, de que elemento y si es Mayor.
class Imprint {
  const Imprint({
    required this.pose,
    required this.kind,
    required this.glow,
    required this.accent,
    this.glyph,
    this.major = false,
    this.delay = Duration.zero,
  });

  /// Desde una cara de carta: su atmosfera decide el elemento y los colores.
  factory Imprint.of(
    TarotFace face,
    TablePose pose, {
    Duration delay = Duration.zero,
  }) {
    final a = tarotAtmosphere(face);
    return Imprint(
      pose: pose,
      kind: MotionKind.fromName(a.motion) ?? MotionKind.air,
      glow: a.glow,
      accent: a.accent,
      major: face.kind == TarotFaceKind.major,
      glyph: tarotMajorGlyph(face),
      delay: delay,
    );
  }

  final TablePose pose;
  final MotionKind kind;
  final Color glow;
  final Color accent;
  final bool major;
  final String? glyph;

  /// Espera antes de empezar: el volteo de la carta tiene que terminar.
  final Duration delay;

  static const Duration duration = Duration(milliseconds: 1600);
}

/// Una huella en la mesa, en unidades de mesa. Se reproduce una vez y avisa.
class ImprintPiece extends StatefulWidget {
  const ImprintPiece({super.key, required this.imprint, required this.onDone});

  final Imprint imprint;
  final VoidCallback onDone;

  /// Lo que ocupa alrededor de la carta: la rafaga sale de sus bordes.
  static const Size area = Size(
    TableGeometry.cardW * 2.6,
    TableGeometry.cardH * 2,
  );

  @override
  State<ImprintPiece> createState() => _ImprintPieceState();
}

class _ImprintPieceState extends State<ImprintPiece>
    with SingleTickerProviderStateMixin {
  // la espera del volteo va dentro de la animacion: sin temporizadores sueltos
  late final _c = AnimationController(
    vsync: this,
    duration: widget.imprint.delay + Imprint.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 mientras espera; de 0 a 1 durante la huella.
  double get _t {
    final total = _c.duration!.inMicroseconds;
    final wait = widget.imprint.delay.inMicroseconds;
    return ((_c.value * total - wait) / (total - wait)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.imprint.pose;
    const area = ImprintPiece.area;
    return Positioned(
      left: p.x - area.width / 2,
      top: p.y - area.height / 2,
      width: area.width,
      height: area.height,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: area,
            painter: ImprintPainter(
              widget.imprint,
              t: _t,
              scale: p.scale,
              glow: TableQualityScope.levelOf(context) < 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la huella en el instante `t` (0..1). El centro es el de la carta.
class ImprintPainter extends CustomPainter {
  ImprintPainter(
    this.imprint, {
    required this.t,
    this.scale = 1,
    this.glow = true,
  });

  final Imprint imprint;
  final double t;
  final double scale;

  /// El resplandor del glifo (se quita con la calidad baja).
  final bool glow;

  static final List<List<double>> _seeds = () {
    final r = math.Random(11);
    return [
      for (var i = 0; i < 24; i++) [for (var k = 0; k < 4; k++) r.nextDouble()],
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final hw = TableGeometry.cardW * scale / 2,
        hh = TableGeometry.cardH * scale / 2;
    final fade = 1 - Curves.easeIn.transform(t);
    if (imprint.major) _major(canvas, c, hw, hh, fade);
    _burst(canvas, c, hw, hh, fade);
  }

  /// Un Mayor: destello dorado detras y su glifo encima de la carta.
  void _major(Canvas canvas, Offset c, double hw, double hh, double fade) {
    final grow = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      c,
      hh * (.8 + grow * 1.1),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                ArcanumColors.goldLight.withValues(alpha: .55 * fade),
                ArcanumColors.gold.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: c, radius: hh * (.8 + grow * 1.1)),
            ),
    );
    final g = imprint.glyph;
    if (g == null) return;
    // el glifo sube un poco y se apaga; aparece en el primer quinto
    final show = (t / .2).clamp(0.0, 1.0) * fade;
    final tp = TextPainter(
      text: TextSpan(
        text: g,
        style: TextStyle(
          fontSize: 30,
          fontFamilyFallback: kGlyphFallback,
          color: ArcanumColors.goldLight.withValues(alpha: show),
          shadows: [
            if (glow)
              Shadow(
                color: ArcanumColors.gold.withValues(alpha: .8 * show),
                blurRadius: 12,
              ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, hh + 18 + tp.height + 12 * grow));
  }

  /// La rafaga del elemento, saliendo de los bordes de la carta.
  void _burst(Canvas canvas, Offset c, double hw, double hh, double fade) {
    final dot = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < _seeds.length; i++) {
      final s = _seeds[i];
      final a = s[0] * 2 * math.pi;
      // punto de partida en el borde de la carta
      final edge = c + Offset(math.cos(a) * hw, math.sin(a) * hh);
      final color = (s[2] > .6 ? imprint.accent : imprint.glow);
      switch (imprint.kind) {
        case MotionKind.fire || MotionKind.sun:
          // ascuas que suben desde el borde, meciendose
          final up = t * (40 + s[1] * 70);
          final at = edge + Offset(math.sin(t * 9 + s[3] * 6) * 5, -up);
          dot.color = color.withValues(alpha: fade * (.5 + .5 * s[3]));
          canvas.drawCircle(at, 1.2 + s[2] * 2, dot);
        case MotionKind.water:
          // tres ondas bajo la carta, que se abren
          if (i >= 3) return;
          final k = ((t - i * .15) / .85).clamp(0.0, 1.0);
          if (k == 0) continue;
          final r = hw * (1.1 + k * 1.4);
          ring.color = imprint.accent.withValues(alpha: .55 * (1 - k));
          canvas.drawOval(
            Rect.fromCenter(
              center: c + Offset(0, hh * .6),
              width: r * 2,
              height: r * .6,
            ),
            ring,
          );
        case MotionKind.air || MotionKind.moon:
          // destellos que se alejan del borde
          final out = t * (20 + s[1] * 50);
          final at = edge + Offset(math.cos(a), math.sin(a)) * out;
          final blink = math.max(0.0, math.sin(t * 14 + s[3] * 6));
          dot.color = imprint.accent.withValues(alpha: fade * blink);
          canvas.drawRect(
            Rect.fromCenter(center: at, width: 2.2, height: 2.2),
            dot,
          );
        case MotionKind.earth:
          // motas que caen del borde
          final down = t * t * (30 + s[1] * 50);
          final at = edge + Offset(math.sin(s[3] * 6) * 4, down);
          dot.color = color.withValues(alpha: fade * (.4 + .5 * s[2]));
          canvas.drawCircle(at, 1 + s[2] * 1.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(ImprintPainter old) =>
      old.t != t ||
      old.imprint != imprint ||
      old.scale != scale ||
      old.glow != glow;
}
