import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/umbral/application/umbral_controller.dart';
import 'package:arcanum_app/features/umbral/data/umbral_cache.dart';
import 'package:arcanum_app/features/umbral/presentation/umbral_reading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = 'Hoy note un limite que llevaba tiempo sin mirar.';

class _MemoryCache implements UmbralCache {
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
  @override
  Future<void> save(Map<String, dynamic> contract) async {}
}

class _FakeApi implements ArcanumApi {
  final List<Map<String, dynamic>> grimoireBodies = [];

  @override
  Future<Map<String, dynamic>> umbral({String? tz}) async => _contract;

  @override
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    grimoireBodies.add(body);
    return {'id': 'entrada-1'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} no se usa en este test');
}

final _contract = <String, dynamic>{
  'contract_version': 'horoscope_daily/1',
  'selector_version': 'umbral-selector-1.0.0',
  'editorial_version': 'umbral-editorial-1.0.0',
  'ephemeris': 'swisseph/moshier',
  'computed_at': '2026-08-15T17:00:00+00:00',
  'precision': 'full',
  'window': {
    'timezone': 'America/Bogota',
    'local_date': '2026-08-15',
    'starts_at': '2026-08-15T05:00:00+00:00',
    'ends_at': '2026-08-16T05:00:00+00:00',
    'reference_at': '2026-08-15T17:00:00+00:00',
  },
  'factors': [1],
  'reading': {
    'headline': 'Cuadratura de Saturno al Sol natal, con 0.4° de orbe.',
    'headlines': ['Cuadratura de Saturno al Sol natal, con 0.4° de orbe.'],
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

Future<_FakeApi> _pump(WidgetTester tester) async {
  final api = _FakeApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        umbralCacheProvider.overrideWithValue(_MemoryCache()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UmbralReadingView()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// La lectura es larga: sin desplazarse hasta el widget, el tap cae fuera de
/// la pantalla y el test falla por geometria, no por comportamiento.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('la reflexion esta cerrada hasta que se pide', (tester) async {
    await _pump(tester);

    // Una caja de texto siempre abierta bajo la lectura es una invitacion
    // permanente a dejar rastro. El rastro se pide, no se da por hecho.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Guardar una reflexión cifrada'), findsOneWidget);

    await _tap(tester, find.text('Guardar una reflexión cifrada'));

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('la reflexion sale cifrada y el texto claro no viaja', (
    tester,
  ) async {
    final api = await _pump(tester);

    await _tap(tester, find.text('Guardar una reflexión cifrada'));
    await tester.enterText(find.byType(TextField), _secret);
    await _tap(tester, find.text('Sellar'));

    expect(api.grimoireBodies, hasLength(1));
    final body = api.grimoireBodies.single;

    expect(body['encrypted_content'], isNotNull);
    expect(body['content_iv'], isNotNull);
    expect(body['encrypted_content'], startsWith('v2:'));

    // Ni el texto entero ni ningun fragmento reconocible suyo.
    final enviado = body.values.map((value) => '$value').join(' ');
    expect(enviado, isNot(contains(_secret)));
    expect(enviado, isNot(contains('limite')));
    expect(enviado, isNot(contains('llevaba tiempo')));
  });

  testWidgets('la CTA de profundizar existe pero no hace nada', (tester) async {
    await _pump(tester);

    expect(find.text('Profundizar con el Oráculo'), findsOneWidget);
    expect(find.text('Todavía no disponible.'), findsOneWidget);
    // Construida, no cableada: ningun boton la envuelve.
    expect(
      find.ancestor(
        of: find.text('Profundizar con el Oráculo'),
        matching: find.byType(ButtonStyleButton),
      ),
      findsNothing,
    );
  });

  testWidgets('la lectura muestra los cinco bloques y su trazabilidad', (
    tester,
  ) async {
    await _pump(tester);

    for (final label in [
      'LECTURA DEL UMBRAL',
      'CIELO OBSERVADO',
      'LECTURA SIMBÓLICA',
      'PRÁCTICA OPCIONAL',
      'POR QUÉ APARECE HOY',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    expect(
      find.textContaining('Contrato: horoscope_daily/1'),
      findsOneWidget,
    );
    expect(find.textContaining('swisseph/moshier'), findsOneWidget);
  });
}
