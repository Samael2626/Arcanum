/// Movimiento de la mesa: que las piezas VIAJEN en vez de aparecer.
///
/// El estado salta de golpe (una carta esta o no esta); aqui se anima el
/// cambio. Tres piezas:
/// - [PoseMotion]: una pieza va de su sitio anterior al nuevo, o nace volando
///   desde donde salio (el monton, el abanico, el estante).
/// - [DepartingPiece]: lo que se va (una carta devuelta, un monton unido)
///   vuela a su destino y despues desaparece.
/// - [ShuffleTheaterPainter]: el barajado se ve. Es teatro: el orden lo fija
///   el servidor, la animacion solo cuenta lo que pasa.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'table_geometry.dart';

typedef Birth = ({TablePose from, Duration delay});

TablePose lerpPose(TablePose a, TablePose b, double t) {
  // el giro va por el camino corto: de 350 a 10 no da la vuelta entera
  var dr = (b.rot - a.rot) % 360;
  if (dr > 180) dr -= 360;
  return TablePose(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    rot: a.rot + dr * t,
    scale: a.scale + (b.scale - a.scale) * t,
  );
}

double _bump(double t) => math.sin(math.pi * t.clamp(0.0, 1.0));

/// Una pieza que se mueve de un sitio a otro sin saltar.
///
/// Arrastrada, va pegada al dedo: sin animacion (seguir con retraso se nota
/// como lag). Nacida, sale de donde vino y, con retraso, en escalera.
mixin PoseMotion<W extends StatefulWidget> on State<W>, TickerProvider {
  late final AnimationController motion;
  late TablePose _from;
  late TablePose _to;
  bool _waiting = false;

  static const travel = Duration(milliseconds: 420);

  /// Llamar en `initState`. Crea el controlador ahi y no al primer uso: si el
  /// primer uso fuera el `dispose`, crear un ticker desmontando revienta.
  void motionStart(TablePose pose, Birth? birth) {
    motion = AnimationController(vsync: this, duration: travel);
    _to = pose;
    _from = birth?.from ?? pose;
    if (birth == null) return;
    _waiting = true;
    Future<void>.delayed(birth.delay, () {
      if (!mounted) return;
      _waiting = false;
      motion.forward(from: 0);
    });
  }

  void motionUpdate(TablePose pose, {required bool dragging}) {
    if (pose == _to) return;
    if (dragging) {
      motion.stop();
      _waiting = false;
      _from = _to = pose;
      return;
    }
    _from = shownPose;
    _to = pose;
    motion.forward(from: 0);
  }

  /// «Reducir movimiento»: las piezas aparecen en su sitio, sin viajar.
  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Altura extra a mitad de viaje: lo que se mueve se levanta un poco.
  double get motionLift => !_still && motion.isAnimating
      ? _bump(motion.value) *
            18 *
            (_from.offset - _to.offset).distance.clamp(0, 160) /
            160
      : 0;

  TablePose get shownPose {
    if (_still) return _to;
    if (_waiting) return _from;
    if (!motion.isAnimating) return _to;
    return lerpPose(_from, _to, Curves.easeOutCubic.transform(motion.value));
  }

  void motionDispose() => motion.dispose();
}

/// Lo que se marcha: vuela a su destino, se apaga al llegar y avisa.
class DepartingPiece extends StatefulWidget {
  const DepartingPiece({
    super.key,
    required this.from,
    required this.to,
    required this.child,
    required this.onDone,
    this.duration = const Duration(milliseconds: 480),
  });

  final TablePose from;
  final TablePose to;
  final Widget child;
  final VoidCallback onDone;
  final Duration duration;

  @override
  State<DepartingPiece> createState() => _DepartingPieceState();
}

class _DepartingPieceState extends State<DepartingPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: widget.duration)
      ..forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final v = Curves.easeInOutCubic.transform(_t.value);
          final p = lerpPose(widget.from, widget.to, v);
          return Opacity(
            // se funde solo al final, ya encima del monton
            opacity: (1 - (v - .8) / .2).clamp(0.0, 1.0),
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(p.x, p.y, _bump(v) * 24, 1)
                ..rotateZ(p.rot * math.pi / 180)
                ..scaleByDouble(p.scale, p.scale, 1, 1)
                ..translateByDouble(
                  -TableGeometry.cardW / 2,
                  -TableGeometry.cardH / 2,
                  0,
                  1,
                ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    ),
  );
}

