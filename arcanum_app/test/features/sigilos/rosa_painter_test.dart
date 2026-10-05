// Paridad del lienzo de la Rosa-Cruz: el pintor de Flutter frente al SVG
// exportado rasterizado por Chromium (sin texto). _fixtures_rosa.mjs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'painter_parity_test.dart' show decodePng, diffPct, painterImage;
import 'rosa_parity_test.dart' show docFor;

/// Umbral: el mismo que el del sigilo de letras.
const kMaxPct = 0.06;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/rosa.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final pngs = Directory('test/features/sigilos/fixtures/png_rosa').listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));

  test('hay imagenes de referencia', () => expect(pngs.length, greaterThan(30)));

  for (final f in pngs) {
    final i = int.parse(RegExp(r'ros(\d+)\.png').firstMatch(f.path)![1]!);
    final c = cases[i];
    testWidgets('lienzo = SVG en el navegador · caso $i · ${c['name'] ?? c['hebrew']}${c['colors'] == true ? ' colores' : ''}${c['diagram'] == false ? ' sin diagrama' : ''}', (tester) async {
      await tester.runAsync(() async {
        final doc = docFor(c);
        final s = doc.scene();
        // el texto depende de la fuente de cada lado: no entra en la comparacion
        final fg = [for (final g in s.fg) if (g.layer != 'rose-text') g];
        final got = await painterImage([s.bg, fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(pct, lessThan(kMaxPct), reason: '${pct.toStringAsFixed(3)} % de pixeles distintos');
      });
    });
  }
}
