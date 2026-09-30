// La nota del cielo, plegada al pie del horoscopo.
//
// Lo que se vigila aqui NO es tipografia: es que la jerga no vuelva al cuerpo
// del texto. Hasta el 26-sep-2026 el horoscopo abria por "Venus atraviesa
// Escorpio y tira de tu Jupiter natal en Acuario" y los testers no lo
// entendian. Si la marca del backend y la de la app se separan, la nota se
// queda dentro de la prosa y eso vuelve a pasar sin que nada falle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/shared/widgets/nota_del_cielo.dart';

/// Un texto como el que compone el servidor: cuerpo llano y nota al final.
const _conNota =
    'Hoy algo aprieta y no afloja, y lo que firmes sera con lo prestado.\n'
    '\n'
    'Lima lo que llevas tiempo serrando.\n'
    '\n'
    'El cielo de hoy: Venus en pelea con tu Jupiter de nacimiento; '
    'Nodo Norte a favor de tu Luna de nacimiento; luna llena creciente.';

void main() {
  group('partir', () {
    test('separa el cuerpo de la nota y le quita la marca', () {
      final p = TextoConNota.partir(_conNota);
      expect(p.cuerpo, contains('Lima lo que llevas tiempo serrando.'));
      expect(p.cuerpo, isNot(contains('El cielo de hoy')));
      expect(p.cuerpo, isNot(contains('Venus')));
      expect(p.nota, startsWith('Venus en pelea con tu Jupiter'));
      expect(p.nota, isNot(contains('El cielo de hoy')));
    });

    test('un texto sin nota se devuelve entero, con nota nula', () {
      // Pasa de verdad: `nota_del_cielo` devuelve cadena vacia con el cielo en
      // calma, y el archivo guarda lecturas de antes del 26-sep-2026.
      const viejo = 'Saturno aprieta sobre tu Sol natal y pide oficio.';
      final p = TextoConNota.partir(viejo);
      expect(p.nota, isNull);
      expect(p.cuerpo, viejo);
    });

    test('la marca sin nada detras no cuenta como nota', () {
      final p = TextoConNota.partir('Algo pesa hoy.\n\nEl cielo de hoy:');
      expect(p.nota, isNull);
      expect(p.cuerpo, contains('El cielo de hoy:'));
    });

    test('con dos notas se pliega la ULTIMA', () {
      // Una lectura vieja puede traer la del modelo y la del servidor. La
      // duplicada se queda en el cuerpo, donde se ve y se arregla, en vez de
      // desaparecer en silencio.
      final p = TextoConNota.partir(
        'Algo pesa.\n\nEl cielo de hoy: la del modelo.\n\n'
        'El cielo de hoy: la buena del servidor.',
      );
      expect(p.nota, 'la buena del servidor.');
      expect(p.cuerpo, contains('la del modelo'));
    });

    test('la marca tiene que ser la misma que la del backend', () {
      // `horoscope.MARCA_NOTA` en arcanum-api. Si cambia una y no la otra, la
      // jerga vuelve a la prosa.
      expect(marcaNotaDelCielo, 'El cielo de hoy:');
    });
  });

  group('la linea tocable', () {
    Widget envuelto(String nota) => MaterialApp(
      home: Scaffold(body: NotaDelCielo(nota)),
    );

    testWidgets('arranca plegada: el titulo se ve, la nota no', (t) async {
      await t.pumpWidget(envuelto('Venus en pelea con tu Jupiter.'));
      expect(find.text('El cielo de hoy'), findsOneWidget);
      expect(find.text('Venus en pelea con tu Jupiter.'), findsNothing);
    });

    testWidgets('se toca y abre, y se vuelve a tocar y cierra', (t) async {
      await t.pumpWidget(envuelto('Venus en pelea con tu Jupiter.'));

      await t.tap(find.text('El cielo de hoy'));
      await t.pumpAndSettle();
      expect(find.text('Venus en pelea con tu Jupiter.'), findsOneWidget);

      await t.tap(find.text('El cielo de hoy'));
      await t.pumpAndSettle();
      expect(find.text('Venus en pelea con tu Jupiter.'), findsNothing);
    });

    testWidgets('el area de toque llega a los 48 dp de la casa', (t) async {
      await t.pumpWidget(envuelto('Venus en pelea con tu Jupiter.'));
      final caja = t.getRect(find.byType(InkWell));
      expect(caja.height, greaterThanOrEqualTo(48.0));
    });
  });
}
