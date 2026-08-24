import 'package:arcanum_app/shared/astro_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los ángulos no son planetas: no están en `planetEs` ni tienen glifo.
///
/// Ese detalle se coló en pantalla. La tabla de ángulos vivía como mapa privado
/// dentro del sello, así que la tarjeta del cielo de hoy —que muestra los
/// mismos datos— pintaba **`midheaven`** tal cual, en inglés y en minúscula,
/// dentro de una frase en español.
///
/// No lo cazó ningún test porque todos los que tocan esa tarjeta usan planetas.
/// Se vio al retratar la pantalla y mirarla.
void main() {
  group('los puntos se dicen en español', () {
    test('los ángulos tienen nombre', () {
      expect(pointEs('midheaven'), 'Medio Cielo');
      expect(pointEs('ascendant'), 'Ascendente');
    });

    test('los planetas siguen funcionando', () {
      expect(pointEs('saturn'), 'Saturno');
      expect(pointEs('north_node'), 'Nodo Norte');
    });

    test('todo lo que el motor puede mandar tiene traducción', () {
      // La lista es la de `CLASSICAL_POINTS` del backend: es exactamente lo que
      // puede llegar como `transit` o como `natal` desde que solo trabajamos
      // con cuerpos clásicos.
      const delMotor = [
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
        'north_node', 'ascendant', 'midheaven',
      ];
      for (final clave in delMotor) {
        expect(
          pointEs(clave),
          isNot(clave),
          reason: '$clave llegaría a pantalla en inglés',
        );
      }
    });

    test('lo desconocido se muestra crudo, no vacío', () {
      // Peor que en español, y mucho mejor que un hueco silencioso: si algún
      // día el motor manda un punto nuevo, se ve que falta.
      expect(pointEs('chiron'), 'chiron');
      expect(pointEs(null), '');
      expect(pointEs(''), '');
    });
  });
}
