/// La banda del anio: de quien es el anio que esta viviendo esta persona.
///
/// No es un transito y no se pinta como uno. Un transito pasa —dura horas o
/// semanas y el sello ya lo dibuja como figura—; la profeccion es el MARCO,
/// dura hasta el proximo cumpleanios y no cambia en todo el anio. Por eso va
/// debajo del sello, separada por un filete, y en registro de medallon en vez
/// de rueda: una rueda gira, un anio enmarca.
///
/// EL MEDALLON ES EL DATO. Las doce marcas del aro son las doce casas, y la
/// encendida es la casa profectada: quien no lea la linea de texto ve igual en
/// que sector cae su anio. Se cuenta a la manera de una carta —casa 1 a la
/// izquierda, y de ahi en sentido antihorario—, que es como estan dibujadas
/// las casas en la rueda natal de Cielos. Dos pantallas, una sola convencion.
///
/// SIN FECHA DE NACIMIENTO NO HAY BANDA. El backend devuelve `profection: null`
/// cuando no puede saber la edad, y aqui eso se respeta al pie de la letra: no
/// se pinta un hueco, ni un "sin datos", ni un boton para completar el perfil.
/// Ausencia declarada, la misma regla que dejo el corte de Bogota.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../hoy_lore.dart';

class BandaDelAnio extends StatelessWidget {
  const BandaDelAnio({super.key, required this.profection, this.year});

  /// `{age, house, sign, sign_es, lord, points_in_sign}` tal como lo manda
  /// `/astral/sky-today`. Null cuando no hay fecha de nacimiento.
  final Map<String, dynamic>? profection;

  /// El transito que toca al senor del anio, si hoy lo hay. Va en la banda y no
  /// en los chips del sello porque contesta otra pregunta: los chips dicen que
  /// aprieta hoy, esto dice si lo de hoy va con el tema del anio.
  final Map<String, dynamic>? year;

