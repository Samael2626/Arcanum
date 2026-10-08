// El lienzo de Sello personal contra el SVG rasterizado en Chromium.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painter_parity_test.dart' show decodePng, diffPct, painterImage;
import 'personal_parity_test.dart' show personalFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/personal.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final pngs = Directory('test/features/sigilos/fixtures/png_personal').listSync().whereType<File>().toList();
  test('hay imagenes de referencia', () => expect(pngs.length, 11));
  for (final f in pngs) {
    final i = int.parse(RegExp(r'per(\d+)\.png').firstMatch(f.path)![1]!);
    testWidgets('lienzo = SVG del navegador · caso $i', (tester) async {
      await tester.runAsync(() async {
        final doc = personalFor(cases[i]);
        final s = doc.scene();
        final fg = [for (final g in s.fg)
          if (g.prims == null) g else SceneGroup(layer: g.layer, color: g.color, prims: [for (final p in g.prims!) if (p is! TextPrim) p])];
        final got = await painterImage([const <SceneGroup>[], fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(pct, lessThan(.06), reason: '${pct.toStringAsFixed(3)} % de pixeles distintos');
      });
    });
  }
}
