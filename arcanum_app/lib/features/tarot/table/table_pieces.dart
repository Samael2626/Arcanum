/// Piezas vivas de la mesa: cartas en juego y montones, como widgets.
///
/// Las cartas en juego son pocas y ricas (lamina RWS, volteo por palo, lector
/// de pantalla), asi que van como widgets. Cada una anima sola lo que cambia:
/// el viaje a su sitio, el volteo y el giro de 180 grados. Mientras va pegada
/// al dedo no anima nada: seguir al dedo con retraso se nota como lag.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../oraculo/widgets/tarot_card.dart';
import 'table_director.dart';
import 'table_geometry.dart';
import 'table_painters.dart';

const _cardSize = Size(TableGeometry.cardW, TableGeometry.cardH);

/// Matriz de una pieza en la mesa: posicion, altura, giro, escala e inclinacion.
Matrix4 pieceMatrix(
  TablePose p, {
  double lift = 0,
  double tiltX = 0,
  double tiltY = 0,
}) {
  const deg = math.pi / 180;
  return Matrix4.identity()
    ..translateByDouble(p.x, p.y, lift, 1)
    ..rotateZ(p.rot * deg)
    ..scaleByDouble(p.scale, p.scale, 1, 1)
    ..rotateX(tiltX * deg)
    ..rotateY(tiltY * deg)
    ..translateByDouble(-_cardSize.width / 2, -_cardSize.height / 2, 0, 1);
}

