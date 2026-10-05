import 'package:arcanum_app/features/tarot/table/table_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lista del abanico: 78 posiciones con toque de 48 dp', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    int? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FanPickerButton(
                positions: List.generate(78, (i) => i),
                onChoose: (position) => chosen = position,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FilledButton)).height, 48);
    await tester.tap(find.text('Elegir carta (78)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.bySemanticsLabel('Carta 1 de 78, posicion 1 del mazo'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(InkWell).first).height, 48);
    await tester.tap(find.text('Carta 1'));
    await tester.pump();
    expect(chosen, 0);
    semantics.dispose();
  });
}
