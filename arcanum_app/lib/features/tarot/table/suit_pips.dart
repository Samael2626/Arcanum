/// Simbolos del palo junto a la carta desvelada (especificacion §6), como en
/// el prototipo (`showPips`):
/// - tantos como su numero (5 de Oros, 5 pentaculos);
/// - figuras: corona y su palo;
/// - Mayores: su numero romano, en vertical;
/// - invertida: los simbolos, invertidos.
///
/// Una columna a la derecha de la carta, 5 unidades fuera y 6 desde arriba,
/// con iconos de trazo de 16 unidades. Entran uno a uno con un pequeño salto
/// (420 ms cada uno, 70 ms entre uno y otro); con «reducir movimiento», o al
/// volver a una mesa ya desvelada, estan sin mas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../oraculo/widgets/tarot_card.dart';
import 'table_geometry.dart';

/// Iconos que lleva una cara: el nombre del palo repetido, o corona + palo.
List<String> pipsFor(TarotFace face) => switch (face.kind) {
  TarotFaceKind.pip => [
    for (var i = 0; i < (face.number ?? 1).clamp(1, 10); i++) face.suit!,
  ],
  TarotFaceKind.court => ['corona', face.suit!],
  TarotFaceKind.major || TarotFaceKind.fallback => const [],
};

/// Numero romano de un Mayor, o null.
String? romanFor(TarotFace face) =>
    face.kind == TarotFaceKind.major ? face.numeral : null;

// el prototipo separaba 2 con cartas de 190 de alto; con las de 176 de la app,
// 1 deja que el Diez quepa en una columna, como alli
const _icon = 16.0, _gap = 1.0;
const _ink = Color(0xFFF7E3A6);

class SuitPips extends StatefulWidget {
  const SuitPips({
    super.key,
    required this.face,
    required this.reversed,
    this.instant = false,
    this.glow = true,
  });

  final TarotFace face;
  final bool reversed;

  /// Sin entrada: ya estaba desvelada al llegar a la mesa.
  final bool instant;

  /// Halo del numero romano (se quita con la calidad baja).
  final bool glow;

  /// Lo que ocupa la columna, para colocarla junto a la carta.
  static const Size area = Size(_icon * 2 + _gap, TableGeometry.cardH - 6);

  @override
  State<SuitPips> createState() => _SuitPipsState();
}

class _SuitPipsState extends State<SuitPips>
    with SingleTickerProviderStateMixin {
  late final List<String> _icons = pipsFor(widget.face);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 120 + 70 * _icons.length + 420),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.instant || still) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: SuitPips.area,
          painter: SuitPipsPainter(
            icons: _icons,
            roman: romanFor(widget.face),
            reversed: widget.reversed,
            elapsed: _c.value * _c.duration!.inMilliseconds,
            glow: widget.glow,
          ),
        ),
      ),
    ),
  );
}

/// Escala de cada icono en su entrada: de 0,2 a 1,35 y se asienta en 1.
double pipScale(double ms) {
  if (ms <= 0) return 0;
  final t = (ms / 420).clamp(0.0, 1.0);
  final e = Curves.easeOut.transform(t);
  if (e < .6) return .2 + (1.35 - .2) * (e / .6);
  return 1.35 + (1 - 1.35) * ((e - .6) / .4);
}

class SuitPipsPainter extends CustomPainter {
  SuitPipsPainter({
    required this.icons,
    required this.roman,
    required this.reversed,
    required this.elapsed,
    this.glow = true,
  });

  final List<String> icons;
  final String? roman;
  final bool reversed;

  /// Milisegundos desde que empezo a entrar.
  final double elapsed;
  final bool glow;

  /// Cuantos iconos caben en una columna antes de pasar a la siguiente.
  static int get perColumn =>
      ((SuitPips.area.height + _gap) / (_icon + _gap)).floor();

  /// Centro del icono `i` dentro de la columna.
  static Offset centerOf(int i) {
    final col = i ~/ perColumn, row = i % perColumn;
    return Offset(
      col * (_icon + _gap) + _icon / 2,
      row * (_icon + _gap) + _icon / 2,
    );
  }

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = roman;
    if (r != null) return _roman(canvas, r);
    for (var i = 0; i < icons.length; i++) {
      final s = pipScale(elapsed - 120 - 70 * i);
      if (s <= 0) continue;
      canvas
        ..save()
        ..translate(centerOf(i).dx, centerOf(i).dy)
        ..scale(s * _icon / 20)
        ..rotate(reversed ? math.pi : 0)
        ..drawPath(pipPath(icons[i]), _stroke)
        ..restore();
    }
  }

  void _roman(Canvas canvas, String text) {
    final s = pipScale(elapsed - 120);
    if (s <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Cormorant Garamond',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1,
          color: const Color(0xFFF2DFA0),
          shadows: [
            if (glow) const Shadow(color: Color(0xCCEDAE30), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // en vertical, como `writing-mode: vertical-rl`: leido de arriba abajo
    canvas
      ..save()
      ..translate(_icon / 2, tp.width / 2)
      ..scale(s)
      ..rotate(math.pi / 2 + (reversed ? math.pi : 0))
      ..translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SuitPipsPainter old) =>
      old.elapsed != elapsed ||
      old.reversed != reversed ||
      old.glow != glow ||
      old.roman != roman ||
      !identical(old.icons, icons);
}

final _star = [
  for (var i = 0; i < 5; i++)
    Offset(
      math.cos((-90 + i * 144) * math.pi / 180) * 6.6,
      math.sin((-90 + i * 144) * math.pi / 180) * 6.6,
    ),
];

/// Trazo de cada icono en una caja de -10 a 10, los del prototipo (`PIP`).
Path pipPath(String kind) => switch (kind) {
  'oros' =>
    Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 8.6))
      ..addPolygon(_star, true),
  'copas' =>
    Path()
      ..moveTo(-6.5, -7)
      ..lineTo(6.5, -7)
      ..cubicTo(6.5, -.5, 3.5, 2.5, 0, 2.5)
      ..cubicTo(-3.5, 2.5, -6.5, -.5, -6.5, -7)
      ..close()
      ..moveTo(0, 2.5)
      ..lineTo(0, 7.5)
      ..moveTo(-4.5, 8)
      ..lineTo(4.5, 8),
  'espadas' =>
    Path()
      ..moveTo(0, -9.5)
      ..lineTo(0, 4)
      ..moveTo(-5.5, 4)
      ..lineTo(5.5, 4)
      ..moveTo(0, 4)
      ..lineTo(0, 9.5)
      ..moveTo(-1.6, -6.5)
      ..lineTo(0, -9.5)
      ..lineTo(1.6, -6.5),
  'bastos' =>
    Path()
      ..moveTo(-3.5, 9.5)
      ..lineTo(3.5, -9.5)
      ..moveTo(1.2, -4.2)
      ..lineTo(4.8, -5.3)
      ..moveTo(-.9, 1.4)
      ..lineTo(-4.6, 2.2)
      ..moveTo(2.4, -7.4)
      ..lineTo(4.7, -5.5),
  'corona' =>
    Path()
      ..moveTo(-8, 5)
      ..lineTo(8, 5)
      ..lineTo(9.4, -5)
      ..lineTo(4.6, -.4)
      ..lineTo(0, -8.5)
      ..lineTo(-4.6, -.4)
      ..lineTo(-9.4, -5)
      ..close(),
  _ => Path(),
};
