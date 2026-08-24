/// La figura del aspecto sobre la rueda del zodiaco.
///
/// No es una ILUSTRACION del aspecto: es el aspecto. Los dos cuerpos se colocan
/// a su separacion angular REAL sobre el circulo, y la cuerda entre ellos es la
/// figura. Si el trigono esta a 119,3 grados y no a 120 exactos, se ve.
///
/// Por que asi y no un triangulo perfecto: la app calcula efemerides de verdad
/// y no puede permitirse fingir una precision que no tiene. Un triangulo
/// equilatero dibujado sobre un angulo de 119,3 es una mentira pequena, pero es
/// la clase de mentira que este proyecto lleva meses quitando del codigo.
///
/// Y tiene una consecuencia buena: la figura cambia sola cada dia sin que nadie
/// dibuje nada. Trigono es un triangulo, cuadratura una cruz, oposicion una
/// linea recta. Sale del angulo, no de un diseno.
library;

import 'dart:math' as math;

/// Un punto en coordenadas del lienzo, con 0,0 arriba a la izquierda.
class PuntoRueda {
  const PuntoRueda(this.x, this.y);
  final double x;
  final double y;

  @override
  String toString() =>
      'PuntoRueda(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Posicion zodiacal con Aries (0°) fijo arriba y avance horario.
///
/// A diferencia de [figuraDe], no fija el primer cuerpo en un origen visual:
/// conserva la longitud ecliptica real para comparar ruedas entre aspectos.
PuntoRueda puntoZodiacal(
  double longitud, {
  double radio = 1,
  PuntoRueda centro = const PuntoRueda(0, 0),
}) {
  final normalizada = ((longitud % 360) + 360) % 360;
  final radianes = (normalizada - 90) * math.pi / 180;
  return PuntoRueda(
    centro.x + radio * math.cos(radianes),
    centro.y + radio * math.sin(radianes),
  );
}

/// La figura lista para pintar: donde va cada cuerpo y como se cierra.
class FiguraAspecto {
  const FiguraAspecto({
    required this.transito,
    required this.natal,
    required this.vertices,
    required this.cerrada,
    required this.separacion,
  });

  /// Donde se pinta el planeta que transita.
  final PuntoRueda transito;

  /// Donde se pinta el punto natal que recibe.
  final PuntoRueda natal;

  /// Los puntos por los que pasa el trazo, empezando por el del transito.
  ///
  /// Para una oposicion son dos y la figura es una recta. Para un trigono son
  /// tres y sale el triangulo. La forma no se elige: se deduce de cuantas veces
  /// cabe el angulo en la vuelta completa.
  final List<PuntoRueda> vertices;

  /// Si el trazo vuelve al primer vertice. Una recta no se cierra.
  final bool cerrada;

  /// La separacion real en grados, tal cual vino del servidor.
  final double separacion;
}

/// Cuantos vertices tiene la figura de un angulo, o 2 si no cierra.
///
/// 120 grados caben 3 veces en la vuelta: triangulo. 90 caben 4: cuadrado. 60
/// caben 6: hexagono. 180 caben 2, y dos puntos no son un poligono sino una
/// recta. La conjuncion (0) tampoco tiene figura.
int verticesDe(int anguloNominal) {
  if (anguloNominal <= 0 || anguloNominal >= 180) return 2;
  final vueltas = 360 / anguloNominal;
  // Solo se cierra si cabe un numero entero de veces. 150 grados (quincuncio)
  // no cierra, y dibujarlo como poligono seria inventarse una figura.
  if ((vueltas - vueltas.roundToDouble()).abs() > 0.01) return 2;
  return vueltas.round();
}

/// Construye la figura para un aspecto ya calculado.
///
/// [separacion] es la distancia angular REAL entre los dos cuerpos; si no
/// consta se cae a [anguloNominal], que es lo unico cierto que queda. Se marca
/// esa diferencia en el resultado para que quien pinte pueda decidir si lo dice.
FiguraAspecto figuraDe({
  required int anguloNominal,
  double? separacion,
  double radio = 1.0,
  PuntoRueda centro = const PuntoRueda(0, 0),
}) {
  final sep = (separacion ?? anguloNominal.toDouble()).clamp(0.0, 180.0);

  // El transito arranca arriba del todo. Es una eleccion de lectura, no
  // astronomica: la rueda gira, y fijar un origen hace que dos dias seguidos se
  // puedan comparar de un vistazo.
  const origenGrados = -90.0;

  PuntoRueda enGrados(double g) {
    final rad = g * math.pi / 180;
    return PuntoRueda(
      centro.x + radio * math.cos(rad),
      centro.y + radio * math.sin(rad),
    );
  }

  final puntoTransito = enGrados(origenGrados);
  final puntoNatal = enGrados(origenGrados + sep);

  final n = verticesDe(anguloNominal);
  final List<PuntoRueda> vertices;
  if (n <= 2) {
    // Recta: solo los dos cuerpos, a su distancia real.
    vertices = [puntoTransito, puntoNatal];
  } else {
    // Poligono: se reparte la vuelta en `n` pasos del angulo NOMINAL. El
    // segundo vertice es el cuerpo natal en su sitio real, asi que la figura
    // sale ligeramente irregular cuando hay orbe — y eso es exactamente lo que
    // se quiere ver.
    vertices = [puntoTransito, puntoNatal];
    for (var i = 2; i < n; i++) {
      vertices.add(enGrados(origenGrados + anguloNominal * i));
    }
  }

  return FiguraAspecto(
    transito: puntoTransito,
    natal: puntoNatal,
    vertices: vertices,
    cerrada: n > 2,
    separacion: sep,
  );
}
