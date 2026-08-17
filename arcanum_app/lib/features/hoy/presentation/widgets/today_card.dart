import 'package:flutter/material.dart';

import '../../../../shared/widgets/arcanum_mood.dart';

/// El panel de Hoy: gradiente plano dentro de un `RepaintBoundary`.
///
/// Existe en vez de `ArcanumCard` a proposito. Hoy es la pantalla que mas se
/// abre y la que mas paneles apila, y `ArcanumCard` pinta su fondo con un
/// `CustomPaint` que aqui no compensa. Un test de la pantalla vigila que no
/// vuelva a colarse esa tarjeta cara; si haces un panel nuevo para Hoy, usa
/// este.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.mood,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    this.radius = 18,
    this.intensity = 0.55,
  });

  final ArcanumMood mood;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: mood.accent.withValues(alpha: 0.34)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(mood.edge, mood.core, intensity * 0.45)!,
              mood.edge,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4A000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
