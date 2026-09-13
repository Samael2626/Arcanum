import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import 'arcanum_drawer.dart';

import '../auth/auth_controller.dart';
import '../content/sections.dart';
import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import '../../shared/widgets/info_dot.dart';

/// Carcasa con barra superior contextual + barra inferior.
///
/// Arriba (por pantalla): nombre místico de la sección + subtítulo llano + "?"
/// que explica + avatar que abre el perfil. Abajo: las secciones, en el mismo
/// orden que `arcanumSections`. La barra superior se OCULTA en las sub-rutas
/// (una obra, un capítulo), que traen su propio AppBar con botón de volver.
///
/// EL HORÓSCOPO YA NO ES UN BOTÓN FLOTANTE. Lo fue mientras estuvo fuera de la
/// barra, y eso obligaba a un caso especial entero aquí dentro: ninguna
/// pestaña marcada mientras se leía, el indicador apagado a mano y un índice
/// falso para que `NavigationBar` no protestara. Con pestaña propia, todo eso
/// sobra.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final indice = navigationShell.currentIndex;

    return Scaffold(
      // El cajon de la cuenta cuelga del avatar, a la derecha, que es donde
      // esta el avatar. `endDrawer` y no `drawer`: abrirlo desde el borde
      // izquierdo chocaria con el gesto de volver atras del sistema.
      endDrawer: const ArcanumDrawer(),
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
      bottomNavigationBar: NavigationBar(
          selectedIndex: indice,
          // Tocar la pestaña en la que ya estás vuelve a su raíz, que es lo que
          // espera cualquiera: sirve para salir de una sub-ruta sin buscar el
          // botón de volver.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == indice,
          ),
          // La barra SALE de `arcanumSections`, no de una lista escrita a
          // mano: son la misma cosa y mantenerlas en dos sitios ya se torcio
          // una vez -- seis destinos contra cinco ramas, y tocar el ultimo
          // llamaba a una rama inexistente.
          destinations: [
            for (final seccion in arcanumSections)
              NavigationDestination(
                icon: Icon(seccion.icon),
                selectedIcon: Icon(seccion.selectedIcon),
                label: seccion.title,
              ),
          ],
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

/// Avatar circular con la inicial del practicante. Abre el cajon de la cuenta
/// -- Perfil, Ajustes y Privacidad -- desde cualquier seccion.
///
/// Antes empujaba directo a `/perfil`, y Ajustes y Privacidad colgaban uno
/// dentro del otro: tres toques para llegar a la politica de datos. El cajon
/// los pone a la misma altura.
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
      label: 'Abrir tu cuenta',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: Scaffold.of(context).openEndDrawer,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          // Sin filete, como el resto de la app: lo que le da forma es el
          // propio material.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ArcanumResin.gradient(mood: ArcanumMood.neutral),
            boxShadow: ArcanumResin.shadow,
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
