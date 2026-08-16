import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/umbral/application/umbral_controller.dart';
import 'package:arcanum_app/features/umbral/data/umbral_cache.dart';
import 'package:arcanum_app/features/umbral/domain/umbral_reading.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCache implements UmbralCache {
  Map<String, dynamic>? value;

  @override
  Future<void> clear() async => value = null;
  @override
  Future<Map<String, dynamic>?> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> contract) async => value = contract;
}

/// Api de prueba: responde el contrato guardado o revienta como si no hubiera
/// red. No sale a ningun sitio.
class _FakeApi implements ArcanumApi {
  Map<String, dynamic>? contract;
  bool offline = false;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> umbral({String? tz}) async {
    calls++;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/astral/umbral'),
        reason: 'sin red',
      );
    }
    return contract!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} no se usa en este test');
}

Map<String, dynamic> _contract(String localDate) => {
  'contract_version': 'horoscope_daily/1',
  'selector_version': 'umbral-selector-1.0.0',
  'editorial_version': 'umbral-editorial-1.0.0',
  'ephemeris': 'swisseph/moshier',
  'computed_at': '${localDate}T17:00:00+00:00',
  'precision': 'full',
  'window': {
    'timezone': 'America/Bogota',
    'local_date': localDate,
    'starts_at': '${localDate}T05:00:00+00:00',
    'ends_at': '${localDate}T05:00:00+00:00',
    'reference_at': '${localDate}T17:00:00+00:00',
  },
  'factors': [1],
  'reading': {
    'headline': 'Un hecho del $localDate.',
    'headlines': ['Un hecho del $localDate.'],
    'observed_sky': ['Saturno en 12.0° de Piscis.'],
    'symbolic_reading': ['La tradición lee la cuadratura como una fricción.'],
    'practice': 'Anota un límite que hoy notaste.',
    'why_today': ['La elección es determinista.'],
    'sources': [
      {'id': 'swisseph', 'layer': 'astronomía', 'text': 'Swiss Ephemeris.'},
    ],
    'limits': ['La astronomía es comprobable.'],
    'tension': false,
    'tension_note': null,
    'is_personalized': true,
  },
  'degraded_reason': null,
};

Future<(ProviderContainer, _FakeApi, _MemoryCache)> _bootstrap() async {
  final api = _FakeApi();
  final cache = _MemoryCache();
  final container = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(api),
      umbralCacheProvider.overrideWithValue(cache),
    ],
  );
  return (container, api, cache);
}

void main() {
  test('con red, la lectura se guarda en cache y no se marca cacheada',
      () async {
    final (container, api, cache) = await _bootstrap();
    addTearDown(container.dispose);
    api.contract = _contract('2026-08-15');

    final reading = await container.read(umbralProvider.future);

    expect(reading!.stale, isFalse);
    expect(cache.value, isNotNull);
  });

  test('sin red se muestra la ultima lectura, con su fecha y marcada',
      () async {
    final (container, api, cache) = await _bootstrap();
    addTearDown(container.dispose);
    cache.value = _contract('2026-08-14');
    api.offline = true;

    final reading = await container.read(umbralProvider.future);

    expect(reading!.stale, isTrue);
    // Conserva la fecha y la zona originales: no se re-sitúa en hoy.
    expect(reading.localDate, '2026-08-14');
    expect(reading.timezone, 'America/Bogota');
    expect(reading.headline, contains('2026-08-14'));
  });

  test('sin red la app no regenera nada por su cuenta', () async {
    final (container, api, cache) = await _bootstrap();
    addTearDown(container.dispose);
    cache.value = _contract('2026-08-14');
    api.offline = true;

    final reading = await container.read(umbralProvider.future);

    // El contenido es EXACTAMENTE el guardado: ni un campo recalculado.
    final guardado = UmbralReading.fromJson(cache.value!, stale: true);
    expect(reading!.headline, guardado.headline);
    expect(reading.observedSky, guardado.observedSky);
    expect(reading.symbolicReading, guardado.symbolicReading);
    expect(reading.whyToday, guardado.whyToday);
    expect(reading.computedAt, guardado.computedAt);
  });

  test('sin red y sin cache no se inventa una lectura', () async {
    final (container, api, _) = await _bootstrap();
    addTearDown(container.dispose);
    api.offline = true;

    // Se observa el estado en vez de esperar el future: lo que importa es que
    // la pantalla reciba un error y no una lectura fabricada.
    container.listen(umbralProvider, (_, _) {}, fireImmediately: true);
    for (var i = 0; i < 10 && container.read(umbralProvider).isLoading; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    final state = container.read(umbralProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<DioException>());
    expect(state.value, isNull);
  });

  test('refrescar vuelve a pedir y sustituye la cacheada', () async {
    final (container, api, cache) = await _bootstrap();
    addTearDown(container.dispose);
    cache.value = _contract('2026-08-14');
    api.offline = true;
    expect((await container.read(umbralProvider.future))!.stale, isTrue);

    api.offline = false;
    api.contract = _contract('2026-08-15');
    await container.read(umbralProvider.notifier).refresh();

    final reading = container.read(umbralProvider).value!;
    expect(reading.stale, isFalse);
    expect(reading.localDate, '2026-08-15');
    expect(cache.value!['window']['local_date'], '2026-08-15');
  });
}
