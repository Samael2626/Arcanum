/// Implementacion real de [CityIndex] sobre el catalogo empaquetado.
///
/// Los dos assets los genera `tools/build_city_catalog.py` a partir de GeoNames.
///
/// Como esta pensado, en corto:
/// - `cities.txt` se carga como UNA cadena y no se trocea nunca: las filas se
///   localizan por una tabla de comienzos de linea (`Int32List`), y solo las
///   30 que se devuelven se convierten en objetos.
/// - Las filas vienen ordenadas por poblacion descendente desde el generador,
///   asi que el numero de fila YA es el orden de relevancia: en tiempo de
///   busqueda no se ordena nada ni hace falta guardar la poblacion.
/// - `cities.bin` es un indice binario de comienzos de palabra ordenado
///   alfabeticamente. Buscar es una busqueda binaria sobre el (dos docenas de
///   comparaciones) y recorrer el tramo que casa. Barrer el megabyte de nombres
///   en cada tecla se midio en decenas de milisegundos y no cabia en un
///   fotograma; esto se queda en microsegundos.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'city_index.dart';

/// Catalogo de ciudades cargado desde los assets.
class CityCatalog implements CityIndex {
  CityCatalog._(
    this._raw,
    this._lineStarts,
    this._wordIndex,
    this._countryLine0,
    this._countryCount,
    this._regionLine0,
    this._zoneLine0,
    this._zoneCount,
    this._searchLine0,
    this._cityCount,
    this._countryCodes,
  );

  /// Texto del catalogo dentro del bundle.
  static const String assetKey = 'assets/data/cities.txt';

  /// Indice binario de busqueda dentro del bundle.
  static const String indexAssetKey = 'assets/data/cities.bin';

  /// Atribucion EXIGIDA por la licencia CC BY 4.0 de GeoNames.
  ///
  /// La pantalla que use el catalogo tiene que pintar este texto de forma
  /// visible. Sin el, el uso de los datos no cumple la licencia.
  static const String attribution =
      'Ciudades y zonas horarias: GeoNames (geonames.org), CC BY 4.0.';

  static const String _magic = 'ARCANUM_CITIES';
  static const String _version = '1';
  static const int _indexMagic = 0x41434958; // 'ACIX'
  static const int _indexVersion = 1;

  /// Bits bajos de cada entrada del indice: la fila. Los altos, el
  /// desplazamiento de la palabra dentro del nombre.
  static const int _cityBits = 20;
  static const int _cityMask = (1 << _cityBits) - 1;

  static const int _newline = 0x0A;
  static const int _tab = 0x09;

  final String _raw;

  /// Comienzo de cada linea del texto. El ultimo elemento es el fin del texto.
  final Int32List _lineStarts;

  /// Comienzos de palabra, ordenados alfabeticamente por el texto que sigue.
  final Int32List _wordIndex;

  final int _countryLine0;
  final int _countryCount;
  final int _regionLine0;
  final int _zoneLine0;
  final int _zoneCount;

  /// Primera linea de la seccion de nombres de busqueda. La seccion de filas
  /// empieza en `_searchLine0 + _cityCount` y va alineada por indice.
  final int _searchLine0;
  final int _cityCount;

  /// Codigo ISO de cada fila, empaquetado en 16 bits ('E' << 8 | 'S'), para
  /// filtrar por pais sin tocar el texto.
  final Uint16List _countryCodes;

  List<Country>? _countryCache;
  Map<String, String>? _countryByCode;

  /// Numero de localidades del catalogo.
  int get cityCount => _cityCount;

  /// Numero de entradas del indice de palabras.
  int get wordCount => _wordIndex.length;

