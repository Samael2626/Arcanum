// Paridad del motor de capas y de la transliteracion con el prototipo.
// Casos: arcanum-sigil-prototype/_fixtures.mjs -> fixtures/capas.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/features/sigilos/engine/hebrew.dart';
import 'package:arcanum_app/features/sigilos/engine/layers.dart';
import 'package:arcanum_app/features/sigilos/engine/letter_sigil.dart';
import 'package:flutter_test/flutter_test.dart';

const _tol = 1e-6;

double _d(Object? v) => (v as num).toDouble();

void _pt(String what, (double, double) got, List<dynamic> js) {
  expect(got.$1, closeTo(_d(js[0]), _tol), reason: '$what x');
  expect(got.$2, closeTo(_d(js[1]), _tol), reason: '$what y');
}

void _prim(LayerPrim got, Map<String, dynamic> js, String where) {
  expect(got.op, closeTo(_d(js['op']), _tol), reason: '$where opacidad');
  switch (js['k']) {
    case 'circle':
      final c = got as CirclePrim;
      expect([c.cx, c.cy, c.r, c.w], [for (final k in ['cx', 'cy', 'r', 'w']) closeTo(_d(js[k]), _tol)], reason: where);
    case 'poly':
      final p = got as PolyPrim;
      expect(p.closed, js['closed'], reason: where);
      expect(p.w, closeTo(_d(js['w']), _tol), reason: where);
      final pts = js['pts'] as List;
      expect(p.pts.length, pts.length, reason: where);
      for (var i = 0; i < pts.length; i++) {
        _pt('$where vertice $i', p.pts[i], pts[i] as List);
      }
    case 'text':
      final t = got as TextPrim;
      expect(t.ch, js['ch'], reason: where);
      expect(t.font, js['font'], reason: where);
      expect([t.x, t.y, t.rot, t.size], [for (final k in ['x', 'y', 'rot', 'size']) closeTo(_d(js[k]), _tol)], reason: '$where «${t.ch}»');
    case 'glyph':
      final g = got as GlyphLayerPrim;
      expect(g.ch, js['ch'], reason: where);
      expect([g.x, g.y, g.rot, g.size], [for (final k in ['x', 'y', 'rot', 'size']) closeTo(_d(js[k]), _tol)], reason: where);
    default:
      fail('primitiva desconocida ${js['k']}');
  }
}

