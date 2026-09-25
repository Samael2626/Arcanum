import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../content/sections.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/bloque_saldo.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import '../../shared/widgets/arcanum_toggle.dart';

/// El cajon: TODA la navegacion, desde que la barra de abajo dejo de existir.
///
/// Hasta el 21-sep-2026 esto guardaba solo lo secundario -- Perfil, Ajustes,
/// Privacidad -- y las cinco secciones vivian en una `NavigationBar`. Ahora
/// cuelgan las dos cosas del mismo cajon, separadas por una linea.
///
/// LAS SECCIONES NO SE ESCRIBEN AQUI. Salen de `arcanumSections`, que sigue
/// siendo la fuente unica: el indice de cada fila es el indice de su rama del
/// shell, igual que lo era el del destino de la barra. Ese invariante no lo
/// cambio el quitar la barra, solo cambio quien lo dibuja.
///
/// QUE CUESTA, CONTADO
///
///   Cielo       0 -> 0   es el arranque del router
///   Las otras   1 -> 2   abrir el cajon, y luego la seccion
///   Perfil      2 -> 2
///   Ajustes     2 -> 2
///   Privacidad  2 -> 2
///
/// O sea que lo diario pasa de 4 toques a 8. Se acepta a sabiendas.
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
class ArcanumDrawer extends StatelessWidget {
  const ArcanumDrawer({super.key, required this.navigationShell});

  /// El mismo shell que dibuja el cuerpo. Hace falta para dos cosas: saber que
  /// rama esta abierta (que fila va marcada) y cambiar de rama sin perder su
  /// pila, que es lo que daba `goBranch` a la barra.
  final StatefulNavigationShell navigationShell;

  /// Cuanto deja ver. Por debajo de esto el texto de dentro empieza a pelearse
  /// con lo que hay detras.
  static const _opacidad = 0.88;

  static const _blur = 14.0;

  @override
  Widget build(BuildContext context) {
    final base = ArcanumResin.gradient(mood: ArcanumMood.neutral);
    final indice = navigationShell.currentIndex;

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
                    // El saldo, ARRIBA. Es lo unico de aqui que antes no se
                    // podia ver sin chocar antes con un 402, asi que va donde
                    // se mira primero. Lo que desplaza esta contado en la nota
                    // de la 1.0.6: a 360 dp el cajon ya scrolleaba antes de
                    // esto, y lo que baja del pliegue es "Privacidad y datos".
                    const BloqueSaldoCajon(),
                    for (var i = 0; i < arcanumSections.length; i++)
                      _FilaSeccion(
                        seccion: arcanumSections[i],
                        activa: i == indice,
                        // `initialLocation` solo cuando ya estas en esa rama:
                        // es lo que hacia la barra, y sirve para salir de una
                        // sub-ruta sin buscar el boton de volver.
                        onTap: () => navigationShell.goBranch(
                          i,
                          initialLocation: i == indice,
                        ),
                      ),
                    const _Separador(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: SectionLabel('TU CUENTA'),
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

/// La linea que separa las secciones de la cuenta. Sin filete a los lados: se
/// para donde para el texto de las filas.
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
  });

  final IconData icono;
  final IconData iconoActivo;
  final String rotulo;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final estilo = ArcanumSelection.textStyle(activa, size: 16);

    return Semantics(
      button: true,
      selected: activa,
      label: rotulo,
      child: InkWell(
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

/// Una seccion: cambia de RAMA, no apila. Aqui "activa" significa que su rama
/// es la que esta abierta detras del cajon.
class _FilaSeccion extends StatelessWidget {
  const _FilaSeccion({
    required this.seccion,
    required this.activa,
    required this.onTap,
  });

  final ArcanumSection seccion;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Fila(
    icono: seccion.icon,
    iconoActivo: seccion.selectedIcon,
    rotulo: seccion.title,
    activa: activa,
    onTap: onTap,
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
  });

  final IconData icono;
  final IconData iconoActivo;
  final String rotulo;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    final aqui = GoRouterState.of(context).uri.path == ruta;
    return _Fila(
      icono: icono,
      iconoActivo: iconoActivo,
      rotulo: rotulo,
      activa: aqui,
      onTap: () {
        if (!aqui) context.push(ruta);
      },
    );
  }
}
