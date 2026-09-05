@Tags(['capturas'])
library;

import 'dart:io';

import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retrata los dos selectores del onboarding: fecha y hora.
///
/// Son las dos pantallas que ve cada persona nueva y que nadie vuelve a mirar
/// después, así que son justo las que se quedan atrás. Salían en inglés y con
/// el morado y el vino por defecto de Material; esto deja constancia de cómo
/// quedan, sin depender de tener un teléfono enchufado.
///
///     flutter test test/capturas --update-goldens --run-skipped
///
/// LAS FUENTES HAY QUE CARGARLAS A MANO: en un entorno de test Flutter usa
/// Ahem, una fuente de cuadros negros, y el retrato saldría ilegible.
Future<void> _cargarFuentes() async {
  for (final familia in const {
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
  }.entries) {
    final cargador = FontLoader(familia.key);
    for (final ruta in familia.value) {
      cargador.addFont(
        File(ruta).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await cargador.load();
  }
}

const _telefono = Size(360, 640);
const _escala = 3.0;

/// La misma configuración que monta `main.dart`.
Future<void> _montar(WidgetTester tester, VoidCallback Function(BuildContext) abrir) async {
  tester.view
    ..physicalSize = _telefono * _escala
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildArcanumTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: abrir(context), child: const Text('abrir')),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });

  testWidgets('11 el selector de fecha', (tester) async {
    await _montar(
      tester,
      (context) => () => showDatePicker(
        context: context,
        initialDate: DateTime(1990, 6, 15),
        firstDate: DateTime(1900),
        lastDate: DateTime(2030),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('salida/11-selector-fecha.png'),
    );
  });

  testWidgets('12 el selector de hora', (tester) async {
    await _montar(
      tester,
      (context) => () => showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 14, minute: 30),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('salida/12-selector-hora.png'),
    );
  });
}
