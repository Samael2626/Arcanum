// Guardar y reabrir un sigilo: el documento pasa por JSON (lo que se cifra en
// el Grimorio) y al abrirlo el motor lo regenera con el mismo SVG.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'svg_parity_test.dart' show docFor;

SigilDoc roundTrip(SigilDoc d) => SigilDoc.fromJson(
  jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
);

void main() {
  final cases =
      ((jsonDecode(
                    File(
                      'test/features/sigilos/fixtures/capas.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['svgs']
              as List)
          .cast<Map<String, dynamic>>();

  test('los 52 sigilos de referencia vuelven identicos tras guardarse', () {
    for (var i = 0; i < cases.length; i++) {
      final d = docFor(cases[i]);
      expect(roundTrip(d).buildSVG(), d.buildSVG(), reason: 'caso $i');
    }
  });

  test(
    'vuelven tambien las ediciones de letra, los trazos ocultos y los remates por punta',
    () {
      final d = SigilDoc(terminals: 'ring', style: presetStyle('lacre'))
        ..generate('AMOR DIOS LUZ');
      final l = d.sigil.active.first;
      l.user
        ..dx = .21
        ..drot = 30
        ..fx = true;
      d.sigil.hidden = [d.sigil.prims[1].key];
      d.rebuild();
      final end = freeEnds(d.sigil.visible).first;
      d.endStyles[end.key] = 'pattee';
      final back = roundTrip(d);
      expect(back.buildSVG(), d.buildSVG());
      expect(back.sigil.hidden, d.sigil.hidden);
      expect(back.endStyles, d.endStyles);
      expect(back.sigil.letters.first.user.drot, 30);
    },
  );

  test('un sigilo sin intencion se guarda y se abre vacio', () {
    final back = roundTrip(SigilDoc());
    expect(back.sigil.prims, isEmpty);
  });

  test('una version mas nueva que la app se rechaza con un mensaje claro', () {
    final j = SigilDoc().toJson()..['v'] = SigilDoc.kVersion + 1;
    expect(() => SigilDoc.fromJson(j), throwsFormatException);
  });

  test('el documento guardado pesa poco (se cifra entero)', () {
    final d = docFor(
      cases.firstWhere((c) => (c['layers'] as List).length == 4),
    );
    final n = utf8.encode(jsonEncode(d.toJson())).length;
    expect(n, lessThan(8000), reason: '$n bytes');
  });
}
