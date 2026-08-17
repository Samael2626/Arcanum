import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/places/city_index.dart';
import 'package:arcanum_app/core/places/city_index_provider.dart';
import 'package:arcanum_app/shared/widgets/place_chooser.dart';

// ── Dobles ───────────────────────────────────────────────────────────────────
//
// El catalogo real lo construye otra mitad del trabajo. La pantalla se prueba
// contra esta implementacion falsa del contrato: es lo unico que la UI conoce.

const _cordobaEs = City(
  name: 'Córdoba',
  region: 'Andalucía',
  country: 'España',
  countryCode: 'ES',
  lat: 37.88,
  lon: -4.78,
  timezone: 'Europe/Madrid',
);

const _cordobaAr = City(
  name: 'Córdoba',
  region: 'Córdoba',
  country: 'Argentina',
  countryCode: 'AR',
  lat: -31.42,
  lon: -64.18,
  timezone: 'America/Argentina/Cordoba',
);

class _FakeCityIndex implements CityIndex {
  _FakeCityIndex({this.countriesFail = false});

  static const cities = [_cordobaEs, _cordobaAr];
  final bool countriesFail;

  /// Lo que la pantalla pidio de verdad, para comprobar que el pais acota.
  final queries = <String>[];
  final countryCodes = <String?>[];

