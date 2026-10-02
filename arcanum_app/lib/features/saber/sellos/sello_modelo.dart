import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute;

/// Una colección del catálogo (Agrippa 1651, Goetia 1916) con su procedencia.
/// Es obra ajena reproducida: la licencia y el escaneo viajan con cada pieza.
class SelloFuente {
  const SelloFuente({
    required this.id,
    required this.name,
    required this.short,
    required this.work,
    required this.edition,
    required this.scan,
    required this.license,
  });

  final String id, name, short, work, edition, scan, license;

  factory SelloFuente.fromJson(String id, Map<String, dynamic> j) =>
      SelloFuente(
        id: id,
        name: j['name'] as String,
        short: j['short'] as String,
        work: j['work'] as String,
        edition: j['edition'] as String,
        scan: j['scan'] as String,
        license: j['license'] as String,
      );
}

/// Un trazo del calco: camino SVG con su desplazamiento dentro de la caja.
typedef SelloTrazo = (String d, double tx, double ty);

class SelloPieza {
  const SelloPieza({
    required this.id,
    required this.source,
    required this.title,
    required this.page,
    required this.leaf,
    required this.scanUrl,
    required this.w,
    required this.h,
    required this.paths,
    this.name,
    this.planet,
    this.planetName,
    this.kind,
    this.role,
    this.note,
    this.ranks = const [],
    this.metals = const [],
    this.alt = const [],
    this.spirit,
    this.fig,
    this.second = false,
  });

  final String id, source, title, scanUrl;
  final String? name, planet, planetName, kind, role, note;
  final List<String> ranks, metals, alt;
  final int? spirit, fig;
  final bool second;
  final int page, leaf;
  final double w, h;
  final List<SelloTrazo> paths;

  bool get esGoetia => source == 'goetia1916';

  factory SelloPieza.fromJson(Map<String, dynamic> j) {
    List<String> lista(String k) => [
      for (final x in (j[k] as List? ?? const [])) x as String,
    ];
    return SelloPieza(
      id: j['id'] as String,
      source: j['source'] as String,
      title: j['title'] as String,
      page: (j['page'] as num).toInt(),
      leaf: (j['leaf'] as num).toInt(),
      scanUrl: j['scanUrl'] as String,
      w: (j['w'] as num).toDouble(),
      h: (j['h'] as num).toDouble(),
      name: j['name'] as String?,
      planet: j['planet'] as String?,
      planetName: j['planetName'] as String?,
      kind: j['kind'] as String?,
      role: j['role'] as String?,
      note: (j['note'] as String?)?.trim().isEmpty ?? true
          ? null
          : j['note'] as String,
      ranks: lista('ranks'),
      metals: lista('metals'),
      alt: lista('alt'),
      spirit: (j['spirit'] as num?)?.toInt(),
      fig: (j['fig'] as num?)?.toInt(),
      second: j['second'] as bool? ?? false,
      paths: [
        for (final p in j['paths'] as List)
          (
            (p as List)[0] as String,
            (p[1] as num).toDouble(),
            (p[2] as num).toDouble(),
          ),
      ],
    );
  }
}

class CatalogoSellos {
  const CatalogoSellos({
    required this.sources,
    required this.goetiaRanks,
    required this.items,
  });

  final Map<String, SelloFuente> sources;
  final List<String> goetiaRanks;
  final List<SelloPieza> items;

  static const assetPath = 'assets/sellos/catalogo-sellos.json';

  SelloFuente fuenteDe(SelloPieza p) => sources[p.source]!;

  Iterable<SelloPieza> de(String source) =>
      items.where((p) => p.source == source);

  /// La otra figura de un espíritu con dos sellos, si la tiene.
  SelloPieza? pareja(SelloPieza p) {
    if (!p.esGoetia) return null;
    for (final o in items) {
      if (o.id != p.id && o.source == p.source && o.spirit == p.spirit) {
        return o;
      }
    }
    return null;
  }

  factory CatalogoSellos.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return CatalogoSellos(
      sources: {
        for (final e in (j['sources'] as Map<String, dynamic>).entries)
          e.key: SelloFuente.fromJson(e.key, e.value as Map<String, dynamic>),
      },
      goetiaRanks: [for (final r in j['goetiaRanks'] as List) r as String],
      items: [
        for (final p in j['items'] as List)
          SelloPieza.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  /// Carga el asset y lo parsea fuera del hilo de la interfaz: son ~2,9 MB.
  static Future<CatalogoSellos> cargar() async {
    final raw = await rootBundle.loadString(assetPath);
    return compute(CatalogoSellos.parse, raw);
  }
}
