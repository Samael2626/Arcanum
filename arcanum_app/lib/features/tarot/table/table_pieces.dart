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
import 'table_motion.dart';
import 'table_painters.dart';
import 'table_quality.dart';

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

/// Carta en juego.
class TableCardPiece extends StatefulWidget {
  const TableCardPiece({
    super.key,
    required this.view,
    required this.back,
    this.positionLabel,
    this.birth,
  });

  final PieceView view;
  final ui.Image back;

  /// Donde esta (hueco, apartada...), para el lector de pantalla.
  final String? positionLabel;

  /// De donde sale volando al aparecer (el monton, el abanico), o null.
  final Birth? birth;

  @override
  State<TableCardPiece> createState() => _TableCardPieceState();
}

class _TableCardPieceState extends State<TableCardPiece>
    with TickerProviderStateMixin, PoseMotion {
  // se crean al montar, no al primer uso (ver PoseMotion.motionStart)
  late final AnimationController _flip;
  late final AnimationController _turn;

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
    motionStart(widget.view.pose, widget.birth);
    _flip = AnimationController(
      vsync: this,
      value: widget.view.card!.faceUp ? 1 : 0,
    );
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: _reversed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(TableCardPiece old) {
    super.didUpdateWidget(old);
    final v = widget.view, c = v.card!;
    if (c.slug != old.view.card!.slug) _face = _resolve();
    motionUpdate(v.pose, dragging: v.dragging);
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
    motionDispose();
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
          animation: Listenable.merge([motion, _flip, _turn]),
          builder: (context, _) {
            // «reducir movimiento»: volteo y giro de golpe, sin saltos; la
            // esquina sigue al dedo porque la mueve el usuario
            final still = MediaQuery.disableAnimationsOf(context);
            final up = widget.view.card!.faceUp;
            // grados de volteo: la esquina manda mientras el dedo tira de ella
            final peel = v.peelAngle;
            final flip = peel > 0
                ? peel
                : still
                ? (up ? 180.0 : 0.0)
                : 180 *
                      (_flipFrom + (1 - _flipFrom) * _flip.value) *
                      (up ? 1 : 0);
            final turn = still ? (_reversed ? 1.0 : 0.0) : _turn.value;
            final turnBump = still ? 0.0 : math.sin(math.pi * turn);
            return Transform(
              transform: pieceMatrix(
                shownPose,
                lift:
                    v.lift +
                    turnBump * 20 +
                    (still && peel == 0
                        ? 0
                        : math.sin(math.pi * flip / 180) * 14),
                tiltX: v.tiltX,
                tiltY: v.tiltY,
              ),
              child: _card(flip, peel > 0 ? v.peelHingeX : 0, turn),
            );
          },
        ),
      ),
    );
  }

  /// Carta volteada `deg` grados sobre una bisagra en `hingeX` (0 = el centro).
  Widget _card(double deg, double hingeX, double turn) {
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
          angle: math.pi * turn,
          child: RepaintBoundary(
            child: TarotCardFaceArt(face: _face, size: _cardSize),
          ),
        ),
      );
    } else {
      side = Transform.rotate(
        angle: math.pi * turn,
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
              blurRadius: TableQualityScope.levelOf(context) < 1
                  ? 6 + widget.view.lift * .15
                  : 0,
              offset: Offset(0, 3 + widget.view.lift * .08),
            ),
          ],
        ),
        child: SizedBox.fromSize(size: _cardSize, child: side),
      ),
    );
  }
}

/// Carta pedida al servidor que aun no ha llegado: un dorso que sale del
/// abanico y vuela a su sitio en el acto. Cuando llega la de verdad, esta
/// desaparece y la otra nace donde estaba. No se toca.
class PendingCardPiece extends StatefulWidget {
  const PendingCardPiece({
    super.key,
    required this.view,
    required this.back,
    this.birth,
  });

  final PieceView view;
  final ui.Image back;
  final Birth? birth;

  @override
  State<PendingCardPiece> createState() => _PendingCardPieceState();
}

