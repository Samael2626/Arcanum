/// La nota del cielo: los nombres del transito, plegados al pie del texto.
///
/// POR QUE EXISTE, que es lo que no se debe deshacer sin leer esto
///
/// Hasta el 26-sep-2026 el horoscopo abria por "Venus atraviesa Escorpio y tira
/// de tu Jupiter natal en Acuario". Los testers no lo entendian, y con razon: es
/// la primera oracion y no significa nada para quien no sabe astrologia. Desde
/// entonces el cuerpo del texto va en castellano y los nombres viajan al final,
/// en una linea que `horoscope.nota_del_cielo` compone en el servidor y que
/// empieza por la MARCA de abajo.
///
/// El servidor ya la escribe sin palabras de oficio -- "Venus en pelea con tu
/// Jupiter de nacimiento" y no "cuadratura" --, asi que esto no traduce nada:
/// solo la separa del cuerpo y la deja plegada.
///
/// PLEGADA Y NO AL PIE EN LETRA PEQUENA, que fue la otra opcion sobre la mesa:
/// quien no sabe astrologia no tiene que tropezarse con la jerga ni para
/// ignorarla, y quien la quiere la abre. Se toca, y abre: el area de toque son
/// 48 dp de alto aunque la linea mida menos.
///
/// SI EL TEXTO NO TRAE NOTA no se pinta nada. Pasa de verdad y no es un error:
/// `nota_del_cielo` devuelve cadena vacia con el cielo en calma, y ademas
/// existen lecturas guardadas de antes del 26-sep que nunca la tuvieron.
library;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Como empieza la nota que compone el servidor.
///
/// Tiene que ser la MISMA cadena que `horoscope.MARCA_NOTA` en el backend. Si
/// una de las dos cambia, la nota se queda dentro del cuerpo y se pinta como si
/// fuera parte de la prosa: no se ve un error, se ve la jerga otra vez en la
/// pantalla. Hay un test que fija este literal.
const String marcaNotaDelCielo = 'El cielo de hoy:';

/// El texto partido en lo que se lee y lo que se pliega.
class TextoConNota {
  const TextoConNota(this.cuerpo, this.nota);

  /// La prosa, sin la nota.
  final String cuerpo;

  /// La nota SIN su marca, o null si el texto no traia ninguna.
  final String? nota;

  /// Parte por la ULTIMA aparicion de la marca.
  ///
  /// La ultima y no la primera: si el modelo escribio su propia nota y el
  /// servidor pego la buena debajo, `con_nota` ya se queda solo con una, pero
  /// una lectura vieja guardada en la base puede traer las dos. Cortando por la
  /// ultima se pliega la de verdad y la duplicada se queda en el cuerpo, donde
  /// se ve y se puede arreglar, en vez de desaparecer sin que nadie se entere.
  static TextoConNota partir(String texto) {
    final limpio = texto.trim();
    final corte = limpio.toLowerCase().lastIndexOf(
      marcaNotaDelCielo.toLowerCase(),
    );
    if (corte < 0) return TextoConNota(limpio, null);

    final cuerpo = limpio.substring(0, corte).trim();
    final nota = limpio.substring(corte + marcaNotaDelCielo.length).trim();
    // Una marca sin nada detras no es una nota: se deja el texto como estaba
    // para no comerse una linea que quizas era parte de la prosa.
    if (nota.isEmpty) return TextoConNota(limpio, null);
    return TextoConNota(cuerpo, nota);
  }
}

/// La linea tocable que abre la nota.
class NotaDelCielo extends StatefulWidget {
  const NotaDelCielo(this.nota, {super.key});

  /// El contenido de la nota, ya sin la marca.
  final String nota;

  @override
  State<NotaDelCielo> createState() => _NotaDelCieloState();
}

class _NotaDelCieloState extends State<NotaDelCielo> {
  bool _abierta = false;

  /// El minimo de la casa para cualquier cosa que se toque.
  static const _alturaDeToque = 48.0;

  @override
  Widget build(BuildContext context) {
    final etiqueta = _abierta ? 'Cerrar el cielo de hoy' : 'Ver el cielo de hoy';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _abierta,
          label: etiqueta,
          child: InkWell(
            onTap: () => setState(() => _abierta = !_abierta),
            child: SizedBox(
              height: _alturaDeToque,
              child: Row(
                children: [
                  Text(
                    // Sin los dos puntos de la marca: aqui es un titulo, no el
                    // arranque de una frase.
                    'El cielo de hoy',
                    style: ArcanumText.body(13).copyWith(
                      color: ArcanumColors.ivoryMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _abierta ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: ArcanumColors.ivoryMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_abierta)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.nota,
              style: ArcanumText.body(13).copyWith(
                color: ArcanumColors.ivoryMuted,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
