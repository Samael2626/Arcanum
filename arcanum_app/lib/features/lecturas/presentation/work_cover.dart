import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';

/// La portada de una obra, dibujada por la app.
///
/// No hay imágenes: inventar la cubierta de una edición de 1653 sería fabricar
/// un objeto que no existe, en una sección cuyo valor es citar fuentes reales.
/// Lo que se dibuja es lo verificable — título, autor, año — sobre una
/// encuadernación sobria, con una filigrana que sale del propio título para que
/// cada obra sea reconocible de un vistazo sin fingir que es un facsímil.
class WorkCover extends StatelessWidget {
  final String title;
  final String author;
  final int? year;
  final double height;
  final double width;

  const WorkCover({
    super.key,
    required this.title,
    required this.author,
    required this.height,
    required this.width,
    this.year,
  });

  /// Cada obra recibe siempre el mismo tono: derivarlo del título lo hace
  /// estable entre sesiones sin guardar nada.
  double get _hueShift {
    var sum = 0;
    for (final unit in title.codeUnits) {
      sum = (sum + unit) % 360;
    }
    return sum / 360;
  }

  @override
  Widget build(BuildContext context) {
    final tint = HSLColor.fromColor(ArcanumColors.surfaceHigh)
        .withHue((200 + _hueShift * 120) % 360)
        .withLightness(0.11)
        .toColor();

    return Semantics(
      label: '$title, de $author${year != null ? ', $year' : ''}',
      image: true,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            bottomLeft: Radius.circular(3),
            topRight: Radius.circular(7),
            bottomRight: Radius.circular(7),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint, ArcanumColors.background],
          ),
          border: Border.all(
            color: ArcanumColors.goldMuted.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(2, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // El lomo: la banda oscura del canto izquierdo que hace que un
            // rectángulo parezca un libro puesto de pie.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(width * 0.13, 16, width * 0.08, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❦',
                    style: TextStyle(
                      fontSize: width * 0.11,
                      color: ArcanumColors.gold.withValues(alpha: 0.75),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: ArcanumText.heading(
                        width * 0.115,
                        color: ArcanumColors.gold,
                      ).copyWith(height: 1.18),
                    ),
                  ),
                  Container(
                    height: 1,
                    width: width * 0.3,
                    color: ArcanumColors.goldMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    author,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ArcanumText.body(
                      width * 0.072,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                  if (year != null)
                    Text(
                      '$year',
                      style: ArcanumText.body(
                        width * 0.066,
                        color: ArcanumColors.goldMuted,
                        italic: true,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
