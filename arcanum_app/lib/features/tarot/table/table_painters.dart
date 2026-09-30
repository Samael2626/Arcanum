/// Pintores de la mesa, en unidades de mesa (600 x 900).
///
/// Lo que es igual en muchas piezas se pinta con `CustomPainter` (tecnica
/// elegida tras medir en el movil: el abanico de 78 dorsos iba estable a 60 fps
/// asi). El dorso se graba UNA vez en una imagen y despues solo se estampa.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../oraculo/widgets/tarot_card.dart';
import '../domain/table_models.dart';
import 'table_geometry.dart';

/// Graba el dorso del naipe en una imagen, para estamparlo muchas veces sin
/// volver a calcular sus degradados y trazos en cada frame.
ui.Image recordCardBack({double pixelRatio = 2}) {
  const size = Size(TableGeometry.cardW, TableGeometry.cardH);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(pixelRatio);
  paintTarotBack(canvas, size);
  final picture = rec.endRecording();
  final image = picture.toImageSync(
    (size.width * pixelRatio).ceil(),
    (size.height * pixelRatio).ceil(),
  );
  picture.dispose();
  return image;
}

final _cardRect = Rect.fromCenter(
  center: Offset.zero,
  width: TableGeometry.cardW,
  height: TableGeometry.cardH,
);

void _stamp(Canvas canvas, ui.Image back, TablePose p, Paint paint) {
  canvas
    ..save()
    ..translate(p.x, p.y)
    ..rotate(p.rot * math.pi / 180)
    ..scale(p.scale)
    ..drawImageRect(
      back,
      Rect.fromLTWH(0, 0, back.width.toDouble(), back.height.toDouble()),
      _cardRect,
      paint,
    )
    ..restore();
}

/// El paño: marco de madera, tela, huecos de la tirada y el «Interpretar»
/// bordado. Solo se repinta si cambia la tirada, el hueco marcado o si ya se
/// puede interpretar.
class FeltPainter extends CustomPainter {
  FeltPainter({this.spread, this.hotSlot, this.ready = false});

  final SpreadDef? spread;
  final int? hotSlot;
  final bool ready;

