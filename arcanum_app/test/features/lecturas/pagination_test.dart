import 'package:arcanum_app/features/lecturas/domain/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

/// Medida falsa y predecible: una unidad por palabra.
///
/// Con una medida real haría falta pantalla y el test dejaría de comprobar el
/// reparto para comprobar la tipografía. Aquí una palabra ocupa 1, así que
/// "cabe" se lee directamente en el enunciado de cada caso.
double wordsMeasure(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length.toDouble();

ParagraphSource p(String anchor, int words) =>
    ParagraphSource(anchor: anchor, text: List.filled(words, 'palabra').join(' '));

void main() {
  group('reparto en paginas', () {
    test('los parrafos que caben juntos van en la misma pagina', () {
      final pages = paginateChapter(
        paragraphs: [p('a', 3), p('b', 3), p('c', 3)],
        measure: wordsMeasure,
        pageHeight: 10,
      );

      expect(pages, hasLength(1));
      expect(pages.first.fragments.map((f) => f.anchor), ['a', 'b', 'c']);
    });

    test('cuando no cabe, el parrafo entero pasa a la pagina siguiente', () {
      final pages = paginateChapter(
        paragraphs: [p('a', 6), p('b', 6)],
        measure: wordsMeasure,
        pageHeight: 10,
      );

      expect(pages, hasLength(2));
      expect(pages[0].fragments.single.anchor, 'a');
      expect(pages[1].fragments.single.anchor, 'b');
    });

    test('el hueco entre parrafos cuenta para el reparto', () {
      // Dos parrafos de 5 en una pagina de 10 caben justo... salvo que el
      // hueco entre ellos ocupe. Ignorarlo es lo que empuja la ultima linea
      // fuera de la pantalla.
      final sinHueco = paginateChapter(
        paragraphs: [p('a', 5), p('b', 5)],
        measure: wordsMeasure,
        pageHeight: 10,
      );
      final conHueco = paginateChapter(
        paragraphs: [p('a', 5), p('b', 5)],
        measure: wordsMeasure,
        pageHeight: 10,
        paragraphSpacing: 1,
      );

      expect(sinHueco, hasLength(1));
      expect(conHueco, hasLength(2));
    });

    test('un capitulo sin parrafos sigue teniendo una pagina', () {
      final pages = paginateChapter(
        paragraphs: const [],
        measure: wordsMeasure,
        pageHeight: 10,
      );
      expect(pages, hasLength(1));
      expect(pages.single.isEmpty, isTrue);
    });

    test('sin layout todavia, todo cabe en una pagina provisional', () {
      final pages = paginateChapter(
        paragraphs: [p('a', 500)],
        measure: wordsMeasure,
        pageHeight: 0,
      );
      expect(pages, hasLength(1));
    });
  });

  group('division de parrafos largos', () {
    test('un parrafo mas largo que la pagina se parte en fragmentos', () {
      final pages = paginateChapter(
        paragraphs: [p('largo', 25)],
        measure: wordsMeasure,
        pageHeight: 10,
      );

      expect(pages.length, greaterThan(1));
      // Todos los fragmentos son del mismo parrafo y van numerados en orden.
      final fragments = pages.expand((page) => page.fragments).toList();
      expect(fragments.every((f) => f.anchor == 'largo'), isTrue);
      expect(
        fragments.map((f) => f.fragmentIndex),
        List.generate(fragments.length, (i) => i),
      );
    });

    test('ningun fragmento excede el alto de una pagina', () {
      final pages = paginateChapter(
        paragraphs: [p('largo', 137)],
        measure: wordsMeasure,
        pageHeight: 12,
      );

      for (final page in pages) {
        for (final fragment in page.fragments) {
          expect(wordsMeasure(fragment.text), lessThanOrEqualTo(12));
        }
      }
    });

    test('no se pierde ni una palabra al partir', () {
      // La garantia que importa: partir es un corte visual, no una perdida de
      // texto. Unir los fragmentos devuelve el parrafo entero.
      final original = List.generate(90, (i) => 'palabra$i').join(' ');
      final pages = paginateChapter(
        paragraphs: [ParagraphSource(anchor: 'x', text: original)],
        measure: wordsMeasure,
        pageHeight: 7,
      );

      final rebuilt = pages
          .expand((page) => page.fragments)
          .map((f) => f.text)
          .join(' ');
      expect(rebuilt, original);
    });

    test('no se parte por la mitad de una palabra', () {
      final pages = paginateChapter(
        paragraphs: [
          ParagraphSource(
            anchor: 'x',
            text: List.generate(40, (i) => 'palabra$i').join(' '),
          ),
        ],
        measure: wordsMeasure,
        pageHeight: 6,
      );

      for (final fragment in pages.expand((page) => page.fragments)) {
        for (final word in fragment.text.split(' ')) {
          expect(word, matches(RegExp(r'^palabra\d+$')), reason: word);
        }
      }
    });

    test('los fragmentos declaran si vienen o siguen', () {
      final pages = paginateChapter(
        paragraphs: [p('x', 25)],
        measure: wordsMeasure,
        pageHeight: 10,
      );
      final fragments = pages.expand((page) => page.fragments).toList();

      expect(fragments.first.isContinuation, isFalse);
      expect(fragments.first.continuesAfter, isTrue);
      expect(fragments.last.isContinuation, isTrue);
      expect(fragments.last.continuesAfter, isFalse);
    });
  });

  group('de posicion estable a pagina visual', () {
    final pages = paginateChapter(
      paragraphs: [p('a', 4), p('b', 4), p('c', 4), p('d', 25)],
      measure: wordsMeasure,
      pageHeight: 8,
    );

    test('encuentra la pagina que contiene el ancla', () {
      final index = pageIndexForPosition(pages, paragraphAnchor: 'c');
      expect(pages[index].fragments.any((f) => f.anchor == 'c'), isTrue);
    });

    test('encuentra el fragmento exacto de un parrafo partido', () {
      final index = pageIndexForPosition(
        pages,
        paragraphAnchor: 'd',
        fragmentIndex: 2,
      );
      expect(
        pages[index].fragments.any(
          (f) => f.anchor == 'd' && f.fragmentIndex == 2,
        ),
        isTrue,
      );
    });

    test('si el fragmento ya no existe, cae en el mismo parrafo', () {
      // Pasa de verdad: el usuario sube el tamano de letra y el parrafo se
      // parte en otros tantos trozos. Volver al parrafo correcto importa mucho
      // mas que al trozo exacto; mandarlo al principio del capitulo, no.
      final index = pageIndexForPosition(
        pages,
        paragraphAnchor: 'd',
        fragmentIndex: 999,
      );
      expect(pages[index].fragments.any((f) => f.anchor == 'd'), isTrue);
    });

    test('un ancla desconocida empieza por el principio', () {
      expect(pageIndexForPosition(pages, paragraphAnchor: 'no-existe'), 0);
    });
  });
}