  /// Carga el catalogo desde el bundle de assets.
  ///
  /// `loadString` ya decodifica el UTF-8 fuera del hilo de UI cuando el asset
  /// es grande, y el indice binario se usa tal cual, sin analizar. Lo que queda
  /// en este hilo es el barrido de saltos de linea, medido en
  /// `test/core/places/city_catalog_perf_test.dart`.
  static Future<CityCatalog> load({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final text = await source.loadString(assetKey);
    final index = await source.load(indexAssetKey);
    final catalog = CityCatalog.parse(text, index);
    // Una busqueda de mentira aqui: deja hecha la tabla de paises y calienta el
    // camino de codigo, para que la primera tecla de verdad no pague ese coste.
    catalog.searchSync('aa', limit: 1);
    return catalog;
  }

  /// Indexa el contenido del catalogo. Sincrono y sin dependencias de Flutter,
  /// para poder medirlo y probarlo con el dataset real.
  factory CityCatalog.parse(String source, ByteData index) {
    final headerEnd = source.indexOf('\n');
    final header = headerEnd < 0 ? <String>[] : source.substring(0, headerEnd).split('\t');
    if (header.length < 6 || header[0] != _magic || header[1] != _version) {
      throw const FormatException('Catalogo de ciudades ilegible o de otra version');
    }
    final countryCount = int.parse(header[2]);
    final regionCount = int.parse(header[3]);
    final zoneCount = int.parse(header[4]);
    final cityCount = int.parse(header[5]);

    final totalLines = 1 + countryCount + regionCount + zoneCount + cityCount * 2;
    final lineStarts = Int32List(totalLines + 1);
    var line = 1;
    final length = source.length;
    for (var i = 0; i < length; i++) {
      if (source.codeUnitAt(i) == _newline) {
        if (line > totalLines) break;
        lineStarts[line++] = i + 1;
      }
    }
    if (line <= totalLines) {
      throw const FormatException('Catalogo de ciudades incompleto');
    }

    const countryLine0 = 1;
    final regionLine0 = countryLine0 + countryCount;
    final zoneLine0 = regionLine0 + regionCount;
    final searchLine0 = zoneLine0 + zoneCount;
    final recordLine0 = searchLine0 + cityCount;

    // Codigo de pais de cada fila: tercer campo, se llega saltando dos tabuladores.
    final codes = Uint16List(cityCount);
    for (var i = 0; i < cityCount; i++) {
      var cursor = lineStarts[recordLine0 + i];
      var tabs = 0;
      while (tabs < 2) {
        if (source.codeUnitAt(cursor++) == _tab) tabs++;
      }
      codes[i] = (source.codeUnitAt(cursor) << 8) | source.codeUnitAt(cursor + 1);
    }

    return CityCatalog._(
      source,
      lineStarts,
      _readWordIndex(index),
      countryLine0,
      countryCount,
      regionLine0,
      zoneLine0,
      zoneCount,
      searchLine0,
      cityCount,
      codes,
    );
  }

  /// El indice se usa tal cual esta en el bundle: cuando la vista cae alineada
  /// a 4 bytes no se copia ni un byte.
  static Int32List _readWordIndex(ByteData data) {
    if (data.lengthInBytes < 12 ||
        data.getInt32(0, Endian.little) != _indexMagic ||
        data.getInt32(4, Endian.little) != _indexVersion) {
      throw const FormatException('Indice de ciudades ilegible o de otra version');
    }
    final count = data.getInt32(8, Endian.little);
    if (data.lengthInBytes < 12 + count * 4) {
      throw const FormatException('Indice de ciudades incompleto');
    }
    final offset = data.offsetInBytes + 12;
    if (offset % 4 == 0 && Endian.host == Endian.little) {
      return Int32List.view(data.buffer, offset, count);
    }
    final copy = Int32List(count);
    for (var i = 0; i < count; i++) {
      copy[i] = data.getInt32(12 + i * 4, Endian.little);
    }
    return copy;
  }

  @override
  Future<List<City>> search(
    String query, {
    String? countryCode,
    int limit = 30,
  }) async =>
      searchSync(query, countryCode: countryCode, limit: limit);

  /// Version sincrona de [search]. Es la que se mide: si esto pasa de 16 ms, el
  /// buscador no sirve para escribir en directo.
  ///
  /// LIMITE CONOCIDO: "contiene" aqui significa "alguna palabra del nombre
  /// empieza por lo escrito". "york" encuentra "New York City", pero "adrid" no
  /// encuentra "Madrid". Es lo que permite responder con una busqueda binaria en
  /// vez de barrer los 69.628 nombres en cada tecla, y es la forma en la que se
  /// buscan sitios: por el principio de una palabra, no por su mitad.
  List<City> searchSync(String query, {String? countryCode, int limit = 30}) {
    if (limit <= 0) return const [];
    final needle = foldForSearch(query);
    // Una letra suelta casa con medio mundo y no ayuda a nadie.
    if (needle.length < 2) return const [];

    final filter = _packCountry(countryCode);
    if (countryCode != null && filter == 0) return const [];

    final low = _lowerBound(needle);
    final high = _upperBound(needle, low);
    if (low >= high) return const [];

    // Dos cubos: el que empieza por la consulta manda sobre el que solo la
    // contiene. Dentro de cada uno, la fila mas baja es la mas poblada.
    final starts = _Best(limit);
    final inside = _Best(limit);
    for (var i = low; i < high; i++) {
      final entry = _wordIndex[i];
      final row = entry & _cityMask;
      if (filter != 0 && _countryCodes[row] != filter) continue;
      if (entry >> _cityBits == 0) {
        starts.offer(row);
      } else {
        inside.offer(row);
      }
    }

    final picked = starts.take(limit);
    if (picked.length < limit) {
      // Una fila puede entrar por dos palabras ("san jose de san juan"): no
      // puede aparecer dos veces en la lista.
      final seen = picked.toSet();
      for (final row in inside.take(limit)) {
        if (picked.length >= limit) break;
        if (seen.add(row)) picked.add(row);
      }
    }
    return [for (final row in picked) _cityAt(row)];
  }

  @override
  Future<List<Country>> countries() async => countriesSync();

  /// Version sincrona de [countries]. Ya vienen ordenados por nombre desde el
  /// generador: volver a ordenarlos aqui seria trabajo repetido.
  List<Country> countriesSync() {
    final cached = _countryCache;
    if (cached != null) return cached;
    final list = <Country>[];
    for (var i = 0; i < _countryCount; i++) {
      final line = _lineAt(_countryLine0 + i);
      final tab = line.indexOf('\t');
      list.add(Country(code: line.substring(0, tab), name: line.substring(tab + 1)));
    }
    final result = List<Country>.unmodifiable(list);
    _countryCache = result;
    return result;
  }

  /// Primera entrada del indice cuyo texto no queda por debajo de [needle].
  int _lowerBound(String needle) {
    var low = 0;
    var high = _wordIndex.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compareEntry(_wordIndex[mid], needle) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Primera entrada, a partir de [from], que ya no empieza por [needle].
  int _upperBound(String needle, int from) {
    var low = from;
    var high = _wordIndex.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compareEntry(_wordIndex[mid], needle) <= 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Compara el texto de una entrada con [needle]: negativo si va antes, 0 si
  /// empieza por [needle], positivo si va despues. El salto de linea corta la
  /// palabra, asi que un nombre mas corto siempre va antes.
  int _compareEntry(int entry, String needle) {
    final start = _lineStarts[_searchLine0 + (entry & _cityMask)] + (entry >> _cityBits);
    for (var i = 0; i < needle.length; i++) {
      final here = _raw.codeUnitAt(start + i);
      if (here == _newline) return -1;
      final diff = here - needle.codeUnitAt(i);
      if (diff != 0) return diff;
    }
    return 0;
  }

  City _cityAt(int row) {
    final line = _lineAt(_searchLine0 + _cityCount + row);
    final f = line.split('\t');
    final regionId = int.parse(f[1]);
    final zoneId = int.parse(f[3]);
    return City(
      name: f[0],
      region: regionId == 0 ? '' : _lineAt(_regionLine0 + regionId),
      country: _countryName(f[2]),
      countryCode: f[2],
      lat: double.parse(f[4]),
      lon: double.parse(f[5]),
      timezone: zoneId < _zoneCount ? _lineAt(_zoneLine0 + zoneId) : '',
    );
  }

  String _countryName(String code) {
    final byCode = _countryByCode ??= {
      for (final country in countriesSync()) country.code: country.name,
    };
    return byCode[code] ?? code;
  }

  String _lineAt(int line) {
    final end = _lineStarts[line + 1] - 1;
    final start = _lineStarts[line];
    return end <= start ? '' : _raw.substring(start, end);
  }

  static int _packCountry(String? code) {
    if (code == null || code.length != 2) return 0;
    final upper = code.toUpperCase();
    return (upper.codeUnitAt(0) << 8) | upper.codeUnitAt(1);
  }

  /// Normaliza lo que escribe la persona igual que lo hizo el generador:
  /// minusculas, sin acentos y sin caracteres de control.
  ///
  /// La tabla replica `fold()` de `tools/build_city_catalog.py`. Dart no trae
  /// normalizacion Unicode en la libreria estandar, asi que las marcas
  /// combinantes (texto ya descompuesto) se descartan una a una.
  static String foldForSearch(String input) {
    final out = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      if (rune < 0x20 || rune == 0x7F) continue;
      if (rune < 0x80) {
        out.writeCharCode(rune);
        continue;
      }
      if (rune >= 0x300 && rune <= 0x36F) continue; // marcas combinantes
      final replacement = _folded[rune];
      if (replacement != null) out.write(replacement);
      // Lo que no se sabe transliterar se descarta: el indice es ASCII puro.
    }
    return out.toString().trim();
  }

  static const Map<int, String> _folded = {
    0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
    0xE6: 'ae', 0xE7: 'c', 0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
    0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i', 0xF0: 'd', 0xF1: 'n',
    0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o',
    0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u', 0xFD: 'y', 0xFE: 'th',
    0xFF: 'y', 0xDF: 'ss',
    0x101: 'a', 0x103: 'a', 0x105: 'a', 0x107: 'c', 0x109: 'c', 0x10B: 'c',
    0x10D: 'c', 0x10F: 'd', 0x111: 'd', 0x113: 'e', 0x115: 'e', 0x117: 'e',
    0x119: 'e', 0x11B: 'e', 0x11D: 'g', 0x11F: 'g', 0x121: 'g', 0x123: 'g',
    0x125: 'h', 0x127: 'h', 0x129: 'i', 0x12B: 'i', 0x12D: 'i', 0x12F: 'i',
    0x131: 'i', 0x135: 'j', 0x137: 'k', 0x13A: 'l', 0x13C: 'l', 0x13E: 'l',
    0x140: 'l', 0x142: 'l', 0x144: 'n', 0x146: 'n', 0x148: 'n', 0x14B: 'n',
    0x14D: 'o', 0x14F: 'o', 0x151: 'o', 0x153: 'oe', 0x155: 'r', 0x157: 'r',
    0x159: 'r', 0x15B: 's', 0x15D: 's', 0x15F: 's', 0x161: 's', 0x163: 't',
    0x165: 't', 0x167: 't', 0x169: 'u', 0x16B: 'u', 0x16D: 'u', 0x16F: 'u',
    0x171: 'u', 0x173: 'u', 0x175: 'w', 0x177: 'y', 0x17A: 'z', 0x17C: 'z',
    0x17E: 'z',
    0x2BB: "'", 0x2019: "'",
  };
}

/// Las N filas mas bajas (= mas pobladas) vistas hasta ahora, sin ordenar nada
/// al final: el tramo del indice viene en orden alfabetico, no de relevancia.
class _Best {
  _Best(this._capacity);

  final int _capacity;
  final List<int> _rows = <int>[];

  void offer(int row) {
    if (_rows.length >= _capacity && row >= _rows[_rows.length - 1]) return;
    var low = 0;
    var high = _rows.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_rows[mid] < row) {
        low = mid + 1;
      } else if (_rows[mid] == row) {
        return; // la misma fila puede entrar por dos palabras distintas
      } else {
        high = mid;
      }
    }
    _rows.insert(low, row);
    if (_rows.length > _capacity) _rows.removeLast();
  }

  List<int> take(int count) =>
      _rows.length <= count ? List<int>.of(_rows) : _rows.sublist(0, count);
}
