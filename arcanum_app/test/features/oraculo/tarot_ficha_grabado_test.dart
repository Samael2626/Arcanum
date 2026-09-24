// El grabado de 1909 dentro de la ficha de Aprender.
//
// La decision que esto fija: el gesto vive SOLO aqui. La rejilla de 78 se
// queda estatica, porque darle el volteo obligaria a sacar la cara de cada
// carta fuera de su celda -- el GridView la destruye al salir de pantalla --
// y a convertir un catalogo en un muestrario a medio voltear.
import 'package:arcanum_app/features/oraculo/tarot_learn.dart';
import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _carta = <String, dynamic>{
  'slug': 'la-estrella',
  'arcana': 'major',
  'number': 17,
  'element': 'air',
  'meaning_upright': 'Esperanza.',
  'meaning_reversed': 'Desaliento.',
};

/// Abre la ficha y deja la hoja quieta.
Future<void> _abrirFicha(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildArcanumTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTarotCardSheet(context, _carta),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// El gesto de la carta, que sigue ahi tanto con trazo como con grabado.
Finder get _gesto => find.byKey(const ValueKey('ficha-naipe'));
Finder get _naipe => find.byType(TarotNaipe);

String? _laminaMontada(WidgetTester tester) {
  final imagenes = tester.widgetList<Image>(find.byType(Image));
  for (final i in imagenes) {
    final p = i.image;
    final asset = p is ResizeImage ? p.imageProvider : p;
    if (asset is AssetImage && asset.assetName.startsWith('assets/tarot/')) {
      return asset.assetName;
    }
  }
  return null;
}

void main() {
  testWidgets('la ficha abre con el trazo de ARCANUM y lo dice', (
    tester,
  ) async {
    await _abrirFicha(tester);
    expect(_naipe, findsOneWidget);
    expect(_laminaMontada(tester), isNull);
    expect(
      find.text('Toca la carta para ver el grabado de 1909'),
      findsOneWidget,
    );
  });

  testWidgets('el toque trae el grabado de 1909 de esa carta', (tester) async {
    await _abrirFicha(tester);
    await tester.tap(_gesto);
    await tester.pumpAndSettle();

    expect(_laminaMontada(tester), 'assets/tarot/la-estrella.webp');
    expect(find.text('Grabado de 1909 · toca para volver'), findsOneWidget);
  });

  testWidgets('el segundo toque devuelve el trazo', (tester) async {
    await _abrirFicha(tester);
    await tester.tap(_gesto);
    await tester.pumpAndSettle();
    await tester.tap(_gesto);
    await tester.pumpAndSettle();

    expect(_laminaMontada(tester), isNull);
    expect(_naipe, findsOneWidget);
  });

  testWidgets('a media vuelta todavia se ve la cara de antes', (tester) async {
    // El canto manda: hasta los 90 grados la carta sigue siendo la de antes, y
    // el rotulo de debajo tiene que decir lo mismo que la cara.
    await _abrirFicha(tester);
    await tester.tap(_gesto);
    await tester.pump(const Duration(milliseconds: 120));

    expect(_laminaMontada(tester), isNull);
    expect(
      find.text('Toca la carta para ver el grabado de 1909'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('el rotulo anuncia lo que hace el toque', (tester) async {
    await _abrirFicha(tester);
    expect(find.bySemanticsLabel('Ver el grabado de 1909'), findsOneWidget);
    await tester.tap(_gesto);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Volver al trazo de ARCANUM'), findsOneWidget);
  });
}
