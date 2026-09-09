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
/// Los numeros del velo se midieron sobre una tarjeta de 479 px de alto. La
/// tarjeta real no mide siempre eso -- depende del texto y del tamano de
/// fuente del sistema -- asi que se escalan proporcionalmente. Es la unica
/// libertad que se toma respecto al mockup, y va aqui dicha.
library;

import 'package:flutter/material.dart';

import 'zodiaco_laminas.g.dart';

/// Negro del fondo, el mismo con el que se midio el contraste. No es oro: el
/// velo baja el brillo del grabado sin tenirlo.
const _tinta = Color(0xFF0A0A0F);

/// Topes del bloque de datos en la variante sin correr, en px de referencia.
const _topes = [214.0, 252.0, 304.0, 340.0];
const _alfas = [0.0, 0.72, 0.93, 0.96];

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
              // El velo se midio contra 479 px de alto. Si la tarjeta real es
              // mas alta o mas baja, los topes se estiran con ella: lo que
              // importa es que el oscuro caiga donde cae el texto, y el texto
              // tambien se ha movido.
              final escala = caja.maxHeight / altoDeReferencia;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: lamina.banda
                          ? lamina.altoLamina * escala
                          : caja.maxHeight,
                      width: double.infinity,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          lamina.asset,
                          fit: BoxFit.cover,
                          alignment: lamina.banda
                              ? Alignment.topCenter
                              : Alignment.center,
                          // La lamina es fondo: si no esta, la tarjeta sigue
                          // siendo legible y no se cae nada.
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _velo(lamina.delta, escala, caja.maxHeight),
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
  LinearGradient _velo(int delta, double escala, double alto) {
    final paradas = <double>[];
    final colores = <Color>[];

    void punto(double y, double alfa) {
      paradas.add((y * escala / alto).clamp(0.0, 1.0));
      colores.add(_tinta.withValues(alpha: alfa));
    }

    // Banda del rotulo, arriba. En px y no en fraccion, para que reparta igual
    // en una tarjeta corta que en una larga.
    punto(0, 0.88);
    punto(34, 0.55);
    punto(66, 0.34);
    // Franja limpia: solo la base tenue, que baja el brillo sin apagar color.
    punto(_topes[0] + delta, 0.34);
    // Bloque de datos: de aqui abajo mandan las cifras.
    for (var i = 1; i < _topes.length; i++) {
      punto(_topes[i] + delta, _alfas[i]);
    }
    punto(alto / escala, _alfas.last);

    // Dos paradas no pueden ir a la misma altura ni desordenadas: con la
    // tarjeta muy corta el delta empuja los topes fuera y el degradado se
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
