// Lienzo de Comparar contra Chromium, sin texto ni soporte de pergamino.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'compare_parity_test.dart' show compareFor;
import 'painter_parity_test.dart' show decodePng, diffPct, painterImage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases =
      (jsonDecode(
                File(
                  'test/features/sigilos/fixtures/compare.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  final pngs = Directory(
    'test/features/sigilos/fixtures/png_compare',
  ).listSync().whereType<File>().toList();
  test('hay imagenes de referencia', () => expect(pngs.length, 10));
  for (final f in pngs) {
    final i = int.parse(RegExp(r'cmp(\d+)\.png').firstMatch(f.path)![1]!);
    testWidgets('lienzo = SVG del navegador · caso $i', (tester) async {
      await tester.runAsync(() async {
        final scene = compareFor(cases[i]).scene(includeText: false);
        final got = await painterImage([const <SceneGroup>[], scene.fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(
          pct,
          lessThan(.06),
          reason: '${pct.toStringAsFixed(3)} % de pixeles distintos',
        );
      });
    });
  }
}
