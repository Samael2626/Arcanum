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
/// LO QUE SE VE ES LO MISMO QUE EN LA APP, y se consigue reusando las piezas
/// reales, no copiándolas. Esta tarjeta nació antes de la plantilla zodiacal de
/// los doce signos y se quedó atrás: la app enseñaba el grabado de Bayer con su
/// aro realzado y el nombre del signo, y lo que salía por WhatsApp era un fondo
/// negro con una figura suelta. Dos maneras de pintar lo mismo, y solo una se
/// actualizó.
///
/// Ahora el fondo es `LaminaDelSigno` —el mismo widget que la tarjeta de Hoy— y
/// la figura es `PintorRueda`, el mismo pintor del sello. Cambiar el diseño de
/// Hoy cambia esto con él.
library;


import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';
import '../../hoy/presentation/widgets/lamina_del_signo.dart';
import '../../hoy/presentation/widgets/sello_del_cielo.dart';
import '../../hoy/presentation/widgets/zodiaco_laminas.g.dart';

/// Tamaño lógico. A `pixelRatio: 3` sale 1080x1350, que es 4:5 exacto.
const tarjetaAncho = 360.0;
const tarjetaAlto = 450.0;

class TarjetaCompartir extends StatelessWidget {
  const TarjetaCompartir({
    super.key,
    required this.aspecto,
    required this.profeccion,
    required this.texto,
    this.signo,
    this.signoIngles,
  });

  /// Signo solar de quien comparte. Null mientras el cielo carga o si la carta
  /// no trae Sol: entonces la tarjeta sale sin grabado, igual que la de Hoy, y
  /// no se rompe nada.
  final Signo? signo;

  /// El mismo signo en ingles, para el glifo y el nombre.

  /// El tránsito del día (`today`, o el capítulo si hoy no hay nada rápido).
  final Map<String, dynamic>? aspecto;

  /// El año profectado, si esta persona lo tiene. Sin fecha de nacimiento no
  /// hay banda, igual que en la pantalla.
  final Map<String, dynamic>? profeccion;

  final String? signoIngles;

  /// El horóscopo completo. Aquí solo se usa su primera oración.
  final String texto;

  @override
  Widget build(BuildContext context) {
    final frase = primeraFrase(texto);
    final a = aspecto;
    return Container(
      width: tarjetaAncho,
      height: tarjetaAlto,
      // El degradado sigue de fondo para cuando NO hay signo: es lo que se ve
      // si la carta no trae Sol, y sin el la tarjeta quedaria en negro liso.
      decoration: const BoxDecoration(
        color: ArcanumColors.background,
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.95,
          colors: [Color(0xFF1D1608), ArcanumColors.background],
        ),
      ),
      child: Stack(
        children: [
          // La lamina, con su velo por zonas y su delta por signo. El MISMO
          // widget que pinta el fondo de la tarjeta de Hoy.
          if (signo != null) ...[
            LaminaDelSigno(signo: signo!, radio: BorderRadius.zero),
            // OSCURECIDO PROPIO DE ESTA TARJETA, y a proposito no se toca el
            // velo de `LaminaDelSigno`: ese esta medido para la tarjeta de Hoy
            // -- 320x627 -- y cambiarlo alli movería doce contrastes ya
            // validados. Esta es 360x450, y su bloque de texto cae donde aquel
            // velo todavia no ha cerrado.
            //
            // Medido sobre los doce signos: sin esto, el titular de Tauro se
            // queda en 4,43 contra el 4,5 de AA. Tauro es la plancha del papel
            // crema, la misma que ya obligo a corregir la banda del rotulo.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.52, 0.70, 1.0],
                      colors: [
                        Color(0x000A0A0F),
                        Color(0x8C0A0A0F),
                        Color(0xB30A0A0F),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Padding(
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
            if (signoIngles != null) ...[
              const SizedBox(height: 6),
              Text(
                '${signGlyph[signoIngles] ?? ''}  '
                        '${signEs[signoIngles] ?? ''}'
                    .toUpperCase(),
                textAlign: TextAlign.center,
                style: ArcanumText.label().copyWith(
                  color: ArcanumColors.gold,
                  fontFamilyFallback: kGlyphFallback,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                // `progreso: 1` -- el sello ya roto. En la app el aro se abre
                // con una animacion; aqui la tarjeta retrata el final.
                child: SizedBox.square(
                  dimension: 168,
                  child: CustomPaint(
                    painter: PintorRueda(
                      anguloNominal: (a?['angle'] as num?)?.toInt() ?? 0,
                      separacion: (a?['separation'] as num?)?.toDouble(),
                      progreso: 1,
                      sobreLamina: signo != null,
                      glifo: signGlyph[signoIngles ?? ''],
                    ),
                  ),
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
                // Oro y no `ivoryMuted`: medido sobre la lamina, el marfil
                // apagado se quedaba en 4,04 de contraste, por debajo del 4,5
                // de AA. El oro claro pasa y ademas separa el dato del
                // horoscopo, que va en marfil.
                style: ArcanumText.body(12, color: ArcanumColors.goldLight),
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
        ],
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
