/// Que no aparezca ingles en una app en espanol.
///
/// El catalogo guarda los titulos del Book T bilingues, separados por barra, y
/// las pantallas los pintaban ENTEROS. Se vio con la app en el telefono.
import 'package:arcanum_app/shared/titulo_book_t.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('se queda con la mitad española', () {
    expect(tituloEnEspanol('The Fool / El Loco'), 'El Loco');
    expect(
      tituloEnEspanol('Root of the Powers of Water / Raíz de los Poderes del Agua'),
      'Raíz de los Poderes del Agua',
    );
    expect(tituloEnEspanol('Lord of Material Works / Señor de las Obras Materiales'),
        'Señor de las Obras Materiales');
  });

  test('un título que ya viene solo en español no se toca', () {
    expect(tituloEnEspanol('El Mago'), 'El Mago');
  });

  test('sin barra devuelve lo que hay, aunque sea inglés', () {
    // Perder el dato seria peor que mostrarlo en el idioma equivocado: al menos
    // asi se ve que falta traducir, en vez de quedar un hueco silencioso.
    expect(tituloEnEspanol('The Fool'), 'The Fool');
  });

  test('vacío y nulo no revientan', () {
    expect(tituloEnEspanol(null), '');
    expect(tituloEnEspanol(''), '');
    expect(tituloEnEspanol('   '), '');
  });

  test('una barra sin nada detrás devuelve el original', () {
    expect(tituloEnEspanol('The Fool /'), 'The Fool /');
  });

  test('ninguna carta real deja inglés a la vista', () {
    // Muestras reales del catalogo de produccion.
    const reales = [
      'The Fool / El Loco',
      'The Magus / El Mago',
      'Root of the Powers of Fire / Raíz de los Poderes del Fuego',
      'Lord of Peace Restored / Señor de la Paz Restaurada',
    ];
    const inglesas = ['the ', 'root ', 'lord ', 'powers', 'of the'];
    for (final r in reales) {
      final es = tituloEnEspanol(r).toLowerCase();
      for (final w in inglesas) {
        expect(es.contains(w), isFalse, reason: '"$w" sigue en "$es"');
      }
    }
  });
}