void main() {
  final data = jsonDecode(File('test/features/sigilos/fixtures/capas.json').readAsStringSync()) as Map<String, dynamic>;
  final stacks = (data['stacks'] as List).cast<Map<String, dynamic>>();

  for (final st in stacks) {
    final ctxJ = st['ctx'] as Map<String, dynamic>;
    final layers = [for (final l in st['layers'] as List) Layer.fromJson(l as Map<String, dynamic>)];
    final name = '${layers.map((l) => l.type.name).join(' + ')} · ${ctxJ['text']}';
    test(name, () {
      final ctx = LayerCtx(text: ctxJ['text'] as String, planet: ctxJ['planet'] as String?, title: ctxJ['title'] as String, sub: ctxJ['sub'] as String);
      final lay = layoutLayers(layers, ctx);
      expect(lay.contentR, closeTo(_d(st['contentR']), _tol), reason: 'hueco para el sigilo');
      final parts = (st['parts'] as List).cast<Map<String, dynamic>>();
      expect(lay.parts.length, parts.length, reason: 'capas visibles');
      for (var i = 0; i < parts.length; i++) {
        final p = lay.parts[i], j = parts[i], g = j['g'] as Map<String, dynamic>;
        final where = '${p.layer.type.name} #$i';
        expect(p.layer.id, j['id']);
        if (j['R'] == null) {
          expect(p.r, isNull, reason: where);
        } else {
          expect(p.r, closeTo(_d(j['R']), _tol), reason: '$where radio');
        }
        expect(p.g.inner, closeTo(_d(g['inner']), _tol), reason: '$where hueco');
        _pt('$where centro', p.g.center, g['center'] as List);
        final verts = g['vertices'] as List, radii = g['radii'] as List, prims = g['prims'] as List;
        expect(p.g.vertices.length, verts.length, reason: '$where vertices');
        for (var k = 0; k < verts.length; k++) {
          _pt('$where vertice', p.g.vertices[k], verts[k] as List);
        }
        expect(p.g.radii.length, radii.length, reason: '$where radios');
        for (var k = 0; k < radii.length; k++) {
          final r = radii[k] as List;
          expect([p.g.radii[k].$1, p.g.radii[k].$2, p.g.radii[k].$3], [for (final v in r) closeTo(_d(v), _tol)], reason: '$where radio $k');
        }
        expect(p.g.prims.length, prims.length, reason: '$where primitivas');
        for (var k = 0; k < prims.length; k++) {
          _prim(p.g.prims[k], prims[k] as Map<String, dynamic>, '$where prim $k');
        }
      }
    });
  }

  for (final t in (data['translit'] as List).cast<Map<String, dynamic>>()) {
    test('transliteracion: ${t['name']}', () {
      expect(transliterate(t['name'] as String, TranslitMethod.consonantal).hebrew, t['consonantal']);
      expect(transliterate(t['name'] as String, TranslitMethod.full).hebrew, t['full']);
    });
  }

  // la c: suave ante e/i (ס), dura en el resto y al final de palabra (כ, final ך)
  const casosC = {
    'Marc': 'מרך', 'Frederic': 'פרדריך', 'Cecilia': 'ססיליה', 'Lucas': 'לוכס', 'Rocco': 'רוכו',
    'Chesed': 'חסד', 'Isaac': 'יצחק', 'Marc Cid': 'מרך סיד',
  };
  casosC.forEach((name, he) {
    test('transliteracion de la c: $name = $he', () => expect(transliterate(name, TranslitMethod.consonantal).hebrew, he));
  });
  test('letra a letra: Marc = מארך (la c final sigue siendo dura)', () {
    expect(transliterate('Marc', TranslitMethod.full).hebrew, 'מארך');
  });
  test('ninguna c final se lee como s', () {
    const names = ['Marc', 'Frederic', 'Eric', 'Isac', 'Ludovic', 'Lorenc', 'Franc', 'Domenec', 'Joaquic', 'Benedic', 'Tomic', 'Pic', 'Sec',
      'Roc', 'Vic', 'Luc', 'Nic', 'Duc', 'Bec', 'Mac', 'Tec', 'Zac', 'Arc', 'Oc', 'Ac', 'Ec'];
    for (final n in names) {
      final h = transliterate(n, TranslitMethod.consonantal).hebrew;
      expect(h.endsWith('ך'), isTrue, reason: '$n = $h');
    }
  });
  test('el anillo hebreo de Marc lleva la Kaf final', () {
    final lay = layoutLayers([Layer.create('c1', LayerType.ringHebrew)], LayerCtx.letters('Marc'));
    final chars = lay.parts.single.g.prims.whereType<TextPrim>().map((t) => t.ch).join();
    expect(chars, 'מרך');
  });

  test('Samuel se escribe con su grafia biblica', () {
    expect(transliterate('Samuel', TranslitMethod.consonantal).hebrew, 'שמואל');
    expect(cleanHebrew('שְׁמוּאֵל'), 'שמואל');
  });

  for (final f in (data['framed'] as List).cast<Map<String, dynamic>>()) {
    test('el sigilo cabe en el hueco de los marcos (pila ${f['stack']})', () {
      final layers = [for (final l in (stacks[f['stack'] as int]['layers'] as List)) Layer.fromJson(l as Map<String, dynamic>)];
      final contentR = layoutLayers(layers, LayerCtx.letters('Mi practica mantiene enfoque sereno')).contentR;
      expect(contentR, closeTo(_d(f['contentR']), _tol));
      final sg = LetterSigil()..generate('Mi practica mantiene enfoque sereno', contentR: contentR);
      expect(sg.view!.k, closeTo(_d(f['k']), 1e-6));
      expect(sg.view!.cx, closeTo(_d(f['cx']), 1e-9));
    });
  }

  test('una capa guardada vuelve igual (JSON de ida y vuelta)', () {
    final l = Layer.create('c9', LayerType.star)
      ..points = 7
      ..shape = 'wide'
      ..rot = 12;
    final back = Layer.fromJson(jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), l.toJson());
  });
}
