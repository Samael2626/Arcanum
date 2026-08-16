import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/state/confirmed_place.dart';

/// Cielo del momento en el lugar confirmado por la persona.
///
/// Devuelve null cuando no hay lugar confirmado. Antes esta llamada traía
/// Bogotá por defecto y la pantalla mostraba la hora planetaria de un
/// meridiano que no era el de nadie en particular, sin decirlo. Ahora, sin
/// lugar, no hay cielo: la pantalla lo declara y ofrece confirmarlo.
final todaySkyProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final place = ref.watch(confirmedPlaceProvider);
  if (place == null) return null;
  return ref.read(arcanumApiProvider).today(
    lat: place.lat,
    lon: place.lon,
    tz: place.timezone,
  );
});
