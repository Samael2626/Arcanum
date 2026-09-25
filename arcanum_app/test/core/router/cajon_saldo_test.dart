/// El cajon con el bloque de saldo, y lo que ese bloque desplaza.
///
/// El bloque de saldo es la pieza que MAS cambia el cajon, asi que aqui se mide
/// lo que cuesta en vez de suponerlo: a 360 dp de ancho, que filas quedan por
/// debajo del pliegue. Cada elemento que se anade empuja a otro fuera, y eso se
/// cuenta, no se estima.
library;

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/shared/widgets/bloque_saldo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiConSaldo extends ArcanumApi {
  _ApiConSaldo({
    this.creditos = 3,
    this.gastaCredito = false,
    this.falla = false,
    this.fallaTambienElSaldo = false,
  }) : super(Dio());

  final int creditos;
  final bool gastaCredito;

  /// Falla `/credits/usage/today`, como un backend que aun no lo tiene.
  final bool falla;

  /// Falla tambien `/credits/balance`: no queda nada que ensenar.
  final bool fallaTambienElSaldo;
  int llamadas = 0;
  int llamadasBalance = 0;

  @override
  Future<Map<String, dynamic>> creditsBalance() async {
    llamadasBalance++;
    if (fallaTambienElSaldo) {
      throw DioException(requestOptions: RequestOptions(path: '/b'));
    }
    return {'balance': creditos};
  }

  @override
  Future<Map<String, dynamic>> usageToday() async {
    llamadas++;
    if (falla) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return {
      'balance': creditos,
      'acciones': {
        'tarot': {
          'limite_diario': 1,
          'usado': gastaCredito ? 1 : 0,
          'restante': gastaCredito ? 0 : 1,
          'siguiente_gasta_credito': gastaCredito,
        },
      },
    };
  }
}

Future<void> _montar(
  WidgetTester tester,
  Widget hijo, {
  _ApiConSaldo? api,
  Size tamano = const Size(360, 800),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [arcanumApiProvider.overrideWithValue(api ?? _ApiConSaldo())],
      child: MaterialApp(home: Scaffold(body: hijo)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('el bloque del cajon', () {
    testWidgets('pinta el saldo que dice el servidor', (tester) async {
      await _montar(tester, const BloqueSaldoCajon(), api: _ApiConSaldo(creditos: 7));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('créditos'), findsOneWidget);
      expect(find.text('Conseguir más'), findsOneWidget);
    });

    testWidgets('en singular dice "crédito"', (tester) async {
      await _montar(tester, const BloqueSaldoCajon(), api: _ApiConSaldo(creditos: 1));
      expect(find.text('crédito'), findsOneWidget);
    });

    testWidgets('sin saldo leído NO pinta un cero', (tester) async {
      // Un cero es una cifra, y una cifra falsa manda a comprar a quien ya
      // tiene creditos. Mientras no se sabe, se dice que no se sabe.
      await _montar(
        tester,
        const BloqueSaldoCajon(),
        api: _ApiConSaldo(falla: true, fallaTambienElSaldo: true),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('0'), findsNothing);
      expect(find.text('Saldo no disponible'), findsOneWidget);
    });

    testWidgets('si falla el cupo, el saldo llega igual por /credits/balance', (
      tester,
    ) async {
      // `/credits/usage/today` es nuevo: un backend mas viejo que esta app
      // responde 404. Quedarse en "Saldo no disponible" esconderia un saldo que
      // el otro endpoint sabe perfectamente.
      final api = _ApiConSaldo(creditos: 5, falla: true);
      await _montar(tester, const BloqueSaldoCajon(), api: api);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Saldo no disponible'), findsNothing);
      expect(api.llamadasBalance, 1);
    });

    testWidgets('la zona tocable llega a 48 dp', (tester) async {
      await _montar(tester, const BloqueSaldoCajon());
      final caja = tester.getSize(find.byKey(const Key('saldo-cajon')));
      expect(caja.height, greaterThanOrEqualTo(48));
    });
  });

  group('el bloque del oráculo', () {
    testWidgets('con cupo libre dice que entra en el cupo, no que cuesta', (
      tester,
    ) async {
      // Es el caso que hacia falta distinguir: "gasta 1 credito" seria falso.
      await _montar(
        tester,
        const BloqueSaldoOraculo(accion: 'tarot'),
        api: _ApiConSaldo(creditos: 0, gastaCredito: false),
      );
      expect(
        find.textContaining('entra en tu cupo de hoy'),
        findsOneWidget,
      );
      expect(find.textContaining('gasta 1'), findsNothing);
    });

    testWidgets('agotado el cupo sí dice que gasta uno', (tester) async {
      await _montar(
        tester,
        const BloqueSaldoOraculo(accion: 'tarot'),
        api: _ApiConSaldo(creditos: 4, gastaCredito: true),
      );
      expect(find.textContaining('esta lectura gasta 1'), findsOneWidget);
    });

    testWidgets('de una acción que el servidor no manda, explica la regla', (
      tester,
    ) async {
      // No se afirma lo que cuesta ESTA lectura, que no se sabe; se dice la
      // regla, que es cierta siempre.
      await _montar(
        tester,
        const BloqueSaldoOraculo(accion: 'cielos'),
        api: _ApiConSaldo(creditos: 2),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('esta lectura gasta'), findsNothing);
      expect(find.textContaining('entra en tu cupo de hoy'), findsNothing);
      expect(find.textContaining('primero tu cupo diario'), findsOneWidget);
    });

    testWidgets('con el cupo caído enseña saldo y la regla, no un error', (
      tester,
    ) async {
      await _montar(
        tester,
        const BloqueSaldoOraculo(accion: 'tarot'),
        api: _ApiConSaldo(creditos: 9, falla: true),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('9'), findsOneWidget);
      expect(find.textContaining('primero tu cupo diario'), findsOneWidget);
      expect(find.text('Saldo no disponible'), findsNothing);
    });

    testWidgets('la zona tocable llega a 48 dp', (tester) async {
      await _montar(tester, const BloqueSaldoOraculo(accion: 'tarot'));
      final caja = tester.getSize(find.byKey(const Key('saldo-oraculo')));
      expect(caja.height, greaterThanOrEqualTo(48));
    });
  });

  group('el saldo se lee del servidor, no se cuenta aquí', () {
    testWidgets('se pide una sola vez por montaje', (tester) async {
      final api = _ApiConSaldo();
      await _montar(tester, const BloqueSaldoCajon(), api: api);
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.llamadas, 1);
    });
  });
}
