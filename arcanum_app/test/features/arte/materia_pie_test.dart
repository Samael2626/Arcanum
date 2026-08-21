/// El pie de las fichas de Materia Magica.
///
/// La politica Health Content and Services de Google Play exige recordar que se
/// consulte a un profesional cuando la app ofrece informacion relacionada con
/// salud. Una ficha que muestra un campo TOXICIDAD y cita a Culpeper lo es.
///
/// Estas fichas fueron el rojo numero 1 del semaforo legal durante toda la
/// investigacion y no tenian ni una linea de aviso: mostraban el dato de
/// toxicidad crudo y nada mas.
import 'package:arcanum_app/features/arte/materia_lore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `props` son las PROPIEDADES de la ficha: el widget las lee de
/// `d['properties']`, no de la raiz del mapa.
Future<void> _abrir(WidgetTester tester, Map<String, dynamic> props) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showMateriaLoreSheet(
            context,
            future: Future.value(<String, dynamic>{'properties': props}),
            slug: 'x',
            name: 'Prueba',
            itemType: 'planta',
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toda ficha recuerda consultar a un profesional', (tester) async {
    await _abrir(tester, {'fuente': 'Culpeper'});
    expect(find.textContaining('No sustituye atención médica'), findsOneWidget);
    expect(find.textContaining('histórica y cultural'), findsOneWidget);
  });

  testWidgets('una planta toxica ademas lo dice sin rodeos', (tester) async {
    await _abrir(tester, {'toxicidad': 'alta', 'fuente': 'Dioscórides'});
    // Aqui el riesgo no es una multa: es una intoxicacion, y por eso este
    // aviso no se acorta ni se esconde.
    expect(find.textContaining('no la ingieras'), findsOneWidget);
  });

  testWidgets('una planta inocua no se marca como toxica', (tester) async {
    await _abrir(tester, {'toxicidad': 'no tóxica', 'fuente': 'Culpeper'});
    expect(find.textContaining('no la ingieras'), findsNothing);
    // Pero el recordatorio generico sigue, porque la ficha sigue siendo
    // informacion relacionada con salud.
    expect(find.textContaining('No sustituye atención médica'), findsOneWidget);
  });

  testWidgets('sin dato de toxicidad no se supone que la haya', (tester) async {
    await _abrir(tester, {'fuente': 'Agrippa'});
    expect(find.textContaining('no la ingieras'), findsNothing);
  });
}
