import 'package:arcanum_app/shared/widgets/arcane_currency_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('los emblemas se pintan y conservan el tamano pedido', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ArcaneCurrencyEmblem(currency: ArcaneCurrency.fragment),
              ArcaneCurrencyEmblem(currency: ArcaneCurrency.credit, size: 36),
            ],
          ),
        ),
      ),
    );

    final emblems = find.byType(ArcaneCurrencyEmblem);
    expect(emblems, findsNWidgets(2));
    expect(tester.getSize(emblems.at(0)), const Size(24, 24));
    expect(tester.getSize(emblems.at(1)), const Size(36, 36));
    expect(tester.takeException(), isNull);
  });
}
