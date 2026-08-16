import 'package:flutter/foundation.dart';

/// Nivel de precisión declarado por el servidor.
///
/// No es una escala de calidad: es una declaración de qué se puede afirmar.
/// Un nivel bajo no da una lectura peor, da una que no finge saber lo que no
/// sabe.
enum UmbralPrecision {
  full('Con tu carta completa'),
  noTime('Sin hora de nacimiento'),
  general('Cielo común del día'),
  unavailable('Sin situar');

  const UmbralPrecision(this.label);
  final String label;

  static UmbralPrecision parse(String? raw) => switch (raw) {
    'full' => UmbralPrecision.full,
    'no_time' => UmbralPrecision.noTime,
    'general' => UmbralPrecision.general,
    _ => UmbralPrecision.unavailable,
  };
}

@immutable
class UmbralSource {
  final String id;
  final String layer;
  final String text;

  const UmbralSource({
    required this.id,
    required this.layer,
    required this.text,
  });

  factory UmbralSource.fromJson(Map<String, dynamic> json) => UmbralSource(
    id: json['id'] as String? ?? '',
    layer: json['layer'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );
}

/// Contrato `horoscope_daily/1` tal como llega. Nada se calcula aquí: la app
/// no reinterpreta el cielo, lo muestra.
@immutable
class UmbralReading {
  final String contractVersion;
  final String selectorVersion;
  final String editorialVersion;
  final String ephemeris;
  final DateTime computedAt;
  final UmbralPrecision precision;
  final String? localDate;
  final String? timezone;
  final String? degradedReason;
  final int factorCount;
  final bool isPersonalized;
  final bool tension;
  final String? tensionNote;
  final String? headline;
  final String? practice;
  final List<String> headlines;
  final List<String> observedSky;
  final List<String> symbolicReading;
  final List<String> whyToday;
  final List<String> limits;
  final List<UmbralSource> sources;

  /// Verdadero cuando esta lectura viene del caché y no se pudo actualizar.
  /// La app NO la regenera: una lectura de ayer con fecha de ayer es honesta;
  /// una recalculada en el teléfono sería otra cosa distinta con el mismo
  /// nombre.
  final bool stale;

  const UmbralReading({
    required this.contractVersion,
    required this.selectorVersion,
    required this.editorialVersion,
    required this.ephemeris,
    required this.computedAt,
    required this.precision,
    required this.factorCount,
    required this.isPersonalized,
    required this.tension,
    required this.headlines,
    required this.observedSky,
    required this.symbolicReading,
    required this.whyToday,
    required this.limits,
    required this.sources,
    this.localDate,
    this.timezone,
    this.degradedReason,
    this.tensionNote,
    this.headline,
    this.practice,
    this.stale = false,
  });

  bool get hasReading => headline != null;

  /// Encabezado de la pantalla: fecha local y zona, o la razón de que falten.
  String get situation {
    if (localDate == null || timezone == null) return 'Sin fecha local situada';
    return '$localDate · $timezone';
  }

  static List<String> _strings(Object? raw) =>
      (raw as List?)?.map((item) => item.toString()).toList(growable: false) ??
      const <String>[];

  factory UmbralReading.fromJson(
    Map<String, dynamic> json, {
    bool stale = false,
  }) {
    final window = json['window'] as Map<String, dynamic>?;
    final reading = json['reading'] as Map<String, dynamic>?;
    final factors = json['factors'] as List? ?? const [];

    return UmbralReading(
      contractVersion: json['contract_version'] as String? ?? '',
      selectorVersion: json['selector_version'] as String? ?? '',
      editorialVersion: json['editorial_version'] as String? ?? '',
      ephemeris: json['ephemeris'] as String? ?? '',
      computedAt:
          DateTime.tryParse(json['computed_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      precision: UmbralPrecision.parse(json['precision'] as String?),
      localDate: window?['local_date'] as String?,
      timezone: window?['timezone'] as String?,
      degradedReason: json['degraded_reason'] as String?,
      factorCount: factors.length,
      isPersonalized: reading?['is_personalized'] as bool? ?? false,
      tension: reading?['tension'] as bool? ?? false,
      tensionNote: reading?['tension_note'] as String?,
      headline: reading?['headline'] as String?,
      practice: reading?['practice'] as String?,
      headlines: _strings(reading?['headlines']),
      observedSky: _strings(reading?['observed_sky']),
      symbolicReading: _strings(reading?['symbolic_reading']),
      whyToday: _strings(reading?['why_today']),
      limits: _strings(reading?['limits'] ?? json['limits']),
      sources:
          (reading?['sources'] as List?)
              ?.map(
                (item) => UmbralSource.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false) ??
          const <UmbralSource>[],
      stale: stale,
    );
  }
}
