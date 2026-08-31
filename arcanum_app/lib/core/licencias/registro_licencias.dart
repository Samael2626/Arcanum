import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../places/city_catalog.dart';

/// Licencias de terceros que ARCANUM tiene la obligacion de distribuir.
///
/// La SIL Open Font License 1.1 exige que su texto viaje CON el software: no
/// basta con enlazarlo. Las cuatro fuentes empaquetadas son OFL, y hasta ahora
/// dos de ellas (Cormorant Garamond y Crimson Pro) ni siquiera tenian su
/// fichero en el arbol.
///
/// Los datos de GeoNames van bajo CC BY 4.0, que pide atribucion visible. Esa
/// atribucion ya se pinta en el selector de lugar; aqui se repite para que
/// tambien conste en el listado formal.
///
/// Se registran de forma perezosa: `LicenseRegistry` solo tira del generador
/// cuando alguien abre `showLicensePage()`, asi que esto no cuesta nada en el
/// arranque.

/// Ficheros de licencia empaquetados, con los paquetes a los que cubren.
const Map<String, List<String>> _licenciasDeFuentes = {
  'assets/fonts/OFL-CormorantGaramond.txt': ['Cormorant Garamond'],
  'assets/fonts/OFL-CrimsonPro.txt': ['Crimson Pro'],
  // La familia de glifos es un subconjunto fusionado de estas dos, asi que
  // arrastra las licencias de ambas.
  'assets/fonts/OFL-Libertinus.txt': ['Libertinus Serif', 'ARCANUM Glifos'],
  'assets/fonts/OFL-Noto.txt': ['Noto', 'ARCANUM Glifos'],
};

void registrarLicencias() {
  LicenseRegistry.addLicense(() async* {
    for (final entrada in _licenciasDeFuentes.entries) {
      final texto = await rootBundle.loadString(entrada.key);
      yield LicenseEntryWithLineBreaks(entrada.value, texto);
    }

    yield LicenseEntryWithLineBreaks(
      const ['GeoNames'],
      '${CityCatalog.attribution}\n\n'
      'Los nombres de ciudades, sus coordenadas y sus zonas horarias proceden '
      'de GeoNames (https://www.geonames.org), distribuidos bajo licencia '
      'Creative Commons Attribution 4.0 International (CC BY 4.0).\n\n'
      'Texto de la licencia: https://creativecommons.org/licenses/by/4.0/',
    );

    yield const LicenseEntryWithLineBreaks(
      ['Obras historicas'],
      'Los textos de Lecturas son obras en dominio publico. Cada obra lleva su '
      'procedencia y su nota de licencia en su propia ficha dentro de la '
      'aplicacion.',
    );
  });
}
