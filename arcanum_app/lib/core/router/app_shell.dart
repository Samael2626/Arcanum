import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'arcanum_drawer.dart';

import '../content/sections.dart';
import '../state/flow_providers.dart';
import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import '../../shared/widgets/info_dot.dart';
import '../../features/hoy/presentation/widgets/reliquary_fx.dart';
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
          // Se reconstruye en cada navegación para saber si estamos en una
          // raíz de sección (mostrar barra), en una sub-ruta (ocultarla) o en
          // la portada (cabecera del Atlas de reliquias y su fondo).
          body: Consumer(
            builder: (context, ref, _) {
              final cara = ref.watch(cieloCaraProvider);
              return AnimatedBuilder(
                animation: router.routerDelegate,
                builder: (context, _) {
                  final location =
                      router.routerDelegate.currentConfiguration.uri.path;
                  final section = arcanumSectionForRoute(location);
                  final portada = location == '/hoy' && cara == 0;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: portada
                            ? const ReliquaryBackdrop()
                            : const SizedBox.shrink(),
                      ),
                      SafeArea(
                        child: Column(
                          children: [
                            if (portada)
                              const _PortadaBar()
                            else if (section != null)
                              _SectionBar(section: section),
                            Expanded(child: navigationShell),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
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

/// Cabecera de la portada, la del Atlas de reliquias: hamburguesa, la marca,
/// que es esto en llano y el sello de la cuenta. Sin «?», sin casa y sin
/// pestanas: la portada ES la casa, y la carta tiene su entrada en el cielo
/// vivo.
class _PortadaBar extends StatelessWidget {
  const _PortadaBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(9, 12, 14, 6),
    child: Row(
      children: [
        const _MenuPrincipal(color: ArcanumColors.goldLight, size: 26),
        const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // la marca no se parte nunca: con letra grande se encoge
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ARCANUM',
                    maxLines: 1,
                    style: ArcanumText.wordmark(size: 27).copyWith(
                      letterSpacing: 2.2,
                      color: ArcanumColors.goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cielo · tu carta natal y lo que hoy la toca',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _AccountSeal(),
      ],
    ),
  );
}

/// El sello de la cuenta: la Luna en bronce. Abre el mismo menu, que guarda
/// la cuenta al pie.
class _AccountSeal extends StatelessWidget {
  const _AccountSeal();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Abrir tu cuenta',
    child: Semantics(
      button: true,
      label: 'Abrir tu cuenta y el menú',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('portada-cuenta'),
        customBorder: const CircleBorder(),
        onTap: () => Scaffold.of(context).openDrawer(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ArcanumColors.gold.withValues(alpha: .47),
                ),
                gradient: const RadialGradient(
                  center: Alignment(-.4, -.8),
                  radius: .9,
                  colors: [
                    ArcanumColors.reliquarySealLight,
                    ArcanumColors.reliquarySealDark,
                  ],
                  stops: [0, .7],
                ),
              ),
              alignment: Alignment.center,
              child: ReliquaryMark.crescent.draw(size: 22),
            ),
          ),
        ),
      ),
    ),
  );
}

/// La hamburguesa abre el mapa de la app. Su zona tactil mide 48.
class _MenuPrincipal extends ConsumerWidget {
  const _MenuPrincipal({this.color = ArcanumColors.gold, this.size = 22});

  final Color color;
  final double size;

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
              child: Icon(Icons.menu, size: size, color: color),
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
