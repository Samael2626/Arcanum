import 'package:arcanum_app/shared/widgets/prosa_generada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La maquetacion NO puede inventarse cortes.
///
/// Un texto sin saltos se pinta entero: partirlo contando oraciones seria
/// decidir donde termina una idea sin haberla leido, y el corte caeria a veces
/// en mitad de un razonamiento.
void main() {
  group('como se parte', () {
    test('por lineas en blanco, que es lo que pide el prompt', () {
      final p = ProsaGenerada.partir('Lo de hoy.\n\nEl capitulo.\n\nEl cierre.');
      expect(p, ['Lo de hoy.', 'El capitulo.', 'El cierre.']);
    });

    test('por saltos sueltos si no hay lineas en blanco', () {
      expect(ProsaGenerada.partir('Uno.\nDos.'), ['Uno.', 'Dos.']);
    });

    test('un bloque sin saltos se queda entero', () {
      const t = 'Marte forma un trigono. Algo aprieta. Y no afloja del todo.';
      expect(ProsaGenerada.partir(t), [t]);
    });

    test('los trozos vacios no cuentan como parrafo', () {
      expect(ProsaGenerada.partir('Uno.\n\n\n\nDos.\n\n'), ['Uno.', 'Dos.']);
    });

    test('texto vacio no pinta nada', () {
      expect(ProsaGenerada.partir('   '), isEmpty);
    });
  });

  testWidgets('el cierre respira mas que los parrafos, con tres bloques', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProsaGenerada('Hoy.\n\nEl capitulo.\n\nEl cierre.'),
        ),
      ),
    );
    final huecos = t
        .widgetList<SizedBox>(find.byType(SizedBox))
        .map((s) => s.height)
        .whereType<double>()
        .toList();
    expect(huecos, hasLength(2));
    expect(
      huecos.last,
      greaterThan(huecos.first),
      reason: 'El giro de describir a proponer se marca con aire, no con un '
          'encabezado.',
    );
  });

  testWidgets('con dos bloques no hay cierre que separar', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProsaGenerada('Hoy.\n\nEl capitulo.')),
      ),
    );
    final huecos = t
        .widgetList<SizedBox>(find.byType(SizedBox))
        .map((s) => s.height)
        .whereType<double>()
        .toList();
    expect(huecos, hasLength(1));
    expect(huecos.single, 18.0);
  });

  testWidgets('el interlineado es de lectura larga, no de titular', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProsaGenerada('Un parrafo.'))),
    );
    expect(t.widget<Text>(find.byType(Text)).style!.height, 1.58);
  });
}
