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
  bool active = false,
  int focusEpoch = 0,
  TarotCara initialCara = TarotCara.dorso,
  VoidCallback? onHintShown,
  VoidCallback? onToggle,
  ValueChanged<TarotCara>? onCaraChanged,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Center(
        child: TarotCardView(
          card: card,
          index: 0,
          active: active,
          focusEpoch: focusEpoch,
          initialCara: initialCara,
          onToggle: onToggle ?? () {},
          onCaraChanged: onCaraChanged,
          pulseHint: pulseHint,
          onHintShown: onHintShown,
        ),
      ),
    ),
  ),
);

/// Deja pasar el reparto y cualquier animacion pendiente.
///
/// El primer `pump` largo no sobra: el reparto arranca desde un `Timer`, y un
/// `Timer` pendiente NO programa frames. Con `pumpAndSettle` a secas la carta
/// se daba por quieta sin haberse repartido siquiera, y el reparto saltaba
/// despues, en mitad de lo que viniera. Este pump lo dispara primero.
Future<void> _reposo(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 6),
  );
}

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

  testWidgets(
    'la invitacion ocupa el hueco del significado, y se va con el giro',
    (tester) async {
      await tester.pumpWidget(_app(mayor));
      await _reposo(tester);

      expect(find.text('Toca la carta para descubrirla.'), findsOneWidget);
      expect(find.text('Un significado.'), findsNothing);

      await tester.tap(_naipe);
      await _reposo(tester);

      expect(
        find.text('Toca la carta para descubrirla.'),
        findsNothing,
        reason: 'la invitacion sobra en cuanto la carta ya esta descubierta',
      );
      expect(find.text('Un significado.'), findsOneWidget);
    },
  );

  testWidgets('el toque la descubre y el significado aparece con ella', (
    tester,
  ) async {
    var enfocada = 0;
    await tester.pumpWidget(_app(mayor, onToggle: () => enfocada++));
    await _reposo(tester);

    await tester.tap(_naipe);
    await _reposo(tester);

    expect(find.text('Un significado.'), findsOneWidget);
    expect(enfocada, 0, reason: 'el primer toque voltea, no enfoca');
  });

  testWidgets('el segundo toque trae el grabado y el tercero lo devuelve', (
    tester,
  ) async {
    await tester.pumpWidget(_app(mayor));
    await _reposo(tester);

    // Boca abajo no hay ninguna imagen: la lamina ni se decodifica.
    expect(find.byType(Image), findsNothing);

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'el primer toque es la cara vectorial, que se pinta, no se carga',
    );

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(find.byType(Image), findsOneWidget, reason: 'el grabado de 1909');

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'el tercer toque vuelve al trazo de ARCANUM',
    );
  });

  testWidgets('la etiqueta de accesibilidad dice a donde lleva el toque', (
    tester,
  ) async {
    await tester.pumpWidget(_app(mayor));
    await _reposo(tester);
    expect(find.bySemanticsLabel('Descubrir la carta'), findsOneWidget);

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(find.bySemanticsLabel('Ver el grabado de 1909'), findsOneWidget);

    await tester.tap(_naipe);
    await _reposo(tester);
    expect(find.bySemanticsLabel('Volver al trazo de ARCANUM'), findsOneWidget);
  });

  testWidgets('la carta descubierta se enfoca a cada toque, no solo al abrir', (
    tester,
  ) async {
    var enfocada = 0;
    await tester.pumpWidget(_app(mayor, onToggle: () => enfocada++));
    await _reposo(tester);

    await tester.tap(_naipe); // descubrir: todavia no enfoca
    await _reposo(tester);
    expect(enfocada, 0);

    await tester.tap(_naipe); // al grabado
    await _reposo(tester);
    await tester.tap(_naipe); // de vuelta
    await _reposo(tester);
    expect(enfocada, 2);
  });

  testWidgets('enfocar una carta la acentua, y el acento tambien acaba', (
    tester,
  ) async {
    await tester.pumpWidget(_app(mayor));
    await _reposo(tester);
    await tester.tap(_naipe); // descubrir
    await _reposo(tester);

    // Enfocarla sin tocarla: es lo que hace el mini-panel de la tirada.
    await tester.pumpWidget(_app(mayor, active: true));
    await tester.pump();
    expect(
      tester.binding.hasScheduledFrame,
      isTrue,
      reason: 'el acento tiene que haber arrancado',
    );

    await _reposo(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reenfocar la carta activa vuelve a disparar un acento visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(mayor, active: true, initialCara: TarotCara.vectorial),
    );
    await _reposo(tester);

    await tester.pumpWidget(
      _app(
        mayor,
        active: true,
        initialCara: TarotCara.vectorial,
        focusEpoch: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('tarot-effect-flash')), findsOneWidget);
    await _reposo(tester);
  });

  testWidgets('cada palo pinta su efecto durante el asentamiento', (
    tester,
  ) async {
    final casos = <({Map<String, dynamic> carta, int flipMs, Key efecto})>[
      (carta: mayor, flipMs: 700, efecto: const ValueKey('tarot-effect-flash')),
      (
        carta: _carta(
          name: 'As de Bastos',
          slug: 'as-de-bastos',
          suit: 'bastos',
          number: 1,
        ),
        flipMs: 250,
        efecto: const ValueKey('tarot-effect-mote-0'),
      ),
      (
        carta: _carta(
          name: 'Tres de Copas',
          slug: 'tres-de-copas',
          suit: 'copas',
          number: 3,
        ),
        flipMs: 430,
        efecto: const ValueKey('tarot-effect-sweep'),
      ),
      (
        carta: _carta(
          name: 'Dos de Espadas',
          slug: 'dos-de-espadas',
          suit: 'espadas',
          number: 2,
        ),
        flipMs: 200,
        efecto: const ValueKey('tarot-effect-cut'),
      ),
    ];

    for (final caso in casos) {
      await tester.pumpWidget(_app(caso.carta));
      await _reposo(tester);
      await tester.tap(_naipe);
      await tester.pump();
      await tester.pump(Duration(milliseconds: caso.flipMs));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byKey(caso.efecto),
        findsOneWidget,
        reason: '${caso.carta['name']} no pinta su efecto al asentarse',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Oros se aplasta con una amplitud materialmente visible', (
    tester,
  ) async {
    final oros = _carta(name: 'Rey de Oros', slug: 'rey-de-oros', suit: 'oros');
    await tester.pumpWidget(_app(oros));
    await _reposo(tester);
    await tester.tap(_naipe);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1));

    final finder = find.byKey(const ValueKey('tarot-motion-0'));
    final landed = tester
        .widget<Transform>(finder)
        .transform
        .getMaxScaleOnAxis();
    await tester.pump(const Duration(milliseconds: 130));
    final squashed = tester
        .widget<Transform>(finder)
        .transform
        .getMaxScaleOnAxis();

    expect(landed - squashed, greaterThan(0.025));
    await _reposo(tester);
  });

  testWidgets('la miniatura de tirada refleja dorso, vectorial y RWS', (
    tester,
  ) async {
    Future<void> pumpFace(TarotCara cara) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TarotTiradaMiniatura(card: mayor, cara: cara, width: 58),
        ),
      ),
    );

    await pumpFace(TarotCara.dorso);
    expect(find.byType(Image), findsNothing);

    await pumpFace(TarotCara.vectorial);
    expect(find.byType(Image), findsNothing);

    await pumpFace(TarotCara.rws);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('diez toques en cadena no dejan nada colgando', (tester) async {
    // El acento y el asentamiento comparten controlador a proposito: cada
    // disparo REINICIA el que hay en vez de abrir otro. Diez toques seguidos,
    // cada uno antes de que acabe el anterior, tienen que dejar una sola
    // animacion viva -- y ninguna al final.
    await tester.pumpWidget(_app(mayor));
    await _reposo(tester);

    for (var i = 0; i < 10; i++) {
      await tester.tap(_naipe);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await _reposo(tester);

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(TarotCardView), findsOneWidget);
  });

  testWidgets('con movimiento reducido, enfocar no anima', (tester) async {
    await tester.pumpWidget(_app(mayor, disableAnimations: true));
    await _reposo(tester);
    await tester.tap(_naipe);
    await tester.pump();

    await tester.pumpWidget(_app(mayor, disableAnimations: true, active: true));

    // `_engage` -- el glow y el `lift` de la carta activa -- sigue corriendo:
    // son 170 ms y no entran en este cambio. Lo que NO puede correr es el
    // acento, que en un Mayor dura 675 ms. Si a los 450 ms ya no queda ni un
    // frame, es que el acento no llego a arrancar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'con movimiento reducido el acento no debe animarse',
    );
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
