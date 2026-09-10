/// Metadatos de cada sección de la app.
///
/// Una sola fuente de verdad para la barra superior: el nombre MÍSTICO (la
/// identidad, la marca), un subtítulo LLANO (el maestro: qué es esto, siempre
/// visible) y la clave de glosario del "?" (la explicación a fondo).
///
/// Las CINCO PRIMERAS son, en ese orden, las ramas del shell y los destinos de
/// la barra inferior. Si cambias uno, cambia el otro.
///
/// La sexta ('/horoscopo') es una rama SIN destino en la barra: se llega por el
/// boton flotante del shell. Esta aqui porque necesita la misma barra superior
/// que las demas -- nombre, subtitulo y "?" --, y no en la barra de abajo
/// porque seis etiquetas no caben en una pantalla estrecha y ninguna de las
/// cinco actuales sobra.
class ArcanumSection {
  /// Ruta raíz de la rama (p. ej. '/hoy').
  final String route;

  /// Nombre evocador. No se traduce ni se aplana: es la marca.
  final String title;

  /// Línea llana bajo el título. Enseña al principiante sin tocar el aura.
  final String subtitle;

  /// Clave del glosario para el botón "?" de la barra superior.
  final String helpKey;

  const ArcanumSection({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.helpKey,
  });
}

const List<ArcanumSection> arcanumSections = [
  ArcanumSection(
    route: '/hoy',
    title: 'Hoy',
    subtitle: 'El cielo de hoy y tu siguiente paso',
    helpKey: 'hora_planetaria',
  ),
  ArcanumSection(
    route: '/cielos',
    title: 'Cielos',
    subtitle: 'Tu carta natal y los signos del zodiaco',
    helpKey: 'carta_natal',
  ),
  ArcanumSection(
    route: '/grimorio',
    title: 'Grimorio',
    subtitle: 'Tu diario mágico: notas, ritos y hechizos',
    helpKey: 'grimorio',
  ),
  ArcanumSection(
    route: '/saber',
    title: 'Saber',
    subtitle: 'Plantas y libros de la tradición',
    helpKey: 'materia',
  ),
  ArcanumSection(
    route: '/oraculo',
    title: 'Oráculo',
    subtitle: 'Consulta: tarot y respuestas guiadas',
    helpKey: 'tarot',
  ),
  // Sexta rama, sin destino en la barra inferior. Ver la nota de arriba.
  ArcanumSection(
    route: '/horoscopo',
    title: 'Horóscopo',
    subtitle: 'Tu cielo de hoy, sobre tu carta',
    helpKey: 'transitos',
  ),
];

/// Ruta de la rama del horoscopo. Vive aqui y no suelta en el shell para que
/// el router, la barra superior y el boton flotante digan la misma cadena.
const rutaHoroscopo = '/horoscopo';

/// Indice de esa rama dentro del shell: va detras de las cinco de la barra.
final indiceHoroscopo = arcanumSections.indexWhere(
  (s) => s.route == rutaHoroscopo,
);

/// La sección cuya raíz coincide EXACTA con [location]. Devuelve null en las
/// sub-rutas (un capítulo, una obra): ahí la barra superior de sección se
/// oculta para no chocar con el AppBar propio de esas pantallas.
ArcanumSection? arcanumSectionForRoute(String location) {
  for (final section in arcanumSections) {
    if (section.route == location) return section;
  }
  return null;
}
