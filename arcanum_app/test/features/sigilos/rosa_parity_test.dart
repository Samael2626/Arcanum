// Paridad de la familia Rosa-Cruz con el prototipo: petalos, recorrido, marcas,
// gematria y SVG. Casos: _fixtures_rosa.mjs -> fixtures/rosa.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffSvg;

RosaDoc docFor(Map<String, dynamic> c) => RosaDoc(
      name: (c['name'] as String?) ?? '',
      method: TranslitMethod.values.byName(c['method'] as String),
      hebrew: c['hebrew'] as String,
      colors: (c['colors'] as bool?) ?? false,
      diagram: (c['diagram'] as bool?) ?? true,
      endBar: (c['endBar'] as bool?) ?? true,
      transparent: (c['transparent'] as bool?) ?? false,
      style: SigilStyle.fromJson(c['style'] as Map<String, dynamic>),
    );

void main() {
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/rosa.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  group('el Lamen', () {
    test('22 petales: 3 madres, 7 dobles, 12 simples', () {
      expect(kPetals.length, 22);
      expect(kRoseRings.map((r) => r.letters.length), [3, 7, 12]);
    });

    test('madres: Alef arriba, Shin abajo a la derecha, Mem abajo a la izquierda', () {
      final a = kPetals['א']!, s = kPetals['ש']!, m = kPetals['מ']!;
      expect(a.x, closeTo(kC, 1e-9));
      expect(a.y, lessThan(kC));
      expect(s.x, greaterThan(kC));
      expect(s.y, greaterThan(kC));
      expect(m.x, lessThan(kC));
      expect(m.y, greaterThan(kC));
    });

    test('dobles: Pe arriba a la izquierda, Kaf arriba a la derecha, Dalet abajo', () {
      final p = kPetals['פ']!, k = kPetals['כ']!, d = kPetals['ד']!;
      expect(p.x, lessThan(kC));
      expect(p.y, lessThan(kC));
      expect(k.x, greaterThan(kC));
      expect(k.y, lessThan(kC));
      expect(p.x - kC, closeTo(-(k.x - kC), 1e-9));
      expect(d.x, closeTo(kC, 1e-9));
      expect(d.y, greaterThan(kC));
    });

    test('zodiaco antihorario: He arriba, Vav a su izquierda, Qof a su derecha, Lamed abajo', () {
      expect(kPetals['ה']!.x, closeTo(kC, 1e-9));
      expect(kPetals['ה']!.y, lessThan(kC));
      expect(kPetals['ו']!.x, lessThan(kC));
      expect(kPetals['ק']!.x, greaterThan(kC));
      expect(kPetals['ל']!.x, closeTo(kC, 1e-9));
      expect(kPetals['ל']!.y, greaterThan(kC));
    });

    test('cada letra tiene color de la escala del Rey y nombre', () {
      for (final he in kPetals.keys) {
        expect(kRoseColors.containsKey(he), isTrue, reason: he);
        expect(kRoseInfo.containsKey(he), isTrue, reason: he);
      }
    });
  });

  test('gematria de nombres conocidos', () {
    expect(gematria('שדי').std, 314);
    expect(gematria('מטטרון').std, 314);
    expect(gematria('מטטרון').gadol, 964);
    expect(gematria('יהוה').std, 26);
  });

  test('una final se traza en el petalo de su letra base (Marc = מרך termina en Kaf)', () {
    final doc = RosaDoc()..setName('Marc');
    expect(doc.hebrew, 'מרך');
    expect(doc.trace.map((v) => v.he).join(), 'מרכ');
  });

  group('paridad con el prototipo (${cases.length} casos)', () {
    test('hay casos con quiebro, lazo, lazo por paso y trazo apartado', () {
      final vs = [for (final c in cases) for (final w in c['words'] as List) ...(w as List).cast<Map<String, dynamic>>()];
      expect(vs.any((v) => v['crook'] == true), isTrue);
      expect(vs.any((v) => v['noose'] == true), isTrue);
      expect(vs.any((v) => v['pass'] != null), isTrue);
      expect(vs.any((v) => v['shifted'] == true), isTrue);
    });

    for (final (i, c) in cases.indexed) {
      test('caso $i: ${c['name'] ?? c['hebrew']}${c['colors'] == true ? ' colores' : ''}${c['diagram'] == false ? ' sin diagrama' : ''}${c['endBar'] == false ? ' sin barra' : ''}', () {
        final doc = docFor(c);
        if ((c['name'] as String?) != null) {
          final again = RosaDoc()..setName(c['name'] as String, translit: doc.method);
          expect(again.hebrew, doc.hebrew, reason: 'transcripcion');
        }
        final words = doc.words, jsWords = (c['words'] as List).cast<List>();
        expect(words.length, jsWords.length);
        for (var w = 0; w < words.length; w++) {
          expect(words[w].length, jsWords[w].length);
          for (var s = 0; s < words[w].length; s++) {
            final a = words[w][s], b = jsWords[w][s] as Map<String, dynamic>;
            final at = 'palabra $w letra $s';
            expect(a.he, b['he'], reason: at);
            expect(a.ch, b['ch'], reason: at);
            expect(a.repeat, b['repeat'], reason: at);
            expect(a.shifted, b['shifted'], reason: at);
            expect(a.crook, b['crook'], reason: at);
            expect(a.noose, b['noose'], reason: at);
            expect(a.x, closeTo((b['x'] as num).toDouble(), 1e-6), reason: at);
            expect(a.y, closeTo((b['y'] as num).toDouble(), 1e-6), reason: at);
            if (b['turn'] == null) {
              expect(a.turn, isNull, reason: at);
            } else {
              expect(a.turn, closeTo((b['turn'] as num).toDouble(), 1e-6), reason: at);
            }
            final pass = b['pass'] as Map<String, dynamic>?;
            expect(a.pass?.he, pass?['he'], reason: at);
            if (pass != null) {
              expect(a.pass!.d, closeTo((pass['d'] as num).toDouble(), 1e-6), reason: at);
              expect(a.pass!.t, closeTo((pass['t'] as num).toDouble(), 1e-9), reason: at);
            }
          }
        }
        final g = gematria(doc.hebrew), jg = c['gematria'] as Map<String, dynamic>;
        expect(g.std, jg['std']);
        expect(g.gadol, jg['gadol']);
        // la lectura en palabras
        final lines = {for (final l in (c['lines'] as List)) (l as List)[0] as String: l[1] as String};
        if (words.any((w) => w.isNotEmpty)) {
          expect(doc.recorrido, lines['Recorrido']);
          expect('${doc.marks.join('; ')}.', lines['Marcas']);
        }
        expect(doc.gematriaText, lines['Gematría']);
        final full = doc.buildSVG();
        final tail = full.substring(full.indexOf('<g data-layer="rose'));
        final diff = diffSvg(tail, c['svg'] as String);
        expect(diff, isNull, reason: diff);
      });
    }
  });

  test('el lienzo dibuja los mismos trazos, anchos y opacidades que escribe el SVG', () {
    final mark = RegExp(r'<path data-mark="(\w+)" d="([^"]+)"[^>]*? stroke-width="([\d.]+)"');
    for (final c in cases) {
      final doc = docFor(c), svg = doc.buildSVG(), scene = doc.scene();
      final fromSvg = [for (final m in mark.allMatches(svg)) '${m[1]}|${m[2]}|${double.parse(m[3]!)}'];
      final fromScene = [
        for (final g in scene.fg)
          if (g.layer.startsWith('rose-') && g.items.isNotEmpty && g.w != null && !{'rose-diagram'}.contains(g.layer))
            for (final it in g.items) '${g.layer == 'rose-segment' ? 'segment' : g.layer.substring(5)}|${it.d}|${g.w}',
      ];
      expect(fromScene, fromSvg, reason: '${c['name'] ?? c['hebrew']}');
      if (doc.diagram) {
        final ops = [for (final m in RegExp(r'fill-opacity="([\d.]+)"').allMatches(svg)) double.parse(m[1]!)];
        final petals = [for (final g in scene.fg) if (g.layer == 'rose-petal' && doc.colors) g.op!];
        expect(petals, ops);
      }
    }
  });

  test('guardar y reabrir devuelve el mismo SVG', () {
    for (final c in cases.take(60)) {
      final doc = docFor(c);
      final again = RosaDoc.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>);
      expect(again.buildSVG(), doc.buildSVG());
    }
  });
}
