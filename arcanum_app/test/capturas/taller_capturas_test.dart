@Tags(['capturas'])
library;

import 'dart:io';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retrata el taller de sigilos a 390x844 con las fuentes reales.
///
///     flutter test test/capturas/taller_capturas_test.dart --update-goldens --run-skipped
///
/// En test Flutter usa Ahem (cuadros negros): las fuentes, iconos incluidos,
/// se cargan a mano.
Future<void> _cargarFuentes() async {
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? 'D:/flutter'}/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  for (final f in <String, List<String>>{
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': ['assets/fonts/CrimsonPro-400.ttf', 'assets/fonts/CrimsonPro-400italic.ttf', 'assets/fonts/CrimsonPro-500.ttf', 'assets/fonts/CrimsonPro-600.ttf'],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
    'Noto Serif Hebrew': ['assets/fonts/NotoSerifHebrew-Regular.ttf'],
    'MaterialIcons': [material],
  }.entries) {
    final c = FontLoader(f.key);
    for (final r in f.value) {
      c.addFont(File(r).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await c.load();
  }
}

Future<TallerScreenState> _montar(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [arcanumApiProvider.overrideWithValue(ArcanumApi(Dio())), userPlaceProvider.overrideWithValue(null)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildArcanumTheme(),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      home: const TallerScreen(),
    ),
  ));
  await tester.pump();
  return tester.state<TallerScreenState>(find.byType(TallerScreen));
}

Future<void> _forjar(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Mi práctica mantiene enfoque sereno');
  await tester.tap(find.text('Forjar'));
  await tester.pump();
}

Offset _sobreLetra(WidgetTester tester, SigilDoc doc) {
  final p = doc.sigil.prims.firstWhere((q) => q.units.length == 1 && q is LinePrim) as LinePrim;
  final a = doc.sigil.view!.toCanvas(p.a), b = doc.sigil.view!.toCanvas(p.b);
  final r = tester.getRect(find.byType(SigilCanvas));
  return Offset(r.left + (a.x + b.x) / 2 * r.width / kSize, r.top + (a.y + b.y) / 2 * r.width / kSize);
}

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('taller: vacio', (tester) async {
    await _montar(tester);
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-1-vacio.png'));
  });

  testWidgets('taller: forjado con una letra elegida', (tester) async {
    final st = await _montar(tester);
    await _forjar(tester);
    await tester.tapAt(_sobreLetra(tester, st.debugDoc));
    await tester.pump();
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-2-radial-letra.png'));
  });

  testWidgets('taller: boton + abierto', (tester) async {
    await _montar(tester);
    await _forjar(tester);
    await tester.tap(find.byTooltip('Añadir'));
    await tester.pump();
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-3-anadir.png'));
  });

  testWidgets('taller: estilo oro con anillo y estrella', (tester) async {
    final st = await _montar(tester);
    await _forjar(tester);
    st.debugDoc.style = presetStyle('oro');
    await tester.tap(find.byTooltip('Añadir'));
    await tester.pump();
    await tester.tap(find.byTooltip('Anillo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Añadir'));
    await tester.pump();
    await tester.tap(find.byTooltip('Estrella'));
    await tester.pump();
    await tester.tap(find.text('Estilo'));
    await tester.pump();
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-4-estilo.png'));
  });

  testWidgets('taller: pestaña Capas con la estrella elegida', (tester) async {
    await _montar(tester);
    await _forjar(tester);
    await tester.tap(find.byTooltip('Añadir'));
    await tester.pump();
    await tester.tap(find.byTooltip('Estrella'));
    await tester.pump();
    await tester.tap(find.text('Capas'));
    await tester.pump();
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-5-capas.png'));
  });

  testWidgets('taller: en horizontal', (tester) async {
    await _montar(tester, size: const Size(844, 390));
    await _forjar(tester);
    await expectLater(find.byType(TallerScreen), matchesGoldenFile('salida/taller-6-horizontal.png'));
  });
}
