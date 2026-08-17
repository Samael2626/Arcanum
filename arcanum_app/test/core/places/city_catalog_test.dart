import 'dart:io';
import 'dart:typed_data';

import 'package:arcanum_app/core/places/city_catalog.dart';
import 'package:arcanum_app/core/places/city_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// Se prueba contra el asset REAL (69.628 filas), no contra una maqueta: los
/// fallos de este buscador salen del volumen y de los acentos, y una maqueta de
/// diez filas no los enseña.
CityCatalog loadRealCatalog() {
  final file = File('assets/data/cities.txt');
  if (!file.existsSync()) {
    fail('Falta ${file.path}. Generalo con: python tools/build_city_catalog.py');
  }
  final index = File('assets/data/cities.bin');
  if (!index.existsSync()) {
    fail('Falta ${index.path}. Generalo con: python tools/build_city_catalog.py');
  }
  return CityCatalog.parse(
    file.readAsStringSync(),
    ByteData.sublistView(index.readAsBytesSync()),
  );
}

bool startsWithQuery(City city, String query) =>
    CityCatalog.foldForSearch(city.name).startsWith(query);

void main() {
  late CityCatalog catalog;

  setUpAll(() {
    catalog = loadRealCatalog();
  });

  test('el catalogo trae las 69.628 filas y sus paises', () {
    expect(catalog.cityCount, greaterThan(69000));
    expect(catalog.countriesSync().length, greaterThan(200));
  });

  test('la atribucion de GeoNames esta lista para pintarse', () {
    expect(CityCatalog.attribution, contains('GeoNames'));
    expect(CityCatalog.attribution, contains('CC BY 4.0'));
  });

  test('buscar sin acentos encuentra el nombre acentuado', () {
    final results = catalog.searchSync('cordoba');
    expect(results, isNotEmpty);
    expect(results.first.name, 'Córdoba');
    expect(results.every((c) => c.timezone.contains('/')), isTrue);
  });

  test('mayusculas, espacios sobrantes y acentos escritos dan lo mismo', () {
    final plain = catalog.searchSync('mexico');
    final fancy = catalog.searchSync('  MÉXICO ');
    expect(fancy.map((c) => c.label), plain.map((c) => c.label));
    expect(plain.first.countryCode, 'MX');
  });

  test('los que empiezan por la consulta van antes que los que la contienen', () {
    final results = catalog.searchSync('york', limit: 30);
    expect(results.length, greaterThan(3));
    var seenInside = false;
    for (final city in results) {
      if (startsWithQuery(city, 'york')) {
        expect(seenInside, isFalse,
            reason: '${city.label} empieza por la consulta y va detras de una '
                'coincidencia interior');
      } else {
        seenInside = true;
      }
    }
    expect(seenInside, isTrue, reason: 'la muestra deberia mezclar los dos casos');
  });

  test('a igualdad manda la poblacion: Madrid es la capital', () {
    final results = catalog.searchSync('madrid');
    expect(results.first.name, 'Madrid');
    expect(results.first.countryCode, 'ES');
    expect(results.first.region, 'Madrid');
    expect(results.first.timezone, 'Europe/Madrid');
    expect(results.first.label, 'Madrid, Madrid, España');
  });

  test('el orden dentro del bloque de prefijos es de mas a menos poblada', () {
    final results = catalog.searchSync('san', limit: 30);
    final prefixes = results.where((c) => startsWithQuery(c, 'san')).toList();
    expect(prefixes.length, greaterThan(5));
    // La primera es Santiago de Chile (~4,8 M), la mayor de todas las
    // "San.../Sant..." del catalogo.
    expect(prefixes.first.name, 'Santiago');
  });

  test('el filtro por pais acota de verdad', () {
    final spanish = catalog.searchSync('cordoba', countryCode: 'ES');
    expect(spanish, isNotEmpty);
    expect(spanish.every((c) => c.countryCode == 'ES'), isTrue);
    expect(spanish.first.name, 'Córdoba');
    expect(spanish.first.region, 'Andalucía');

    final all = catalog.searchSync('cordoba');
    expect(all.any((c) => c.countryCode != 'ES'), isTrue);

    // Minusculas y codigo inexistente.
    expect(catalog.searchSync('cordoba', countryCode: 'es').first.countryCode, 'ES');
    expect(catalog.searchSync('cordoba', countryCode: 'ZZ'), isEmpty);
  });

  test('consulta vacia o de un solo caracter no devuelve nada', () {
    expect(catalog.searchSync(''), isEmpty);
    expect(catalog.searchSync(' '), isEmpty);
    expect(catalog.searchSync('m'), isEmpty);
    expect(catalog.searchSync('  á  '), isEmpty);
    expect(catalog.searchSync('madrid', limit: 0), isEmpty);
  });

  test('una consulta rara no lanza, como mucho no encuentra nada', () {
    const rarezas = [
      '%%%%',
      '\t\n\r',
      '☿☉♄',
      'zzzzzzzzzzzzzz',
      '..',
      '--',
      "o'",
      'ñ',
      'ñoño',
    ];
    for (final rara in rarezas) {
      expect(() => catalog.searchSync(rara), returnsNormally, reason: rara);
    }
    expect(catalog.searchSync('z' * 500), isEmpty);
    // Un tabulador colado no puede cruzar de la columna de busqueda a otra.
    expect(catalog.searchSync('madrid\t1'), isEmpty);
  });

  test('el limite se respeta y nunca hay filas repetidas', () {
    final results = catalog.searchSync('san', limit: 7);
    expect(results.length, 7);
    final labels = results.map((c) => c.label).toSet();
    expect(labels.length, 7);
    // "baden" aparece dos veces dentro de "baden-baden": una sola fila.
    final baden = catalog.searchSync('baden', limit: 30);
    expect(baden.map((c) => c.label).toSet().length, baden.length);
  });

  test('los paises salen en espanol y ordenados', () async {
    final countries = await catalog.countries();
    final byCode = {for (final c in countries) c.code: c.name};
    expect(byCode['ES'], 'España');
    expect(byCode['MX'], 'México');
    expect(byCode['GB'], 'Reino Unido');
    expect(byCode['US'], 'Estados Unidos');
    expect(byCode['DE'], 'Alemania');
    expect(byCode['BR'], 'Brasil');
    expect(byCode['KR'], 'Corea del Sur');
    expect(byCode['CD'], 'República Democrática del Congo');

    final names = countries.map((c) => CityCatalog.foldForSearch(c.name)).toList();
    final sorted = [...names]..sort();
    expect(names, sorted);
  });

  test('la etiqueta se salta la region cuando no consta', () {
    final singapur = catalog.searchSync('singapore', countryCode: 'SG');
    expect(singapur, isNotEmpty);
    expect(singapur.first.region, isEmpty);
    expect(singapur.first.label, 'Singapore, Singapur');
  });

  test('la coincidencia mas poblada por subcadena no adelanta a un prefijo', () {
    final results = catalog.searchSync('york', limit: 30);
    final ny = results.indexWhere((c) => c.name == 'New York City');
    final york = results.indexWhere((c) => c.name == 'York');
    expect(york, isNonNegative);
    expect(ny, isNonNegative);
    expect(york, lessThan(ny),
        reason: 'New York City es mucho mayor, pero solo contiene la consulta');
  });

  test('las coordenadas son las de GeoNames', () {
    final bogota = catalog.searchSync('bogota', countryCode: 'CO').first;
    expect(bogota.name, 'Bogotá');
    expect(bogota.lat, closeTo(4.6097, 0.01));
    expect(bogota.lon, closeTo(-74.0817, 0.01));
    expect(bogota.timezone, 'America/Bogota');
  });

  testWidgets('los dos assets estan declarados en pubspec', (tester) async {
    // Si alguien quita `assets/data/` del pubspec, la app arranca sin catalogo
    // y solo se nota en el movil. Aqui se nota antes.
    //
    // Va dentro de `runAsync` porque `loadString` decodifica el UTF-8 en otro
    // isolate cuando el asset es grande, y el reloj falso de `testWidgets` no
    // lo despierta nunca.
    await tester.runAsync(() async {
      final bundled = await CityCatalog.load();
      expect(bundled.cityCount, catalog.cityCount);
      expect(bundled.wordCount, catalog.wordCount);
      final results = await bundled.search('bogota', countryCode: 'CO');
      expect(results.first.name, 'Bogotá');
    });
  });

  test('cumple el contrato asincrono de CityIndex', () async {
    final CityIndex index = catalog;
    final results = await index.search('paris', countryCode: 'FR', limit: 3);
    expect(results.length, 3);
    // GeoNames publica el nombre local: "Paris", no el exonimo espanol.
    expect(results.first.name, 'Paris');
    expect(await index.search(''), isEmpty);
  });
}
