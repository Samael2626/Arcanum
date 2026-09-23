import 'package:arcanum_app/features/arte/materia_plate_loader.dart';
import 'package:arcanum_app/features/arte/materia_plate_reveal.dart';
import 'package:arcanum_app/shared/widgets/arcanum_mood.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el revelado espera a que la hoja termine de entrar', (
    tester,
  ) async {
    await MateriaPlates.instance.ensureLoaded();
    final plate = MateriaPlates.instance.resolve('ruda')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => MateriaPlateReveal(
                plate: plate,
                mood: ArcanumMood.neutral,
                size: 148,
                element: 'fuego',
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage(plate.entonadoPath),
        tester.element(find.byType(MateriaPlateReveal)),
      );
      await precacheImage(
        AssetImage(plate.grabadoPath),
        tester.element(find.byType(MateriaPlateReveal)),
      );
    });
    await tester.pump();
    // La ruta tarda unos 300 ms. Fuego debe seguir revelandose 400 ms
    // despues de que la hoja ya esta quieta.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
