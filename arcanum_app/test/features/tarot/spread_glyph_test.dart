// Icono de cada tirada dibujado desde sus huecos. Antes las siete compartian
// el mismo icono en el radial y no se distinguian (visto en el GN2200, 7-oct).
// Los huecos son los del backend (arcanum-api/app/domain/spreads.py).
import 'dart:io';
import 'dart:math' as math;

import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/table/spread_glyph.dart';
import 'package:flutter_test/flutter_test.dart';

SpreadDef _spread(String slug, List<(double, double, int)> slots) => SpreadDef(
      slug: slug,
      name: slug,
      description: '',
      cardScale: 1,
      labelByName: false,
      slots: [for (final (x, y, r) in slots) SpreadSlotDef(x: x, y: y, rotation: r, name: '', meaning: '')],
    );

final _spreads = [
  _spread('one_card', [(.5, .5, 0)]),
  _spread('three_card', [(.2, .46, 0), (.5, .46, 0), (.8, .46, 0)]),
  _spread('celtic_cross', [
    (.34, .5, 0), (.34, .5, 90), (.34, .8, 0), (.13, .5, 0), (.34, .2, 0),
    (.55, .5, 0), (.86, .87, 0), (.86, .62, 0), (.86, .38, 0), (.86, .13, 0),
  ]),
  _spread('simple_cross', [(.5, .5, 0), (.2, .5, 0), (.8, .5, 0), (.5, .14, 0), (.5, .86, 0)]),
  _spread('relationship', [(.18, .3, 0), (.82, .3, 0), (.5, .16, 0), (.5, .52, 0), (.5, .87, 0)]),
  _spread('horseshoe', [(.08, .8, -8), (.14, .46, -5), (.29, .17, -2), (.5, .08, 0), (.71, .17, 2), (.86, .46, 5), (.92, .8, 8)]),
  _spread('year_wheel', [
    for (var i = 0; i < 12; i++)
      (.5 + math.cos(-math.pi / 2 + i * math.pi / 6) * .4, .5 + math.sin(-math.pi / 2 + i * math.pi / 6) * .4, 0),
  ]),
];

void main() {
  test('cada tirada tiene su icono, distinto de las demas', () {
    final glyphs = {for (final s in _spreads) s.slug: spreadGlyph(s)!};
    expect(glyphs.values.toSet(), hasLength(_spreads.length));
  });

  test('una carta por hueco, dentro del cuadro de 24', () {
    for (final s in _spreads) {
      final g = spreadGlyph(s)!;
      expect('<path'.allMatches(g), hasLength(s.slots.length), reason: s.slug);
      for (final m in RegExp(r'-?\d+\.\d').allMatches(g)) {
        expect(double.parse(m[0]!), inInclusiveRange(0, 24), reason: '${s.slug}: $g');
      }
    }
  });

  test('la carta cruzada de la Cruz Celta va girada', () {
    final celtic = _spreads.firstWhere((s) => s.slug == 'celtic_cross');
    final rects = spreadGlyph(celtic)!.split('<path').skip(1).take(2).toList();
    expect(rects[0], isNot(rects[1]));
  });

  test('sin huecos: null (el radial usa el icono generico)', () {
    expect(spreadGlyph(_spread('vacia', const [])), isNull);
  });

  test('muestra visual', () {
    // para mirarla a ojo: escribe las siete en un SVG
    final out = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${24 * _spreads.length + 8 * (_spreads.length - 1)} 24" width="${(24 * _spreads.length + 8 * (_spreads.length - 1)) * 6}" height="144" style="background:#14110f">');
    for (var i = 0; i < _spreads.length; i++) {
      out.write('<g transform="translate(${i * 32} 0)" fill="none" stroke="#d9b86c" stroke-width="1.2" stroke-linejoin="round">${spreadGlyph(_spreads[i])}</g>');
    }
    out.write('</svg>');
    final f = File('${Directory.systemTemp.path}/tiradas.svg')..writeAsStringSync(out.toString());
    expect(f.existsSync(), isTrue);
  });
}
