/// La lamina del signo solar, de fondo de la tarjeta de Hoy.
///
/// Es la plantilla "bayerG", que se cerro en el mockup y se valido midiendo,
/// no mirando. Tres cosas la componen y ninguna es decorativa:
///
///   1. LA PLANCHA A SANGRE. El grabado de Bayer (1603) va de fondo de la
///      tarjeta, a color y sin pasarlo por la paleta: es la lamina real, solo
///      colocada. Cada signo trae su recorte ya a la proporcion de la tarjeta,
///      asi que `BoxFit.cover` no recorta nada. Piscis es la excepcion y va en
///      banda; el manifest explica por que.
///
///   2. EL VELO POR ZONAS. No es una rampa pareja ni un velo uniforme: es una
///      base tenue mas dos bandas oscuras justo donde cae el texto. Arriba, el
///      rotulo; abajo, el bloque de datos. En medio queda la franja limpia
///      donde se ve la bestia. Los datos mandan sobre el fondo, esa es la
///      regla.
///
///   3. EL DELTA. Donde arranca ese bloque de datos NO es constante: la figura
///      de cada plancha mide distinto. El numero sale de donde acaba el foco
///      del signo y esta topado por el contraste real del texto que va encima
///      -- en Cancer y Escorpio manda el contraste y la figura se funde por
///      abajo. Los doce pasan AA (4,5) con el minimo en 4,73. Ver el campo
///      `velo` del manifest y la tabla generada en `zodiaco_laminas.g.dart`.
///
/// Los topes del velo van en PIXELES desde arriba, no en fraccion del alto.
/// Es a proposito, y se probo al reves: escalandolos con el alto de la tarjeta
/// el velo se estiraba y el rotulo se quedaba sobre el grabado a plena luz. Lo
/// que fija esos numeros no es el alto de la tarjeta sino donde cae el
/// contenido -- el rotulo a 16, el aro de 44 a 220, los chips justo despues --
/// y eso no se mueve porque la tarjeta crezca por abajo. Lo que crece por
/// abajo ya esta en el oscuro final.
library;

import 'package:flutter/material.dart';

import 'zodiaco_laminas.g.dart';

/// Negro del fondo, el mismo con el que se midio el contraste. No es oro: el
/// velo baja el brillo del grabado sin tenirlo.
const _tinta = Color(0xFF0A0A0F);

/// Topes del bloque de datos, en px desde el borde de arriba de la tarjeta.
///
/// El mockup los dejo en 214/252/304/340, pero su tarjeta media 324x479 y la
/// de verdad mide 320x604 con el contenido mas abajo: medida en la pantalla
/// compilada, la banda de chips cae en 257..283 y el titular arranca en 289,
/// contra 226..252 y 258 del mockup. Son 31 px de diferencia y se aplican
/// aqui. La FORMA de la rampa no cambia -- +38, +52, +36 entre topes -- porque
/// eso es lo que se valido: oscuro del todo justo antes del titular.
const _topes = [245.0, 283.0, 335.0, 371.0];
const _alfas = [0.0, 0.72, 0.95, 0.97];

/// La banda del rotulo. 'TU CIELO DE HOY' va de 30 a 47, medido, y el aro
/// empieza sobre 63: la banda se mantiene opaca hasta pasado el rotulo y se
/// abre antes de llegar al aro. La primera version caia demasiado pronto y el
/// rotulo se quedaba en 2,26 de contraste sobre las planchas claras.
const _bandaRotulo = [0.0, 52.0, 92.0];
const _alfaRotulo = [0.88, 0.84, 0.34];

class LaminaDelSigno extends StatelessWidget {
  const LaminaDelSigno({super.key, required this.signo, required this.radio});

  final Signo signo;
  final BorderRadius radio;

  @override
  Widget build(BuildContext context) {
    final lamina = laminasDelZodiaco[signo]!;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: radio,
          child: LayoutBuilder(
            builder: (context, caja) {
              final alto = caja.maxHeight;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: lamina.banda
                          ? caja.maxWidth * lamina.altoLamina / 324
                          : alto,
                      width: double.infinity,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          lamina.asset,
                          // `cover` NO: la tarjeta es mas estrecha de
                          // proporcion que el recorte, asi que recortaba los
                          // lados y se comia el encuadre que se midio signo a
                          // signo. Con `fitWidth` el ancho se respeta entero y
                          // lo que falta por abajo cae donde el velo ya esta
                          // casi opaco.
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                          // La lamina es fondo: si no esta, la tarjeta sigue
                          // siendo legible y no se cae nada.
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _velo(lamina.delta, alto),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// El velo entero en un solo degradado: la banda del rotulo, el bloque de
  /// datos corrido por su delta, y la base tenue por debajo de todo.
  LinearGradient _velo(int delta, double alto) {
    final paradas = <double>[];
    final colores = <Color>[];

    void punto(double y, double alfa) {
      paradas.add((y / alto).clamp(0.0, 1.0));
      colores.add(_tinta.withValues(alpha: alfa));
    }

    // Banda del rotulo, arriba.
    for (var i = 0; i < _bandaRotulo.length; i++) {
      punto(_bandaRotulo[i], _alfaRotulo[i]);
    }
    // Franja limpia: solo la base tenue, que baja el brillo sin apagar color.
    punto(_topes[0] + delta, 0.34);
    // Bloque de datos: de aqui abajo mandan las cifras.
    for (var i = 1; i < _topes.length; i++) {
      punto(_topes[i] + delta, _alfas[i]);
    }
    punto(alto, _alfas.last);

    // Dos paradas no pueden ir a la misma altura ni desordenadas: en una
    // tarjeta corta el delta empuja los topes fuera del 1.0 y el degradado se
    // rompe. Se aplanan aqui en vez de dejar que reviente en pantalla.
    for (var i = 1; i < paradas.length; i++) {
      if (paradas[i] <= paradas[i - 1]) {
        paradas[i] = (paradas[i - 1] + 0.0001).clamp(0.0, 1.0);
      }
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colores,
      stops: paradas,
    );
  }
}
