// Paridad de la interaccion con el prototipo: guias con iman, capa y trazo
// bajo el dedo, giro con iman y gestos reales grabados con el raton en el
// navegador (mismos eventos, en coordenadas de lienzo, reproducidos aqui).
// Casos: arcanum-sigil-prototype/_fixtures.mjs -> fixtures/interaccion.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/engine/geometry.dart';
import 'package:arcanum_sigilos/engine/interaction.dart';
import 'package:arcanum_sigilos/engine/layers.dart';
import 'package:arcanum_sigilos/engine/sigil_doc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffNumeric, diffSvg;

double _d(Object? v) => (v as num).toDouble();

void main() {
  final data = jsonDecode(File('test/features/sigilos/fixtures/interaccion.json').readAsStringSync()) as Map<String, dynamic>;
  final pxScale = _d(data['pxScale']);
  final intention = data['intention'] as String;
  SigilDoc freshDoc() => SigilDoc(layers: [for (final l in (data['doc'] as Map)['layers'] as List) Layer.fromJson(l as Map<String, dynamic>)])..generate(intention);
  final probes = data['probes'] as Map<String, dynamic>;
  final pts = [for (final p in probes['pts'] as List) Pt(_d(p['x']), _d(p['y']))];

  test('guias con iman en ${pts.length} puntos (punto, vertical, horizontal, anillo, angulo)', () {
    final doc = freshDoc();
    final snaps = (probes['snap'] as List).cast<Map<String, dynamic>>();
    final kinds = <String>{};
    for (var i = 0; i < snaps.length; i++) {
      final s = snaps[i];
      final r = snapPoint(doc, pts[i], s['ex'] as String?, pxScale: pxScale);
      final q = s['q'] as Map<String, dynamic>;
      expect(r.p.x, closeTo(_d(q['x']), 1e-6), reason: 'x del punto $i');
      expect(r.p.y, closeTo(_d(q['y']), 1e-6), reason: 'y del punto $i');
      final g = (s['guides'] as List).cast<Map<String, dynamic>>();
      expect(r.guides.map((x) => x.kind.name).toList(), g.map((x) => x['k']).toList(), reason: 'guias del punto $i');
      kinds.addAll(g.map((x) => x['k'] as String));
    }
    expect(kinds, containsAll(['point', 'v', 'h', 'circle', 'ray']), reason: 'los casos cubren todas las guias');
  });

  test('capa bajo el dedo en ${pts.length} puntos', () {
    final doc = freshDoc();
    final hits = probes['hits'] as List;
    for (var i = 0; i < pts.length; i++) {
      expect(layerAt(doc, pts[i])?.id, hits[i], reason: 'punto $i');
    }
  });

  test('trazo bajo el dedo en ${pts.length} puntos', () {
    final doc = freshDoc();
    final prims = probes['prims'] as List;
    for (var i = 0; i < pts.length; i++) {
      final p = primAt(doc, pts[i], doc.sigil.visible);
      if (prims[i] == null) {
        expect(p, isNull, reason: 'punto $i');
      } else {
        expect(diffNumeric(p!.key, prims[i] as String), isNull, reason: 'punto $i');
      }
    }
  });

  test('giro con iman: se pega a multiplos de 15 grados si esta a 4 o menos', () {
    for (final a in (probes['angles'] as List).cast<List>()) {
      expect(snapAngle(_d(a[0])), closeTo(_d(a[1]), 1e-9), reason: '${a[0]} grados');
    }
    expect(snapAngle(43), 45);
    expect(snapAngle(37), 37);
    expect(snapAngle(43, magnet: false), 43);
  });

  // gestos grabados: se reproducen en orden sobre el mismo documento
  final doc = freshDoc();
  final ctl = CanvasController(doc);
  // las capas nuevas tienen otro id en cada lado: id de JS -> id de Dart
  final idMap = {for (final l in doc.layers) l.id: l.id};
  for (final g in (data['gestures'] as List).cast<Map<String, dynamic>>()) {
    test('gesto: ${g['name']}', () {
      final before = g['before'] as Map<String, dynamic>;
      ctl
        ..sel = null
        ..layerSel = null
        ..termPick = before['termPick'] as bool
        ..hideMode = before['hideMode'] as bool
        ..stampMode = before['stampMode'] as bool
        ..termBrush = before['termBrush'] as String
        ..stampSym = before['stampSym'] as String;
      final idsBefore = doc.layers.map((l) => l.id).toSet();
      for (final e in (g['events'] as List).cast<List>()) {
        final pt = Pt(_d(e[1]), _d(e[2]));
        final alt = e[3] as bool;
        switch (e[0]) {
          case 'pointerdown':
            ctl.pointerDown(pt, pxScale: pxScale, alt: alt);
          case 'pointermove':
            ctl.pointerMove(pt, pxScale: pxScale, alt: alt);
          case 'pointerup':
            ctl.pointerUp();
        }
      }
      final a = g['after'] as Map<String, dynamic>;
      expect(ctl.sel, a['sel'], reason: 'letra elegida');
      final jsLayers = (a['layers'] as List).cast<Map<String, dynamic>>();
      final newDart = doc.layers.where((l) => !idsBefore.contains(l.id)).map((l) => l.id).toList();
      final newJs = jsLayers.map((l) => l['id'] as String).where((id) => !idMap.containsKey(id)).toList();
      expect(newDart.length, newJs.length, reason: 'capas creadas por el gesto');
      for (var i = 0; i < newJs.length; i++) {
        idMap[newJs[i]] = newDart[i];
      }
      expect(ctl.layerSel, a['layerSel'] == null ? null : idMap[a['layerSel']], reason: 'capa elegida');
      expect(doc.layers.length, jsLayers.length, reason: 'numero de capas');
      for (var i = 0; i < jsLayers.length; i++) {
        final l = doc.layers[i], j = jsLayers[i];
        expect(l.type.name, j['type']);
        // solo los simbolos tienen x, y; los marcos se desplazan con dx, dy
        final keys = l.type == LayerType.symbol ? ['x', 'y', 'dx', 'dy'] : ['dx', 'dy'];
        final got = {'x': l.x, 'y': l.y, 'dx': l.dx, 'dy': l.dy};
        expect([for (final k in keys) got[k]], [for (final k in keys) closeTo(_d(j[k]), 1e-6)], reason: 'posicion de ${l.type.name}');
        if (l.type == LayerType.symbol) expect(l.sym, j['sym']);
      }
      (a['users'] as Map<String, dynamic>).forEach((ch, u) {
        final l = doc.sigil.letters.firstWhere((x) => x.ch == ch).user, m = u as Map<String, dynamic>;
        expect(l.dx, closeTo(_d(m['dx']), 1e-9), reason: 'dx de $ch');
        expect(l.dy, closeTo(_d(m['dy']), 1e-9), reason: 'dy de $ch');
      });
      final hidden = (a['hidden'] as List).cast<String>();
      expect(doc.sigil.hidden.length, hidden.length, reason: 'trazos ocultos');
      for (var i = 0; i < hidden.length; i++) {
        expect(diffNumeric(doc.sigil.hidden[i], hidden[i]), isNull);
      }
      final ends = (a['endStyles'] as Map<String, dynamic>);
      expect(doc.endStyles.length, ends.length, reason: 'remates por punta');
      ends.forEach((k, v) => expect(doc.endStyles.entries.any((e) => diffNumeric(e.key, k) == null && e.value == v), isTrue, reason: 'remate $v en $k'));
      expect(doc.sigil.view!.k, closeTo(_d((a['view'] as Map)['k']), 1e-9), reason: 'encuadre');
      expect(diffSvg(doc.buildSVG(), a['svg'] as String), isNull, reason: 'el SVG tras el gesto');
    });
  }
}
