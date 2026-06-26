import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/main.dart';

void main() {
  testWidgets('ARCANUM muestra el wordmark al arrancar', (tester) async {
    await tester.pumpWidget(const ArcanumApp());
    expect(find.text('ARCANUM'), findsOneWidget);
  });
}
