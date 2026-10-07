import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/atlas_home_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los mosaicos de la portada, desde el 07-oct-2026 la entrada a las
/// secciones. Heredan lo que vigilaba el cajon cuando las listaba: que esten
/// todas, que cada una abra la suya y que ninguna baje de 48 de alto.
///
/// Se monta el panel suelto porque aqui se puede elegir `showTable`: en la app
/// sale de `kDebugMode || kProfileMode` y los tests corren en debug, asi que
/// la placa del Oraculo de la tienda solo se ve desde aqui. El viaje real por
/// el router lo prueba `navegacion/cajon_navegacion_test.dart`.
void main() {
  const moon = {
    'phase_name': 'Gibosa creciente',
    'illumination': 0.62,
    'is_waxing': true,
  };

  Future<List<String>> montar(
    WidgetTester t, {
    required bool showTable,
    double width = 411,
  }) async {
    t.view
      ..physicalSize = Size(width * 3, 2745)
      ..devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    final abiertos = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AtlasHomePanel(
              moon: moon,
              observedAt: DateTime(2026, 10, 7, 21, 30),
              showTable: showTable,
              onMoonTap: () => abiertos.add('luna'),
              onHoroscope: () => abiertos.add('/horoscopo'),
              onGrimoire: () => abiertos.add('/grimorio'),
              onSaber: () => abiertos.add('/saber'),
              onTable: () => abiertos.add('/tarot'),
              onOracle: () => abiertos.add('/oraculo'),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    return abiertos;
  }

  Future<void> tocar(WidgetTester t, Key key) async {
    await t.ensureVisible(find.byKey(key));
    await t.pump();
    await t.tap(find.byKey(key));
    await t.pump();
  }

  // Lo que era "cada fila del cajon lleva a una rama que existe": cada placa
  // abre la ruta de SU seccion, y esas rutas son las de `arcanumSections`.
  testWidgets('cada mosaico abre la ruta de su sección', (t) async {
    final abiertos = await montar(t, showTable: false);
    final rutas = {for (final s in arcanumSections) s.route};

    for (final (key, ruta) in [
      (const Key('atlas-horoscopo'), '/horoscopo'),
      (const Key('atlas-grimorio'), '/grimorio'),
      (const Key('atlas-saber'), '/saber'),
      (const Key('atlas-oraculo'), '/oraculo'),
    ]) {
      await tocar(t, key);
      expect(abiertos.last, ruta, reason: '$key abrio otra cosa');
      expect(rutas, contains(ruta), reason: '$ruta no es una seccion');
    }
    await tocar(t, const Key('atlas-cielo'));
    expect(abiertos.last, 'luna');
  });

  testWidgets('la portada nombra las cinco secciones', (t) async {
    await montar(t, showTable: false);
    // Cielo es la portada misma: su placa es la Luna del momento.
    expect(find.byKey(const Key('atlas-cielo')), findsOneWidget);
    for (final s in arcanumSections.skip(1)) {
      expect(find.text(s.title), findsOneWidget, reason: s.title);
    }
  });

  testWidgets('con la mesa, su placa se suma y el Oráculo sigue', (t) async {
    // 07-oct: la mesa sustituia al Oraculo y este se quedaba sin entrada
    final abiertos = await montar(t, showTable: true);
    await tocar(t, const Key('atlas-mesa'));
    expect(abiertos.last, '/tarot');
    await tocar(t, const Key('atlas-oraculo'));
    expect(abiertos.last, '/oraculo');
  });

  // La regla de los 48 que vigilaba las filas del cajon, en los mosaicos, y
  // tambien en pantalla estrecha, donde Grimorio y Saber se apilan.
  for (final width in [411.0, 320.0]) {
    testWidgets('ningún mosaico baja de 48 de alto ($width de ancho)', (
      t,
    ) async {
      await montar(t, showTable: false, width: width);
      for (final key in [
        'atlas-cielo',
        'atlas-oraculo',
        'atlas-horoscopo',
        'atlas-grimorio',
        'atlas-saber',
      ]) {
        final size = t.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
      expect(t.takeException(), isNull, reason: 'algo se desbordo');
    });
  }
}
