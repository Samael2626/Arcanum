// La tarjeta que se comparte y su captura.
//
// Lo que se fija:
//   - que la frase es una oración COMPLETA o no aparece (nunca un corte)
//   - que sin año profectado no se inventa la banda
//   - que la captura sale a 1080x1350: 4:5, el formato del feed
import 'dart:typed_data';

import 'package:arcanum_app/features/horoscopo/compartir_horoscopo.dart';
import 'package:arcanum_app/features/horoscopo/widgets/tarjeta_compartir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _aspecto = {
  'transit': 'moon',
  'natal': 'midheaven',
  'aspect': 'trine',
  'angle': 120,
  'separation': 119.34,
};

const _profeccion = {
  'age': 35,
  'house': 5,
  'sign_es': 'Capricornio',
  'lord': 'saturn',
};

Future<GlobalKey> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? profeccion = _profeccion,
  String texto = 'Saturno cierra un cuadrado con tu Sol. Y hay más después.',
}) async {
  final clave = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: clave,
            child: TarjetaCompartir(
              aspecto: _aspecto,
              profeccion: profeccion,
              texto: texto,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return clave;
}

/// Ancho y alto de un PNG, leidos de su cabecera IHDR.
///
/// A mano y sin dependencia nueva: los ocho bytes que van del 16 al 23 son el
/// ancho y el alto en big-endian, y esta es la unica cosa que hace falta saber
/// del fichero. Anadir un decodificador entero al proyecto para leer dos
/// enteros seria pagar caro una comprobacion barata.
(int, int) _tamanoPng(Uint8List png) {
  int leer(int desde) =>
      (png[desde] << 24) | (png[desde + 1] << 16) |
      (png[desde + 2] << 8) | png[desde + 3];
  return (leer(16), leer(20));
}

void main() {
  group('la frase', () {
    test('se queda con la primera oración completa', () {
      expect(
        primeraFrase('Saturno aprieta hoy. Mañana afloja. Y luego otra cosa.'),
        'Saturno aprieta hoy.',
      );
    });

    test('respeta los signos de cierre y los espacios sobrantes', () {
      expect(primeraFrase('  ¿Y si no?   Pues eso.  '), '¿Y si no?');
      expect(primeraFrase('Una sola línea sin más.'), 'Una sola línea sin más.');
    });

    test('si la primera oración no cabe, NO se corta: se deja fuera', () {
      final larga = '${'palabra ' * 40}final.';
      expect(primeraFrase(larga), '');
    });

    test('un texto sin puntuación solo entra si cabe entero', () {
      expect(primeraFrase('cielo en calma'), 'cielo en calma');
      expect(primeraFrase('a' * 200), '');
    });

    test('un texto vacío no rompe', () {
      expect(primeraFrase(''), '');
      expect(primeraFrase('   '), '');
    });
  });

  group('la tarjeta', () {
    testWidgets('nombra el tránsito, el año y la frase', (tester) async {
      await _montar(tester);
      expect(find.text('Luna trígono tu Medio Cielo'), findsOneWidget);
      expect(find.text('Este año manda Saturno · casa 5'), findsOneWidget);
      expect(
        find.text('Saturno cierra un cuadrado con tu Sol.'),
        findsOneWidget,
      );
      expect(find.text('ARCANUM'), findsOneWidget);
    });

    testWidgets('sin año profectado no se inventa la banda', (tester) async {
      await _montar(tester, profeccion: null);
      expect(find.textContaining('Este año manda'), findsNothing);
      expect(find.text('Luna trígono tu Medio Cielo'), findsOneWidget);
    });

    testWidgets('no lleva el texto entero, solo la frase', (tester) async {
      await _montar(tester);
      expect(find.textContaining('Y hay más después'), findsNothing);
    });
  });

  group('la captura', () {
    testWidgets('sale a 1080x1350, que es 4:5', (tester) async {
      final clave = await _montar(tester);
      // `runAsync`: `toImage` espera a que el motor rasterice de verdad, y con
      // el reloj falso de `testWidgets` esa espera no termina nunca. Se cazo
      // colgando la suite entera.
      final png = await tester.runAsync(() => pintarTarjeta(clave));

      expect(png, isNotNull);
      final (ancho, alto) = _tamanoPng(png as Uint8List);
      expect(ancho, (tarjetaAncho * densidadTarjeta).round());
      expect(alto, (tarjetaAlto * densidadTarjeta).round());
      expect(ancho / alto, closeTo(4 / 5, 0.001));
    });

    testWidgets('sin widget montado devuelve null, no un fichero roto', (
      tester,
    ) async {
      expect(await tester.runAsync(() => pintarTarjeta(GlobalKey())), isNull);
    });
  });
}
