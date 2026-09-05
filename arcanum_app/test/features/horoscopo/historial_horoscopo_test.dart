// El historial del horóscopo. Lo que se fija aquí:
//   - que NO se pide al abrir la pantalla, solo cuando se pide verlo
//   - que una lectura vieja, sin los campos que el motor aprendió después,
//     se pinta igual en vez de romper la lista
//   - que un fallo de red no escupe la traza
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/horoscopo/widgets/historial_horoscopo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiConArchivo extends ArcanumApi {
  _ApiConArchivo(this.dias, {this.falla = false}) : super(Dio());

  final List<Map<String, dynamic>> dias;
  final bool falla;
  int llamadas = 0;

  @override
  Future<List<Map<String, dynamic>>> horoscopeHistory({int limit = 30}) async {
    llamadas++;
    if (falla) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return dias;
  }
}

/// Una lectura de hoy, con todo lo que el motor sabe ahora.
final _completa = {
  'date': DateTime.now().toIso8601String().split('T').first,
  'text': 'Saturno cierra un cuadrado con tu Sol.',
  'sky': {
    'today': {'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine'},
    'profection': {'house': 5, 'lord': 'saturn'},
    'ingress': {'transit': 'mars', 'to_house': 7},
  },
};

/// Una de las primeras: su cielo no traía año, ingreso ni carriles.
final _vieja = {
  'date': '2026-08-01',
  'text': 'De cuando el motor sabía menos.',
  'sky': <String, dynamic>{},
};

Future<_ApiConArchivo> _montar(
  WidgetTester tester,
  List<Map<String, dynamic>> dias, {
  bool falla = false,
}) async {
  final api = _ApiConArchivo(dias, falla: falla);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [arcanumApiProvider.overrideWithValue(api)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HistorialHoroscopo()),
        ),
      ),
    ),
  );
  await tester.pump();
  return api;
}

void main() {
  testWidgets('no pide nada hasta que se pide verlo', (tester) async {
    final api = await _montar(tester, [_completa]);
    expect(api.llamadas, 0);
    expect(find.text('Ver días anteriores'), findsOneWidget);

    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();
    expect(api.llamadas, 1);
  });

  testWidgets('lista los días con su titular', (tester) async {
    await _montar(tester, [_completa]);
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();

    expect(find.text('DÍAS ANTERIORES'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Luna trígono Medio Cielo'), findsOneWidget);
  });

  testWidgets('una lectura vieja sin campos nuevos se pinta igual', (
    tester,
  ) async {
    await _montar(tester, [_vieja]);
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();

    // Aparece con su fecha, y sin titular inventado.
    expect(find.text('1 de agosto'), findsOneWidget);
    expect(find.textContaining('trígono'), findsNothing);
  });

  testWidgets('el texto de un día se lee al desplegarlo', (tester) async {
    await _montar(tester, [_vieja]);
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();
    expect(find.text('De cuando el motor sabía menos.'), findsNothing);

    await tester.tap(find.text('1 de agosto'));
    await tester.pumpAndSettle();
    expect(find.text('De cuando el motor sabía menos.'), findsOneWidget);
  });

  testWidgets('sin días guardados lo dice, sin parecer un fallo', (
    tester,
  ) async {
    await _montar(tester, []);
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no hay días guardados'), findsOneWidget);
  });

  testWidgets('un fallo de red no enseña la traza', (tester) async {
    await _montar(tester, [], falla: true);
    await tester.tap(find.text('Ver días anteriores'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo leer tu archivo ahora mismo.'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
