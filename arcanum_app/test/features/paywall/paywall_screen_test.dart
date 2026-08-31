import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:arcanum_app/features/paywall/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta el paywall con los precios que devolveria la tienda.
Future<void> _montar(
  WidgetTester tester, {
  required Map<String, String> precios,
  String? ahorro,
}) async {
  // El paywall es una lista larga: con el viewport por defecto (800x600) el
  // plan anual queda debajo del pliegue y no se construye.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storePricesProvider.overrideWith((ref) async => precios),
        descuentoAnualProvider.overrideWith((ref) async => ahorro),
      ],
      child: const MaterialApp(home: PaywallScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('sin respuesta de la tienda no se muestra ningun precio', (
    tester,
  ) async {
    await _montar(tester, precios: const {});

    // Un precio escrito a mano miente fuera de Estados Unidos y es motivo de
    // rechazo en ambas tiendas: si la tienda calla, no hay cifra que ensenar.
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('/mes'), findsNothing);
  });

  testWidgets('sin precio, la compra no se puede tocar', (tester) async {
    await _montar(tester, precios: const {});

    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Empezar prueba gratis'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('se muestran los precios que da la tienda, en su moneda', (
    tester,
  ) async {
    await _montar(
      tester,
      precios: const {
        ProductIds.premiumAnnual: 'COP 199.900/año',
        ProductIds.premiumMonthly: 'COP 19.900',
        ProductIds.credit1: 'COP 4.900',
        ProductIds.pack3: 'COP 11.900',
      },
      ahorro: 'AHORRA 16%',
    );

    expect(find.text('COP 199.900/año'), findsOneWidget);
    expect(find.text('O COP 19.900/mes'), findsOneWidget);
    expect(find.text('AHORRA 16%'), findsOneWidget);
    expect(find.textContaining('COP 4.900'), findsOneWidget);
  });

  testWidgets('los SKUs retirados no se ofrecen', (tester) async {
    await _montar(
      tester,
      precios: const {
        ProductIds.premiumAnnual: 'COP 199.900/año',
        ProductIds.credit1: 'COP 4.900',
      },
    );

    expect(find.textContaining('10 créditos'), findsNothing);
    expect(find.textContaining('50 créditos'), findsNothing);
  });
}
