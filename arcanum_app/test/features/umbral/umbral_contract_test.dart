import 'package:arcanum_app/features/umbral/domain/umbral_reading.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _contract({
  String precision = 'full',
  Map<String, dynamic>? window,
  Map<String, dynamic>? reading,
  List<Object>? factors,
  String? degraded,
}) => {
  'contract_version': 'horoscope_daily/1',
  'selector_version': 'umbral-selector-1.0.0',
  'editorial_version': 'umbral-editorial-1.0.0',
  'ephemeris': 'swisseph/moshier',
  'computed_at': '2026-08-15T17:00:00+00:00',
  'precision': precision,
  'window': window,
  'factors': factors ?? const <Object>[],
  'reading': reading,
  'degraded_reason': degraded,
};

const _window = {
  'timezone': 'America/Bogota',
  'local_date': '2026-08-15',
  'starts_at': '2026-08-15T05:00:00+00:00',
  'ends_at': '2026-08-16T05:00:00+00:00',
  'reference_at': '2026-08-15T17:00:00+00:00',
};

Map<String, dynamic> _reading({
  bool personalized = true,
  bool tension = false,
}) => {
  'headline': 'Cuadratura de Saturno al Sol natal, con 0.4° de orbe.',
  'headlines': ['Cuadratura de Saturno al Sol natal, con 0.4° de orbe.'],
  'observed_sky': ['Saturno en 12.0° de Piscis.'],
  'symbolic_reading': ['La tradición lee la cuadratura como una fricción.'],
  'practice': 'Anota un límite que hoy notaste.',
  'why_today': ['La elección es determinista.'],
  'sources': [
    {'id': 'swisseph', 'layer': 'astronomía', 'text': 'Swiss Ephemeris.'},
  ],
  'limits': ['La astronomía es comprobable; la lectura simbólica no.'],
  'tension': tension,
  'tension_note': tension ? 'No apuntan al mismo sitio.' : null,
  'is_personalized': personalized,
};

void main() {
  test('el contrato se lee entero y conserva su trazabilidad', () {
    final reading = UmbralReading.fromJson(
      _contract(window: _window, reading: _reading(), factors: [1]),
    );

    expect(reading.contractVersion, 'horoscope_daily/1');
    expect(reading.selectorVersion, 'umbral-selector-1.0.0');
    expect(reading.editorialVersion, 'umbral-editorial-1.0.0');
    expect(reading.ephemeris, 'swisseph/moshier');
    expect(reading.precision, UmbralPrecision.full);
    expect(reading.situation, '2026-08-15 · America/Bogota');
    expect(reading.hasReading, isTrue);
    expect(reading.stale, isFalse);
  });

  test('nunca se muestran mas de dos factores', () {
    for (final count in [1, 2]) {
      final reading = UmbralReading.fromJson(
        _contract(
          window: _window,
          reading: _reading(),
          factors: List<Object>.filled(count, 1),
        ),
      );
      expect(reading.factorCount, count);
      expect(reading.headlines.length, lessThanOrEqualTo(2));
    }
  });

  test('sin ventana no se afirma ninguna fecha local', () {
    final reading = UmbralReading.fromJson(
      _contract(
        precision: 'unavailable',
        degraded: 'Sin zona horaria confirmada.',
      ),
    );

    expect(reading.precision, UmbralPrecision.unavailable);
    expect(reading.localDate, isNull);
    expect(reading.timezone, isNull);
    expect(reading.hasReading, isFalse);
    expect(reading.situation, 'Sin fecha local situada');
    expect(reading.degradedReason, isNotNull);
  });

  test('una precision desconocida degrada, nunca asciende', () {
    final reading = UmbralReading.fromJson(_contract(precision: 'inventada'));
    expect(reading.precision, UmbralPrecision.unavailable);
  });

  test('sin carta la lectura se declara no personalizada', () {
    final reading = UmbralReading.fromJson(
      _contract(
        precision: 'general',
        window: _window,
        reading: _reading(personalized: false),
        degraded: 'Todavía no hay carta natal calculada.',
      ),
    );

    expect(reading.precision, UmbralPrecision.general);
    expect(reading.isPersonalized, isFalse);
    expect(reading.degradedReason, contains('carta natal'));
  });

  test('la tension llega con su nota y no fusionada', () {
    final reading = UmbralReading.fromJson(
      _contract(window: _window, reading: _reading(tension: true)),
    );
    expect(reading.tension, isTrue);
    expect(reading.tensionNote, isNotNull);
  });

  test('una lectura marcada como cacheada lo dice', () {
    final reading = UmbralReading.fromJson(
      _contract(window: _window, reading: _reading()),
      stale: true,
    );
    expect(reading.stale, isTrue);
    // Conserva la fecha y la zona con las que se calculo: no se re-sitúa.
    expect(reading.localDate, '2026-08-15');
    expect(reading.timezone, 'America/Bogota');
  });

  test('la etiqueta de cada precision dice que se puede afirmar', () {
    expect(UmbralPrecision.full.label, 'Con tu carta completa');
    expect(UmbralPrecision.noTime.label, 'Sin hora de nacimiento');
    expect(UmbralPrecision.general.label, 'Cielo común del día');
    expect(UmbralPrecision.unavailable.label, 'Sin situar');
  });
}
