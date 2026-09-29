// Paridad del SVG completo (escena + estilo) con el prototipo: soporte,
// texturas, capas, trazo, remates y efectos. Casos: _fixtures.mjs -> capas.json
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/features/sigilos/engine/layers.dart';
import 'package:arcanum_app/features/sigilos/engine/letter_sigil.dart';
import 'package:arcanum_app/features/sigilos/engine/reduction.dart';
import 'package:arcanum_app/features/sigilos/engine/sigil_doc.dart';
import 'package:arcanum_app/features/sigilos/engine/style.dart';
import 'package:arcanum_app/features/sigilos/engine/terminals.dart';
import 'package:flutter_test/flutter_test.dart';

final _num = RegExp(r'-?\d+(?:\.\d+)?');

String? diffNumeric(String a, String b, {double tol = 0.011}) {
  if (a.split(_num).join('#') != b.split(_num).join('#')) return 'texto distinto';
  final sa = _num.allMatches(a).map((m) => m[0]!).toList(), sb = _num.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] == sb[i]) continue;
    final x = double.parse(sa[i]), y = double.parse(sb[i]);
    // mismo valor escrito distinto (7 frente a 7.00) es un fallo de formato
    if (x == y) return 'formato ${sa[i]} frente a ${sb[i]}';
    // la tolerancia es solo para el ultimo decimal de seno y coseno
    if ((x - y).abs() > tol) return 'numero ${sa[i]} frente a ${sb[i]}';
  }
  return null;
}

/// Compara dos SVG etiqueta a etiqueta; devuelve la primera diferencia.
String? diffSvg(String dart, String js) {
  final a = dart.split('><'), b = js.split('><');
  for (var i = 0; i < a.length && i < b.length; i++) {
    final d = diffNumeric(a[i], b[i]);
    if (d != null) return 'etiqueta $i: $d\n  dart: ${a[i]}\n  js:   ${b[i]}';
  }
  if (a.length != b.length) return 'numero de etiquetas: dart ${a.length}, js ${b.length}';
  return null;
}

SigilDoc docFor(Map<String, dynamic> c) {
  final doc = SigilDoc(
    layers: [for (final l in c['layers'] as List) Layer.fromJson(l as Map<String, dynamic>)],
    style: SigilStyle.fromJson(c['style'] as Map<String, dynamic>),
    terminals: c['terminals'] as String,
    transparent: c['transparent'] as bool,
  );
  doc.sigil
    ..method = ReductionMethod.values.byName(c['method'] as String)
    ..mode = ComposeMode.values.byName(c['mode'] as String);
  doc.generate(c['text'] as String);
  // la clave de la punta viene del JS: se busca la misma punta en Dart
  final ends = freeEnds(doc.sigil.visible);
  (c['endStyles'] as Map<String, dynamic>).forEach((jsKey, style) {
    final e = ends.firstWhere((e) => diffNumeric(e.key, jsKey) == null);
    doc.endStyles[e.key] = style as String;
  });
  return doc;
}

void main() {
  final cases = ((jsonDecode(File('test/features/sigilos/fixtures/capas.json').readAsStringSync()) as Map<String, dynamic>)['svgs'] as List)
      .cast<Map<String, dynamic>>();

  test('hay SVG de referencia de todos los estilos', () {
    final presets = cases.map((c) => (c['style'] as Map)['preset']).toSet();
    expect(presets, containsAll(['pergamino', 'papel', 'lacre', 'oro', 'burdeos', 'plata', 'metal', 'flash-venus', 'flash-saturn', 'propio']));
    expect(cases.any((c) => c['transparent'] == true), isTrue);
    expect(cases.any((c) => (c['endStyles'] as Map).isNotEmpty), isTrue);
  });

  for (final c in cases) {
    final st = c['style'] as Map<String, dynamic>;
    final name = '${c['text']} · ${c['mode']} · ${(c['layers'] as List).length} capas · ${st['preset']}'
        '${st['line'] == 'double' ? ' doble' : ''}${st['relief'] == true ? ' relieve' : ''}${st['glow'] == true ? ' resplandor' : ''}'
        ' · remate ${c['terminals']}${(c['endStyles'] as Map).isNotEmpty ? ' + uno' : ''}${c['transparent'] == true ? ' · transparente' : ''}';
    test(name, () {
      final svg = docFor(c).buildSVG();
      expect(diffSvg(svg, c['svg'] as String), isNull);
    });
  }

  test('los relampagueantes siguen Flying Roll XIV (campo del planeta, signo complementario)', () {
    const pairs = {
      'mars': ('#de2a1f', '#1d9a58'), 'venus': ('#1d9a58', '#de2a1f'), 'sun': ('#f28a1c', '#2f63d6'), 'moon': ('#2f63d6', '#f28a1c'),
      'mercury': ('#f2cf1d', '#7b31b3'), 'jupiter': ('#7b31b3', '#f2cf1d'), 'saturn': ('#3c2b8f', '#f0aa1a'),
    };
    pairs.forEach((p, v) {
      final s = presetStyle('flash-$p');
      expect((s.bg, s.ink), v, reason: p);
    });
  });

  test('el metal de cada planeta es el de la Goetia (p. 48)', () {
    expect(metalStyle('mars').metal, 'hierro');
    expect(metalStyle('sun').metal, 'oro');
    expect(metalStyle('moon').metal, 'plata');
    expect(metalStyle('saturn').metal, 'plomo');
  });

  test('regente del dia: domingo Sol, lunes Luna', () {
    expect(dayRuler(DateTime(2026, 9, 27)), 'sun');
    expect(dayRuler(DateTime(2026, 9, 28)), 'moon');
    expect(dayRuler(DateTime(2026, 10, 3)), 'saturn');
  });

  test('fondo transparente: el SVG no lleva soporte', () {
    final doc = SigilDoc(transparent: true)..generate('Luz');
    expect(doc.buildSVG().contains('data-layer="bg'), isFalse);
    doc.transparent = false;
    expect(doc.buildSVG().contains('data-layer="bg"'), isTrue);
  });
}
