// Vuelca el catalogo editorial a JSON para que el arnes de calibracion en
// Python mida contra la fuente de verdad y no contra una copia a mano.
//
// Vive en tool/ y no en test/ a proposito: `flutter test` sin argumentos solo
// barre test/, asi que esto nunca corre solo ni escribe archivos de sorpresa.
// Se ejecuta a mano con el entorno de Flutter, que hace falta porque el
// catalogo importa package:flutter/foundation.dart.
//
// Uso:
//   cd arcanum_app
//   flutter test tool/dump_name_catalog.dart

import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/features/name_threshold/data/name_catalog.dart';
import 'package:arcanum_app/features/name_threshold/data/name_sources.dart';
import 'package:flutter_test/flutter_test.dart';

const _outputPath = '../tools/names/gold.json';

void main() {
  test('volcar catalogo de nombres a JSON', () {
    final entries = NameCatalog.entries
        .map(
          (entry) => <String, Object?>{
            'id': entry.id,
            'display_name': entry.displayName,
            'variants': entry.variants,
            'tradition': entry.tradition.name,
            'allows_historical_gematria':
                entry.tradition.allowsHistoricalGematria,
            'form_evidence': entry.formEvidence.name,
            'meaning_evidence': entry.meaningEvidence.name,
            'meaning': entry.meaning,
            'etymology': entry.etymology,
            'documented_form': entry.archiveForm,
            'has_historical_hebrew': entry.hasHistoricalHebrew,
            'source_id': entry.source.id,
            'citation': entry.citation,
          },
        )
        .toList(growable: false);

    final payload = <String, Object?>{
      'schema': 'arcanum-name-gold-1.0.0',
      'count': entries.length,
      'traditions': {
        for (final tradition in NameTradition.values)
          tradition.name: NameCatalog.byTradition(tradition).length,
      },
      'entries': entries,
    };

    final file = File(_outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );

    expect(entries, isNotEmpty);
    stdout.writeln('Escritas ${entries.length} fichas en $_outputPath');
  });
}
