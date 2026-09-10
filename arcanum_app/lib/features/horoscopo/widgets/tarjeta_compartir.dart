/// La tarjeta que se comparte. No es una captura de la pantalla.
///
/// Una captura llevaría la barra de navegación, el botón flotante, el texto
/// entero a cuerpo 15 y el fondo de una app: en el feed de otra persona eso es
/// un pantallazo, no una pieza. Esto es una composición aparte y con otro
/// trabajo: 4:5 (el formato que menos recorta Instagram y WhatsApp), la figura
/// del aspecto grande, tres líneas y una frase.
///
/// LA FRASE ES UNA FRASE, NO EL TEXTO. El horóscopo son varios párrafos y en
/// una imagen no se leen: se recorta la PRIMERA ORACIÓN COMPLETA que quepa, y
/// si no cabe ninguna entera no se corta a media palabra — se deja fuera. Un
/// texto cortado con puntos suspensivos promete algo que la imagen no da.
///
/// La figura se dibuja con `figuraDe`, la misma del sello: los dos cuerpos a su
/// separación real. Aquí tampoco se finge un triángulo equilátero.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';
import '../../hoy/domain/figura_aspecto.dart';

/// Tamaño lógico. A `pixelRatio: 3` sale 1080x1350, que es 4:5 exacto.
const tarjetaAncho = 360.0;
const tarjetaAlto = 450.0;

class TarjetaCompartir extends StatelessWidget {
  const TarjetaCompartir({
    super.key,
    required this.aspecto,
    required this.profeccion,
    required this.texto,
  });

  /// El tránsito del día (`today`, o el capítulo si hoy no hay nada rápido).
  final Map<String, dynamic>? aspecto;

  /// El año profectado, si esta persona lo tiene. Sin fecha de nacimiento no
  /// hay banda, igual que en la pantalla.
  final Map<String, dynamic>? profeccion;

  /// El horóscopo completo. Aquí solo se usa su primera oración.
  final String texto;

  @override
  Widget build(BuildContext context) {
    final frase = primeraFrase(texto);
    return Container(
      width: tarjetaAncho,
      height: tarjetaAlto,
      decoration: const BoxDecoration(
        color: ArcanumColors.background,
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.95,
          colors: [Color(0xFF1D1608), ArcanumColors.background],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ARCANUM',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                11,
                color: ArcanumColors.gold,
              ).copyWith(letterSpacing: 5),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Center(
                child: SizedBox.square(
                  dimension: 150,
                  child: CustomPaint(painter: _PintorFigura(aspecto)),
                ),
              ),
            ),
            if (_titular() != null) ...[
              Text(
                _titular()!,
                textAlign: TextAlign.center,
                style: ArcanumText.heading(19, color: ArcanumColors.goldLight),
              ),
              const SizedBox(height: 6),
            ],
            if (profeccion != null) ...[
              Text(
                _lineaDelAnio()!,
                textAlign: TextAlign.center,
                style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 12),
            ],
            if (frase.isNotEmpty)
              Text(
                frase,
                textAlign: TextAlign.center,
                style: ArcanumText.body(13, color: ArcanumColors.ivory),
              ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: ArcanumColors.goldMuted.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Descifra el cielo, traza tu camino',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                10,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _titular() {
    final a = aspecto;
    if (a == null) return null;
    final t = pointEs(a['transit'] as String?);
    final n = pointEs(a['natal'] as String?);
    final asp = aspectEs[a['aspect'] as String?];
    if (t.isEmpty || n.isEmpty || asp == null) return null;
    return '$t $asp tu $n';
  }

  String? _lineaDelAnio() {
    final p = profeccion;
    if (p == null) return null;
    final senor = pointEs(p['lord'] as String?);
    final casa = (p['house'] as num?)?.toInt();
    if (senor.isEmpty || casa == null) return null;
    return 'Este año manda $senor · casa $casa';
  }
}

/// El máximo que cabe legible en la tarjeta sin bajar el cuerpo de letra.
const _maxFrase = 150;

/// La primera oración completa del texto, o vacío si ninguna cabe.
///
/// Público para poder probarlo sin renderizar: es la única lógica de la
/// tarjeta que puede equivocarse en silencio.
String primeraFrase(String texto) {
  final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return '';
  final fin = RegExp(r'[.!?](\s|$)').firstMatch(limpio);
  if (fin == null) {
    // Un texto sin puntuación: o cabe entero, o no se enseña. Cortar a media
    // palabra y poner puntos suspensivos promete lo que la imagen no da.
    return limpio.length <= _maxFrase ? limpio : '';
  }
  final frase = limpio.substring(0, fin.end).trim();
  return frase.length <= _maxFrase ? frase : '';
}

/// La figura del aspecto: aro, cuerda y los dos cuerpos.
class _PintorFigura extends CustomPainter {
  const _PintorFigura(this.aspecto);

  final Map<String, dynamic>? aspecto;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final r = size.width / 2 - 10;

    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ArcanumColors.goldMuted.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      centro,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = ArcanumColors.goldMuted.withValues(alpha: 0.25),
    );

    final a = aspecto;
    if (a == null) return;
    final figura = figuraDe(
      anguloNominal: (a['angle'] as num?)?.toInt() ?? 0,
      separacion: (a['separation'] as num?)?.toDouble(),
      radio: r,
      centro: PuntoRueda(centro.dx, centro.dy),
    );

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = ArcanumColors.gold.withValues(alpha: 0.85);
    final camino = Path()
      ..moveTo(figura.vertices.first.x, figura.vertices.first.y);
    for (final v in figura.vertices.skip(1)) {
      camino.lineTo(v.x, v.y);
    }
    if (figura.cerrada) camino.close();
    canvas.drawPath(camino, trazo);

    for (final p in [figura.transito, figura.natal]) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        4.5,
        Paint()..color = ArcanumColors.goldLight,
      );
    }

    // Un punto de luz en el centro: el ojo necesita un ancla cuando la figura
    // es una recta (oposicion) y no hay poligono que mirar.
    canvas.drawCircle(
      centro,
      2,
      Paint()..color = ArcanumColors.goldMuted.withValues(alpha: 0.8),
    );
    // Marcas cardinales, para que el aro no sea un circulo pelado.
    for (var i = 0; i < 12; i++) {
      final ang = i * math.pi / 6;
      final dir = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(
        centro + dir * r,
        centro + dir * (r - (i % 3 == 0 ? 6 : 3)),
        Paint()
          ..strokeWidth = i % 3 == 0 ? 1.2 : 0.7
          ..color = ArcanumColors.goldMuted.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorFigura viejo) => viejo.aspecto != aspecto;
}
