import 'package:arcanum_app/shared/widgets/arcanum_card.dart';
import 'package:arcanum_app/shared/widgets/arcanum_mood.dart';
import 'package:arcanum_app/shared/widgets/arcanum_resin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda la regla congelada en la pieza que mas se repite.
///
/// `ArcanumCard` se instancia 18 veces en nueve pantallas. Si alguien le
/// devuelve el filete "para que se vea el borde", lo devuelve en toda la app
/// de una sentada, asi que conviene que se caiga un test y no que se note seis
/// meses despues en una captura.
void main() {
  Future<BoxDecoration> decoracion(WidgetTester t, {ArcanumMood? mood}) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArcanumCard(mood: mood, child: const Text('contenido')),
        ),
      ),
    );
    final container = t.widget<Container>(
      find
          .ancestor(of: find.byType(ArcanumResin), matching: find.byType(Container))
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('la tarjeta no lleva filete, con humor o sin el', (t) async {
    expect(
      (await decoracion(t)).border,
      isNull,
      reason: 'La regla esta congelada: cero filete. Lo separa la sombra.',
    );
    expect((await decoracion(t, mood: ArcanumMood.fire)).border, isNull);
    expect((await decoracion(t, mood: ArcanumMood.sun)).border, isNull);
  });

  testWidgets('lo que la despega del fondo es la sombra, y sigue ahi', (
    t,
  ) async {
    final sombras = (await decoracion(t)).boxShadow!;
    expect(sombras, hasLength(1));
    expect(sombras.single.blurRadius, 18);
    expect(sombras.single.offset, const Offset(0, 8));
  });

  testWidgets('el material es Resina, no una superficie suelta', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ArcanumCard(child: Text('contenido'))),
      ),
    );
    expect(find.byType(ArcanumResin), findsOneWidget);
  });
}
