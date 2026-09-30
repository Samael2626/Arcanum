// Paridad del lienzo: el pintor de Flutter frente al SVG exportado rasterizado
// por el navegador (Chromium), que es la referencia de «lo que se exporta».
// Solo casos sin texto: la geometria debe coincidir; el texto depende de la
// fuente de cada lado (Crimson Pro en la app, Georgia en el SVG).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcanum_sigilos/ui/scene_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show docFor;

/// Porcentaje de pixeles con diferencia fuerte (el suavizado de bordes no cuenta).
Future<double> diffPct(ui.Image a, ui.Image b) async {
  final da = (await a.toByteData())!, db = (await b.toByteData())!;
  var n = 0;
  for (var i = 0; i < da.lengthInBytes; i += 4) {
    var m = 0;
    for (var k = 0; k < 3; k++) {
      final d = (da.getUint8(i + k) - db.getUint8(i + k)).abs();
      if (d > m) m = d;
    }
    if (m > 64) n++;
  }
  return n / (da.lengthInBytes / 4) * 100;
}

Future<ui.Image> decodePng(Uint8List bytes) async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

Future<ui.Image> painterImage(List<dynamic> scene, int px) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec)..scale(px / 800);
  for (final groups in scene) {
    paintScene(c, groups);
  }
  return rec.endRecording().toImage(px, px);
}

/// Umbral: el doble del peor caso real medido (0,029 %).
const kMaxPct = 0.06;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = ((jsonDecode(File('test/features/sigilos/fixtures/capas.json').readAsStringSync()) as Map<String, dynamic>)['svgs'] as List)
      .cast<Map<String, dynamic>>();
  final pngs = Directory('test/features/sigilos/fixtures/png').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('hay imagenes de referencia', () => expect(pngs.length, greaterThan(20)));

  for (final f in pngs) {
    final i = int.parse(RegExp(r'svg(\d+)\.png').firstMatch(f.path)![1]!);
    final c = cases[i], st = c['style'] as Map<String, dynamic>;
    testWidgets('lienzo = SVG en el navegador · caso $i · ${c['mode']} · ${st['preset']}${st['relief'] == true ? ' relieve' : ''}${st['glow'] == true ? ' resplandor' : ''}${st['line'] == 'double' ? ' doble' : ''}', (tester) async {
      await tester.runAsync(() async {
        final doc = docFor(c);
        final s = doc.scene(transparent: doc.transparent);
        final got = await painterImage([s.bg, s.fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(pct, lessThan(kMaxPct), reason: '${pct.toStringAsFixed(3)} % de pixeles distintos');
      });
    });
  }
}
