import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las tiradas tal como las sirve el backend (GET /tarot/spreads, 05-oct).
List<SpreadDef> _spreads() => [
  for (final j
      in jsonDecode(File('test/fixtures/tarot_spreads.json').readAsStringSync())
          as List)
    SpreadDef.fromJson(j as Map<String, dynamic>),
];

/// Tamaño aproximado de la etiqueta: el del pintor real ronda esto.
Size _size(SpreadDef sp, int i) {
  final text = sp.labelByName ? sp.slots[i].name : '${i + 1}';
  return Size(text.length * 11.0 + 6, 26);
}

void main() {
  for (final sp in _spreads()) {
    test('${sp.slug}: ninguna etiqueta pisa un hueco ni otra etiqueta', () {
      // GN2200, Cruz Celta: la 1 y la 2 se pisaban en el cruce y las
      // cartas de la columna tapaban el 8 y el 10
      final centers = slotLabelCenters(sp, (i) => _size(sp, i));
      final labels = [
        for (var i = 0; i < sp.cardCount; i++)
          Rect.fromCenter(
            center: centers[i],
            width: _size(sp, i).width,
            height: _size(sp, i).height,
          ),
      ];
      final slots = [for (var i = 0; i < sp.cardCount; i++) slotRect(sp, i)];
      for (var i = 0; i < labels.length; i++) {
        for (var j = 0; j < slots.length; j++) {
          expect(
            labels[i].overlaps(slots[j]),
            isFalse,
            reason: 'etiqueta ${i + 1} pisa el hueco ${j + 1}',
          );
        }
        for (var j = i + 1; j < labels.length; j++) {
          expect(
            labels[i].overlaps(labels[j]),
            isFalse,
            reason: 'etiquetas ${i + 1} y ${j + 1}',
          );
        }
        expect(
          TableGeometry.cloth.contains(labels[i].topLeft) &&
              TableGeometry.cloth.contains(labels[i].bottomRight),
          isTrue,
          reason: 'etiqueta ${i + 1} fuera del paño',
        );
      }
    });
  }

  test('el hueco girado 90 grados ocupa a lo ancho', () {
    final celtic = _spreads().firstWhere((s) => s.slug == 'celtic_cross');
    final r = slotRect(celtic, 1);
    expect(r.width, greaterThan(r.height));
  });
}
