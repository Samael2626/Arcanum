// Los dos selectores del onboarding: en español y con la paleta de la casa.
//
// Se veían en inglés ("Select date", "Cancel") y con el morado y el vino por
// defecto de Material, en las dos pantallas seguidas que recorre cada persona
// nueva. Aquí se fija que ninguna de las dos cosas vuelva.
import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// La misma configuración que monta `main.dart`. Si aquí y allí se separan, el
/// test dejaría de probar la app y pasaría a probarse a sí mismo.
Widget _app(Widget home) => MaterialApp(
  theme: buildArcanumTheme(),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('es')],
  locale: const Locale('es'),
  home: home,
);

Future<void> _abrirFecha(WidgetTester tester) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDatePicker(
            context: context,
            initialDate: DateTime(2000, 1, 1),
            firstDate: DateTime(1900),
            lastDate: DateTime(2030),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _abrirHora(WidgetTester tester) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 12, minute: 0),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('en español', () {
    testWidgets('el selector de fecha ya no dice Select date', (tester) async {
      await _abrirFecha(tester);

      expect(find.text('Select date'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Seleccionar fecha'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('ACEPTAR'), findsOneWidget);
      // El calendario también: los días de la semana y el mes.
      expect(find.text('enero de 2000'), findsOneWidget);
      expect(find.text('sáb, 1 ene'), findsOneWidget);
    });

    testWidgets('y el de hora tampoco dice Select time', (tester) async {
      await _abrirHora(tester);

      expect(find.text('Select time'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });

  group('con la paleta de la casa', () {
    testWidgets('el tema de fecha no deja el morado de Material', (
      tester,
    ) async {
      final tema = buildArcanumTheme().datePickerTheme;

      expect(tema.backgroundColor, ArcanumColors.surface);
      expect(tema.headerForegroundColor, ArcanumColors.goldLight);
      // El día elegido: oro de fondo, tinta oscura encima.
      expect(
        tema.dayBackgroundColor?.resolve({WidgetState.selected}),
        ArcanumColors.gold,
      );
      expect(
        tema.dayForegroundColor?.resolve({WidgetState.selected}),
        ArcanumColors.background,
      );
    });

    testWidgets('el de hora tampoco, ni en el AM/PM', (tester) async {
      final tema = buildArcanumTheme().timePickerTheme;

      expect(tema.backgroundColor, ArcanumColors.surface);
      expect(tema.dialHandColor, ArcanumColors.gold);
      // El AM/PM era el bloque vino por defecto; el borgoña de la casa está
      // reservado a la carta invertida del Tarot.
      //
      // `dayPeriodColor` está tipado como `Color` aunque acepte un
      // `WidgetStateColor`: hay que devolverlo a su tipo para poder resolverlo.
      final periodo =
          (tema.dayPeriodColor! as WidgetStateColor).resolve({
            WidgetState.selected,
          });
      expect(periodo, isNot(ArcanumColors.burgundy));
      expect(
        (tema.dayPeriodTextColor! as WidgetStateColor).resolve({
          WidgetState.selected,
        }),
        ArcanumColors.goldLight,
      );
    });

    testWidgets('el diálogo se pinta sobre la superficie de la app', (
      tester,
    ) async {
      await _abrirHora(tester);

      final dialogo = tester.widget<Dialog>(find.byType(Dialog).first);
      expect(
        dialogo.backgroundColor ?? buildArcanumTheme().timePickerTheme.backgroundColor,
        ArcanumColors.surface,
      );
    });
  });
}
