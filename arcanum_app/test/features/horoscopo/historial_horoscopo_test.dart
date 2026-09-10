// El historial del horóscopo. Lo que se fija aquí:
//   - que NO se pide al abrir la pantalla, solo cuando se pide verlo
//   - que una lectura vieja, sin los campos que el motor aprendió después,
//     se pinta igual en vez de romper la lista
//   - que un fallo de red no escupe la traza
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/horoscopo/widgets/historial_horoscopo.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiConArchivo extends ArcanumApi {
  _ApiConArchivo(this.dias, {this.falla = false, this.sinCreditos = false})
    : super(Dio());

  final List<Map<String, dynamic>> dias;
  final bool falla;
  final bool sinCreditos;
  int llamadas = 0;
  final List<DateTime> recuperados = [];

  @override
  Future<Map<String, dynamic>> horoscope({DateTime? day}) async {
    recuperados.add(day!);
    if (sinCreditos) {
      throw DioException(
        requestOptions: RequestOptions(path: '/astral/horoscope'),
        response: Response(
          requestOptions: RequestOptions(path: '/astral/horoscope'),
          statusCode: 402,
          data: const {'detail': {'code': 'credits_required'}},
        ),
      );
    }
    return {'date': day.toIso8601String().split('T').first, 'text': 'aquel día'};
  }

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
  bool sinCreditos = false,
}) async {
  final api = _ApiConArchivo(dias, falla: falla, sinCreditos: sinCreditos);
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

  group('los días que no se abrieron', () {
    final hoy = DateTime(2026, 9, 10);

    Map<String, dynamic> archivada(DateTime d) => {
      'date': d.toIso8601String().split('T').first,
      'text': 'texto',
      'sky': <String, dynamic>{},
    };

    test('no se ofrece nada anterior a la primera lectura', () {
      // Antes de esa fecha no había nada que abrir: cobrar por "recuperar" un
      // día en el que no era usuaria sería venderle una ausencia.
      final faltan = diasSinAbrir([
        archivada(DateTime(2026, 9, 8)),
      ], hoy: hoy);
      expect(faltan, [DateTime(2026, 9, 9)]);
    });

    test('ni hoy, que es gratis', () {
      final faltan = diasSinAbrir([
        archivada(DateTime(2026, 9, 1)),
      ], hoy: hoy);
      expect(faltan.contains(hoy), isFalse);
    });

    test('sin archivo no se ofrece nada', () {
      expect(diasSinAbrir(const [], hoy: hoy), isEmpty);
    });

    test('los días leídos no se ofrecen', () {
      final faltan = diasSinAbrir([
        archivada(DateTime(2026, 9, 5)),
        archivada(DateTime(2026, 9, 7)),
        archivada(DateTime(2026, 9, 9)),
      ], hoy: hoy);
      expect(faltan, [DateTime(2026, 9, 8), DateTime(2026, 9, 6)]);
    });

    test('se ofrecen como mucho cinco, y los más recientes', () {
      final faltan = diasSinAbrir([
        archivada(DateTime(2026, 8, 20)),
      ], hoy: hoy);
      expect(faltan.length, 5);
      expect(faltan.first, DateTime(2026, 9, 9));
    });

    test('nada más allá del horizonte del motor', () {
      final faltan = diasSinAbrir([
        archivada(DateTime(2026, 1, 1)),
      ], hoy: hoy);
      final masViejo = faltan.last;
      expect(hoy.difference(masViejo).inDays, lessThanOrEqualTo(30));
    });

    testWidgets('el día perdido se ofrece con su precio', (tester) async {
      final api = await _montar(tester, [_completa, _vieja]);
      await tester.tap(find.text('Ver días anteriores'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no lo abriste'), findsWidgets);
      expect(find.text('Recuperarlo por 1 crédito'), findsWidgets);
      expect(api.recuperados, isEmpty, reason: 'no se pide hasta que se toca');
    });

    testWidgets('al tocarlo se pide ESE día', (tester) async {
      final api = await _montar(tester, [_completa, _vieja]);
      await tester.tap(find.text('Ver días anteriores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recuperarlo por 1 crédito').first);
      await tester.pump();

      expect(api.recuperados.length, 1);
      expect(api.recuperados.first.hour, 0);
    });

    testWidgets('sin créditos lo dice y ofrece la tienda', (tester) async {
      await _montar(tester, [_completa, _vieja], sinCreditos: true);
      await tester.tap(find.text('Ver días anteriores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recuperarlo por 1 crédito').first);
      await tester.pumpAndSettle();

      expect(find.text('No te quedan créditos para recuperarlo.'), findsOneWidget);
      expect(find.text('Ver planes y créditos'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });
}
