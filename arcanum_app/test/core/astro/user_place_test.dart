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

  test('acepta también número, que es como puede volver del perfil cacheado', () {
    final place = userPlaceOf({'birth_lat': 40.4168, 'birth_lon': -3});
    expect(place!.lat, closeTo(40.4168, 1e-9));
    expect(place.lon, closeTo(-3, 1e-9));
  });

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
}
