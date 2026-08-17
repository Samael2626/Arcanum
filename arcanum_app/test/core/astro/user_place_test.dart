import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee las coordenadas tal como las serializa /users/me (texto)', () {
    final place = userPlaceOf({
      'birth_lat': '40.416800',
      'birth_lon': '-3.703800',
    });
    expect(place, isNotNull);
    expect(place!.lat, closeTo(40.4168, 1e-9));
    expect(place.lon, closeTo(-3.7038, 1e-9));
  });

  test(
    'acepta también número, que es como puede volver del perfil cacheado',
    () {
      final place = userPlaceOf({'birth_lat': 40.4168, 'birth_lon': -3});
      expect(place!.lat, closeTo(40.4168, 1e-9));
      expect(place.lon, closeTo(-3, 1e-9));
    },
  );

  test('sin lugar confirmado devuelve null, nunca una ciudad', () {
    // Cada uno de estos casos acabaria en Bogota si hubiera un default.
    for (final user in <Map<String, dynamic>?>[
      null,
      {},
      {'birth_lat': '4.71'}, // media coordenada no es un lugar
      {'birth_lat': null, 'birth_lon': null},
      {'birth_lat': '', 'birth_lon': ''},
      {'birth_lat': 'Bogotá', 'birth_lon': 'Colombia'},
      {'birth_lat': true, 'birth_lon': false},
      {'birth_lat': '91', 'birth_lon': '0'}, // fuera de rango
      {'birth_lat': '0', 'birth_lon': '181'},
      {'birth_lat': 'NaN', 'birth_lon': 'NaN'},
      {'birth_lat': 'Infinity', 'birth_lon': '0'},
    ]) {
      expect(userPlaceOf(user), isNull, reason: '$user');
    }
  });

  test('los límites exactos del planeta son lugares válidos', () {
    expect(userPlaceOf({'birth_lat': '-90', 'birth_lon': '180'}), isNotNull);
  });

  group('residencia frente a nacimiento', () {
    const bogota = {'birth_lat': '4.7110', 'birth_lon': '-74.0700'};

    test('con residencia declarada, manda la residencia', () {
      // El cielo de hoy se mide desde donde estás, no desde donde naciste.
      final place = userPlaceOf({
        ...bogota,
        'current_lat': '40.4168',
        'current_lon': '-3.7038',
      });
      expect(place!.lat, closeTo(40.4168, 1e-9));
    });

    test('sin residencia se usa el nacimiento', () {
      // Vacío significa "vivo donde nací": nadie tiene que rellenar nada.
      expect(userPlaceOf(bogota)!.lat, closeTo(4.7110, 1e-9));
      expect(
        userPlaceOf({...bogota, 'current_lat': null, 'current_lon': null})!.lat,
        closeTo(4.7110, 1e-9),
      );
    });

    test('una residencia inservible cae al nacimiento, no a null', () {
      // Media coordenada, texto o fuera de rango no son un lugar. Perder el
      // cielo entero por una residencia corrupta sería peor que ignorarla.
      for (final rota in <Map<String, dynamic>>[
        {'current_lat': '40.4168'},
        {'current_lat': 'Madrid', 'current_lon': 'España'},
        {'current_lat': '91', 'current_lon': '0'},
        {'current_lat': '', 'current_lon': ''},
      ]) {
        expect(
          userPlaceOf({...bogota, ...rota})!.lat,
          closeTo(4.7110, 1e-9),
          reason: '$rota',
        );
      }
    });

    test('residencia válida sin nacimiento también es un lugar', () {
      final place = userPlaceOf({
        'current_lat': '40.4168',
        'current_lon': '-3.7038',
      });
      expect(place, isNotNull);
    });

    test('sin ninguno de los dos sigue siendo null', () {
      expect(userPlaceOf({'current_lat': null, 'birth_lat': null}), isNull);
    });
  });
}
