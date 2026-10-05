import 'package:arcanum_app/features/tarot/table/table_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Stack(children: [Positioned.fill(child: child)]),
  ),
);

void main() {
  group('ayuda de gestos', () {
    testWidgets('sale la primera vez, se cierra con Entendido y deja el ?', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host(const TableHelp()));
      await tester.pump();
      expect(find.text('Cómo se usa la mesa'), findsOneWidget);
      expect(find.text('Mantener'), findsNothing); // va dentro de un Text.rich
      expect(find.textContaining('Desliza hasta la opción'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Cómo se usa la mesa'), findsNothing);
      expect(find.text('?'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(TableHelp.seenKey),
        isTrue,
      );

      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.text('Cómo se usa la mesa'), findsOneWidget);
    });

    testWidgets('se cierra sola a los 40 s', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host(const TableHelp()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 39));
      expect(find.text('Cómo se usa la mesa'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Cómo se usa la mesa'), findsNothing);
    });

    testWidgets('si ya se vio, no vuelve a salir sola', (tester) async {
      SharedPreferences.setMockInitialValues({TableHelp.seenKey: true});
      await tester.pumpWidget(_host(const TableHelp()));
      await tester.pump();
      expect(find.text('Cómo se usa la mesa'), findsNothing);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('deshacer', () {
    testWidgets('sin nada que deshacer no se ve', (tester) async {
      await tester.pumpWidget(_host(UndoDot(until: null, onUndo: () {})));
      expect(find.bySemanticsLabel('Deshacer'), findsNothing);
    });

    testWidgets('se ofrece mientras dura y tocarlo deshace', (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _host(
          UndoDot(
            until: DateTime.now().add(const Duration(seconds: 5)),
            onUndo: () => undone++,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Deshacer'), findsOneWidget);
      expect(tester.getSize(find.bySemanticsLabel('Deshacer')).height, 48);
      await tester.tap(find.bySemanticsLabel('Deshacer'));
      expect(undone, 1);
    });

    testWidgets('el anillo se consume y el boton desaparece al acabarse', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UndoDot(
            until: DateTime.now().add(const Duration(seconds: 5)),
            onUndo: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, lessThan(.7));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.bySemanticsLabel('Deshacer'), findsNothing);
    });
  });
}
