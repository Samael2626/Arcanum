// SVG exportado con el texto en trazos: el contorno sale de las mismas fuentes
// empaquetadas con que el lienzo pinta, y en el mismo sitio. Se comprueba
// pintando dos veces con las fuentes REALES cargadas: el pintor de la app
// (texto) y el SVG exportado leido tal cual (sus transform y sus d).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painter_parity_test.dart' show diffPct;

const _intencion = 'Mi práctica mantiene enfoque sereno';

Future<void> _loadFonts() async {
  Future<ByteData> f(String n) async => ByteData.sublistView(Uint8List.fromList(File('assets/fonts/$n').readAsBytesSync()));
  await (FontLoader('Crimson Pro')
        ..addFont(f('CrimsonPro-400.ttf'))
        ..addFont(f('CrimsonPro-400italic.ttf')))
      .load();
  await (FontLoader('Noto Serif Hebrew')..addFont(f('NotoSerifHebrew-Regular.ttf'))).load();
  await (FontLoader('ArcanumGlifos')..addFont(f('ArcanumGlifos-Regular.ttf'))).load();
}

List<double> _nums(String s) => RegExp(r'-?[\d.]+').allMatches(s).map((m) => double.parse(m[0]!)).toList();

/// Lee el SVG del texto en trazos (solo el formato que escribe textOutlineSVG).
void _paintOutlined(ui.Canvas c, String svg) {
  final groups = RegExp(r'<g transform="translate\(([^)]*)\) rotate\(([^)]*)\)" fill="[^"]*"[^>]*>(.*?)</g>');
  final paths = RegExp(r'<path transform="translate\(([^)]*)\) scale\(([^)]*)\)" d="([^"]*)"/>');
  for (final g in groups.allMatches(svg)) {
    final t = _nums(g[1]!), rot = double.parse(g[2]!);
    c.save();
    c.translate(t[0], t[1]);
    c.rotate(rot * math.pi / 180);
    for (final p in paths.allMatches(g[3]!)) {
      final tr = _nums(p[1]!), sc = _nums(p[2]!);
      c.save();
      c.translate(tr[0], tr[1]);
      c.scale(sc[0], sc[1]);
      c.drawPath(pathOf(p[3]!), ui.Paint()..color = const ui.Color(0xFF000000));
      c.restore();
    }
    c.restore();
  }
}

Future<ui.Image> _img(void Function(ui.Canvas) draw) {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec)..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  draw(c);
  return rec.endRecording().toImage(800, 800);
}

SigilDoc _doc(List<Layer> layers) => SigilDoc(layers: layers)..generate(_intencion);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  final casos = <String, List<Layer>>{
    'anillo latino': [Layer.create('a', LayerType.ringLatin)..text = 'Straße ÁNGEL lux']..first.sep = 'dot',
    'anillo hebreo': [Layer.create('a', LayerType.ringHebrew)],
    'inscripcion en arco': [Layer.create('a', LayerType.inscription)..text = 'VOLUNTAS'],
    'rotulo (cursiva y simbolo)': [Layer.create('a', LayerType.caption)..title = 'Mi sello'..sub = 'con ♄︎ Saturno'],
  };

  for (final MapEntry(key: nombre, value: capas) in casos.entries) {
    test('$nombre: el SVG en trazos se ve como el lienzo', () async {
      final doc = _doc(capas);
      final groups = doc.scene(transparent: true).fg.where((g) => g.prims?.any((p) => p is TextPrim) ?? false).toList();
      expect(groups, isNotEmpty);
      final svg = sceneSVG(groups, outline: true);
      expect(svg, isNot(contains('<text')), reason: 'todo el texto de este caso esta en las fuentes');
      final black = [for (final g in groups) SceneGroup(layer: g.layer, color: '#000000', prims: [for (final p in g.prims!) if (p is TextPrim) p])];
      final pintor = await _img((c) => paintScene(c, black));
      final exportado = await _img((c) => _paintOutlined(c, svg));
      final d = await diffPct(pintor, exportado);
      // texto de verdad en los dos (no dos lienzos en blanco)
      final px = (await exportado.toByteData())!.buffer.asUint32List();
      expect(px.where((v) => v != 0xFFFFFFFF).length, greaterThan(500));
      // umbral: el doble del peor caso real medido (0,031 %); 2 px de desvio dan >= 0,11 %
      expect(d, lessThan(.06), reason: '$nombre: $d % de pixeles distintos');
    });
  }

  test('sin la opcion, el SVG sigue llevando <text> (paridad con el prototipo)', () {
    final doc = _doc([Layer.create('a', LayerType.ringLatin)]);
    expect(doc.buildSVG(), contains('<text'));
    final out = doc.buildSVG(outlineText: true);
    expect(out, isNot(contains('<text')));
    expect(out, contains('<g transform="translate('));
  });

  test('un caracter que no esta en las fuentes se queda como texto, no como hueco', () {
    final t = TextPrim(400, 400, 0, 20, 'A✠B', kLatFont, 1);
    expect(textOutlineSVG(t, '#000', ''), isNull);
    expect(primsSVG([t], '#000', outline: true), contains('<text'));
  });
}