enum ShuffleStyle { cascada, porEncima, sobreElPano }

ShuffleStyle shuffleStyleOf(String id) => switch (id) {
  'por_encima' => ShuffleStyle.porEncima,
  'sobre_el_pano' => ShuffleStyle.sobreElPano,
  _ => ShuffleStyle.cascada,
};

/// Cuanto dura cada barajado, los del prototipo.
Duration shuffleDuration(ShuffleStyle s) => switch (s) {
  ShuffleStyle.cascada => const Duration(milliseconds: 900),
  ShuffleStyle.porEncima => const Duration(milliseconds: 1300),
  ShuffleStyle.sobreElPano => const Duration(milliseconds: 1700),
};

/// Dorsos que representan el barajado sobre el monton. Pocos (hasta 14): el
/// ojo no cuenta, solo ve el gesto.
class ShuffleTheaterPainter extends CustomPainter {
  ShuffleTheaterPainter({
    required this.pile,
    required this.style,
    required this.t,
    required this.back,
    required this.count,
    required this.seed,
  });

  final TablePose pile;
  final ShuffleStyle style;
  final double t;
  final ui.Image back;
  final int count;
  final int seed;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;
  static final _shadow = Paint()
    ..color = Colors.black.withValues(alpha: .35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  void _card(Canvas canvas, Offset at, double rotDeg, double lift) {
    final s = pile.scale;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: TableGeometry.cardW,
      height: TableGeometry.cardH,
    );
    canvas
      ..save()
      ..translate(at.dx, at.dy - lift)
      ..rotate(rotDeg * math.pi / 180)
      ..scale(s)
      ..drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(Offset(0, 3 + lift * .1)),
          const Radius.circular(9),
        ),
        _shadow,
      )
      ..drawImageRect(
        back,
        Rect.fromLTWH(0, 0, back.width.toDouble(), back.height.toDouble()),
        rect,
        _paint,
      )
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = count.clamp(4, 14);
    final c = pile.offset;
    final w = TableGeometry.cardW * pile.scale;
    switch (style) {
      case ShuffleStyle.cascada:
        // se parte en dos mitades, se abren y se entrelazan de vuelta
        final h = n ~/ 2;
        final open = Curves.easeOut.transform((t / .35).clamp(0.0, 1.0));
        for (var i = 0; i < n; i++) {
          final left = i < h;
          final order = left ? 2 * i : 2 * (i - h) + 1;
          final back = ((t - .4 - order * .035) / .2).clamp(0.0, 1.0);
          final spread = open * (1 - Curves.easeInOut.transform(back));
          _card(
            canvas,
            c + Offset((left ? -1 : 1) * w * .62 * spread, 0),
            pile.rot + (left ? -7 : 7) * spread,
            (6 + (left ? i : i - h)) * spread,
          );
        }
      case ShuffleStyle.porEncima:
        // tres cartas suben por encima y vuelven abajo, cuatro veces
        final round = (t * 4).floor().clamp(0, 3);
        final local = t * 4 - round;
        final lift = _bump(local) * TableGeometry.cardH * pile.scale * .7;
        for (var i = 0; i < n; i++) {
          final moving = (i + round * 3) % n < 3;
          _card(
            canvas,
            c - Offset(0, moving ? lift : 0),
            pile.rot,
            moving ? 4 : 0,
          );
        }
      case ShuffleStyle.sobreElPano:
        // las cartas se esparcen y giran sobre el paño, y vuelven al monton
        final rnd = math.Random(seed);
        final out = _bump((t * 1.15).clamp(0.0, 1.0));
        for (var i = 0; i < n + 4; i++) {
          final a = rnd.nextDouble() * math.pi * 2 + t * math.pi * 1.6;
          final r = 70 + rnd.nextDouble() * 110;
          final spin = rnd.nextDouble() * 360;
          _card(
            canvas,
            c + Offset(math.cos(a) * r, math.sin(a) * r * .8) * out,
            pile.rot + (spin + t * 140) * out,
            2,
          );
        }
    }
  }

  @override
  bool shouldRepaint(ShuffleTheaterPainter old) =>
      old.t != t || old.style != style || old.pile != pile;
}
