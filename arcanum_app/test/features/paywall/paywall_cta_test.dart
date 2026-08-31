import 'package:arcanum_app/features/paywall/paywall_screen.dart';
import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPaywall(WidgetTester tester) async {
  // Pantalla alta: las tres tarjetas viven en un ListView y el CTA de
  // Practicante queda fuera del viewport por defecto.
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Sin precios de tienda la hoja de packs no se abre, y es a proposito:
        // no se vende lo que no se sabe cuanto cuesta. Aqui se simula que la
        // tienda respondio para poder probar el CTA.
        storePricesProvider.overrideWith((ref) async => const {
          ProductIds.credit1: 'COP 4.900',
          ProductIds.pack3: 'COP 11.900',
          ProductIds.premiumAnnual: 'COP 199.900/año',
        }),
      ],
      child: const MaterialApp(home: PaywallScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Practicante anuncia los packs, no "Continuar gratis"', (tester) async {
    await _pumpPaywall(tester);

    // 1) el CTA explícito de Practicante está presente
    expect(find.text('Ver créditos y packs'), findsOneWidget);

    // 2) ninguna tarjeta anuncia "Continuar gratis" donde se abren packs de pago
    final practicante = find.ancestor(
      of: find.text('Prácticante'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: practicante.first, matching: find.text('Continuar gratis')),
      findsNothing,
      reason: 'Practicante abre packs de pago: no puede decir "Continuar gratis"',
    );
  });

  testWidgets('tocar el CTA de Practicante abre la hoja de packs', (tester) async {
    await _pumpPaywall(tester);

    expect(find.text('Créditos y packs'), findsNothing);

    await tester.tap(find.text('Ver créditos y packs'));
    await tester.pumpAndSettle();

    expect(find.text('Créditos y packs'), findsOneWidget);
  });

  testWidgets('los otros planes conservan su texto automático', (tester) async {
    await _pumpPaywall(tester);

    // Explorador (sin precio, no seleccionado) sigue con el fallback.
    expect(find.text('Continuar gratis'), findsOneWidget);
    // Místico (seleccionado) sigue ofreciendo la prueba.
    expect(find.text('Empezar prueba gratis'), findsOneWidget);
  });
}
