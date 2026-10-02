import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/saber/sellos/sello_ficha.dart';
import 'package:arcanum_app/features/saber/sellos/sello_modelo.dart';
import 'package:arcanum_app/features/saber/sellos/sellos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

Future<void> _montar(WidgetTester tester, Future<CatalogoSellos> cat) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildArcanumTheme(),
      home: Scaffold(body: SellosScreen(catalogoOverride: cat)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Los filtros son una tira horizontal perezosa: Marte aparece al desplazarla.
Future<void> _hastaMarte(WidgetTester tester) => tester.scrollUntilVisible(
  find.text('Marte'),
  80,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CatalogoSellos cat;

  setUpAll(() async {
    cat = CatalogoSellos.parse(
      await rootBundle.loadString(CatalogoSellos.assetPath),
    );
  });

  testWidgets('abre en Agrippa con sus 23 piezas y la fuente a la vista', (
    tester,
  ) async {
    await _montar(tester, Future.value(cat));
    expect(find.text('Agrippa · planetas'), findsOneWidget);
    expect(find.text('Sello'), findsWidgets);
    // la cuadrícula es perezosa: baja hasta la última pieza para comprobar que existe
    await tester.scrollUntilVisible(
      find.text('Inteligencia de las inteligencias'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Inteligencia de las inteligencias'), findsOneWidget);
  });

  testWidgets('el filtro por planeta deja solo sus piezas', (tester) async {
    await _montar(tester, Future.value(cat));
    await _hastaMarte(tester);
    await tester.tap(find.text('Marte'));
    await tester.pumpAndSettle();
    final marte = cat.de('agrippa1651').where((p) => p.planetName == 'Marte');
    expect(marte, hasLength(3));
    expect(find.text('Sello'), findsOneWidget);
    expect(find.text('Espíritu'), findsOneWidget);
    expect(find.text('Inteligencia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Todos'),
      -80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Sello'), findsWidgets);
  });

  testWidgets(
    'Goetia: filtra por rango y cambia de colección sin arrastrar el filtro',
    (tester) async {
      await _montar(tester, Future.value(cat));
      await tester.tap(find.text('Goetia'));
      await tester.pumpAndSettle();
      expect(find.text('Goetia · 72 espíritus'), findsOneWidget);
      expect(find.text('1 · Bael'), findsOneWidget);
      await tester.tap(find.text('Rey'));
      await tester.pumpAndSettle();
      expect(find.text('1 · Bael'), findsOneWidget);
      expect(find.text('2 · Agares'), findsNothing); // Agares es Duque
      // volver a Agrippa limpia el filtro
      await tester.tap(find.text('Agrippa'));
      await tester.pumpAndSettle();
      expect(find.text('Sello'), findsWidgets);
    },
  );

  testWidgets('tocar una pieza abre su ficha con la procedencia completa', (
    tester,
  ) async {
    await _montar(tester, Future.value(cat));
    await tester.tap(find.text('Goetia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 · Bael'));
    await tester.pumpAndSettle();
    final f = cat.sources['goetia1916']!;
    expect(find.text('Sello de Bael'), findsOneWidget);
    expect(find.text(f.work), findsOneWidget);
    expect(find.text(f.edition), findsOneWidget);
    expect(find.text(f.scan), findsOneWidget);
    expect(find.text(f.license), findsOneWidget);
    expect(find.textContaining('su sello va en oro'), findsOneWidget);
    expect(find.text('Copiar enlace al escaneo'), findsOneWidget);
  });

  testWidgets('la ficha de un espíritu con dos sellos lleva a su pareja', (
    tester,
  ) async {
    final doble = cat.de('goetia1916').firstWhere((p) => cat.pareja(p) != null);
    final otra = cat.pareja(doble)!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(
          body: SelloFicha(catalogo: cat, pieza: doble, onElegir: (_) {}),
        ),
      ),
    );
    expect(find.text('Ver su otro sello (figura ${otra.fig})'), findsOneWidget);
  });

  testWidgets('las piezas con nota la muestran en la ficha', (tester) async {
    final conNota = cat.items.firstWhere((p) => p.note != null);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(
          body: SelloFicha(catalogo: cat, pieza: conNota, onElegir: (_) {}),
        ),
      ),
    );
    expect(find.text(conNota.note!), findsOneWidget);
  });

  testWidgets(
    'filtros y celdas se pueden tocar (≥ 48 dp) y hablan con el lector',
    (tester) async {
      await _montar(tester, Future.value(cat));
      await _hastaMarte(tester);
      for (final rotulo in ['Todos', 'Marte', 'Agrippa', 'Goetia']) {
        final caja = tester.getRect(
          find
              .ancestor(of: find.text(rotulo), matching: find.byType(InkWell))
              .first,
        );
        expect(caja.height, greaterThanOrEqualTo(48), reason: rotulo);
      }
      final celda = tester.getRect(
        find
            .ancestor(
              of: find.text('Sello').first,
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(celda.width, greaterThanOrEqualTo(48));
      expect(celda.height, greaterThanOrEqualTo(48));
      final etiqueta = tester.getSemantics(
        find.bySemanticsLabel('Sello de Saturno, Saturno'),
      );
      expect(etiqueta, isNotNull);
    },
  );

  testWidgets('si el catálogo falla, ofrece reintentar', (tester) async {
    await _montar(
      tester,
      Future<CatalogoSellos>(() => throw StateError('catalogo roto')),
    );
    expect(
      find.text('No se pudo abrir el catálogo de sellos.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