  @override
  Future<List<City>> search(
    String query, {
    String? countryCode,
    int limit = 30,
  }) async {
    queries.add(query);
    countryCodes.add(countryCode);
    if (query.trim().length < 2) return const [];
    final texto = query.toLowerCase();
    return cities
        .where(
          (c) =>
              c.name.toLowerCase().contains(texto) &&
              (countryCode == null || c.countryCode == countryCode),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<Country>> countries() async {
    if (countriesFail) throw StateError('catalogo roto');
    return const [
      Country(code: 'AR', name: 'Argentina'),
      Country(code: 'ES', name: 'España'),
    ];
  }
}

/// Catalogo que nunca termina de abrir: para ver el estado de carga.
class _PendingCityIndex implements CityIndex {
  @override
  Future<List<City>> search(
    String query, {
    String? countryCode,
    int limit = 30,
  }) => Completer<List<City>>().future;

  @override
  Future<List<Country>> countries() => Completer<List<Country>>().future;
}

class _FakeApi extends ArcanumApi {
  _FakeApi() : super(Dio());

  final calls = <Map<String, String>>[];
  Object? failWith;

  @override
  Future<Map<String, dynamic>> geoResolve({
    required String country,
    required String city,
  }) async {
    calls.add({'country': country, 'city': city});
    if (failWith != null) throw failWith!;
    return {
      'display_name': 'Aldea del Rey, Castilla-La Mancha, España',
      'lat': '38.83',
      'lon': '-3.87',
      'timezone': 'Europe/Madrid',
    };
  }
}

// ── Armazon ──────────────────────────────────────────────────────────────────

class _Host extends StatelessWidget {
  const _Host({required this.onDone});

  final void Function(ChosenPlace?) onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            onPressed: () async {
              final place = await showPlaceChooser(
                ctx,
                title: 'Dónde vives',
                confirmQuestion: '¿Es aquí donde vives?',
              );
              onDone(place);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
  }
}

void main() {
  late _FakeApi api;

  setUp(() => api = _FakeApi());

  /// Abre la hoja y devuelve un contenedor de lo que acabe devolviendo.
  Future<_Result> open(
    WidgetTester tester,
    CityIndex index, {
    bool settle = true,
  }) async {
    final result = _Result();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityIndexProvider.overrideWithValue(index),
          arcanumApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          home: _Host(
            onDone: (place) {
              result.done = true;
              result.place = place;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return result;
  }

  Future<void> type(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const Key('place-query')), texto);
    await tester.pump();
  }

  group('estados del selector', () {
    testWidgets('mientras abre el catálogo lo dice, sin spinner mudo', (
      tester,
    ) async {
      await open(tester, _PendingCityIndex(), settle: false);
      await tester.pump();
      expect(
        find.text('Preparando el catálogo de localidades…'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('con el catálogo listo pide escribir', (tester) async {
      await open(tester, _FakeCityIndex());
      expect(
        find.textContaining('Escribe al menos dos letras'),
        findsOneWidget,
      );
    });

    testWidgets('mientras filtra lo dice', (tester) async {
      await open(tester, _FakeCityIndex());
      await type(tester, 'cor');
      expect(find.text('Buscando…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Buscando…'), findsNothing);
    });

    testWidgets('cada fila desambigua sola', (tester) async {
      await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      expect(find.text('Córdoba, Andalucía, España'), findsOneWidget);
      expect(find.text('Córdoba, Córdoba, Argentina'), findsOneWidget);
    });

    testWidgets('elegir se ve antes de confirmar', (tester) async {
      await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      expect(find.text('Usar este lugar'), findsNothing);
      await tester.tap(find.text('Córdoba, Andalucía, España'));
      await tester.pumpAndSettle();
      expect(find.text('Usar este lugar'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('sin resultados ofrece la salida de rescate', (tester) async {
      await open(tester, _FakeCityIndex());
      await type(tester, 'Aldea del Rey');
      await tester.pumpAndSettle();
      expect(
        find.text('No encontramos ninguna localidad con ese nombre.'),
        findsOneWidget,
      );
      expect(find.text('¿No encuentras tu localidad?'), findsOneWidget);
    });

    testWidgets('si el catálogo no abre lo dice y abre el rescate', (
      tester,
    ) async {
      await open(tester, _FakeCityIndex(countriesFail: true));
      expect(
        find.text('No pudimos abrir el catálogo de localidades.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('la atribución de GeoNames está siempre a la vista', (
      tester,
    ) async {
      await open(tester, _FakeCityIndex());
      expect(find.text(kPlacesAttribution), findsOneWidget);
      expect(kPlacesAttribution.contains('GeoNames'), isTrue);
      expect(kPlacesAttribution.contains('CC BY 4.0'), isTrue);
    });
  });

  group('qué se devuelve', () {
    testWidgets('elegir de la lista devuelve ese lugar exacto', (tester) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Córdoba, Córdoba, Argentina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este lugar'));
      await tester.pumpAndSettle();

      final place = result.place!;
      expect(place.displayName, 'Córdoba, Córdoba, Argentina');
      expect(place.lat, '-31.42');
      expect(place.lon, '-64.18');
      expect(place.timezone, 'America/Argentina/Cordoba');
    });

    testWidgets('cancelar devuelve null', (tester) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      // Tocar fuera de la hoja: es lo que hace quien se arrepiente.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(result.place, isNull);
    });

    testWidgets('elegir una fila no cierra: hace falta confirmar', (
      tester,
    ) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Córdoba, Andalucía, España'));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
    });
  });

  group('el texto libre nunca se cuela', () {
    testWidgets('Enter no elige el primero a ciegas', (tester) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      expect(find.text('Usar este lugar'), findsNothing);
    });

    testWidgets('lo tecleado sin elegir no sale hacia el servidor', (
      tester,
    ) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Bogotá inventada');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result.place, isNull);
      expect(api.calls, isEmpty);
    });

    testWidgets('el rescate exige confirmación antes de devolver', (
      tester,
    ) async {
      final result = await open(tester, _FakeCityIndex());
      await type(tester, 'Aldea del Rey');
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿No encuentras tu localidad?'));
      await tester.pumpAndSettle();

      // Lo tecleado se reaprovecha como borrador, pero no se ha mandado nada.
      expect(api.calls, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'España');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(api.calls.single, {'country': 'España', 'city': 'Aldea del Rey'});
      // Sigue sin devolverse: hay que confirmar.
      expect(result.done, isFalse);
      expect(find.text('¿Es aquí donde vives?'), findsOneWidget);

      await tester.tap(find.text('Corregir'));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);

      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, es este'));
      await tester.pumpAndSettle();

      expect(result.place!.displayName, contains('Aldea del Rey'));
      expect(result.place!.timezone, 'Europe/Madrid');
    });

    testWidgets('el rescate con país vacío no llama al servidor', (
      tester,
    ) async {
      await open(tester, _FakeCityIndex());
      await type(tester, 'Aldea del Rey');
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿No encuentras tu localidad?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      expect(find.text('Completa país y localidad.'), findsOneWidget);
    });
  });

  group('el país acota la búsqueda', () {
    testWidgets('sin país elegido se busca en todo el mundo', (tester) async {
      final index = _FakeCityIndex();
      await open(tester, index);
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();
      expect(index.countryCodes.last, isNull);
      expect(find.text('Córdoba, Córdoba, Argentina'), findsOneWidget);
    });

    testWidgets('elegir país filtra y se puede volver a todo el mundo', (
      tester,
    ) async {
      final index = _FakeCityIndex();
      await open(tester, index);
      await type(tester, 'Córdoba');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('place-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('España').last);
      await tester.pumpAndSettle();

      expect(index.countryCodes.last, 'ES');
      expect(find.text('Córdoba, Córdoba, Argentina'), findsNothing);
      expect(find.text('Córdoba, Andalucía, España'), findsOneWidget);

      await tester.tap(find.byKey(const Key('place-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todo el mundo').last);
      await tester.pumpAndSettle();

      expect(index.countryCodes.last, isNull);
      expect(find.text('Córdoba, Córdoba, Argentina'), findsOneWidget);
    });
  });

  group('mensajes de error', () {
    test('sin conexión se dice sin filtrar la traza', () {
      final texto = placeChooserErrorMessage(
        Exception('No se pudo contactar con https://api/geo/resolve'),
      );
      expect(
        texto,
        'No hay conexión para buscar el lugar. Inténtalo más tarde.',
      );
      expect(texto.contains('https'), isFalse);
    });

    test('cualquier otro fallo no expone el error crudo', () {
      final texto = placeChooserErrorMessage(
        Exception('DioException 500 /geo/resolve token=abc'),
      );
      expect(texto.contains('500'), isFalse);
      expect(texto.contains('token'), isFalse);
    });
  });
}

class _Result {
  bool done = false;
  ChosenPlace? place;
}
