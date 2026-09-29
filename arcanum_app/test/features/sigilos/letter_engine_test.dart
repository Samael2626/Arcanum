// Paridad del motor de letras con el prototipo (fuente de verdad).
// Los casos los genera arcanum-sigil-prototype/_fixtures.mjs ejecutando el JS.
// Tolerancia numerica de 0,011: seno y coseno pueden diferir en el ultimo
// decimal entre V8 y la libm de Dart; el resto debe ser identico.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/features/sigilos/engine/fusion.dart';
import 'package:arcanum_app/features/sigilos/engine/geometry.dart';
import 'package:arcanum_app/features/sigilos/engine/letter_sigil.dart';
import 'package:arcanum_app/features/sigilos/engine/reduction.dart';
import 'package:arcanum_app/features/sigilos/engine/terminals.dart';
import 'package:flutter_test/flutter_test.dart';

final _num = RegExp(r'-?\d+(?:\.\d+)?');

/// Igualdad de cadenas con numeros tolerantes.
String? diffNumeric(String a, String b, {double tol = 0.011}) {
  final ta = a.split(_num), tb = b.split(_num);
  if (ta.join('#') != tb.join('#')) return 'texto distinto:\n  dart: $a\n  js:   $b';
  final sa = _num.allMatches(a).map((m) => m[0]!).toList(), sb = _num.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] == sb[i]) continue;
    final x = double.parse(sa[i]), y = double.parse(sb[i]);
    // mismo valor escrito distinto (7 frente a 7.00) es un fallo de formato
    if (x == y) return 'formato ${sa[i]} frente a ${sb[i]}:\n  dart: $a\n  js:   $b';
    // la tolerancia es solo para el ultimo decimal de seno y coseno
    if ((x - y).abs() > tol) return 'numero ${sa[i]} frente a ${sb[i]}:\n  dart: $a\n  js:   $b';
  }
  return null;
}

