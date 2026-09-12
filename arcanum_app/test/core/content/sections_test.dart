// La barra de abajo y las secciones son la MISMA lista.
//
// Este fichero fija dos cosas distintas. Las invariantes estructurales —que no
// haya rutas repetidas, que todas empiecen por «/»— y los LITERALES de los
// títulos y subtítulos, que son texto que ve el usuario y se decidió uno a uno.
//
// Fijar literales parece excesivo hasta que alguien los cambia de paso, sin
// querer, arreglando otra cosa: ya pasó con «VER TODOS LOS ASPECTOS», que se
// acortó por una medición mal hecha y nadie se enteró hasta que se miró una
// captura.
import 'package:arcanum_app/core/content/sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('la lista es coherente', () {
    test('ninguna ruta se repite y todas son absolutas', () {
      final rutas = arcanumSections.map((s) => s.route).toList();
      expect(rutas.toSet().length, rutas.length, reason: 'hay una repetida');
      for (final r in rutas) {
        expect(r.startsWith('/'), isTrue, reason: '$r no es una ruta');
      }
    });

    test('cada sección se puede nombrar y explicar', () {
      for (final s in arcanumSections) {
        expect(s.title, isNotEmpty);
        expect(s.subtitle, isNotEmpty);
        expect(s.helpKey, isNotEmpty, reason: '${s.title} no tiene "?"');
        expect(s.icon, isNot(s.selectedIcon),
            reason: '${s.title} no cambia de icono al elegirla');
      }
    });

    test('`arcanumSectionForRoute` solo acierta en la raíz', () {
      expect(arcanumSectionForRoute('/saber')?.title, 'Saber');
      // En una sub-ruta devuelve null: ahí la barra superior se oculta para no
      // chocar con el AppBar propio de esa pantalla.
      expect(arcanumSectionForRoute('/saber/culpeper'), isNull);
      expect(arcanumSectionForRoute('/no-existe'), isNull);
    });
  });

  group('los rótulos que se ven', () {
    test('son estos cinco, en este orden', () {
      expect(
        arcanumSections.map((s) => s.title).toList(),
        ['Cielo', 'Horóscopo', 'Grimorio', 'Saber', 'Oráculo'],
      );
    });

    // Cada subtítulo dice LO QUE HAY DENTRO, en palabras corrientes. Los tres
    // primeros se corrigieron el 11-sep-2026 porque describían mal su pantalla.
    test('el subtítulo de cada sección es el acordado', () {
      final porRuta = {for (final s in arcanumSections) s.route: s.subtitle};
      expect(porRuta['/hoy'], 'Tu carta natal y lo que hoy la toca');
      expect(porRuta['/horoscopo'], 'Tu cielo de hoy, sobre tu carta');
      expect(porRuta['/grimorio'], 'Tu diario cifrado y los pasajes que guardas');
      expect(porRuta['/saber'], 'Plantas y libros de la tradición');
      expect(porRuta['/oraculo'], 'Tira las cartas, pregunta, o estudia el mazo');
    });

    test('ninguno promete lo que la pantalla no tiene', () {
      final todos = arcanumSections.map((s) => s.subtitle).join(' | ');
      // «ritos y hechizos» sugería plantillas en un editor libre; «respuestas
      // guiadas» no decía nada; «los signos del zodiaco» no está en Cielo, que
      // enseña tránsitos sobre la carta natal.
      for (final promesa in ['ritos y hechizos', 'respuestas guiadas',
                             'los signos del zodiaco']) {
        expect(todos, isNot(contains(promesa)),
            reason: '"$promesa" volvió a un subtítulo');
      }
    });
  });
}
