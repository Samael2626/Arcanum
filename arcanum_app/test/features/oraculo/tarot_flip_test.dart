import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El volteo por palo, el ojo y la pista del gesto.
///
/// Lo que se comprueba aqui no es como se ve, que para eso estan los ojos,
/// sino lo que se puede romper sin que nadie lo note: que la carta no se
/// descubra sola, que el movimiento reducido no anime, que todo acabe en
/// reposo absoluto, y que la pista se ensene UNA vez.

Map<String, dynamic> _carta({
  required String name,
  String? slug,
  String? arcana,
  int? number,
  String? suit,
}) => {
  'name': name,
  'name_es': name,
  'slug': ?slug,
  'arcana': ?arcana,
  'number': ?number,
  'suit': ?suit,
  'position': 'Presente',
  'drawn_upright': true,
  'meaning': 'Un significado.',
};

Widget _app(
  Map<String, dynamic> card, {
  bool disableAnimations = false,
  bool pulseHint = false,
  VoidCallback? onHintShown,
  VoidCallback? onToggle,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Center(
        child: TarotCardView(
          card: card,
          index: 0,
          active: false,
          onToggle: onToggle ?? () {},
          pulseHint: pulseHint,
          onHintShown: onHintShown,
        ),
      ),
    ),
  ),
);

/// Deja pasar el reparto y cualquier animacion pendiente.
Future<void> _reposo(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 20),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 6),
);

/// El naipe, que es lo unico que recibe el toque: el centro de `TarotCardView`
/// cae entre el rotulo de la posicion y la carta, y ahi no hay nada que tocar.
Finder get _naipe => find
    .descendant(
      of: find.byType(TarotCardView),
      matching: find.byType(GestureDetector),
    )
    .first;

void main() {
  final mayor = _carta(
    name: 'El Sol',
    slug: 'el-sol',
    arcana: 'major',
    number: 19,
  );

  testWidgets('la carta llega boca abajo y NO se descubre sola', (
    tester,
  ) async {
    await tester.pumpWidget(_app(mayor));
    await _reposo(tester);

    // El significado solo se pinta cuando la carta ya se ha descubierto.
    expect(find.text('Un significado.'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('el toque la descubre, y el segundo toque enfoca', (
    tester,
  ) async {
    var enfocada = 0;
    await tester.pumpWidget(_app(mayor, onToggle: () => enfocada++));
    await _reposo(tester);

    await tester.tap(_naipe);
    await _reposo(tester);

    expect(find.text('Un significado.'), findsOneWidget);
    expect(enfocada, 0, reason: 'el primer toque voltea, no enfoca');

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(enfocada, 1);
  });

  testWidgets('cada palo acaba en reposo absoluto, sin frames colgando', (
    tester,
  ) async {
    final cartas = <Map<String, dynamic>>[
      mayor,
      _carta(
        name: 'As de Bastos',
        slug: 'as-de-bastos',
        suit: 'bastos',
        number: 1,
      ),
      _carta(
        name: 'Tres de Copas',
        slug: 'tres-de-copas',
        suit: 'copas',
        number: 3,
      ),
      _carta(
        name: 'Dos de Espadas',
        slug: 'dos-de-espadas',
        suit: 'espadas',
        number: 2,
      ),
      _carta(name: 'Rey de Oros', slug: 'rey-de-oros', suit: 'oros'),
    ];

    for (final carta in cartas) {
      await tester.pumpWidget(_app(carta));
      await _reposo(tester);
      await tester.tap(_naipe);
      await _reposo(tester);

      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: '${carta['name']} deja la carta animandose para siempre',
      );
      // Widget nuevo en cada vuelta: la clave evita que se reutilice el estado.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('con movimiento reducido el cambio es instantaneo', (
    tester,
  ) async {
    var pistaDada = 0;
    await tester.pumpWidget(
      _app(
        mayor,
        disableAnimations: true,
        pulseHint: true,
        onHintShown: () => pistaDada++,
      ),
    );
    await _reposo(tester);

    await tester.tap(_naipe);
    await tester.pump(); // UN frame: sin animacion no hace falta mas

    expect(find.text('Un significado.'), findsOneWidget);
    expect(
      pistaDada,
      1,
      reason:
          'sin movimiento no hay gesto que ensenar: la pista se da por vista',
    );
  });

  testWidgets('la pista se ensena una sola vez y avisa al terminar', (
    tester,
  ) async {
    var pistaDada = 0;
    await tester.pumpWidget(
      _app(mayor, pulseHint: true, onHintShown: () => pistaDada++),
    );
    await _reposo(tester);

    await tester.tap(_naipe);
    await _reposo(tester);

    expect(pistaDada, 1);
  });

  testWidgets('sin pista pendiente, nadie avisa de nada', (tester) async {
    var pistaDada = 0;
    await tester.pumpWidget(_app(mayor, onHintShown: () => pistaDada++));
    await _reposo(tester);

    await tester.tap(_naipe);
    await _reposo(tester);

    expect(pistaDada, 0);
  });
}
