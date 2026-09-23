import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final _star = <String, dynamic>{
  'name': 'La Estrella',
  'name_es': 'La Estrella',
  'slug': 'la-estrella',
  'arcana': 'major',
  'number': 17,
  'position': 'Presente',
  'drawn_upright': true,
  'meaning': 'Esperanza.',
};

class _ScrollHarness extends StatefulWidget {
  const _ScrollHarness();

  @override
  State<_ScrollHarness> createState() => _ScrollHarnessState();
}

class _ScrollHarnessState extends State<_ScrollHarness> {
  TarotCara cara = TarotCara.dorso;

  @override
  Widget build(BuildContext context) => ListView(
    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
    children: [
      TarotCardView(
        key: const ValueKey('tirada-la-estrella'),
        card: _star,
        index: 0,
        active: true,
        onToggle: () {},
        initialCara: cara,
        onCaraChanged: (next) => setState(() => cara = next),
      ),
      const SizedBox(height: 2200),
    ],
  );
}

void main() {
  testWidgets('la cara RWS sobrevive dispose e initState por scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: const _ScrollHarness())),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    final tap = find
        .descendant(
          of: find.byType(TarotCardView),
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.tap(tap);
    await tester.pumpAndSettle();
    await tester.tap(tap);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.byType(TarotCardView), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 1800));
    await tester.pumpAndSettle();
    expect(find.byType(TarotCardView), findsOneWidget);
    expect(
      find.byType(Image),
      findsOneWidget,
      reason: 'la cara RWS no debe volver al dorso al salir del cache',
    );
  });
}
