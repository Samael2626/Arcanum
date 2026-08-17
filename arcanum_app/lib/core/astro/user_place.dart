import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Lugar confirmado de una persona.
class UserPlace {
  const UserPlace(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// El UNICO sitio del cliente que decide donde esta una persona.
///
/// Espeja a proposito `user_sky.coords` del servidor: mismo criterio a los dos
/// lados y ninguna ciudad por omision. Una hora planetaria calculada sobre un
/// meridiano ajeno no es una aproximacion, es un dato falso con la misma
/// apariencia que uno verdadero.
///
/// Prefiere la RESIDENCIA y cae al NACIMIENTO. La hora planetaria parte en doce
/// la luz entre el amanecer y el ocaso locales, asi que se mide desde el
/// horizonte de hoy; el de nacimiento no interviene. Residencia vacia significa
/// "vivo donde naci", cierto para la mayoria.
///
/// NO sirve para la carta natal: esa se calcula con el lugar de nacimiento y no
/// cambia nunca. La calcula el servidor, que tiene su propia regla.
///
/// `/users/me` serializa las coordenadas como texto (`Optional[str]` en el
/// esquema), pero el perfil cacheado puede volver como numero segun quien lo
/// escribiera: se aceptan las dos formas y se rechaza cualquier otra. Devuelve
/// null cuando no hay lugar confirmado; NUNCA uno inventado.
UserPlace? userPlaceOf(Map<String, dynamic>? user) {
  return _placeFrom(user?['current_lat'], user?['current_lon']) ??
      _placeFrom(user?['birth_lat'], user?['birth_lon']);
}

/// Un par de coordenadas utilizable, o null si falta o no es un lugar valido.
UserPlace? _placeFrom(Object? rawLat, Object? rawLon) {
  final lat = _coord(rawLat);
  final lon = _coord(rawLon);
  if (lat == null || lon == null) return null;
  // Fuera de rango o no finito es dato corrupto, no un lugar: se descarta en
  // vez de mandarlo al servidor para que lo rechace con un 422.
  if (!lat.isFinite || !lon.isFinite) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return UserPlace(lat, lon);
}

double? _coord(Object? raw) => switch (raw) {
  num n => n.toDouble(),
  String s => double.tryParse(s.trim()),
  _ => null,
};

/// Lugar de la sesion actual, o null mientras no lo haya confirmado.
final userPlaceProvider = Provider<UserPlace?>(
  (ref) => userPlaceOf(ref.watch(authProvider).user),
);
