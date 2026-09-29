// La hoja de la Luna distingue las ocho fases, no dos.
//
// Antes, "QUE FAVORECE" era un binario creciente/menguante: las cuatro fases
// crecientes ensenaban el mismo parrafo y las cuatro menguantes el mismo. El
// `phase_slug` ya viajaba en `/astral/today` y nadie lo leia.
//
// Lo que estos tests vigilan es sobre todo el CAMINO DE VUELTA: si el backend
// reparticiona el ciclo y manda un slug desconocido, la hoja tiene que seguir
// abriendo con el texto de siempre en vez de quedarse muda.
import 'package:arcanum_app/core/content/moon_phase_lore.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/hoy_lore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _abre(
  WidgetTester tester, {
  required String phaseName,
  required bool waxing,
  String? phaseSlug,
}) async {
  // Un arbol vacio antes de cada apertura tira el Navigator y con el la hoja
  // anterior. Sin esto, la segunda llamada pulsa sobre la hoja que sigue
  // abierta y el test compara una fase consigo misma.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildArcanumTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showMoonPhaseSheet(
                context,
                phaseName: phaseName,
                illumination: 0.42,
                waxing: waxing,
                ageDays: 11,
                phaseSlug: phaseSlug,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// El texto de todos los `Text` de la hoja, concatenado.
String _textoVisible(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('con slug conocido, la hoja trae la practica de ESA fase', (
    tester,
  ) async {
    await _abre(
      tester,
      phaseName: 'Cuarto Menguante',
      waxing: false,
      phaseSlug: 'last_quarter',
    );

    final texto = _textoVisible(tester);
    final ficha = moonPhaseLore['last_quarter']!;

    expect(find.text('QUÉ HACER HOY'), findsOneWidget);
    expect(texto, contains(ficha.favorece));
    expect(texto, contains(ficha.practica));
    // Y no cae al binario viejo, que es lo que se vino a sustituir.
    expect(texto, isNot(contains('La Luna que mengua retira y limpia')));
  });

  testWidgets('dos fases menguantes distintas no dicen lo mismo', (
    tester,
  ) async {
    await _abre(
      tester,
      phaseName: 'Cuarto Menguante',
      waxing: false,
      phaseSlug: 'last_quarter',
    );
    final corte = _textoVisible(tester);

    await _abre(
      tester,
      phaseName: 'Menguante',
      waxing: false,
      phaseSlug: 'waning_crescent',
    );
    final barrido = _textoVisible(tester);

    expect(
      corte,
      isNot(equals(barrido)),
      reason: 'las dos menguantes vuelven a ensenar el mismo texto',
    );
  });

  testWidgets('sin slug, la hoja abre igual con el texto de siempre', (
    tester,
  ) async {
    await _abre(tester, phaseName: 'Luna Llena', waxing: true);

    final texto = _textoVisible(tester);
    expect(find.text('QUÉ FAVORECE'), findsOneWidget);
    expect(texto, contains('La Luna que crece suma fuerza'));
    // Sin ficha no se promete lo que no hay.
    expect(find.text('QUÉ HACER HOY'), findsNothing);
  });

  testWidgets('un slug que aqui no existe no deja la hoja muda', (
    tester,
  ) async {
    await _abre(
      tester,
      phaseName: 'Luna Azul',
      waxing: false,
      phaseSlug: 'blue_moon',
    );

    expect(find.text('Luna Azul'), findsWidgets);
    expect(_textoVisible(tester), contains('La Luna que mengua retira'));
  });
}
