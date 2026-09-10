@Tags(['capturas'])
library;

// Mide la tarjeta REAL: donde cae cada texto respecto al borde de arriba. Los
// topes del velo se decidieron sobre un mockup HTML y su tarjeta no es esta.
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'zodiaco_capturas_test.dart' as base;

void main() {
  testWidgets('geometria de la tarjeta', (tester) async {
    await base.montarParaMedir(tester, 'capricorn');
    final tarjeta = tester.getRect(find.byType(TodayCard).first);
    debugPrint('TARJETA alto=${tarjeta.height.toStringAsFixed(1)} '
        'ancho=${tarjeta.width.toStringAsFixed(1)}');
    for (final texto in ['TU CIELO DE HOY', '♑  CAPRICORNIO',
      'Luna trígono Medio Cielo', 'Separación real: 119,3°',
      'Abrir el sello del Sol', 'ESTE AÑO MANDA', 'Casa 5, en Capricornio']) {
      final f = find.text(texto);
      if (f.evaluate().isEmpty) {
        debugPrint('  (sin) $texto');
        continue;
      }
      final r = tester.getRect(f.first);
      debugPrint('  y ${(r.top - tarjeta.top).toStringAsFixed(0)}'
          '..${(r.bottom - tarjeta.top).toStringAsFixed(0)}'
          '  x ${(r.left - tarjeta.left).toStringAsFixed(0)}'
          '..${(r.right - tarjeta.left).toStringAsFixed(0)}  $texto');
    }
    final sky = tester.getRect(find.byType(SkyTodayCard).first);
    debugPrint('SKYCARD alto=${sky.height.toStringAsFixed(1)}');
  });
}
