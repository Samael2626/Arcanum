// Laminas de Materia Arcana: resuelve slug -> las dos caras de la pieza.
//
// Fuente de verdad: assets/materia/manifest.json, que escribe
// `tools/build_materia_laminas.py --laminas`. Cubre las 39 piezas con
// procedencia comprobada contra Commons (27 hierbas y 12 signos); el resto del
// catalogo sigue con el grabado vectorial y no tiene entrada aqui.
//
// Convive con EngravingManifest, que resuelve los SVG vectoriales: este manda
// cuando la pieza tiene lamina historica, y aquel es el respaldo.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'engraving_manifest_loader.dart' show normalizeMateriaSlug;

/// Las dos caras de una pieza, con su procedencia.
class MateriaPlate {
  const MateriaPlate({
    required this.slug,
    required this.nombre,
    required this.tipo,
    required this.entonado,
    required this.grabado,
    required this.obra,
    required this.source,
    required this.license,
    required this.px,
    this.autor,
  });

  final String slug;
  final String nombre;
  final String tipo;

  /// Cara cerrada: la lamina virada a la tinta de ARCANUM.
  final String entonado;

  /// Cara abierta: el grabado tal y como se imprimio.
  final String grabado;

  final String obra;
  final String source;
  final String license;

  /// Ancho y alto de la lamina empaquetada. No es decoracion: la tarjeta
  /// necesita saber si la plancha es vertical o apaisada ANTES de decidir
  /// cuanto sitio darle, y el manifest es el unico que lo sabe sin abrir la
  /// imagen.
  final List<int> px;

  final String? autor;

  /// Alto partido por ancho. Una botanica ronda 1,7; un mapa celeste de Bayer,
  /// 0,77.
  double get relacion => px.length == 2 && px.first > 0
      ? px.last / px.first
      : 1;

  String get entonadoPath => 'assets/$entonado';
  String get grabadoPath => 'assets/$grabado';

  /// El credito al pie de la lamina. La licencia es de dominio publico, asi
  /// que esto no es una obligacion legal: es lo que separa una app de
  /// ocultismo serio de un tablero de recortes.
  String get credito => [
    if (autor != null && autor!.isNotEmpty) autor,
    obra,
  ].join(', ');

  factory MateriaPlate.fromJson(String slug, Map<String, dynamic> j) =>
      MateriaPlate(
        slug: slug,
        nombre: (j['nombre'] ?? '') as String,
        tipo: (j['tipo'] ?? '') as String,
        entonado: j['entonado'] as String,
        grabado: j['grabado'] as String,
        obra: (j['obra'] ?? '') as String,
        source: (j['source'] ?? '') as String,
        license: (j['license'] ?? 'public-domain') as String,
        px: ((j['px'] as List?) ?? const [1, 1]).cast<int>(),
        autor: j['autor'] as String?,
      );
}

class MateriaPlates {
  MateriaPlates._();
  static final MateriaPlates instance = MateriaPlates._();

  static const String manifestAsset = 'assets/materia/manifest.json';

  Map<String, MateriaPlate> _entries = const {};
  Future<void>? _loadFuture;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final raw = await rootBundle.loadString(manifestAsset);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _entries = decoded.map(
      (slug, v) => MapEntry(
        normalizeMateriaSlug(slug),
        MateriaPlate.fromJson(slug, v as Map<String, dynamic>),
      ),
    );
    _loaded = true;
  }

  /// La lamina del slug, o null si la pieza no tiene una comprobada.
  ///
  /// Los slugs del catalogo llevan tilde en algunos registros (`beleño`) y en
  /// los signos vienen prefijados (`signo-aries`), mientras el manifest usa el
  /// nombre del asset. Las dos formas resuelven a la misma lamina.
  MateriaPlate? resolve(String slug) {
    final clave = normalizeMateriaSlug(slug);
    return _entries[clave] ?? _entries[_sinPrefijoDeSigno(clave)];
  }

  static String _sinPrefijoDeSigno(String slug) =>
      slug.startsWith('signo-') ? slug.substring(6) : slug;

  Iterable<MateriaPlate> get all => _entries.values;
}
