@Tags(['capturas'])
library;

/// La tarjeta que se comparte, en los DOCE signos.
///
/// Cada plancha de Bayer tiene su propio brillo, asi que el contraste del texto
/// sobre ella no se puede dar por bueno midiendo uno solo. Es el mismo criterio
/// con el que se valido la lamina de Hoy signo a signo.
///
///     flutter test test/capturas/tarjeta_doce_test.dart --update-goldens --run-skipped
import 'dart:io';

import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/horoscopo/compartir_horoscopo.dart';
import 'package:arcanum_app/features/horoscopo/widgets/tarjeta_compartir.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/zodiaco_laminas.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ingles = {
  Signo.aries: 'aries', Signo.tauro: 'taurus', Signo.geminis: 'gemini',
  Signo.cancer: 'cancer', Signo.leo: 'leo', Signo.virgo: 'virgo',
  Signo.libra: 'libra', Signo.escorpio: 'scorpio',
  Signo.sagitario: 'sagittarius', Signo.capricornio: 'capricorn',
  Signo.acuario: 'aquarius', Signo.piscis: 'pisces',
};

Future<void> _cargarFuentes() async {
  final m = <String, List<String>>{
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
  };
  for (final e in m.entries) {
    final c = FontLoader(e.key);
    for (final r in e.value) {
      c.addFont(File(r).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await c.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });

  for (final entrada in _ingles.entries) {
    testWidgets('tarjeta de ${entrada.value}', (tester) async {
      final clave = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildArcanumTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: RepaintBoundary(
                key: clave,
                child: TarjetaCompartir(
                  aspecto: const {
                    'transit': 'moon', 'natal': 'midheaven',
                    'aspect': 'trine', 'angle': 120, 'separation': 119.34,
                  },
                  profeccion: const {
                    'age': 35, 'house': 5, 'lord': 'saturn',
                  },
                  texto: 'Saturno cierra un cuadrado con tu Sol: figura de '
                      'tension entre cuerpos que se miran de frente.',
                  signo: entrada.key,
                  signoIngles: entrada.value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Sin esto el `Image.asset` de la lamina no se resuelve y el retrato
      // sale sin grabado: el fallo parece del fondo y es del capturador.
      await tester.runAsync(() async {
        for (final img in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(img.image, tester.element(find.byType(Image)));
        }
      });
      await tester.pumpAndSettle();
      final png = await tester.runAsync(() => pintarTarjeta(clave));
      expect(png, isNotNull);
      File('test/capturas/salida/tc-${entrada.value}.png')
          .writeAsBytesSync(png!);
    });
  }
}
