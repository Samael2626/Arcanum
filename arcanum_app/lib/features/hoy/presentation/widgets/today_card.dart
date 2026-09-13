import 'package:flutter/material.dart';

import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/arcanum_resin.dart';

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
    this.fondo,
  });

  final ArcanumMood mood;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double intensity;

  /// Capa que va DETRAS del contenido y dentro del mismo redondeo: hoy, la
  /// lamina del signo solar. Va aparte del `child` porque tiene que quedar por
  /// debajo de todo y recortada por el borde de la tarjeta, no dentro del
  /// padding. Sin ella la tarjeta es exactamente la de antes.
  final Widget? fondo;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        // SIN FILETE, como el resto. Llevaba Border.all(accent al 34 %) y era
        // el ultimo rectangulo duro que quedaba en Cielo: con todo lo demas ya
        // sin linea, se leia como una pegatina sobre el lienzo.
        //
        // El degradado y la sombra salen de ArcanumResin y no se copian aqui:
        // asi el tope de luz que protege el texto es UNO, no dos que se
        // separan con el tiempo. La sombra sube de blur 6 a la de la casa
        // (18, desplazada 8): sin filete, es lo unico que despega la pieza.
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: ArcanumResin.gradient(mood: mood, intensity: intensity),
          boxShadow: ArcanumResin.shadow,
        ),
        // El padding va DENTRO y no en el Container: el fondo tiene que
        // llegar al borde redondeado, no quedarse dentro del margen.
        child: fondo == null
            ? Padding(padding: padding, child: child)
            : Stack(
                children: [
                  fondo!,
                  Padding(padding: padding, child: child),
                ],
              ),
      ),
    );
  }
}
