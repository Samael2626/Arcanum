import 'package:arcanum_app/features/tarot/table/table_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe {
  int? chosen;
  int tableTaps = 0;
}

Future<_Probe> _pump(WidgetTester tester) async {
  final probe = _Probe();
  tester.view
    ..physicalSize = const Size(360, 760)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // lo de debajo: la mesa
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => probe.tableTaps++,
              ),
            ),
            FanPickerButton(
              positions: List.generate(78, (i) => i),
              onChoose: (position) => probe.chosen = position,
            ),
          ],
        ),
      ),
    ),
  );
  return probe;
}

void main() {
  testWidgets('a la vista no hay boton y el dedo pasa a la mesa', (
    tester,
  ) async {
    // Samuel, 05-oct: elegir con «carta 1, carta 2…» sobra; se elige con la lupa
    final probe = await _pump(tester);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('Elegir carta'), findsNothing);
    await tester.tapAt(const Offset(180, 760 - 14 - 24));
    expect(probe.tableTaps, 1);
  });

  testWidgets('el lector de pantalla conserva la lista de 78 con 48 dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final probe = await _pump(tester);
    final open = find.semantics.byLabel('Elegir carta del abanico, 78 cartas');
    expect(open, findsOne);
    tester.semantics.tap(open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.bySemanticsLabel('Carta 1 de 78, posición 1 del mazo'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(InkWell).first).height, 48);
    await tester.tap(find.text('Carta 1'));
    await tester.pump();
    expect(probe.chosen, 0);
    semantics.dispose();
  });
}
