import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// El lugar que la persona CONFIRMO en el onboarding. Nunca un lugar por
/// defecto.
///
/// Existe para que ninguna pantalla vuelva a escribir unas coordenadas en el
/// codigo. La version anterior de `ArcanumApi.today()` traia Bogota como valor
/// por defecto de `lat`/`lon`: todo el mundo, estuviera donde estuviera, veia
/// la hora planetaria de un meridiano ajeno sin que nada en la pantalla lo
/// insinuara. Un dato falso presentado como verdadero es peor que la ausencia
/// del dato, porque la ausencia sí se puede ver.
class ConfirmedPlace {
  final double lat;
  final double lon;

  /// Zona IANA confirmada. Puede faltar aunque las coordenadas existan.
  final String? timezone;

  const ConfirmedPlace({
    required this.lat,
    required this.lon,
    this.timezone,
  });
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Coordenadas confirmadas del perfil, o null si no hay ninguna.
final confirmedPlaceProvider = Provider<ConfirmedPlace?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;
  final lat = _asDouble(user['birth_lat']);
  final lon = _asDouble(user['birth_lon']);
  if (lat == null || lon == null) return null;
  final tz = user['birth_timezone'];
  return ConfirmedPlace(
    lat: lat,
    lon: lon,
    timezone: tz is String && tz.isNotEmpty ? tz : null,
  );
});
