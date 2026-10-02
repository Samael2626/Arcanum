/// Atmosfera de una pieza revelada (D7): la luz de su elemento o su planeta y,
/// detras, su propia lamina muy desenfocada. La usa la «Lectura revelada» de la
/// mesa y la usaran otras pantallas de revelacion (estudiar una carta, Materia,
/// horoscopo).
library;

import 'package:flutter/material.dart';

class Atmosphere extends StatelessWidget {
  const Atmosphere({
    super.key,
    required this.edge,
    required this.core,
    required this.glow,
    this.art,
    this.reversed = false,
  });

  /// Borde oscuro, centro tintado y bruma saturada: los tres tonos de la cara.
  final Color edge;
  final Color core;
  final Color glow;

  /// Lamina de la pieza (un asset). Sin lamina, solo la luz.
  final String? art;

  /// Invertida: la lamina se da la vuelta y la luz cae desde abajo.
  final bool reversed;

  /// La lamina se decodifica a este ancho y se estira: el desenfoque sale del
  /// propio escalado, una vez al decodificar, sin filtro en cada fotograma.
  static const int blurWidth = 24;

  @override
  Widget build(BuildContext context) {
    final light = Alignment(0, reversed ? .35 : -.25);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: light,
              radius: 1.1,
              colors: [glow.withValues(alpha: .55), core, edge],
              stops: const [0, .5, 1],
            ),
          ),
        ),
        if (art case final asset?)
          Opacity(
            opacity: .36,
            child: Transform.rotate(
              angle: reversed ? 3.14159265 : 0,
              child: Transform.scale(
                scale: 1.3,
                child: Image.asset(
                  asset,
                  cacheWidth: blurWidth,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                  // sin lamina queda la luz: no es un error
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: light,
              radius: 1.2,
              colors: [Colors.transparent, Colors.black.withValues(alpha: .6)],
              stops: const [.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}
