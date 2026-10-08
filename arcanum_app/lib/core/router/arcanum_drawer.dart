import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/bloque_saldo.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import '../../shared/widgets/arcanum_toggle.dart';
import '../../features/sendero/application/sendero_guide_controller.dart';
import '../state/flow_providers.dart';

/// Mapa de las secciones y sus accesos directos.
///
/// LA EXCEPCION DE MATERIAL, DICHA EN VOZ ALTA
///
/// Resina es OPACA, y de esa decision salio el veredicto de rendimiento: sin
/// desenfoque no hay `saveLayer` que medir. Este cajon es la unica pieza de la
/// app que se salta esa regla: lleva `BackdropFilter`, porque se pidio vidrio.
///
/// Se acepta porque el coste esta ACOTADO, y conviene saber por que:
///
///   · el `Drawer` no existe hasta que se abre -- fuera de ese momento no
///     cuesta nada, ni siquiera un widget en el arbol;
///   · lo que desenfoca es una pantalla QUIETA, no una lista con scroll, que
///     era el caso que hundia al vidrio cuando se midio;
///   · es una sola capa, no una por componente.
///
/// Si algun dia esto se nota, lo que se quita es el desenfoque y no la
/// transparencia: el alfa del degradado ya deja ver lo de detras y ese no
/// cuesta nada.
class ArcanumDrawer extends ConsumerWidget {
  const ArcanumDrawer({super.key, required this.navigationShell});

  /// Se conserva la firma mientras el shell comparte este cajon con rutas
  /// apiladas. Los mosaicos cambian de rama mediante sus rutas existentes.
  final StatefulNavigationShell navigationShell;

  /// Cuanto deja ver. Por debajo de esto el texto de dentro empieza a pelearse
  /// con lo que hay detras.
  static const _opacidad = 0.88;

  static const _blur = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ArcanumResin.gradient(mood: ArcanumMood.neutral);
    final targets = ref.read(senderoGuideTargetsProvider);
    final path = GoRouterState.of(context).uri.path;
    final cieloCara = ref.watch(cieloCaraProvider);

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.72,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(ArcanumSelection.radius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: base.begin,
                end: base.end,
                stops: base.stops,
                colors: [
                  for (final c in base.colors) c.withValues(alpha: _opacidad),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
                      child: SectionLabel('ARCANUM'),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: SectionLabel('CIELO'),
                    ),
                    _Fila(
                      icono: Icons.wb_twilight_outlined,
                      iconoActivo: Icons.wb_twilight,
                      rotulo: 'Ahora y horas',
                      activa: path == '/hoy' && cieloCara == 0,
                      onTap: () {
                        ref.read(cieloCaraProvider.notifier).set(0);
                        context.go('/hoy');
                      },
                    ),
                    _Fila(
                      icono: Icons.auto_awesome_outlined,
                      iconoActivo: Icons.auto_awesome,
                      rotulo: 'Carta natal',
                      activa: path == '/hoy' && cieloCara == 1,
                      onTap: () {
                        ref.read(cieloCaraProvider.notifier).set(1);
                        context.go('/hoy');
                      },
                    ),
                    const _FilaSeccion(
                      icono: Icons.brightness_4_outlined,
                      iconoActivo: Icons.brightness_4,
                      rotulo: 'Horóscopo',
                      ruta: '/horoscopo',
                    ),
                    const _Separador(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: SectionLabel('PRACTICAR'),
                    ),
                    const _FilaSeccion(
                      icono: Icons.style_outlined,
                      iconoActivo: Icons.style,
                      rotulo: 'Oráculo',
                      ruta: '/oraculo',
                    ),
                    const _FilaSeccion(
                      icono: Icons.menu_book_outlined,
                      iconoActivo: Icons.menu_book,
                      rotulo: 'Grimorio',
                      ruta: '/grimorio',
                    ),
                    const _FilaRuta(
                      icono: Icons.air_outlined,
                      iconoActivo: Icons.air,
                      rotulo: 'Respirar',
                      ruta: '/respirar',
                    ),
                    const _FilaRuta(
                      icono: Icons.auto_fix_high_outlined,
                      iconoActivo: Icons.auto_fix_high,
                      rotulo: 'Taller de sigilos',
                      ruta: '/sigilos',
                    ),
                    if (kDebugMode || kProfileMode)
                      const _FilaRuta(
                        icono: Icons.style_outlined,
                        iconoActivo: Icons.style,
                        rotulo: 'Mesa de tarot · en pruebas',
                        ruta: '/tarot',
                      ),
                    const _Separador(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: SectionLabel('DESCUBRIR'),
                    ),
                    const _FilaSeccion(
                      icono: Icons.local_library_outlined,
                      iconoActivo: Icons.local_library,
                      rotulo: 'Saber · plantas, libros y sellos',
                      ruta: '/saber',
                    ),
                    const _Separador(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: SectionLabel('CUENTA Y AYUDA'),
                    ),
                    const BloqueSaldoCajon(),
                    const _FilaRuta(
                      icono: Icons.auto_awesome_outlined,
                      iconoActivo: Icons.auto_awesome,
                      rotulo: 'Fragmentos Arcanos',
                      ruta: '/fragmentos',
                    ),
                    _FilaRuta(
                      icono: Icons.explore_outlined,
                      iconoActivo: Icons.explore,
                      rotulo: 'Ayuda y recorrido',
                      ruta: '/sendero',
                    ),
                    _FilaRuta(
                      icono: Icons.person_outline,
                      iconoActivo: Icons.person,
                      rotulo: 'Perfil',
                      ruta: '/perfil',
                    ),
                    _FilaRuta(
                      icono: Icons.tune_outlined,
                      iconoActivo: Icons.tune,
                      rotulo: 'Ajustes',
                      ruta: '/settings',
                      tapKey: targets.keyFor('settings'),
                      onOpened: () => ref
                          .read(senderoGuideProvider.notifier)
                          .onAction('settings'),
                    ),
                    // Privacidad sube aqui: estaba a tres toques metida dentro
                    // de Ajustes, y es la pantalla que hay que poder encontrar
                    // sin buscarla.
                    _FilaRuta(
                      icono: Icons.privacy_tip_outlined,
                      iconoActivo: Icons.privacy_tip,
                      rotulo: 'Privacidad y datos',
                      ruta: '/privacy',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Separa el saldo de las opciones de cuenta.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Divider(
      height: 1,
      thickness: 1,
      color: ArcanumSelection.textStyle(false).color!.withValues(alpha: 0.24),
    ),
  );
}

/// Una fila del cajon, con la regla de seleccion de la casa.
///
/// Cero filete. El estado lo llevan el color, el peso y el icono relleno --
/// los tres juntos, como manda [ArcanumSelection].
class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.iconoActivo,
    required this.rotulo,
    required this.activa,
    required this.onTap,
    this.tapKey,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String rotulo;
  final bool activa;
  final VoidCallback onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final estilo = ArcanumSelection.textStyle(activa, size: 16);

