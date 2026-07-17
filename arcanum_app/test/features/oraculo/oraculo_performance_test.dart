import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('una carta queda completamente en reposo tras el reparto', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarotCardView(
            card: const {
              'name': 'El Sol',
              'arcana': 'major',
              'number': 19,
              'position': 'Presente',
              'drawn_upright': true,
              'meaning': 'Claridad.',
            },
            index: 0,
            active: true,
            onToggle: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.byType(TarotCardView), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
