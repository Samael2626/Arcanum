import 'package:arcanum_app/features/lecturas/domain/gutenberg_markup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('las notas editoriales se van', () {
    test('la nota entera entre corchetes pierde los corchetes', () {
      expect(
        limpiarNotasEditoriales('[_Descript._] Esta planta tiene hojas'),
        '_Descript._ Esta planta tiene hojas',
      );
    });

    test('el caso real de Agrimony, sin el corchete de apertura', () {
      // Lo que se veia en el aparato: la ingesta pierde el "[" y quedaba
      // "_Descript._]" a la vista del lector.
      expect(
        limpiarNotasEditoriales('_Descript._] Esta planta tiene hojas'),
        '_Descript._ Esta planta tiene hojas',
      );
    });

    test('el corchete de apertura suelto tambien', () {
      expect(limpiarNotasEditoriales('[_Vertues._ cura'), '_Vertues._ cura');
    });

    test('un texto sin corchetes no se toca', () {
      const limpio = 'Agrimonia de Alejandro y Amara Dulcis';
      expect(limpiarNotasEditoriales(limpio), limpio);
    });

    test('los corchetes que no envuelven cursiva se respetan', () {
      // No todo corchete es de Gutenberg; no se inventa una limpieza que no
      // se pueda justificar.
      const texto = 'segun Dioscorides [libro II] la raiz';
      expect(limpiarNotasEditoriales(texto), texto);
    });
  });

  group('la cursiva se interpreta', () {
    test('el caso real de Plate 1: "_o_" pasa a cursiva', () {
      expect(runsDeMarcado('Alehoof _o_ Hiedra'), const [
        MarkupRun('Alehoof '),
        MarkupRun('o', italic: true),
        MarkupRun(' Hiedra'),
      ]);
    });

    test('varios tramos en el mismo parrafo', () {
      expect(runsDeMarcado('_Descript._ hojas y _Vertues._ raiz'), const [
        MarkupRun('Descript.', italic: true),
        MarkupRun(' hojas y '),
        MarkupRun('Vertues.', italic: true),
        MarkupRun(' raiz'),
      ]);
    });

    test('sin marcado, un solo tramo recto', () {
      expect(runsDeMarcado('texto llano'), const [MarkupRun('texto llano')]);
    });

    test('un guion bajo suelto no pone en cursiva el resto', () {
      // El paginador corta por palabras, asi que un "_asi_" puede quedar
      // partido entre dos paginas. Mejor recto que media pagina en cursiva.
      const suelto = 'la raiz _ y las hojas';
      expect(runsDeMarcado(suelto), const [MarkupRun(suelto)]);
    });

    test('el marcado no cruza saltos de linea', () {
      const texto = 'primera _linea\nsegunda_ linea';
      expect(runsDeMarcado(texto), const [MarkupRun(texto)]);
    });

    test('el texto vacio devuelve un tramo vacio, no una lista vacia', () {
      expect(runsDeMarcado(''), const [MarkupRun('')]);
    });

    test('lo pintado nunca conserva los guiones bajos', () {
      final pintado = runsDeMarcado(
        limpiarNotasEditoriales('_Descript._] Esta planta _tiene_ hojas'),
      ).map((r) => r.text).join();
      expect(pintado, 'Descript. Esta planta tiene hojas');
      expect(pintado.contains('_'), isFalse);
      expect(pintado.contains(']'), isFalse);
    });
  });
}
