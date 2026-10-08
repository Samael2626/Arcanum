// El sello personal se contrasta con _fixtures_personal.mjs del prototipo.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffSvg;

PersonalDoc personalFor(Map<String, dynamic> c) {
  final style = SigilStyle.fromJson(c['style'] as Map<String, dynamic>);
  final letters = SigilDoc(style: style);
  letters.sigil
    ..method = ReductionMethod.values.byName(c['method'] as String? ?? 'unique')
    ..mode = ComposeMode.values.byName(c['mode'] as String? ?? 'fusion');
  letters.generate(c['name'] as String);
  final rosa = RosaDoc(style: style)..setName(c['name'] as String);
  final kamea = KameaDoc(style: style, planet: c['sourcePlanet'] as String? ?? 'saturn')..setName(c['name'] as String);
  return PersonalDoc(
    source: c['source'] as String,
    template: c['template'] as String,
    name: c['label'] as String? ?? '',
    planetChoice: c['planetChoice'] as String? ?? 'auto',
    day: c['day'] as int? ?? 6,
    view: c['view'] as String? ?? 'paper',
    transparent: c['transparent'] as bool? ?? false,
    layers: [for (final l in c['layers'] as List) Layer.fromJson(l as Map<String, dynamic>)],
    letters: letters,
    rosa: rosa,
    kamea: kamea,
  );
}

void main() {
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/personal.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  test('referencias cruzan tres fuentes, tres formatos y dos vistas', () {
    expect(cases.map((c) => c['source']).toSet(), {'letters', 'rosa', 'kamea'});
    expect(cases.map((c) => c['template']).toSet(), {'goetia', 'pentaculo', 'agrippa'});
    expect(cases.map((c) => c['view']).toSet(), containsAll(['paper', 'metal']));
  });
  test('planeta automatico por dia; la kamea obliga al suyo', () {
    final doc = PersonalDoc(day: 0, planetChoice: 'auto');
    expect(doc.planet, 'sun');
    doc.day = 6;
    expect(doc.planet, 'saturn');
    doc.kamea..planet = 'mars'..setName('Samuel');
    doc.source = 'kamea';
    doc.planetChoice = 'venus';
    expect(doc.planet, 'mars');
    expect(doc.buildSVG(), contains('metal: hierro'));
  });
  test('la figura de kamea usa el mismo trazo aunque el documento muestre la tabla', () {
    final doc = PersonalDoc(source: 'kamea');
    doc.kamea..planet = 'mars'..setName('Samuel')..grid = true;
    final markup = doc.sourceMarkup;
    final paths = RegExp(r'<path\b[^>]*\bd="([^"]+)"').allMatches(markup).map((m) => m[1]).toList();
    final scenePaths = [for (final g in doc.scene().fg) if (g.scale != null) for (final item in g.items) item.d];
    expect(scenePaths, paths);
    expect(doc.kamea.grid, isTrue);
  });
  for (final (i, c) in cases.indexed) {
    test('caso $i: ${c['source']} ${c['template']} ${c['name']}', () {
      final doc = personalFor(c);
      expect(doc.planet, c['planet']);
      expect(doc.displayedName, c['name']);
      expect(doc.layout.contentR, closeTo((c['contentR'] as num).toDouble(), 1e-6));
      expect(diffSvg(doc.sourceMarkup, c['sourceMarkup'] as String), isNull, reason: 'fuente');
      final svg = doc.buildSVG().replaceFirst(RegExp(r'<rect width="800" height="800" fill="(?:#1a1612|#efe6d2)"/>'), '');
      expect(diffSvg(svg, c['svg'] as String), isNull, reason: 'sello');
      expect(diffSvg(PersonalDoc.fromJson(doc.toJson()).buildSVG(), doc.buildSVG()), isNull, reason: 'guardado');
      final b = c['bounds'] as Map<String, dynamic>;
      expect(doc.sourceBounds.left, closeTo((b['x'] as num).toDouble(), .05), reason: 'x');
      expect(doc.sourceBounds.top, closeTo((b['y'] as num).toDouble(), .05), reason: 'y');
      expect(doc.sourceBounds.width, closeTo((b['w'] as num).toDouble(), .05), reason: 'w');
      expect(doc.sourceBounds.height, closeTo((b['h'] as num).toDouble(), .05), reason: 'h');
    });
  }
  test('el lienzo conserva cada camino, ancho y opacidad del SVG', () {
    for (final c in cases) {
      final doc = personalFor(c);
      final markup = doc.sourceMarkup;
      final source = <(String, double, double)>[];
      final widths = <double>[0], opacities = <double>[1];
      String? attr(String tag, String key) => RegExp('$key="([^"]+)"').firstMatch(tag)?.group(1);
      for (final m in RegExp(r'<g\b[^>]*>|</g>|<path\b[^>]*>').allMatches(markup)) {
        final tag = m[0]!;
        if (tag.startsWith('<g ')) {
          widths.add(double.tryParse(attr(tag, 'stroke-width') ?? '') ?? widths.last);
          opacities.add((double.tryParse(attr(tag, 'opacity') ?? '') ?? 1) * opacities.last);
        } else if (tag == '</g>') {
          widths.removeLast(); opacities.removeLast();
        } else {
          source.add((attr(tag, 'd')!, double.tryParse(attr(tag, 'stroke-width') ?? '') ?? widths.last,
              (double.tryParse(attr(tag, 'opacity') ?? '') ?? 1) * opacities.last));
        }
      }
      final offset = doc.sourceOffset, scale = doc.sourceScale;
      final scene = [for (final g in doc.scene().fg) if (g.scale != null) g];
      final canvas = <(String, double, double)>[];
      for (final g in scene) {
        expect(g.scale, closeTo(scale, 1e-9));
        expect(g.dx, closeTo(offset.$1, 1e-9));
        expect(g.dy, closeTo(offset.$2, 1e-9));
        for (final p in g.items) { canvas.add((p.d, g.w ?? 0, (g.op ?? 1) * (p.op ?? 1))); }
      }
      String key((String, double, double) s) => '${s.$1}|${s.$2.toStringAsFixed(2)}|${s.$3.toStringAsFixed(3)}';
      expect(canvas.map(key).toList()..sort(), source.map(key).toList()..sort(), reason: '${c['source']} ${c['name']}');
    }
  });
}
