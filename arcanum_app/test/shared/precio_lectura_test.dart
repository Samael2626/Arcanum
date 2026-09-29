// El precio se dice ANTES de pulsar, y solo cuando se sabe.
//
// El fallo que esto evita: el backend cobra 3 por una Cruz Celta desde el
// 28-sep-2026 y la app no decia nada. Se elegia creyendo que valia 1 y el
// precio se descubria con tres creditos menos o con un 402.
import 'package:arcanum_app/core/monetization/saldo.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/shared/widgets/precio_lectura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import '../apoyo/saldo_falso.dart';

/// Un saldo que nunca resuelve, para el caso "todavia cargando".
class _SaldoCargando extends SaldoNotifier {
  @override
  Future<EstadoSaldo> build() => Completer<EstadoSaldo>().future;
  @override
  Future<void> refrescar() async {}
  @override
  Future<bool> trasComprar() async => true;
}

Future<void> _pinta(
  WidgetTester tester,
  Widget w,
  SaldoNotifier Function() saldo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [saldoProvider.overrideWith(saldo)],
      child: MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(body: w),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('el precio de cada tirada', () {
    testWidgets('la Cruz Celta dice que cuesta 3 y la de tres, 1', (
      tester,
    ) async {
      await _pinta(
        tester,
        const PrecioTirada('celtic_cross'),
        () => SaldoFalso(creditos: 5, gastaCredito: true),
      );
      expect(find.text('3 créditos'), findsOneWidget);

      await _pinta(
        tester,
        const PrecioTirada('three_card'),
        () => SaldoFalso(creditos: 5, gastaCredito: true),
      );
      expect(find.text('1 crédito'), findsOneWidget);
    });

    testWidgets('si el servidor no manda precio, no se inventa ninguno', (
      tester,
    ) async {
      // Backend viejo: el mapa viene vacío. Una cifra equivocada en pantalla
      // es peor que ninguna.
      await _pinta(
        tester,
        const PrecioTirada('celtic_cross'),
        () => SaldoFalso(creditos: 5, costes: const {}),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('el aviso antes de interpretar', () {
    testWidgets('con cupo de sobra dice que entra en el cupo', (tester) async {
      await _pinta(
        tester,
        const AvisoPrecioInterpretacion('three_card'),
        () => SaldoFalso(creditos: 5),
      );
      expect(find.textContaining('entra en tu cupo'), findsOneWidget);
    });

    testWidgets('una Cruz Celta NO entra en un cupo de 1 aunque quede', (
      tester,
    ) async {
      // El caso que `siguienteGastaCredito` por sí solo no distingue: queda
      // cupo, pero no el suficiente para esta tirada.
      await _pinta(
        tester,
        const AvisoPrecioInterpretacion('celtic_cross'),
        () => SaldoFalso(creditos: 5),
      );
      expect(find.textContaining('gasta 3 créditos'), findsOneWidget);
    });

    testWidgets('sin saldo para el precio, se avisa antes de pulsar', (
      tester,
    ) async {
      await _pinta(
        tester,
        const AvisoPrecioInterpretacion('celtic_cross'),
        () => SaldoFalso(creditos: 2, gastaCredito: true),
      );
      expect(find.textContaining('Cuesta 3 créditos'), findsOneWidget);
      expect(find.textContaining('tienes 2 créditos'), findsOneWidget);
    });

    testWidgets('mientras carga el saldo no promete nada', (tester) async {
      await _pinta(
        tester,
        const AvisoPrecioInterpretacion('celtic_cross'),
        _SaldoCargando.new,
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
