import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/main.dart';

void main() {
  testWidgets('ARCANUM muestra el wordmark al arrancar', (tester) async {
    // ProviderScope vive en main(), no dentro de ArcanumApp: el harness debe
    // envolverlo o cualquier ConsumerWidget (HoyScreen) rompe al arrancar.
    await tester.pumpWidget(const ProviderScope(child: ArcanumApp()));
    await tester.pump();
    expect(find.text('ARCANUM'), findsOneWidget);
  });
}