TablePose _lerp(TablePose a, TablePose b, double t) {
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

/// Carta en juego.
class TableCardPiece extends StatefulWidget {
  const TableCardPiece({
    super.key,
    required this.view,
    required this.back,
    this.positionLabel,
  });

  final PieceView view;
  final ui.Image back;

  /// Donde esta (hueco, apartada...), para el lector de pantalla.
  final String? positionLabel;

  @override
  State<TableCardPiece> createState() => _TableCardPieceState();
}

class _TableCardPieceState extends State<TableCardPiece>
    with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final AnimationController _flip = AnimationController(vsync: this);
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late TablePose _from = widget.view.pose;
  late TablePose _to = widget.view.pose;
  late TarotFace _face = _resolve();
  double _flipFrom = 0;
  late bool _reversed = widget.view.card!.reversed;

  TarotFace _resolve() {
    final f = widget.view.card!.face;
    return TarotFace.resolve({
      'slug': f.slug,
      'name': f.nameEs ?? f.name ?? '',
      'arcana': f.arcana,
      'suit': f.suit,
      'number': f.number,
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.view.card!.faceUp) _flip.value = 1;
    _turn.value = _reversed ? 1 : 0;
  }

  TablePose get _shown => _move.isAnimating
      ? _lerp(_from, _to, Curves.easeOutCubic.transform(_move.value))
      : _to;

  @override
  void didUpdateWidget(TableCardPiece old) {
    super.didUpdateWidget(old);
    final v = widget.view, c = v.card!;
    if (c.slug != old.view.card!.slug) _face = _resolve();
    if (v.pose != _to) {
      if (v.dragging) {
        _move.stop();
        _from = _to = v.pose;
      } else {
        _from = _shown;
        _to = v.pose;
        _move.forward(from: 0);
      }
    }
    final wasUp = old.view.card!.faceUp;
    if (c.faceUp && !wasUp) {
      // si venia de la esquina, el volteo sigue desde donde la solto el dedo
      final timing = TarotFlipTiming.of(_face);
      _flipFrom = (old.view.peelAngle / 180).clamp(0.0, 1.0);
      _flip
        ..duration = timing.flip * (1 - _flipFrom).clamp(.25, 1.0)
        ..value = 0;
      _flip.animateTo(1, curve: timing.curve);
    } else if (!c.faceUp && wasUp) {
      _flip.value = 0;
      _flipFrom = 0;
    }
    if (c.reversed != _reversed) {
      _reversed = c.reversed;
      _reversed ? _turn.forward() : _turn.reverse();
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _flip.dispose();
    _turn.dispose();
    super.dispose();
  }

  String _semantics() {
    final c = widget.view.card!;
    final where = widget.positionLabel;
    final what = c.faceUp
        ? '${_face.name}${c.reversed ? ', invertida' : ''}'
        : 'Carta boca abajo';
    return where == null ? what : '$what. $where';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    return Positioned(
      left: 0,
      top: 0,
      child: Semantics(
        label: _semantics(),
        button: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([_move, _flip, _turn]),
          builder: (context, _) {
            // grados de volteo: la esquina manda mientras el dedo tira de ella
            final peel = v.peelAngle;
            final flip = peel > 0
                ? peel
                : 180 *
                      (_flipFrom + (1 - _flipFrom) * _flip.value) *
                      (widget.view.card!.faceUp ? 1 : 0);
            final turnBump = math.sin(math.pi * _turn.value);
            return Transform(
              transform: pieceMatrix(
                _shown,
                lift:
                    v.lift +
                    turnBump * 20 +
                    math.sin(math.pi * flip / 180) * 14,
                tiltX: v.tiltX,
                tiltY: v.tiltY,
              ),
              child: _card(flip, peel > 0 ? v.peelHingeX : 0),
            );
          },
        ),
      ),
    );
  }

  /// Carta volteada `deg` grados sobre una bisagra en `hingeX` (0 = el centro).
  Widget _card(double deg, double hingeX) {
    final showFace = deg > 90;
    final dir = widget.view.card!.dir == 0 ? -1 : widget.view.card!.dir;
    final a = deg * math.pi / 180 * dir;
    final m = Matrix4.identity()
      ..translateByDouble(_cardSize.width / 2 + hingeX, 0, 0, 1)
      ..setEntry(3, 2, -1 / 600)
      ..rotateY(a)
      ..translateByDouble(-_cardSize.width / 2 - hingeX, 0, 0, 1);
    Widget side;
    if (showFace) {
      side = Transform(
        alignment: Alignment.center,
        // la cara esta del otro lado: se deshace el espejo del giro
        transform: Matrix4.rotationY(math.pi),
        child: Transform.rotate(
          angle: math.pi * _turn.value,
          child: RepaintBoundary(
            child: TarotCardFaceArt(face: _face, size: _cardSize),
          ),
        ),
      );
    } else {
      side = Transform.rotate(
        angle: math.pi * _turn.value,
        child: RawImage(
          image: widget.back,
          width: _cardSize.width,
          height: _cardSize.height,
          fit: BoxFit.fill,
        ),
      );
    }
    return Transform(
      transform: m,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 6 + widget.view.lift * .15,
              offset: Offset(0, 3 + widget.view.lift * .08),
            ),
          ],
        ),
        child: SizedBox.fromSize(size: _cardSize, child: side),
      ),
    );
  }
}

/// Un monton (o un mazo del estante), con su nombre debajo.
class PilePiece extends StatelessWidget {
  const PilePiece({
    super.key,
    required this.view,
    required this.back,
    this.glow = false,
  });

  final PieceView view;
  final ui.Image back;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final label = view.label;
    return Positioned(
      left: 0,
      top: 0,
      child: Semantics(
        label: '${label ?? 'Montón'}, ${view.count} cartas',
        button: true,
        child: Transform(
          transform: pieceMatrix(
            view.pose,
            lift: view.lift,
            tiltX: view.tiltX,
            tiltY: view.tiltY,
          ),
          child: SizedBox.fromSize(
            size: _cardSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: _cardSize,
                  painter: PilePainter(
                    count: view.count,
                    back: back,
                    glow: glow,
                  ),
                ),
                if (label != null)
                  Positioned(
                    left: -80,
                    right: -80,
                    top: _cardSize.height + 12,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      // dentro de la escala del monton (0,62): 30 unidades se leen a ~12 px
                      style: const TextStyle(
                        fontSize: 30,
                        letterSpacing: 1,
                        color: Color(0xCCECD79A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