    return Semantics(
      button: true,
      selected: activa,
      label: rotulo,
      child: InkWell(
        key: tapKey,
        // `closeDrawer` y no `Navigator.pop`: el pop depende de que el cajon
        // haya dejado una entrada de historial en la ruta, y dentro del shell
        // de go_router eso no se cumple -- el cajon se quedaba abierto encima
        // de la seccion recien abierta.
        onTap: () {
          Scaffold.of(context).closeDrawer();
          onTap();
        },
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ArcanumSelection.minTapHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    ArcanumSelection.icon(activa, icono, iconoActivo),
                    size: 20,
                    color: estilo.color,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(rotulo, style: estilo)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ruta principal del shell: sustituye la rama visible y conserva su estado.
class _FilaSeccion extends StatelessWidget {
  const _FilaSeccion({
    required this.icono,
    required this.iconoActivo,
    required this.rotulo,
    required this.ruta,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String rotulo;
  final String ruta;

  @override
  Widget build(BuildContext context) => _Fila(
    icono: icono,
    iconoActivo: iconoActivo,
    rotulo: rotulo,
    activa: GoRouterState.of(context).uri.path == ruta,
    onTap: () => context.go(ruta),
  );
}

/// Lo de la cuenta: rutas de primer nivel FUERA del shell, asi que se apilan
/// encima con `push` y se vuelve con el boton de atras.
class _FilaRuta extends StatelessWidget {
  const _FilaRuta({
    required this.icono,
    required this.iconoActivo,
    required this.rotulo,
    required this.ruta,
    this.tapKey,
    this.onOpened,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String rotulo;
  final String ruta;
  final Key? tapKey;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final aqui = GoRouterState.of(context).uri.path == ruta;
    return _Fila(
      icono: icono,
      iconoActivo: iconoActivo,
      rotulo: rotulo,
      activa: aqui,
      tapKey: tapKey,
      onTap: () {
        if (!aqui) context.push(ruta);
        onOpened?.call();
      },
    );
  }
}
