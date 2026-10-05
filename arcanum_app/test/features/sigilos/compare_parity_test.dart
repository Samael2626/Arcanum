// La lamina se contrasta con _fixtures_compare.mjs del prototipo.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffSvg;

CompareDoc compareFor(Map<String, dynamic> c) {
  final style = SigilStyle.fromJson(c['style'] as Map<String, dynamic>);
  final doc = CompareDoc(
    day: c['day'] as int,
    planetChoice: c['planetChoice'] as String,
    transparent: c['transparent'] as bool? ?? false,
    letters: SigilDoc(style: style),
    rosa: RosaDoc(style: style),
    kamea: KameaDoc(style: style),
  );
  doc.generate(c['name'] as String);
  return doc;
}

void main() {
  final cases =
      (jsonDecode(
                File(
                  'test/features/sigilos/fixtures/compare.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  test('referencias incluyen Samuel, planetas y transparencia', () {
    expect(cases.length, 19);
    expect(cases.first['name'], 'Samuel');
    expect(cases.first['planet'], 'saturn');
    expect(cases.first['letters'], 'SAMUEL');
    expect(cases.first['hebrew'], 'שמואל');
    expect(cases.any((c) => c['transparent'] == true), isTrue);
  });
  for (final (i, c) in cases.indexed) {
    test('caso $i: ${c['name']} ${c['planet']}', () {
      final doc = compareFor(c);
      expect(doc.ready, isTrue);
      expect(doc.planet, c['planet']);
      expect(doc.rosa.hebrew, c['hebrew']);
      expect(doc.letters.sigil.letters.map((l) => l.ch).join(), c['letters']);
      for (final cell in c['cells'] as List) {
        final src = cell['src'] as String;
        final personal = PersonalDoc(
          source: src,
          letters: doc.letters,
          rosa: doc.rosa,
          kamea: doc.kamea,
        );
        expect(
          diffSvg(personal.sourceMarkup, cell['markup'] as String),
          isNull,
          reason: 'fuente $src',
        );
        final b = cell['bounds'] as Map<String, dynamic>;
        expect(
          personal.sourceBounds.left,
          closeTo((b['x'] as num).toDouble(), .05),
        );
        expect(
          personal.sourceBounds.top,
          closeTo((b['y'] as num).toDouble(), .05),
        );
        expect(
          personal.sourceBounds.width,
          closeTo((b['w'] as num).toDouble(), .05),
        );
        expect(
          personal.sourceBounds.height,
          closeTo((b['h'] as num).toDouble(), .05),
        );
      }
      final svg = doc.buildSVG().replaceFirst(
        '<rect width="800" height="800" fill="#efe6d2"/>',
        '',
      );
      expect(diffSvg(svg, c['svg'] as String), isNull, reason: 'lamina');
      expect(
        diffSvg(CompareDoc.fromJson(doc.toJson()).buildSVG(), doc.buildSVG()),
        isNull,
        reason: 'guardado',
      );
    });
  }
  test('el lienzo conserva caminos, escala y ancho visual del SVG', () {
    for (final c in cases) {
      final doc = compareFor(c);
      final scene = doc.scene(includeText: false);
      for (final cell in c['cells'] as List) {
        final src = cell['src'] as String;
        final markup = cell['markup'] as String;
        final svgPaths = RegExp(r'<path\b[^>]*\bd="([^"]+)"')
            .allMatches(markup).map((m) => m[1]!).toList();
        final groups = scene.fg.where((g) => g.layer.startsWith('compare-$src-') && g.scale != null).toList();
        final canvasPaths = [for (final g in groups) for (final p in g.items) p.d];
        expect(canvasPaths..sort(), svgPaths..sort(), reason: '$src ${c['name']}');
        for (final g in groups.where((g) => g.w != null && g.w! > 0)) {
          expect(g.w! * g.scale!, closeTo(4, 1e-9), reason: 'ancho visual $src');
          expect(g.op ?? 1, inInclusiveRange(0, 1), reason: 'opacidad $src');
        }
      }
    }
  });
}
