@Tags(['capturas'])
library;

// Retrata SOLO la lamina de cada signo, sin texto y sin velo, al tamano exacto
// de la tarjeta. Con ese fondo limpio, el contraste de cualquier velo se
// calcula componiendo en numpy: no hace falta una pasada de capturas por cada
// valor de delta que se quiera probar, y sobre todo la medida deja de
// contaminarse con los pixeles del propio texto.
import 'package:arcanum_app/features/hoy/presentation/widgets/zodiaco_laminas.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'zodiaco_capturas_test.dart' as base;

/// Alto y ancho de la tarjeta, medidos con `zodiaco_geometria_test.dart`.
const _tarjeta = Size(320, 627);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await base.cargarFuentesParaMedir();
  });

  signoDesdeIngles.forEach((ingles, signo) {
    testWidgets('fondo de ${signo.name}', (tester) async {
      tester.view
        ..physicalSize = _tarjeta * 3.0
        ..devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final lamina = laminasDelZodiaco[signo]!;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: const Color(0xFF0A0A0F),
            child: SizedBox.fromSize(
              size: _tarjeta,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: lamina.banda
                          ? _tarjeta.width * lamina.altoLamina / 324
                          : _tarjeta.height,
                      width: double.infinity,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          lamina.asset,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final e in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(e.image, tester.element(find.byType(Image)));
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('salida/fondo-${signo.name}.png'),
      );
    });
  });
}