class _PendingCardPieceState extends State<PendingCardPiece>
    with SingleTickerProviderStateMixin, PoseMotion {
  @override
  void initState() {
    super.initState();
    motionStart(widget.view.pose, widget.birth);
  }

  @override
  void didUpdateWidget(PendingCardPiece old) {
    super.didUpdateWidget(old);
    motionUpdate(widget.view.pose, dragging: widget.view.dragging);
  }

  @override
  void dispose() {
    motionDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: IgnorePointer(
      child: Semantics(
        label: 'Sacando una carta',
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, child) => Transform(
            transform: pieceMatrix(
              shownPose,
              lift: widget.view.lift + motionLift,
            ),
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .45),
                  blurRadius: TableQualityScope.levelOf(context) < 1
                      ? 6 + widget.view.lift * .15
                      : 0,
                  offset: Offset(0, 3 + widget.view.lift * .08),
                ),
              ],
            ),
            child: RawImage(
              image: widget.back,
              width: _cardSize.width,
              height: _cardSize.height,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Un monton (o un mazo del estante), con su nombre debajo. Viaja como las
/// cartas: el corte sale del monton original y el mazo abierto, del estante.
class PilePiece extends StatefulWidget {
  const PilePiece({
    super.key,
    required this.view,
    required this.back,
    this.glow = false,
    this.birth,
    this.shownCount,
  });

  final PieceView view;
  final ui.Image back;
  final bool glow;
  final Birth? birth;

  /// Cartas que se ven en la caja (menos mientras se baraja), o las reales.
  final int? shownCount;

  @override
  State<PilePiece> createState() => _PilePieceState();
}

class _PilePieceState extends State<PilePiece>
    with SingleTickerProviderStateMixin, PoseMotion {
  @override
  void initState() {
    super.initState();
    motionStart(widget.view.pose, widget.birth);
  }

  @override
  void didUpdateWidget(PilePiece old) {
    super.didUpdateWidget(old);
    motionUpdate(widget.view.pose, dragging: widget.view.dragging);
  }

  @override
  void dispose() {
    motionDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final label = view.label;
    return Positioned(
      left: 0,
      top: 0,
      child: Semantics(
        label: '${label ?? 'Montón'}, ${view.count} cartas',
        button: true,
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, child) => Transform(
            transform: pieceMatrix(
              shownPose,
              lift: view.lift + motionLift,
              tiltX: view.tiltX,
              tiltY: view.tiltY,
            ),
            child: child,
          ),
          child: SizedBox.fromSize(
            size: _cardSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: _cardSize,
                  painter: PilePainter(
                    count: widget.shownCount ?? view.count,
                    back: widget.back,
                    glow: widget.glow,
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

/// El sello de cera de la pregunta. Aparece con un golpe al sellar y, al
/// interpretar, se rompe: da un respingo y le cruza una grieta.
class SealPiece extends StatefulWidget {
  const SealPiece({super.key, required this.at, required this.open});

  final Offset at;
  final bool open;

  @override
  State<SealPiece> createState() => _SealPieceState();
}

class _SealPieceState extends State<SealPiece> with TickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _crack;

  static const double _d = 84;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _crack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.open ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(SealPiece old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) _crack.forward(from: 0);
    if (!widget.open && old.open) _crack.value = 0;
  }

  @override
  void dispose() {
    _press.dispose();
    _crack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.at.dx - _d / 2,
      top: widget.at.dy - _d / 2,
      child: Semantics(
        label: widget.open ? 'Pregunta abierta' : 'Pregunta sellada',
        button: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _crack]),
          builder: (context, _) {
            // «reducir movimiento»: el sello esta, sin golpe ni respingo
            final still = MediaQuery.disableAnimationsOf(context);
            // golpe al sellar: entra grande y se asienta
            final press = still
                ? 1.0
                : Curves.elasticOut.transform(_press.value);
            // respingo al romperse: 1,2 y -6 grados que vuelven a su sitio
            final jolt = still ? 0.0 : math.sin(math.pi * _crack.value);
            final crack = still ? 1.0 : _crack.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  press * (1 + .2 * jolt),
                  press * (1 + .2 * jolt),
                  1,
                  1,
                )
                ..rotateZ(-6 * math.pi / 180 * jolt),
              child: CustomPaint(
                size: const Size.square(_d),
                painter: _SealPainter(
                  crack: widget.open ? crack : 0,
                  soft: TableQualityScope.levelOf(context) < 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.crack, this.soft = true});

  /// Sombra desenfocada; con la calidad baja, nitida.
  final bool soft;

  /// 0 sellado; hasta 1, la grieta avanzando.
  final double crack;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final open = crack > 0;
    canvas.drawCircle(
      c.translate(0, 5),
      r,
      soft
          ? (Paint()
              ..color = Colors.black.withValues(alpha: .55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6))
          : (Paint()..color = Colors.black.withValues(alpha: .4)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.24, -.36),
          colors: open
              ? const [Color(0xFF6D2030), Color(0xFF3A0B16), Color(0xFF1D050A)]
              : const [Color(0xFF9B2A3D), Color(0xFF5A1422), Color(0xFF2A0610)],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xBFC9A84C),
    );
    // el emblema: circulo y dos triangulos entrelazados, como el prototipo
    final k = (r - 14) / 12;
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * k
      ..color = const Color(0xFFECD79A).withValues(alpha: open ? .6 : 1);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(k)
      ..drawCircle(Offset.zero, 10.5, gold..strokeWidth = 1.1)
      ..drawPath(
        Path()
          ..moveTo(0, -8)
          ..lineTo(6.9, 4)
          ..lineTo(-6.9, 4)
          ..close()
          ..moveTo(0, 8)
          ..lineTo(-6.9, -4)
          ..lineTo(6.9, -4)
          ..close(),
        gold,
      )
      ..restore();
    if (open) {
      // la grieta cruza en diagonal a 118 grados, como el corte del prototipo
      final a = 118 * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      final from = c - dir * r, to = c + dir * r;
      canvas.drawLine(
        from,
        Offset.lerp(from, to, crack)!,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xF20A0406),
      );
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.crack != crack || old.soft != soft;
}
