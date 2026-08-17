import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'city_index.dart';

/// Punto donde la UI pide el catalogo de ciudades.
///
/// Vive aparte del contrato para que `city_index.dart` siga siendo Dart puro,
/// sin depender de Riverpod: el contrato lo comparten las dos mitades y la
/// implementacion real no tiene por que saber quien la inyecta.
///
/// No hay implementacion por defecto A PROPOSITO. Devolver aqui un indice vacio
/// haria que la pantalla dijera "no encontramos tu localidad" para TODA consulta
/// y pareceria un problema de la persona, no del cableado. Fallando de entrada,
/// el selector muestra el estado "catalogo no disponible" y ofrece el rescate
/// por servidor: ruidoso para nosotros, utilizable para quien lo tenga delante.
///
/// El dueno del catalogo sobrescribe esto en el arranque de la app:
///   ProviderScope(overrides: [cityIndexProvider.overrideWithValue(...)])
final cityIndexProvider = Provider<CityIndex>((ref) {
  throw UnimplementedError(
    'cityIndexProvider sin implementacion: sobrescribelo con el catalogo real.',
  );
});