  static const _frame = RRect.fromLTRBXY(
    0,
    0,
    TableGeometry.width,
    TableGeometry.height,
    28,
    28,
  );
  static const _cloth = RRect.fromLTRBXY(
    22,
    22,
    TableGeometry.width - 22,
    TableGeometry.height - 22,
    16,
    16,
  );
  static const _embroideryCenter = Offset(300, 484);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      _frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2416), Color(0xFF1E120B), Color(0xFF2E1C11)],
        ).createShader(_frame.outerRect),
    );
    canvas.drawRRect(
      _cloth,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.1),
          radius: .95,
          colors: [
            Color(0xFF3A1020),
            ArcanumColors.burgundy,
            Color(0xFF1F0610),
          ],
          stops: [0, .55, 1],
        ).createShader(_cloth.outerRect),
    );
    canvas.drawRRect(
      _cloth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ArcanumColors.goldMuted.withValues(alpha: .6),
    );
    // la linea del estante: lo de arriba no cuenta para la lectura
    canvas.drawLine(
      const Offset(40, TableGeometry.shelfY),
      const Offset(TableGeometry.width - 40, TableGeometry.shelfY),
      Paint()
        ..strokeWidth = .8
        ..color = ArcanumColors.goldMuted.withValues(alpha: .35),
    );
    _embroidery(canvas);
    final sp = spread;
    if (sp != null) {
      for (var i = 0; i < sp.cardCount; i++) {
        _slot(canvas, sp, i);
      }
    }
  }

  void _embroidery(Canvas canvas) {
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = ArcanumColors.gold.withValues(alpha: ready ? .55 : .18);
    canvas
      ..drawCircle(_embroideryCenter, 202, thread)
      ..drawCircle(_embroideryCenter, 194, thread);
    _text(
      canvas,
      'Interpretar',
      const Offset(300, 716),
      TextStyle(
        fontSize: 26,
        letterSpacing: 3,
        color: ArcanumColors.gold.withValues(alpha: ready ? .95 : .28),
        shadows: ready
            ? [
                Shadow(
                  color: ArcanumColors.gold.withValues(alpha: .6),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }

  void _slot(Canvas canvas, SpreadDef sp, int i) {
    final p = slotPose(sp, i);
    final hot = i == hotSlot;
    canvas
      ..save()
      ..translate(p.x, p.y)
      ..rotate(p.rot * math.pi / 180)
      ..scale(p.scale);
    final r = RRect.fromRectAndRadius(_cardRect, const Radius.circular(9));
    canvas.drawRRect(
      r,
      Paint()
        ..color = (hot ? ArcanumColors.gold : Colors.black).withValues(
          alpha: hot ? .16 : .18,
        ),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hot ? 2 : 1
        ..color = ArcanumColors.gold.withValues(alpha: hot ? .9 : .38),
    );
    canvas.restore();
    final label = sp.labelByName ? sp.slots[i].name : '${i + 1}';
    _text(
      canvas,
      label,
      Offset(p.x, p.y + TableGeometry.cardH * p.scale / 2 + 16),
      TextStyle(
        fontSize: sp.labelByName ? 19 : 21,
        letterSpacing: 1,
        color: ArcanumColors.goldLight.withValues(alpha: .7),
      ),
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 220);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(FeltPainter old) =>
      old.spread != spread || old.hotSlot != hotSlot || old.ready != ready;
}

/// Las cartas del abanico: todas dorsos, estampados de la imagen grabada.
class FanPainter extends CustomPainter {
  FanPainter(this.poses, this.back);

  final List<TablePose> poses;
  final ui.Image back;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;
  static final _shadow = Paint()
    ..color = Colors.black.withValues(alpha: .35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in poses) {
      canvas
        ..save()
        ..translate(p.x + 1.5, p.y + 2)
        ..rotate(p.rot * math.pi / 180)
        ..scale(p.scale)
        ..drawRRect(
          RRect.fromRectAndRadius(_cardRect, const Radius.circular(9)),
          _shadow,
        )
        ..restore();
      _stamp(canvas, back, p, _paint);
    }
  }

  @override
  bool shouldRepaint(FanPainter old) =>
      !identical(old.poses, poses) || old.back != back;
}

/// Un monton: cantos apilados segun las cartas que quedan y el dorso encima.
class PilePainter extends CustomPainter {
  PilePainter({required this.count, required this.back, this.glow = false});

  final int count;
  final ui.Image back;

  /// El mazo recien abierto y sin tocar brilla un poco: invita a empezar.
  final bool glow;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Grosor visible: una capa por cada 6 cartas, hasta 13.
  static int layers(int count) =>
      count == 0 ? 0 : math.min(13, (count / 6).ceil());

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final n = layers(count);
    final edge = Paint()..color = const Color(0xFFD9CCAE);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = const Color(0xFF8C7A55);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (glow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cardRect.inflate(10),
          const Radius.circular(16),
        ),
        Paint()
          ..color = ArcanumColors.gold.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    if (count == 0) {
      // monton vacio (su abanico esta abierto): solo el hueco
      canvas.drawRRect(
        RRect.fromRectAndRadius(_cardRect, const Radius.circular(9)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = ArcanumColors.gold.withValues(alpha: .4),
      );
    }
    for (var i = n; i > 0; i--) {
      final r = RRect.fromRectAndRadius(
        _cardRect.shift(Offset(i * .9, i * 1.8)),
        const Radius.circular(9),
      );
      canvas
        ..drawRRect(r, edge)
        ..drawRRect(r, line);
    }
    canvas.restore();
    if (count > 0) _stamp(canvas, back, TablePose(c.dx, c.dy), _paint);
  }

  @override
  bool shouldRepaint(PilePainter old) =>
      old.count != count || old.back != back || old.glow != glow;
}