  @override
  Widget build(BuildContext context) {
    final p = profection;
    final senor = p?['lord'] as String?;
    final casa = (p?['house'] as num?)?.toInt();
    if (p == null || senor == null || casa == null) {
      return const SizedBox.shrink();
    }
    final signo = p['sign_es'] as String?;

    return Semantics(
      label: 'Año profectado: casa $casa, regido por ${pointEs(senor)}',
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Filete(),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => showPlanetLoreSheet(context, senor),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _MedallonDelAnio(casa: casa, senor: senor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTE AÑO MANDA',
                            style: ArcanumText.body(
                              10,
                              color: ArcanumColors.ivoryMuted,
                            ).copyWith(letterSpacing: 2.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pointEs(senor),
                            style: ArcanumText.heading(
                              17,
                              color: ArcanumColors.goldLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pie(casa, signo),
                            style: ArcanumText.body(
                              12,
                              color: ArcanumColors.ivoryMuted,
                            ),
                          ),
                          // El toque va DENTRO de la columna, no suelto debajo
                          // del medallon: es la tercera linea de la misma
                          // pieza -- quien manda, donde, y si hoy le llega
                          // algo -- y como nota aparte se leia como un pie de
                          // pagina de otra cosa.
                          if (_tocaHoy(senor)) ...[
                            const SizedBox(height: 5),
                            Text(
                              _lineaDelToque(),
                              style: ArcanumText.body(
                                12,
                                color: ArcanumColors.gold,
                                italic: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «Casa 5 · Capricornio». El signo puede faltar en material antiguo
  /// cacheado, y entonces se dice solo la casa en vez de escribir un vacio.
  static String _pie(int casa, String? signo) =>
      signo == null || signo.isEmpty ? 'Casa $casa' : 'Casa $casa · $signo';

  bool _tocaHoy(String senor) {
    final y = year;
    return y != null && (y['transit'] == senor || y['natal'] == senor);
  }

  /// «Hoy lo toca la Luna, en sextil.» Se nombra el cuerpo que LLEGA, no el
  /// senor: el senor ya esta escrito arriba y repetirlo no dice nada nuevo.
  ///
  /// Dos formas, porque el senor puede estar en cualquiera de los dos lados:
  /// si lo tocan, llega un planeta del cielo de hoy; si es el quien transita,
  /// lo que toca es un punto de su carta y hay que decir «natal» o pareceria
  /// que hablamos del mismo planeta dos veces.
  String _lineaDelToque() {
    final y = year!;
    final senor = profection!['lord'] as String;
    final asp = aspectEs[y['aspect'] as String?] ?? '';
    if (asp.isEmpty) return 'Hoy el tema del año está en juego.';
    if (y['transit'] == senor) {
      return 'Hoy toca tu ${pointEs(y['natal'] as String?)} natal, en $asp.';
    }
    return 'Hoy lo toca ${_conArticulo(y['transit'] as String?)}, en $asp.';
  }

  /// «el Sol», «la Luna», «Venus». El articulo no es adorno: «lo toca Luna»
  /// esta mal escrito, y esto lo lee una persona. La misma regla que ya sigue
  /// el lacre del sello para «Abrir el sello de la Luna».
  static String _conArticulo(String? clave) {
    const articulo = {'sun': 'el Sol', 'moon': 'la Luna'};
    return articulo[clave] ?? pointEs(clave);
  }
}

/// Filete de separacion. El mismo grosor que el aro del sello, para que las dos
/// piezas se lean del mismo taller.
class _Filete extends StatelessWidget {
  const _Filete();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: ArcanumColors.goldMuted.withValues(alpha: 0.28),
  );
}

/// El medallon: aro grabado, doce marcas y el glifo del senor en el centro.
class _MedallonDelAnio extends StatelessWidget {
  const _MedallonDelAnio({required this.casa, required this.senor});

  final int casa;
  final String senor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 46,
    child: CustomPaint(
      painter: _PintorMedallon(casa: casa),
      child: Center(
        child: Text(
          planetGlyph[senor] ?? '',
          style: ArcanumText.heading(18, color: ArcanumColors.goldLight),
        ),
      ),
    ),
  );
}

class _PintorMedallon extends CustomPainter {
  const _PintorMedallon({required this.casa});

  final int casa;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final r = size.width / 2;
    const anchoBanda = 4.0;
    final rExterior = r - 1.5;
    final rInterior = rExterior - anchoBanda;
    final rMedio = (rExterior + rInterior) / 2;

    final aro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.7);
    canvas.drawCircle(centro, rExterior, aro);
    canvas.drawCircle(
      centro,
      rInterior,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = ArcanumColors.goldMuted.withValues(alpha: 0.32),
    );

    // El sector encendido PRIMERO: un arco de 30 grados relleno dentro de la
    // banda. Es la casa profectada dibujada como lo que es -- un doceavo del
    // circulo --, no como una marca mas larga que las otras. Va debajo de los
    // radios para que estos lo recorten y se vea que ocupa un sector entero.
    final desde = _inicioDeCasa(casa);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: rMedio),
      desde,
      -_porCasa,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = anchoBanda
        ..color = ArcanumColors.goldLight.withValues(alpha: 0.9),
    );

    // Las doce divisiones: radios CRUZANDO la banda, como en una rueda natal.
    // Antes eran marcas que salian hacia fuera y con doce iguales el aro leia
    // como un engranaje; una casa es un sector, no un diente.
    final radio = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.butt
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.55);
    for (var i = 0; i < 12; i++) {
      final ang = _inicioDeCasa(i + 1);
      final dir = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(
        centro + dir * rInterior,
        centro + dir * rExterior,
        radio,
      );
    }
  }

  /// Un doceavo de vuelta, en radianes.
  static const _porCasa = math.pi / 6;

  /// Angulo donde EMPIEZA una casa, en el sistema de `Canvas` (y hacia abajo,
  /// asi que un angulo creciente gira en sentido horario en pantalla).
  ///
  /// La casa 1 arranca a la izquierda y se avanza en sentido antihorario, que
  /// es como estan dibujadas las casas en la rueda natal de Cielos.
  static double _inicioDeCasa(int casa) => math.pi - (casa - 1) * _porCasa;

  @override
  bool shouldRepaint(_PintorMedallon viejo) => viejo.casa != casa;
}
