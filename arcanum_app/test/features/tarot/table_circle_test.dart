import 'package:arcanum_app/features/tarot/table/table_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pregunta viaja al sello en 760 ms y se oculta al terminar', (
    tester,
  ) async {
    final emitter = SealFlightEmitter();
    addTearDown(emitter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SealFlightLayer(emitter: emitter)),
      ),
    );
    emitter.fly(
      'Pregunta de prueba',
      const Rect.fromLTWH(80, 400, 220, 90),
      const Rect.fromLTWH(25, 200, 50, 50),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Pregunta de prueba'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 760));
    await tester.pump();
    expect(find.text('Pregunta de prueba'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SealFlightLayer(emitter: emitter),
        ),
      ),
    );
    emitter.fly(
      'Sin movimiento',
      const Rect.fromLTWH(80, 400, 220, 90),
      const Rect.fromLTWH(25, 200, 50, 50),
    );
    await tester.pump();
    expect(find.text('Sin movimiento'), findsNothing);
  });

  testWidgets('anillo de cierre dura 3400 ms y respeta reducir movimiento', (
    tester,
  ) async {
    final emitter = CircleMarkEmitter();
    addTearDown(emitter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 900,
            child: CircleMarkLayer(emitter: emitter),
          ),
        ),
      ),
    );
    emitter.mark();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1020));
    final painter =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
            as CircleMarkPainter;
    expect(painter.progress, closeTo(.3, .01));
    await tester.pump(const Duration(milliseconds: 2380));
    final finished =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
            as CircleMarkPainter;
    expect(finished.progress, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CircleMarkLayer(emitter: emitter),
        ),
      ),
    );
    emitter.mark();
    await tester.pump(const Duration(milliseconds: 1020));
    final still =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
            as CircleMarkPainter;
    expect(still.progress, 0);
  });
}
