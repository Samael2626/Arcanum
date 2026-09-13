import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:arcanum_app/shared/widgets/arcanum_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El guardian de la regla de seleccion.
///
/// La regla dice que los tres avisos -- color, peso y forma -- van SIEMPRE
/// juntos: sin los tres, el componente incumple, porque el relleno y el borde
/// no llegan al 3:1 de WCAG 1.4.11 en esta paleta y el estado lo carga el
/// texto por 1.4.3. Un comentario en el widget no impide que alguien quite
/// uno dentro de seis meses; esto si.
void main() {
  Widget _montar({required int index, List<ArcanumToggleOption>? options}) =>
      MaterialApp(
        home: Scaffold(
          body: ArcanumToggle(
            index: index,
            onChanged: (_) {},
            options:
                options ??
                const [
                  ArcanumToggleOption(label: 'Ahora'),
                  ArcanumToggleOption(label: 'Tu carta'),
                ],
          ),
        ),
      );

  TextStyle _estilo(WidgetTester t, String rotulo) =>
      t.widget<Text>(find.text(rotulo)).style!;

  group('los tres avisos', () {
    testWidgets('1 · el color separa lo elegido de lo que no', (t) async {
      await t.pumpWidget(_montar(index: 0));
      expect(_estilo(t, 'Ahora').color, ArcanumColors.goldLight);
      expect(_estilo(t, 'Tu carta').color, ArcanumColors.ivoryMuted);
    });

    testWidgets('2 · el peso tambien, y no solo el color', (t) async {
      await t.pumpWidget(_montar(index: 0));
      expect(_estilo(t, 'Ahora').fontWeight, FontWeight.w600);
      expect(_estilo(t, 'Tu carta').fontWeight, FontWeight.w400);
    });

    testWidgets('3 · con icono, la forma cambia de contorno a relleno', (
      t,
    ) async {
      await t.pumpWidget(
        _montar(
          index: 0,
          options: const [
            ArcanumToggleOption(
              label: 'Ahora',
              iconOutlined: Icons.wb_twilight_outlined,
              iconFilled: Icons.wb_twilight,
            ),
            ArcanumToggleOption(
              label: 'Tu carta',
              iconOutlined: Icons.brightness_4_outlined,
              iconFilled: Icons.brightness_4,
            ),
          ],
        ),
      );
      expect(find.byIcon(Icons.wb_twilight), findsOneWidget);
      expect(find.byIcon(Icons.brightness_4_outlined), findsOneWidget);
    });

    test('el color nunca viaja sin el peso', () {
      // Si alguien parte `textStyle` en dos para pedir "solo el color", este
      // test se cae: los dos avisos salen de la misma llamada a proposito.
      final elegido = ArcanumSelection.textStyle(true);
      final suelto = ArcanumSelection.textStyle(false);
      expect(elegido.color, isNot(suelto.color));
      expect(elegido.fontWeight, isNot(suelto.fontWeight));
    });
  });

  group('lo que no es senal', () {
    testWidgets('ninguna pieza lleva filete: el borde no dice el estado', (
      t,
    ) async {
      await t.pumpWidget(_montar(index: 0));
      final fondos = t
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => w.decoration! as BoxDecoration);
      expect(fondos, hasLength(2));
      for (final d in fondos) {
        expect(
          d.border,
          isNull,
          reason: 'La regla esta congelada: cero filete, en ningun estado.',
        );
      }
    });
  });

  group('lo que se toca', () {
    testWidgets('ningun segmento baja de 48 de alto', (t) async {
      await t.pumpWidget(_montar(index: 0));
      for (final rotulo in ['Ahora', 'Tu carta']) {
        expect(
          t.getSize(find.ancestor(
            of: find.text(rotulo),
            matching: find.byType(ConstrainedBox),
          ).first).height,
          greaterThanOrEqualTo(ArcanumSelection.minTapHeight),
        );
      }
    });

    testWidgets('el elegido no se puede volver a pulsar', (t) async {
      var cambios = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcanumToggle(
              index: 0,
              onChanged: (_) => cambios++,
              options: const [
                ArcanumToggleOption(label: 'Ahora'),
                ArcanumToggleOption(label: 'Tu carta'),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.text('Ahora'));
      await t.pump();
      expect(cambios, 0);
      await t.tap(find.text('Tu carta'));
      await t.pump();
      expect(cambios, 1);
    });

    testWidgets('el radio es el de la casa, no uno propio', (t) async {
      await t.pumpWidget(_montar(index: 0));
      final d =
          t.widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
              .decoration!
          as BoxDecoration;
      expect(
        d.borderRadius,
        BorderRadius.circular(ArcanumSelection.radius),
      );
      expect(ArcanumSelection.radius, 16.0);
    });
  });

  test('un conmutador de una sola opcion no existe', () {
    expect(
      () => ArcanumToggle(
        index: 0,
        onChanged: (_) {},
        options: const [ArcanumToggleOption(label: 'Sola')],
      ),
      throwsAssertionError,
    );
  });

  test('un icono sin su pareja rompe el aviso de forma', () {
    expect(
      () => ArcanumToggleOption(
        label: 'Coja',
        iconOutlined: Icons.wb_twilight_outlined,
      ),
      throwsAssertionError,
    );
  });
}
