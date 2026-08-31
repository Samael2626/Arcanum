import 'package:arcanum_app/core/astro/birth_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perfil completo, en la forma que devuelve `/users/me`: las coordenadas van
/// como texto, no como numero.
Map<String, dynamic> _perfil({
  Object? fecha = '2001-01-26T00:00:00Z',
  Object? hora = '2000-01-01T03:00:00Z',
  Object? lat = '6.269732',
  Object? lon = '-75.602560',
  Object? casas = 'placidus',
}) => {
  'birth_date': fecha,
  'birth_time': hora,
  'birth_lat': lat,
  'birth_lon': lon,
  'preferred_house_system': casas,
  // Ruido que NO debe influir: son campos que cambian sin tocar la rueda.
  'display_name': 'Samuel',
  'current_city': 'Medellín',
  'subscription_tier': 'free',
};

void main() {
  test('sin sesion no hay firma', () {
    expect(birthSignatureOf(null), isNull);
  });

  test('un perfil completo produce firma', () {
    expect(birthSignatureOf(_perfil()), isNotNull);
  });

  // El caso que motivo todo esto: la cuenta tenia birth_city pero el perfil
  // cacheado del cliente aun no traia el resto. La firma tiene que ser null,
  // no una cadena a medias, porque el servidor responde 422 igual.
  for (final campo in const [
    'birth_date',
    'birth_time',
    'birth_lat',
    'birth_lon',
  ]) {
    test('sin $campo no hay firma', () {
      final perfil = _perfil()..[campo] = null;
      expect(birthSignatureOf(perfil), isNull);
    });

    test('con $campo vacio tampoco hay firma', () {
      final perfil = _perfil()..[campo] = '   ';
      expect(birthSignatureOf(perfil), isNull);
    });
  }

  test('el mismo nacimiento da la misma firma', () {
    expect(birthSignatureOf(_perfil()), birthSignatureOf(_perfil()));
  });

  test('cambiar campos ajenos a la rueda NO cambia la firma', () {
    final otro = _perfil()
      ..['display_name'] = 'Otra persona'
      ..['current_city'] = 'Bogotá'
      ..['subscription_tier'] = 'premium';
    expect(birthSignatureOf(otro), birthSignatureOf(_perfil()));
  });

  // Por esto la firma es una firma y no un booleano: corregir la hora rehace la
  // carta entera, y un booleano solo veria aparecer los datos, nunca cambiarlos.
  test('corregir la hora de nacimiento cambia la firma', () {
    final corregido = _perfil(hora: '2000-01-01T15:00:00Z');
    expect(birthSignatureOf(corregido), isNot(birthSignatureOf(_perfil())));
  });

  test('corregir el lugar de nacimiento cambia la firma', () {
    final corregido = _perfil(lat: '40.416800', lon: '-3.703800');
    expect(birthSignatureOf(corregido), isNot(birthSignatureOf(_perfil())));
  });

  test('cambiar el sistema de casas cambia la firma', () {
    final corregido = _perfil(casas: 'whole_sign');
    expect(birthSignatureOf(corregido), isNot(birthSignatureOf(_perfil())));
  });

  test('acepta coordenadas numericas, como el perfil cacheado', () {
    expect(birthSignatureOf(_perfil(lat: 6.269732, lon: -75.60256)), isNotNull);
  });
}
