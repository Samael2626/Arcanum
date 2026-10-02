import 'package:arcanum_sigilos/arcanum_sigilos.dart' show pathOf;
import 'package:flutter/material.dart';

import 'sello_modelo.dart';

/// Pinta un sello como lo hace `sealSVG` del prototipo: cada trazo se
/// desplaza a su sitio de la caja del escaneo y se rellena con la tinta.
class SelloPainter extends CustomPainter {
  const SelloPainter(this.pieza, this.color, {this.margen = 0});

  final SelloPieza pieza;
  final Color color;

  /// Aire alrededor, en píxeles lógicos.
  final double margen;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width - margen * 2, alto = size.height - margen * 2;
    if (ancho <= 0 || alto <= 0) return;
    final k = (ancho / pieza.w) < (alto / pieza.h)
        ? ancho / pieza.w
        : alto / pieza.h;
    canvas.save();
    canvas.translate(
      (size.width - pieza.w * k) / 2,
      (size.height - pieza.h * k) / 2,
    );
    canvas.scale(k);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final (d, tx, ty) in pieza.paths) {
      canvas.save();
      canvas.translate(tx, ty);
      canvas.drawPath(pathOf(d), paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SelloPainter old) =>
      old.pieza.id != pieza.id || old.color != color || old.margen != margen;
}
