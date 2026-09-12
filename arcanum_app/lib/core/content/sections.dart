import 'package:flutter/material.dart';

/// Metadatos de cada sección de la app.
///
/// Una sola fuente de verdad para la barra superior: el nombre MÍSTICO (la
/// identidad, la marca), un subtítulo LLANO (el maestro: qué es esto, siempre
/// visible) y la clave de glosario del "?" (la explicación a fondo).
///
/// ESTA LISTA ES LA BARRA DE ABAJO, en este orden: cada seccion es una rama del
/// shell y un destino de la barra, y los dos ordenes son el mismo. Si cambias
/// uno, cambia el otro.
///
/// El horoscopo estuvo fuera de la barra hasta el 11-sep-2026, en una rama a la
/// que solo se llegaba por un boton flotante. Se decidio darle pestana: es lo
/// que se abre a diario, y estando fuera ninguna pestana quedaba marcada
/// mientras se leia.
class ArcanumSection {
  /// Iconos del destino en la barra. Viven aqui y no sueltos en el shell
  /// porque la barra SE CONSTRUYE de esta lista: escritos a mano, un dia hubo
  /// seis destinos contra cinco ramas y tocar el ultimo llamaba a una rama que
  /// no existia. Ningun test lo veia.
  final IconData icon;
  final IconData selectedIcon;

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
    required this.icon,
    required this.selectedIcon,
  });
}

const List<ArcanumSection> arcanumSections = [
  ArcanumSection(
    route: '/hoy',
    icon: Icons.wb_twilight_outlined,
    selectedIcon: Icons.wb_twilight,
    title: 'Cielo',
    subtitle: 'Tu carta natal y lo que hoy la toca',
    helpKey: 'carta_natal',
  ),
  ArcanumSection(
    route: '/horoscopo',
    icon: Icons.brightness_4_outlined,
    selectedIcon: Icons.brightness_4,
    title: 'Horóscopo',
    subtitle: 'Tu cielo de hoy, sobre tu carta',
    helpKey: 'transitos',
  ),
  ArcanumSection(
    route: '/grimorio',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    title: 'Grimorio',
    subtitle: 'Tu diario mágico: notas, ritos y hechizos',
    helpKey: 'grimorio',
  ),
  ArcanumSection(
    route: '/saber',
    icon: Icons.local_library_outlined,
    selectedIcon: Icons.local_library,
    title: 'Saber',
    subtitle: 'Plantas y libros de la tradición',
    helpKey: 'materia',
  ),
  ArcanumSection(
    route: '/oraculo',
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    title: 'Oráculo',
    subtitle: 'Consulta: tarot y respuestas guiadas',
    helpKey: 'tarot',
  ),
];

/// La sección cuya raíz coincide EXACTA con [location]. Devuelve null en las
/// sub-rutas (un capítulo, una obra): ahí la barra superior de sección se
/// oculta para no chocar con el AppBar propio de esas pantallas.
ArcanumSection? arcanumSectionForRoute(String location) {
  for (final section in arcanumSections) {
    if (section.route == location) return section;
  }
  return null;
}
