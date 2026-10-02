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
            painter: ImprintPainter(widget.imprint, t: _t, scale: p.scale),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la huella en el instante `t` (0..1). El centro es el de la carta.
class ImprintPainter extends CustomPainter {
  ImprintPainter(this.imprint, {required this.t, this.scale = 1});

  final Imprint imprint;
  final double t;
  final double scale;

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
      old.t != t || old.imprint != imprint || old.scale != scale;
}
