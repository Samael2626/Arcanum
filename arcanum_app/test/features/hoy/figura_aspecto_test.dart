/// La figura del aspecto sale del angulo, no de un diseno.
///
/// Lo que se fija aqui es que la figura NO mienta: si el trigono esta a 119,3
/// grados, el segundo cuerpo va a 119,3 y no a 120. Dibujar un triangulo
/// perfecto sobre un angulo que no lo es seria fingir una precision que la app
/// no tiene, y este proyecto lleva meses quitando justo esa clase de mentira.
library;

import 'dart:math' as math;

import 'package:arcanum_app/features/hoy/domain/figura_aspecto.dart';
import 'package:flutter_test/flutter_test.dart';

double _grados(PuntoRueda p) {
  final g = math.atan2(p.y, p.x) * 180 / math.pi;
  return (g + 360) % 360;
}

double _separacionEntre(PuntoRueda a, PuntoRueda b) {
  final d = (_grados(b) - _grados(a)).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('cuántos vértices tiene cada aspecto', () {
    test('los que cierran, cierran', () {
      expect(verticesDe(120), 3); // trígono → triángulo
      expect(verticesDe(90), 4); // cuadratura → cuadrado
      expect(verticesDe(60), 6); // sextil → hexágono
    });

    test('la oposición y la conjunción no son polígonos', () {
      expect(verticesDe(180), 2);
      expect(verticesDe(0), 2);
    });

    test('un ángulo que no cabe entero en la vuelta no se cierra', () {
      // 150° (quincuncio) no divide 360. Dibujarlo como polígono sería
      // inventarse una figura que no existe.
      expect(verticesDe(150), 2);
    });
  });

  group('los cuerpos van donde de verdad están', () {
    test('respeta la separación real, no la nominal', () {
      final f = figuraDe(anguloNominal: 120, separacion: 119.3, radio: 100);
      expect(_separacionEntre(f.transito, f.natal), closeTo(119.3, 0.01));
    });

    test('sin separación real cae al ángulo nominal', () {
      // Es lo único cierto que queda; inventarse un desvío sería peor.
      final f = figuraDe(anguloNominal: 90, radio: 100);
      expect(_separacionEntre(f.transito, f.natal), closeTo(90, 0.01));
      expect(f.separacion, 90);
    });

    test('un trígono con orbe NO sale equilátero', () {
      // Este es el test que da sentido a todo lo demás.
      final f = figuraDe(anguloNominal: 120, separacion: 117.0, radio: 100);
      final lado1 = _separacionEntre(f.vertices[0], f.vertices[1]);
      final lado2 = _separacionEntre(f.vertices[1], f.vertices[2]);
      expect(lado1, closeTo(117, 0.01));
      expect(
        (lado1 - lado2).abs() > 1,
        isTrue,
        reason: 'la figura debería verse irregular con orbe de 3°',
      );
    });

    test('la oposición es una recta entre dos puntos', () {
      final f = figuraDe(anguloNominal: 180, separacion: 179.4, radio: 100);
      expect(f.vertices.length, 2);
      expect(f.cerrada, isFalse);
      expect(_separacionEntre(f.transito, f.natal), closeTo(179.4, 0.01));
    });

    test('el trígono se cierra con tres vértices', () {
      final f = figuraDe(anguloNominal: 120, separacion: 120, radio: 100);
      expect(f.vertices.length, 3);
      expect(f.cerrada, isTrue);
    });
  });

  group('la rueda', () {
    test(
      'Aries queda fijo arriba y las longitudes avanzan en sentido horario',
      () {
        final aries = puntoZodiacal(0, radio: 30);
        final cancer = puntoZodiacal(90, radio: 30);
        final libra = puntoZodiacal(180, radio: 30);

        expect(aries.x, closeTo(0, 0.01));
        expect(aries.y, closeTo(-30, 0.01));
        expect(cancer.x, closeTo(30, 0.01));
        expect(cancer.y, closeTo(0, 0.01));
        expect(libra.x, closeTo(0, 0.01));
        expect(libra.y, closeTo(30, 0.01));
      },
    );

    test('todos los vértices caen sobre el círculo', () {
      for (final ang in [60, 90, 120, 180]) {
        final f = figuraDe(anguloNominal: ang, radio: 50);
        for (final v in f.vertices) {
          expect(
            math.sqrt(v.x * v.x + v.y * v.y),
            closeTo(50, 0.01),
            reason: 'vértice fuera del círculo en $ang°',
          );
        }
      }
    });

    test('el tránsito siempre arranca arriba, para poder comparar días', () {
      for (final ang in [60, 90, 120, 180]) {
        final f = figuraDe(anguloNominal: ang, radio: 30);
        expect(f.transito.x, closeTo(0, 0.01));
        expect(f.transito.y, closeTo(-30, 0.01));
      }
    });

    test('el centro se puede mover sin deformar nada', () {
      final f = figuraDe(
        anguloNominal: 120,
        radio: 40,
        centro: const PuntoRueda(100, 100),
      );
      expect(f.transito.x, closeTo(100, 0.01));
      expect(f.transito.y, closeTo(60, 0.01));
    });

    test('una separación imposible se recorta en vez de reventar', () {
      expect(figuraDe(anguloNominal: 120, separacion: 400).separacion, 180);
      expect(figuraDe(anguloNominal: 120, separacion: -5).separacion, 0);
    });
  });
}
