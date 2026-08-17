/// Contrato entre el buscador de ciudades y la UI que lo usa.
///
/// Existe para que el catalogo y la pantalla se puedan construir por separado
/// sin inventar cada uno su version. Ni este archivo ni las firmas de abajo se
/// cambian sin decirlo: son el punto donde se encuentran las dos mitades.
library;

/// Una localidad del catalogo, ya lista para mostrarse y para guardarse.
class City {
  const City({
    required this.name,
    required this.region,
    required this.country,
    required this.countryCode,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  /// Nombre en su idioma, con acentos. "Cordoba" -> "Córdoba".
  final String name;

  /// Division administrativa, para desambiguar. "Andalucía". Vacia si no consta.
  final String region;

  /// Nombre del pais. "España".
  final String country;

  /// ISO-3166 de dos letras. "ES".
  final String countryCode;

  final double lat;
  final double lon;

  /// Zona IANA. "Europe/Madrid". Viene en el catalogo, no se deduce.
  final String timezone;

  /// Lo que ve la persona en la lista y en la confirmacion.
  /// "Córdoba, Andalucía, España" — sin region: "Mónaco, Mónaco".
  String get label =>
      [name, if (region.isNotEmpty) region, country].join(', ');
}

/// Un pais del desplegable.
class Country {
  const Country({required this.code, required this.name});

  /// ISO-3166 de dos letras.
  final String code;

  /// Nombre para mostrar, con acentos.
  final String name;
}

/// Busqueda de localidades sobre el catalogo empaquetado.
///
/// La implementacion real carga el asset; la UI se prueba contra una falsa en
/// memoria. Por eso esto es una interfaz y no una clase concreta.
abstract class CityIndex {
  /// Localidades que casan con [query], ordenadas por relevancia.
  ///
  /// Reglas que la implementacion DEBE cumplir:
  /// - Insensible a acentos y a mayusculas: "cordoba" encuentra "Córdoba".
  /// - Los que empiezan por [query] van antes que los que solo lo contienen.
  /// - A igualdad, primero la localidad mas poblada: quien escribe "Madrid"
  ///   busca la capital, no un pueblo homonimo.
  /// - [countryCode] acota al pais elegido; null busca en todo el mundo.
  /// - Una [query] vacia o de un solo caracter devuelve lista vacia: filtrar
  ///   69.000 filas por una letra no ayuda a nadie y bloquea la interfaz.
  /// - Nunca lanza por una consulta rara. Sin resultados es lista vacia.
  Future<List<City>> search(String query, {String? countryCode, int limit = 30});

  /// Paises del catalogo, ordenados alfabeticamente por nombre.
  Future<List<Country>> countries();
}
