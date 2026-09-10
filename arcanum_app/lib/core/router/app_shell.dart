import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../content/sections.dart';
import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import '../../shared/widgets/info_dot.dart';

/// Carcasa con barra superior contextual + barra inferior + botón flotante.
///
/// Arriba (por pantalla): nombre místico de la sección + subtítulo llano + "?"
/// que explica + avatar que abre el perfil. Abajo: las cinco secciones. La
/// barra superior se OCULTA en las sub-rutas (una obra, un capítulo), que traen
/// su propio AppBar con botón de volver.
///
/// EL BOTÓN DEL HORÓSCOPO VIVE AQUÍ, y no repetido en las cinco pantallas: el
/// shell es el único sitio donde un widget sobrevive a la navegación entre
/// ramas sin reconstruirse ni duplicarse. Va a la IZQUIERDA y flotando por
/// ENCIMA de la barra, no incrustado en ella (`startDocked`), porque ahí caería
/// justo sobre el destino "Hoy" y le robaría el toque.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final indice = navigationShell.currentIndex;
    final enHoroscopo = indice == indiceHoroscopo;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _BotonHoroscopo(
        activo: enHoroscopo,
        onPressed: () => navigationShell.goBranch(indiceHoroscopo),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Se reconstruye en cada navegación para saber si estamos en una
            // raíz de sección (mostrar barra) o en una sub-ruta (ocultarla).
            AnimatedBuilder(
              animation: router.routerDelegate,
              builder: (context, _) {
                final location =
                    router.routerDelegate.currentConfiguration.uri.path;
                final section = arcanumSectionForRoute(location);
                if (section == null) return const SizedBox.shrink();
                return _SectionBar(section: section);
              },
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      // Dentro del horóscopo NINGUNA pestaña está seleccionada, porque el
      // horóscopo no es una de ellas. `NavigationBar` exige un índice válido
      // (0..4) y no admite "ninguno", así que se le da el 0 y se apaga el
      // indicador: marcar "Hoy" cuando no estás en Hoy sería mentirle a la
      // única brújula que tiene la persona para saber dónde está.
      bottomNavigationBar: NavigationBarTheme(
        data: enHoroscopo
            ? const NavigationBarThemeData(
                indicatorColor: Colors.transparent,
                indicatorShape: RoundedRectangleBorder(),
              )
            : const NavigationBarThemeData(),
        child: NavigationBar(
          selectedIndex: enHoroscopo ? 0 : indice,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: !enHoroscopo && index == indice,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_twilight_outlined),
              selectedIcon: Icon(Icons.wb_twilight),
              label: 'Hoy',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Cielos',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Grimorio',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library),
              label: 'Saber',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              selectedIcon: Icon(Icons.style),
              label: 'Oráculo',
            ),
          ],
        ),
      ),
    );
  }
}

/// El botón del horóscopo: un sello dorado, siempre en el mismo sitio.
///
/// Cuando ya estás dentro se apaga y deja de responder. No se esconde: si
/// desapareciera al entrar, el sitio al que se vuelve dejaría de estar donde
/// estaba, y la persona tendría que buscar cómo salir.
class _BotonHoroscopo extends StatelessWidget {
  const _BotonHoroscopo({required this.activo, required this.onPressed});

  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !activo,
      label: activo ? 'Horóscopo, ya estás aquí' : 'Abrir tu horóscopo de hoy',
      child: FloatingActionButton(
        heroTag: 'fab-horoscopo',
        onPressed: activo ? null : onPressed,
        tooltip: activo ? null : 'Horóscopo',
        elevation: activo ? 0 : 6,
        backgroundColor: activo
            ? ArcanumColors.surfaceHigh
            : ArcanumColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: activo
                ? ArcanumColors.goldMuted.withValues(alpha: 0.35)
                : ArcanumColors.gold,
            width: 1.4,
          ),
        ),
        // El glifo del Sol, no un icono de Material: es el mismo alfabeto que
        // usa el resto de la app para nombrar un planeta.
        child: Text(
          '☉',
          style: ArcanumText.heading(
            22,
            color: activo
                ? ArcanumColors.goldMuted.withValues(alpha: 0.45)
                : ArcanumColors.goldLight,
          ),
        ),
      ),
    );
  }
}

/// Barra superior de una sección: identidad + qué es + ayuda + perfil.
class _SectionBar extends StatelessWidget {
  final ArcanumSection section;
  const _SectionBar({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 10, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.title,
                  style: ArcanumText.heading(26, color: ArcanumColors.gold),
                ),
                Text(
                  section.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(
                    13,
                    color: ArcanumColors.ivoryMuted,
                    italic: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // "?" — explica a fondo esta sección (misma hoja del glosario).
          InfoDot(section.helpKey, size: 22),
          const SizedBox(width: 12),
          const _ProfileAvatar(),
        ],
      ),
    );
  }
}

/// Avatar circular con la inicial del practicante. Único punto de entrada al
/// perfil (y, dentro, a los ajustes) desde cualquier pantalla.
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = (user?['display_name'] as String?)?.trim();
    final initial = (name != null && name.isNotEmpty)
        ? name.substring(0, 1).toUpperCase()
        : '☾';
    return Semantics(
      button: true,
      label: 'Abrir perfil',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/perfil'),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ArcanumColors.gold.withValues(alpha: 0.7),
              width: 1.2,
            ),
            gradient: RadialGradient(
              colors: [
                ArcanumColors.gold.withValues(alpha: 0.16),
                Colors.transparent,
              ],
            ),
          ),
          child: Text(
            initial,
            style: ArcanumText.heading(20, color: ArcanumColors.gold),
          ),
        ),
      ),
    );
  }
}
