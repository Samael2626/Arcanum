import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'arcanum_drawer.dart';

import '../content/sections.dart';
import '../state/flow_providers.dart';
import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import '../../shared/widgets/info_dot.dart';
import '../../features/sendero/presentation/sendero_invitation.dart';
import '../../features/sendero/application/sendero_guide_controller.dart';
import '../../features/sendero/presentation/sendero_coach_gate.dart';

/// Las secciones se abren desde la portada o el cajon. La barra superior
/// mantiene visible el retorno a la portada.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);

    return SenderoInvitationGate(
      child: SenderoCoachGate(
        router: router,
        child: Scaffold(
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
        ),
      ),
    );
  }
}

/// Barra superior de una sección: la hamburguesa, identidad, qué es, ayuda y
/// avatar.
class _SectionBar extends ConsumerWidget {
  final ArcanumSection section;
  const _SectionBar({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.read(senderoGuideTargetsProvider);
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
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: KeyedSubtree(
                key: targets.keyFor('help'),
                child: InfoDot(
                  section.helpKey,
                  size: 22,
                  onOpened: () =>
                      ref.read(senderoGuideProvider.notifier).onAction('help'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const _HomeButton(),
        ],
      ),
    );
  }
}

/// La hamburguesa abre el mapa de la app. Su zona tactil mide 48.
class _MenuPrincipal extends ConsumerWidget {
  const _MenuPrincipal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Abrir menú principal',
      child: Semantics(
        button: true,
        label: 'Abrir menú principal',
        child: InkWell(
          customBorder: const CircleBorder(),
          key: ref.read(senderoGuideTargetsProvider).keyFor('menu'),
          onTap: () {
            Scaffold.of(context).openDrawer();
            ref.read(senderoGuideProvider.notifier).onAction('menu');
          },
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

class _HomeButton extends ConsumerWidget {
  const _HomeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Volver a la portada',
    icon: const Icon(Icons.home_outlined, color: ArcanumColors.goldLight),
    onPressed: () {
      ref.read(cieloCaraProvider.notifier).set(0);
      context.go('/hoy');
    },
  );
}
