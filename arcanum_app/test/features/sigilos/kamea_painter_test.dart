// Paridad del lienzo de la Kamea: el pintor de Flutter frente al SVG
// exportado rasterizado por Chromium (sin texto). _fixtures_kamea.mjs.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painter_parity_test.dart' show decodePng, diffPct, painterImage;

/// Umbral: el mismo que el del sigilo de letras.
const kMaxPct = 0.06;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/kamea.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final pngs = Directory('test/features/sigilos/fixtures/png_kamea').listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));

  test('hay imagenes de referencia', () => expect(pngs.length, greaterThan(20)));

  for (final f in pngs) {
    final i = int.parse(RegExp(r'kam(\d+)\.png').firstMatch(f.path)![1]!);
    final c = cases[i];
    testWidgets('lienzo = SVG en el navegador · caso $i · ${c['planet']} ${c['hebrew']}${c['grid'] as bool ? ' tabla' : ''}', (tester) async {
      await tester.runAsync(() async {
        final doc = KameaDoc.fromJson({
          'v': 1,
          'planet': c['planet'],
          'hebrew': c['hebrew'],
          'name': c['name'] ?? '',
          'reduce': c['reduce'],
          'ends': c['ends'],
          'grid': c['grid'],
          'transparent': c['transparent'] ?? false,
          'style': c['style'],
        });
        final s = doc.scene();
        // el texto depende de la fuente de cada lado: no entra en la comparacion
        final fg = [for (final g in s.fg) if (g.layer != 'kamea-numbers' && g.layer != 'caption') g];
        final got = await painterImage([s.bg, fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(pct, lessThan(kMaxPct), reason: '${pct.toStringAsFixed(3)} % de pixeles distintos');
      });
    });
  }
}
