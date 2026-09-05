// La banda del anio. Lo que se fija aqui es lo que no puede fallar nunca:
// que sin fecha de nacimiento NO se pinta nada, y que lo que se pinta esta
// escrito en castellano de verdad.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/features/hoy/presentation/widgets/banda_del_anio.dart';

Future<void> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? profection,
  Map<String, dynamic>? year,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: BandaDelAnio(profection: profection, year: year),
    ),
  ),
);

const _saturnoEnCasa5 = {
  'age': 35,
  'house': 5,
  'sign': 'capricorn',
  'sign_es': 'Capricornio',
  'lord': 'saturn',
  'points_in_sign': ['saturn'],
};

void main() {
  testWidgets('sin profeccion no pinta nada, ni un hueco', (tester) async {
    await _montar(tester, profection: null);
    expect(find.byType(BandaDelAnio), findsOneWidget);
    expect(find.textContaining('AÑO'), findsNothing);
    // Nada que leer y nada que ocupe sitio: ni un placeholder.
    expect(tester.getSize(find.byType(BandaDelAnio)), Size.zero);
  });

  testWidgets('una profeccion incompleta tampoco se pinta a medias', (
    tester,
  ) async {
    await _montar(tester, profection: {'age': 35, 'sign_es': 'Capricornio'});
    expect(tester.getSize(find.byType(BandaDelAnio)), Size.zero);
  });

  testWidgets('dice quien manda, en que casa y en que signo', (tester) async {
    await _montar(tester, profection: _saturnoEnCasa5);
    expect(find.text('ESTE AÑO MANDA'), findsOneWidget);
    expect(find.text('Saturno'), findsOneWidget);
    expect(find.text('Casa 5 · Capricornio'), findsOneWidget);
  });

  testWidgets('sin signo dice solo la casa, no un vacio', (tester) async {
    await _montar(
      tester,
      profection: const {'age': 35, 'house': 5, 'lord': 'saturn'},
    );
    expect(find.text('Casa 5'), findsOneWidget);
  });

  testWidgets('sin transito al senor no hay linea de toque', (tester) async {
    await _montar(
      tester,
      profection: _saturnoEnCasa5,
      year: const {'transit': 'venus', 'natal': 'moon', 'aspect': 'trine'},
    );
    expect(find.textContaining('Hoy'), findsNothing);
  });

  testWidgets('cuando tocan al senor, el cuerpo que llega lleva articulo', (
    tester,
  ) async {
    await _montar(
      tester,
      profection: _saturnoEnCasa5,
      year: const {'transit': 'moon', 'natal': 'saturn', 'aspect': 'sextile'},
    );
    // «Hoy lo toca Luna» estaria mal escrito, y esto lo lee una persona.
    expect(find.text('Hoy lo toca la Luna, en sextil.'), findsOneWidget);
  });

  testWidgets('cuando el senor es quien transita, el otro punto es natal', (
    tester,
  ) async {
    await _montar(
      tester,
      profection: _saturnoEnCasa5,
      year: const {'transit': 'saturn', 'natal': 'sun', 'aspect': 'square'},
    );
    expect(find.text('Hoy toca tu Sol natal, en cuadratura.'), findsOneWidget);
  });
}
