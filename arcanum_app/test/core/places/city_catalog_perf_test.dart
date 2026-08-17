import 'dart:io';
import 'dart:typed_data';

import 'package:arcanum_app/core/places/city_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presupuesto por busqueda. A 60 fps un fotograma dura 16,6 ms: si teclear una
/// letra cuesta mas que eso, la lista se arrastra mientras se escribe.
const Duration frameBudget = Duration(milliseconds: 16);

/// Presupuesto de la carga inicial. Ocurre una sola vez, pero sigue siendo el
/// hilo de UI el que indexa.
const Duration loadBudget = Duration(milliseconds: 400);

/// Consultas del peor caso real: prefijos cortisimos y muy repetidos, que son
/// justamente los que casan con miles de filas.
const List<String> queries = [
  'sa',
  'san',
  'sant',
  'ma',
  'mad',
  'madrid',
  'bo',
  'bog',
  'bogota',
  'co',
  'cor',
  'cordoba',
  'ne',
  'new',
  'york',
  'ville',
  'a',
  'zzzz',
  'ñoño',
  'MÉXICO',
];

void main() {
  test('carga e indexado del catalogo real dentro de presupuesto', () {
    final file = File('assets/data/cities.txt');
    if (!file.existsSync()) {
      fail('Falta ${file.path}. Generalo con: python tools/build_city_catalog.py');
    }

    final indexFile = File('assets/data/cities.bin');
    if (!indexFile.existsSync()) {
      fail('Falta ${indexFile.path}. Generalo con: python tools/build_city_catalog.py');
    }

    final readWatch = Stopwatch()..start();
    final source = file.readAsStringSync();
    final indexBytes = ByteData.sublistView(indexFile.readAsBytesSync());
    readWatch.stop();

    final parseWatch = Stopwatch()..start();
    final catalog = CityCatalog.parse(source, indexBytes);
    parseWatch.stop();

    // Primera busqueda: incluye construir la cache de paises.
    final firstWatch = Stopwatch()..start();
    catalog.searchSync('madrid');
    firstWatch.stop();

    // ignore: avoid_print
    print('[perf] leer asset ${source.length ~/ 1024} KB: '
        '${readWatch.elapsedMilliseconds} ms | indexar: '
        '${parseWatch.elapsedMilliseconds} ms | primera busqueda: '
        '${firstWatch.elapsedMicroseconds} us');

    expect(catalog.cityCount, greaterThan(69000));
    expect(parseWatch.elapsed, lessThan(loadBudget),
        reason: 'indexar el catalogo tarda demasiado');

    var worst = Duration.zero;
    var worstQuery = '';
    for (final query in queries) {
      // Tres pasadas: la primera paga el calentamiento del JIT.
      for (var i = 0; i < 3; i++) {
        catalog.searchSync(query);
      }
      final watch = Stopwatch()..start();
      catalog.searchSync(query);
      watch.stop();
      if (watch.elapsed > worst) {
        worst = watch.elapsed;
        worstQuery = query;
      }
      // ignore: avoid_print
      print('[perf] "$query": ${watch.elapsedMicroseconds} us');
      expect(watch.elapsed, lessThan(frameBudget),
          reason: 'la busqueda "$query" no cabe en un fotograma');
    }

    // Con filtro de pais, que descarta filas pero recorre lo mismo.
    final filteredWatch = Stopwatch()..start();
    catalog.searchSync('san', countryCode: 'ES');
    filteredWatch.stop();
    // ignore: avoid_print
    print('[perf] "san" (solo ES): ${filteredWatch.elapsedMicroseconds} us');
    expect(filteredWatch.elapsed, lessThan(frameBudget));

    // ignore: avoid_print
    print('[perf] peor consulta: "$worstQuery" ${worst.inMicroseconds} us');
  });
}
