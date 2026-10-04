// Paridad de la familia Kamea con el prototipo: casillas, geometria y SVG.
// Casos: _fixtures_kamea.mjs -> fixtures/kamea.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show diffSvg;

void main() {
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/kamea.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  KameaDoc docFor(Map<String, dynamic> c) => KameaDoc(
        planet: c['planet'] as String,
        hebrew: c['hebrew'] as String,
        name: (c['name'] as String?) ?? '',
        reduce: KameaReduce.values.byName(c['reduce'] as String),
        ends: KameaEnds.values.byName(c['ends'] as String),
        grid: c['grid'] as bool,
        transparent: (c['transparent'] as bool?) ?? false,
        style: SigilStyle.fromJson(c['style'] as Map<String, dynamic>),
      );

  group('tablas de Agrippa', () {
    test('las 7 tablas son cuadrados magicos', () {
      for (final k in kKameas) {
        final n = k.n, line = n * (n * n + 1) ~/ 2;
        final all = k.rows.expand((r) => r).toList()..sort();
        expect(all, [for (var i = 1; i <= n * n; i++) i], reason: k.id);
        for (var i = 0; i < n; i++) {
          expect(k.rows[i].reduce((a, b) => a + b), line, reason: '${k.id} fila $i');
          expect([for (final r in k.rows) r[i]].reduce((a, b) => a + b), line, reason: '${k.id} columna $i');
        }
        expect([for (var i = 0; i < n; i++) k.rows[i][i]].reduce((a, b) => a + b), line, reason: '${k.id} diagonal');
        expect([for (var i = 0; i < n; i++) k.rows[i][n - 1 - i]].reduce((a, b) => a + b), line, reason: '${k.id} antidiagonal');
      }
    });

    test('errata de la Luna: fila 1, columna 8 es 54', () => expect(kameaById('moon').rows[0][7], 54));

    test('los nombres suman lo que imprime Agrippa (finales 500-900)', () {
      for (final k in kKameas) {
        for (final n in k.names) {
          expect(n.hebrew.split('').fold(0, (a, ch) => a + kameaValue(ch)), n.sum, reason: n.latin);
        }
      }
    });
  });

  group('paridad con el prototipo (${cases.length} casos)', () {
    test('hay casos de todas las tablas', () {
      expect({for (final c in cases) c['planet']}, {for (final k in kKameas) k.id});
    });

    for (final (i, c) in cases.indexed) {
      test('caso $i: ${c['planet']} ${c['hebrew']} ${c['reduce']} ${c['ends']}${c['grid'] as bool ? ' tabla' : ''}', () {
        final doc = docFor(c);
        final jsWords = (c['words'] as List).cast<List>();
        final words = doc.words;
        expect(words.length, jsWords.length);
        for (var w = 0; w < words.length; w++) {
          expect(words[w].length, jsWords[w].length);
          for (var s = 0; s < words[w].length; s++) {
            final a = words[w][s], b = jsWords[w][s] as Map<String, dynamic>;
            expect(a.ch, b['ch']);
            expect(a.v, b['v']);
            expect(a.cell, b['cell']);
            expect(a.reduced, b['reduced']);
            expect(a.x, closeTo((b['x'] as num).toDouble(), 1e-6));
            expect(a.y, closeTo((b['y'] as num).toDouble(), 1e-6));
          }
        }
        final fit = kameaFit(words), jsFit = (c['fit'] as List).cast<List>();
        for (var w = 0; w < fit.length; w++) {
          for (var s = 0; s < fit[w].length; s++) {
            final q = jsFit[w][s] as List;
            expect(fit[w][s].x, closeTo((q[0] as num).toDouble(), 1e-6));
            expect(fit[w][s].y, closeTo((q[1] as num).toDouble(), 1e-6));
          }
        }
        final cap = kameaCaption(doc.def, doc.hebrew, doc.name), jsCap = c['caption'] as Map<String, dynamic>?;
        expect(cap?.title, jsCap?['title']);
        expect(cap?.sub, jsCap?['sub']);
        final diff = diffSvg(doc.buildSVG(), c['svg'] as String);
        expect(diff, isNull, reason: diff);
      });
    }
  });

  test('la transliteracion de un nombre latino da el hebreo del prototipo', () {
    for (final c in cases) {
      final name = c['name'] as String?;
      if (name == null || hasHebrew(name)) continue;
      final doc = KameaDoc()..setName(name, translit: TranslitMethod.values.byName(c['translit'] as String));
      expect(doc.hebrew, c['hebrew'], reason: name);
    }
  });

  test('guardar y reabrir devuelve el mismo SVG', () {
    for (final c in cases.take(40)) {
      final doc = docFor(c);
      final again = KameaDoc.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>);
      expect(again.buildSVG(), doc.buildSVG());
    }
  });
}