void main() {
  final cases = (jsonDecode(File('test/features/sigilos/fixtures/letras.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  test('hay casos de referencia', () => expect(cases.length, greaterThan(100)));

  for (final cs in cases) {
    final inp = cs['input'] as Map<String, dynamic>;
    final name = '${inp['text']} · ${inp['method']} · ${inp['mode']}'
        '${inp['absorb'] == false ? ' · sin absorber' : ''}${inp['compact'] == false ? ' · sin encaje' : ''}'
        '${(inp['overlap'] as num) > 0 ? ' · solape' : ''}${inp['edits'] != null ? ' · ediciones' : ''}'
        '${inp['hideFirst'] != null ? ' · ocultos' : ''}${inp['perEnd'] != null ? ' · remate por punta' : ''}';
    test(name, () {
      final sg = LetterSigil()
        ..method = ReductionMethod.values.byName(inp['method'] as String)
        ..mode = ComposeMode.values.byName(inp['mode'] as String)
        ..absorb = inp['absorb'] as bool
        ..compact = inp['compact'] as bool
        ..overlap = (inp['overlap'] as num).toDouble();
      final ok = sg.generate(inp['text'] as String);
      final red = cs['reduction'] as Map<String, dynamic>;
      expect(sg.reduction!.cleaned, red['cleaned']);
      expect(sg.reduction!.units, red['units']);
      expect(ok, (red['units'] as List).isNotEmpty);

      final edits = inp['edits'] as Map<String, dynamic>?;
      if (edits != null) {
        for (final l in sg.letters) {
          if (edits[l.ch] != null) l.user = LetterEdit.fromJson(edits[l.ch] as Map<String, dynamic>);
        }
        sg.rebuild();
      }
      if (inp['hideFirst'] != null) {
        sg.hidden = sg.prims.take(inp['hideFirst'] as int).map((p) => p.key).toList();
        sg.rebuild();
      }

      final letters = (cs['letters'] as List).cast<Map<String, dynamic>>();
      expect(sg.letters.map((l) => l.ch).toList(), letters.map((l) => l['ch']).toList());
      for (var i = 0; i < letters.length; i++) {
        final l = sg.letters[i], j = letters[i];
        final twin = j['twin'] as Map<String, dynamic>?;
        expect(l.twin?.by, twin?['by'], reason: 'gemela de ${l.ch}');
        expect(l.twin?.how, twin?['how'], reason: 'como se absorbe ${l.ch}');
        if (twin != null) continue;
        final base = j['base'] as Map<String, dynamic>;
        expect(l.base!.tx, closeTo((base['tx'] as num).toDouble(), 1e-9), reason: 'tx de ${l.ch}');
        expect(l.base!.ty, closeTo((base['ty'] as num).toDouble(), 1e-9), reason: 'ty de ${l.ch}');
        expect(l.base!.s, closeTo((base['s'] as num).toDouble(), 1e-9), reason: 's de ${l.ch}');
        expect(l.legible, closeTo((j['legible'] as num).toDouble(), 1e-9), reason: 'legibilidad de ${l.ch}');
        expect(l.shares, j['shares'], reason: 'con quien comparte ${l.ch}');
      }

      final prims = (cs['prims'] as List).cast<Map<String, dynamic>>();
      expect(sg.prims.length, prims.length, reason: 'numero de trazos tras la fusion');
      for (var i = 0; i < prims.length; i++) {
        final p = sg.prims[i], j = prims[i];
        expect(diffNumeric(p.key, j['key'] as String), isNull);
        expect(p.units, j['units']);
        expect(p.kind, j['kind']);
        expect(p.hidden, j['hidden']);
        expect(diffNumeric(sg.primPath(p), j['d'] as String), isNull);
      }
      final view = cs['view'] as Map<String, dynamic>;
      expect(sg.view!.k, closeTo((view['k'] as num).toDouble(), 1e-6));

      final vis = sg.visible;
      final ends = freeEnds(vis);
      expect(ends.length, (cs['ends'] as List).length, reason: 'puntas libres');
      for (var i = 0; i < ends.length; i++) {
        expect(diffNumeric(ends[i].key, (cs['ends'] as List)[i] as String), isNull);
      }
      final terms = cs['terms'] as Map<String, dynamic>;
      for (final style in terms.keys) {
        final js = (terms[style] as List).cast<Map<String, dynamic>>();
        final dart = terminalList(sg, vis, general: style);
        expect(dart.length, js.length, reason: 'remates $style');
        for (var i = 0; i < js.length; i++) {
          final shapes = (js[i]['shapes'] as List).cast<Map<String, dynamic>>();
          expect(dart[i].shapes.length, shapes.length);
          for (var k = 0; k < shapes.length; k++) {
            expect(diffNumeric(dart[i].shapes[k].d, shapes[k]['d'] as String), isNull, reason: 'remate $style');
            expect(dart[i].shapes[k].fill, shapes[k]['fill']);
          }
        }
      }
      final perEnd = (cs['endStyles'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
      if (perEnd.isNotEmpty) {
        // la clave de la punta viene del JS; se busca la misma punta en Dart
        final jsKey = perEnd.keys.single;
        final match = ends.firstWhere((e) => diffNumeric(e.key, jsKey) == null);
        final dart = terminalList(sg, vis, general: 'none', perEnd: {match.key: perEnd[jsKey]!});
        final js = (cs['perEnd'] as List).cast<Map<String, dynamic>>();
        expect(dart.length, js.length);
        expect(dart.single.style, js.single['style']);
      }
    });
  }

  test('las 26 capitales tienen firma y M/W, N/Z son gemelas', () {
    expect(findTwin('W', ['M'])?.by, 'M');
    expect(findTwin('Z', ['N'])?.by, 'N');
    expect(findTwin('B', ['M']), isNull);
  });

  test('una intencion sin letras latinas no deja sigilo', () {
    final sg = LetterSigil();
    expect(sg.generate('שלום 123'), isFalse);
    expect(sg.prims, isEmpty);
  });

  test('los trazos se funden: la I de AMOR DIOS comparte asta', () {
    final sg = LetterSigil()..method = ReductionMethod.unique;
    sg.generate('DI');
    final shared = sg.prims.where((p) => p.units.length > 1);
    expect(shared, isNotEmpty);
    expect(sg.prims.every((p) => p is LinePrim || p is ArcPrim), isTrue);
  });
}
