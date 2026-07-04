// Engraving manifest loader — resuelve slug -> asset de grabado vectorial (PD).
//
// PREPARADO, NO CABLEADO. Se conecta durante la fase de integración (tras el
// visto bueno de las hierbas). No modifica arte_screen / materia_engravings.
//
// Fuente de verdad: assets/engravings/manifest.json (generado por el pipeline
// de arcanum-artist). status: final | fallback | draft.
//
// Uso previsto (fase integración, requiere añadir flutter_svg al pubspec):
//   final loader = EngravingManifest.instance;
//   await loader.ensureLoaded();
//   final entry = loader.resolve('belladona');
//   if (entry != null && entry.isFinal) {
//     SvgPicture.asset('assets/${entry.asset}',
//       colorFilter: ColorFilter.mode(inkToken, BlendMode.srcIn));
//   } else {
//     // arquetipo de fallback (sello/marco abstracto)
//   }
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class EngravingEntry {
  final String slug;
  final String? asset; // ruta relativa a assets/, p.ej. engravings/hierbas/ruda.svg
  final String source; // URL de procedencia (prueba de licencia)
  final String work; // obra + año
  final String license; // p.ej. public-domain
  final String status; // final | fallback | draft

  const EngravingEntry({
    required this.slug,
    required this.asset,
    required this.source,
    required this.work,
    required this.license,
    required this.status,
  });

  bool get isFinal => status == 'final' && asset != null;

  /// Ruta completa para SvgPicture.asset (assets/ + ruta relativa del manifest).
  String? get assetPath => asset == null ? null : 'assets/$asset';

  factory EngravingEntry.fromJson(String slug, Map<String, dynamic> j) =>
      EngravingEntry(
        slug: slug,
        asset: j['asset'] as String?,
        source: (j['source'] ?? '') as String,
        work: (j['work'] ?? '') as String,
        license: (j['license'] ?? 'public-domain') as String,
        status: (j['status'] ?? 'draft') as String,
      );
}

class EngravingManifest {
  EngravingManifest._();
  static final EngravingManifest instance = EngravingManifest._();

  static const String manifestAsset = 'assets/engravings/manifest.json';

  Map<String, EngravingEntry> _entries = const {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(manifestAsset);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _entries = decoded.map(
      (slug, v) => MapEntry(
        slug,
        EngravingEntry.fromJson(slug, v as Map<String, dynamic>),
      ),
    );
    _loaded = true;
  }

  /// Devuelve la entrada del slug, o null si no está en el manifest.
  /// El caller decide el fallback a arquetipo cuando es null o !isFinal.
  EngravingEntry? resolve(String slug) => _entries[slug];

  Iterable<EngravingEntry> get all => _entries.values;
  Iterable<EngravingEntry> get fallbacks =>
      _entries.values.where((e) => e.status == 'fallback');
}
