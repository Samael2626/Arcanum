import 'package:flutter/material.dart';

import '../../core/theme/arcanum_theme.dart';

/// Prosa larga de IA, maquetada para leerse y no para caber.
///
/// El horoscopo se pintaba con un solo `Text` de 15 px sin interlineado ni
/// separacion: un bloque de seis u ocho oraciones seguidas del que la vista se
/// resbala. Esto no toca el contenido -- el texto llega tal cual del servidor
/// y aqui no se reescribe ni se recorta -- solo lo respira.
///
/// TRES COSAS, Y LAS TRES SON TIPOGRAFIA
///
/// 1. INTERLINEADO a 1,58. Crimson Pro trae un interlineado por defecto de
///    alrededor de 1,2, que es de titular, no de parrafo largo.
/// 2. SEPARACION entre parrafos, que antes era cero.
/// 3. UN RESPIRO MAS ANTES DEL CIERRE. La forma del texto la fija el prompt:
///    parrafo 1 es LO DE HOY, parrafo 2 es EL CAPITULO ABIERTO y el tercero es
///    el CIERRE, donde el texto deja de describir el cielo y dice a que se
///    presta. Ese giro se marca con mas aire, no con un encabezado.
///
/// COMO SE PARTE, Y QUE PASA SI NO VIENE PARTIDO
///
/// Se corta por lineas en blanco, y si no hay, por saltos sueltos. Si el texto
/// llega como un unico bloque sin ningun salto, se pinta como un parrafo: NO
/// se inventan cortes contando oraciones, porque eso seria decidir donde
/// termina una idea sin haberla leido, y el corte caeria a veces en mitad de
/// un razonamiento.
///
/// NO COMPROBADO: si el modelo emite o no la linea en blanco. El prompt le
/// pide "dos parrafos y un cierre" pero tambien "prosa corrida", y no dice
/// explicitamente que separe con un renglon vacio. Si resulta que no lo hace,
/// esto sigue mejorando el interlineado y la separacion no se ve -- y el
/// arreglo seria una linea en el prompt, que no se toca desde aqui.
class ProsaGenerada extends StatelessWidget {
  const ProsaGenerada(this.texto, {super.key, this.size = 15});

  final String texto;
  final double size;

  /// Interlineado de lectura larga.
  static const _height = 1.58;

  /// Aire entre parrafos.
  static const _entreParrafos = 18.0;

  /// Aire antes del cierre: donde el texto cambia de describir a proponer.
  static const _antesDelCierre = 26.0;

  /// Parte por lineas en blanco; si no hay, por saltos sueltos. Nunca por
  /// oraciones: ver la nota de arriba.
  static List<String> partir(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return const [];
    for (final patron in [RegExp(r'\n\s*\n'), RegExp(r'\n')]) {
      final trozos = limpio
          .split(patron)
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (trozos.length > 1) return trozos;
    }
    return [limpio];
  }

  @override
  Widget build(BuildContext context) {
    final parrafos = partir(texto);
    if (parrafos.isEmpty) return const SizedBox.shrink();

    final estilo = ArcanumText.body(size).copyWith(height: _height);
    final ultimo = parrafos.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parrafos.length; i++) ...[
          if (i > 0)
            SizedBox(
              // El cierre solo se separa mas cuando de verdad hay tres bloques:
              // con dos, el segundo es el capitulo abierto y no un cierre.
              height: (i == ultimo && parrafos.length >= 3)
                  ? _antesDelCierre
                  : _entreParrafos,
            ),
          Text(parrafos[i], style: estilo),
        ],
      ],
    );
  }
}
