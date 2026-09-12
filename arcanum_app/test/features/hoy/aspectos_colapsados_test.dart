// Los otros aspectos empiezan cerrados.
//
// Desplegados de golpe son dos columnas de relojes de 176 px que tapan la
// pantalla: el aspecto que manda hoy ya esta destacado arriba, en el sello, y
// esto es el detalle. El detalle se pide, no se impone.
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/level_three_aspects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _overview = <String, dynamic>{
  'transits': {
    'transiting': [
      {'name': 'moon', 'longitude': 120.0},
      {'name': 'mars', 'longitude': 200.0},
      {'name': 'saturn', 'longitude': 310.0},
    ],
    'aspects_to_natal': [
      {'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
        'angle': 120, 'orb': 0.6, 'applying': true},
      {'transit': 'mars', 'natal': 'sun', 'aspect': 'square',
        'angle': 90, 'orb': 1.1, 'applying': false},
      {'transit': 'saturn', 'natal': 'venus', 'aspect': 'opposition',
        'angle': 180, 'orb': 2.0, 'applying': true},
    ],
  },
  'natal_chart': {
    'chart_data': {
      'planets': [
        {'name': 'sun', 'longitude': 20.0},
        {'name': 'venus', 'longitude': 130.0},
      ],
      'midheaven': {'longitude': 0.0},
    },
  },
};

Future<void> _montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildArcanumTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: LevelThreeAspects(overview: Future.value(_overview)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca cerrado: ni un reloj a la vista', (tester) async {
    await _montar(tester);

    expect(find.text('VER TODOS LOS ASPECTOS (3)'), findsOneWidget);
    expect(find.text('TODOS LOS ASPECTOS'), findsNothing);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('se abre al tocarlo, y se vuelve a cerrar', (tester) async {
    await _montar(tester);

    await tester.tap(find.text('VER TODOS LOS ASPECTOS (3)'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('TODOS LOS ASPECTOS'), findsOneWidget);
    expect(find.textContaining('Marte'), findsWidgets);

    await tester.tap(find.text('TODOS LOS ASPECTOS'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('el interruptor se puede tocar sin fallar', (tester) async {
    await _montar(tester);

    final alto = tester.getRect(find.text('VER TODOS LOS ASPECTOS (3)').first);
    final caja = tester.getRect(find.byType(InkWell).first);
    expect(caja.height, greaterThanOrEqualTo(48),
        reason: 'lo tocable no baja de 48');
    expect(alto.height, lessThanOrEqualTo(caja.height));
  });
}
