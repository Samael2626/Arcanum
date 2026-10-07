// Acciones del radial (letra y capa) y su ancla, frente al prototipo: mismos
// botones pulsados en el mismo orden. Casos: _fixtures.mjs -> interaccion.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffSvg;

double _d(Object? v) => (v as num).toDouble();

void main() {
  final r =
      (jsonDecode(
                File(
                  'test/features/sigilos/fixtures/interaccion.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['radial']
          as Map<String, dynamic>;
  final docIn = r['docIn'] as Map<String, dynamic>;
  final doc = SigilDoc(
    layers: [
      for (final l in docIn['layers'] as List)
        Layer.fromJson(l as Map<String, dynamic>),
    ],
  );
  doc.sigil.method = ReductionMethod.unique;
  doc.generate(docIn['intention'] as String);
  final ctl = CanvasController(doc);
  final ids = (r['ids'] as List).cast<String>();
  final acciones = <String, void Function()>{
    'btnRotR': () => ctl.rotateLetter(15),
    'btnRotL': () => ctl.rotateLetter(-15),
    'btnFlipH': ctl.flipLetterH,
    'btnFlipV': ctl.flipLetterV,
    'btnBigger': () => ctl.scaleLetter(true),
    'btnSmaller': () => ctl.scaleLetter(false),
    'btnLetterReset': ctl.resetLetter,
    'btnLayerBigger': () => ctl.scaleLayer(true),
    'btnLayerSmaller': () => ctl.scaleLayer(false),
    'btnLayerRotR': () => ctl.rotateLayer(15),
    'btnLayerRotL': () => ctl.rotateLayer(-15),
    'btnLayerDelete': ctl.deleteSelectedLayer,
  };

  test('el radial hace lo mismo que el prototipo, boton a boton', () {
    final steps = (r['steps'] as List).cast<Map<String, dynamic>>();
    for (final s in steps) {
      final label = s['label'] as String;
      if (label == 'elegir letra') {
        ctl
          ..sel = r['letter'] as String
          ..layerSel = null;
      } else if (label.startsWith('elegir capa ')) {
        ctl
          ..sel = null
          ..layerSel = label.substring('elegir capa '.length);
      } else {
        acciones[label]!();
      }
      final a = s['anchor'] as Map<String, dynamic>?, got = ctl.anchor();
      if (a == null) {
        expect(got, isNull, reason: '$label: sin ancla');
      } else {
        expect(got!.isLetter, a['kind'] == 'letter', reason: label);
        expect(
          [got.x, got.top, got.bottom],
          [
            for (final k in ['x', 'top', 'bottom']) closeTo(_d(a[k]), 1e-6),
          ],
          reason: '$label: ancla',
        );
      }
      (s['users'] as Map<String, dynamic>).forEach((ch, u) {
        final m = u as Map<String, dynamic>,
            e = doc.sigil.letters.firstWhere((l) => l.ch == ch).user;
        expect(
          [e.dx, e.dy, e.ds, e.drot],
          [
            for (final k in ['dx', 'dy', 'ds', 'drot']) closeTo(_d(m[k]), 1e-9),
          ],
          reason: '$label: letra $ch',
        );
        expect(
          [e.fx, e.fy],
          [m['fx'], m['fy']],
          reason: '$label: reflejos de $ch',
        );
      });
      final ls = (s['layers'] as List).cast<Map<String, dynamic>>();
      expect(
        doc.layers.map((l) => l.id).toList(),
        ls.map((l) => l['id']).toList(),
        reason: '$label: capas',
      );
      for (var i = 0; i < ls.length; i++) {
        // cada tipo tiene sus campos: se comparan los que existen en el prototipo
        final got = {
          'size': doc.layers[i].size,
          'scale': doc.layers[i].scale,
          'rot': doc.layers[i].rot,
        };
        for (final k in got.keys.where((k) => ls[i][k] != null)) {
          expect(
            got[k],
            closeTo(_d(ls[i][k]), 1e-9),
            reason: '$label: $k de ${doc.layers[i].type.name}',
          );
        }
      }
      expect(
        diffSvg(doc.buildSVG(), s['svg'] as String),
        isNull,
        reason: '$label: SVG',
      );
    }
    expect(ids.length, 3);
  });

  test('con un modo activo no hay radial', () {
    ctl
      ..sel = doc.sigil.active.first.ch
      ..termPick = true;
    expect(ctl.anchor(), isNull);
    ctl.termPick = false;
    expect(ctl.anchor(), isNotNull);
  });
}
