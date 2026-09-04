import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arcanum_app/core/places/city_index.dart';
import 'package:arcanum_app/core/places/city_index_provider.dart';
import 'package:arcanum_app/features/onboarding/presentation/steps/place_step.dart';

// El paso del lugar es la ultima puerta antes de persistir el nacimiento. Lo
// que se fija aqui es lo que costo el bug de Bogota hardcodeada: NUNCA un lugar
// sin elegir, y nunca uno por omision.

const _medellin = City(
  name: 'Medellín',
  region: 'Antioquia',
  country: 'Colombia',
  countryCode: 'CO',
  lat: 6.2447,
  lon: -75.5748,
  timezone: 'America/Bogota',
);

class _FakeCityIndex implements CityIndex {
  @override
  Future<List<City>> search(
    String query, {
    String? countryCode,
    int limit = 30,
  }) async {
    if (query.trim().length < 2) return const [];
    return _medellin.name.toLowerCase().contains(query.toLowerCase())
        ? const [_medellin]
        : const [];
  }

  @override
  Future<List<Country>> countries() async =>
      const [Country(code: 'CO', name: 'Colombia')];
}

Widget _host({required VoidCallback onNext}) => ProviderScope(
  overrides: [cityIndexProvider.overrideWithValue(_FakeCityIndex())],
  child: MaterialApp(
    home: Scaffold(
      body: PlaceStep(onNext: onNext, onBack: () {}),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sin lugar elegido no se puede finalizar', (tester) async {
    var avanzo = false;
    await tester.pumpWidget(_host(onNext: () => avanzo = true));
    await tester.pumpAndSettle();

    // El boton existe pero esta apagado: `onPressed` null.
    // GoldButton se dibuja sobre un OutlinedButton.
    final boton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Finalizar'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(boton.onPressed, isNull);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(avanzo, isFalse, reason: 'no se avanza sin lugar confirmado');
  });

  testWidgets('el paso ya no tiene cajas de texto propias', (tester) async {
    await tester.pumpWidget(_host(onNext: () {}));
    await tester.pumpAndSettle();

    // Antes habia dos: "País" y "Ciudad". Lo tecleado ahi se mandaba al
    // servidor y volvia el display_name crudo de Nominatim.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Buscar mi ciudad'), findsOneWidget);
  });

  testWidgets('elegir del catalogo deja el nombre legible y permite finalizar', (
    tester,
  ) async {
    var avanzo = false;
    await tester.pumpWidget(_host(onNext: () => avanzo = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar mi ciudad'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Medell');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // Elegir la fila NO cierra la hoja: hace falta confirmar.
    await tester.tap(find.text('Medellín, Antioquia, Colombia').last);
    await tester.pumpAndSettle();
    expect(avanzo, isFalse, reason: 'tocar la fila no confirma nada todavia');

    await tester.tap(find.text('Usar este lugar'));
    await tester.pumpAndSettle();

    // El nombre del catalogo, no la ristra de Nominatim.
    expect(find.text('Medellín, Antioquia, Colombia'), findsOneWidget);
    expect(find.text('Buscar mi ciudad'), findsNothing);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(avanzo, isTrue);
  });

  testWidgets('cerrar el selector sin elegir no deja lugar', (tester) async {
    var avanzo = false;
    await tester.pumpWidget(_host(onNext: () => avanzo = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar mi ciudad'));
    await tester.pumpAndSettle();

    // Cancelar la hoja arrastrandola fuera equivale a devolver null.
    Navigator.of(tester.element(find.byType(PlaceStep))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Buscar mi ciudad'), findsOneWidget);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(avanzo, isFalse);
  });
}
