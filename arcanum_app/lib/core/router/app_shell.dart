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

/// Carcasa con barra superior contextual. YA NO HAY BARRA INFERIOR.
///
/// Arriba (por pantalla): hamburguesa que abre el cajon + nombre místico de la
/// sección + subtítulo llano + "?" que explica + avatar. La barra superior se
/// OCULTA en las sub-rutas (una obra, un capítulo), que traen su propio AppBar
/// con botón de volver.
///
/// LA BARRA DE ABAJO SE QUITO EL 21-sep-2026. Toda la navegacion pasa por
/// `ArcanumDrawer`, que dibuja en vertical la misma `arcanumSections` que
/// alimentaba a la barra y sigue llamando a `goBranch`: las ramas del shell y
/// su estado de pila no se tocan, solo cambia quien las ofrece.
///
/// Lo que se pierde, dicho en voz alta: la barra marcaba la seccion abierta
/// sin que nadie hiciera nada, y ahora hay que abrir el cajon para saber donde
/// estas. Y lo diario pasa de 4 toques a 8. Se decidio a sabiendas.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);

    return Scaffold(
      drawer: ArcanumDrawer(navigationShell: navigationShell),
      // Se abre SOLO por sus dos tiradores, nunca arrastrando desde el borde:
      // ese gesto es el de volver atras del sistema, y ahora que el cajon
      // cuelga del lado izquierdo los dos caerian en el mismo sitio.
      drawerEnableOpenDragGesture: false,
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
    );
  }
}

/// Barra superior de una sección: la hamburguesa, identidad, qué es, ayuda y
/// avatar.
class _SectionBar extends StatelessWidget {
  final ArcanumSection section;
  const _SectionBar({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _MenuPrincipal(),
          const SizedBox(width: 6),
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

/// La hamburguesa: puerta principal a TODA la navegacion, arriba a la
/// izquierda, que es donde la busca cualquiera.
///
/// Fue un sello -- el pentaculo U+26E4 de `ArcanumGlifos` -- mientras el cajon
/// solo guardaba la cuenta. Con las cinco secciones dentro, el glifo bonito
/// deja de decir lo que hay detras: tres lineas son la convencion y aqui la
/// convencion pesa mas, porque esto ya no es un adorno sino el unico camino a
/// las secciones.
///
/// Sin filete, como todo. Su zona tactil son 48 aunque el icono mida 22.
class _MenuPrincipal extends StatelessWidget {
  const _MenuPrincipal();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Navegación',
      child: Semantics(
        button: true,
        label: 'Abrir el menú',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: Scaffold.of(context).openDrawer,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.menu, size: 22, color: ArcanumColors.gold),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar circular con la inicial del practicante. Segundo tirador del MISMO
/// cajon que la hamburguesa: no hay un segundo cajon ni un segundo widget.
///
/// Se queda aunque la hamburguesa haga ya el trabajo, porque el avatar es lo
/// que se toca buscando la cuenta, y la cuenta sigue estando ahi dentro.
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
        onTap: Scaffold.of(context).openDrawer,
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
