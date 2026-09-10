// La agenda del cielo en la pantalla. Lo que se fija:
//   - que solo se ofrecen semana y mes, y el mes sale del techo del SERVIDOR
//   - que cada línea es un suceso con fecha, y el fondo va sin fecha
//   - que un periodo vacío se dice, no se disimula
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/horoscopo/widgets/agenda_del_cielo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiConAgenda extends ArcanumApi {
  _ApiConAgenda({this.vacia = false, this.falla = false, this.tope = 30})
    : super(Dio());

  final bool vacia;
  final bool falla;
  final int tope;
  final List<int> pedidos = [];

  @override
  Future<Map<String, dynamic>> agenda({int days = 7}) async {
    pedidos.add(days);
    if (falla) throw DioException(requestOptions: RequestOptions(path: '/x'));
    final hoy = DateTime.now();
    String dia(int mas) => hoy
        .add(Duration(days: mas))
        .toIso8601String()
        .split('T')
        .first;
    return {
      'from': dia(0),
      'to': dia(days),
      'days': days,
      'max_days': tope,
      'background': vacia
          ? null
          : {'transit': 'jupiter', 'natal': 'north_node', 'aspect': 'opposition'},
      'events': vacia
          ? []
          : [
              {
                'kind': 'aspect_exact',
                'date': dia(1),
                'transit': 'mercury',
                'natal': 'sun',
                'aspect': 'square',
              },
              {
                'kind': 'house_ingress',
                'date': dia(3),
                'transit': 'mars',
                'from_house': 6,
                'to_house': 7,
              },
              {
                'kind': 'profection_change',
                'date': dia(5),
                'age': 37,
                'house': 6,
                'lord': 'mercury',
                'from_lord': 'venus',
              },
            ],
    };
  }
}

Future<_ApiConAgenda> _montar(WidgetTester tester, _ApiConAgenda api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [arcanumApiProvider.overrideWithValue(api)],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AgendaDelCielo())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('carga la semana sola, sin que haya que pedirla', (tester) async {
    final api = await _montar(tester, _ApiConAgenda());
    expect(api.pedidos, [7]);
    expect(find.text('LO QUE VIENE'), findsOneWidget);
  });

  testWidgets('lista los tres tipos de suceso con su día', (tester) async {
    await _montar(tester, _ApiConAgenda());
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('· Mercurio cuadratura tu Sol, exacto'), findsOneWidget);
    expect(find.text('· Marte entra en tu casa 7'), findsOneWidget);
    expect(
      find.text('· Cumples 37: empieza tu año de casa 6, manda Mercurio'),
      findsOneWidget,
    );
  });

  testWidgets('el fondo va aparte y SIN fecha', (tester) async {
    await _montar(tester, _ApiConAgenda());
    expect(find.text('DE FONDO, TODO EL PERIODO'), findsOneWidget);
    expect(find.text('Júpiter oposición tu Nodo Norte'), findsOneWidget);
  });

  testWidgets('el mes se pide con el techo que dice el servidor', (
    tester,
  ) async {
    // El cliente no escribe "30" a mano: si el motor bajara su horizonte, el
    // botón bajaría con él en vez de pedir días que no se pueden calcular.
    final api = await _montar(tester, _ApiConAgenda(tope: 21));
    expect(find.text('21 días'), findsOneWidget);

    await tester.tap(find.text('21 días'));
    await tester.pumpAndSettle();
    expect(api.pedidos, [7, 21]);
  });

  testWidgets('no se ofrece nada más largo que ese techo', (tester) async {
    await _montar(tester, _ApiConAgenda());
    expect(find.text('7 días'), findsOneWidget);
    expect(find.text('30 días'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
    expect(find.textContaining('meses'), findsNothing);
    expect(
      find.textContaining('La agenda llega a 30 días'),
      findsOneWidget,
    );
  });

  testWidgets('un periodo sin nada lo dice, sin disimular', (tester) async {
    await _montar(tester, _ApiConAgenda(vacia: true));
    expect(find.textContaining('Nada señalado'), findsOneWidget);
  });

  testWidgets('un fallo de red no enseña la traza', (tester) async {
    await _montar(tester, _ApiConAgenda(falla: true));
    expect(find.text('No se pudo leer la agenda ahora mismo.'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });
}
