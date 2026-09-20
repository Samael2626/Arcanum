import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import '../../shared/widgets/arcanum_toggle.dart';

/// El cajon de la cuenta: lo que no es una seccion.
///
/// La barra de abajo NO se toca. Sus cinco destinos son las cinco ramas del
/// shell y siguen siendo los mismos; esto cuelga del avatar y solo guarda lo
/// que hoy estaba encadenado uno dentro de otro.
///
/// QUE GANA Y QUE PIERDE, CONTADO
///
///   Perfil      1 -> 2 toques   (abrir el cajon, y luego Perfil)
///   Ajustes     2 -> 2
///   Privacidad  3 -> 2          deja de vivir dentro de Ajustes
///
/// O sea que NO ahorra toques: los reparte. Lo que compra es un sitio donde
/// poner lo que venga sin pelear por una sexta pestana.
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
  const ArcanumDrawer({super.key});

  /// Cuanto deja ver. Por debajo de esto el texto de dentro empieza a pelearse
  /// con lo que hay detras.
  static const _opacidad = 0.88;

  static const _blur = 14.0;

  @override
  Widget build(BuildContext context) {
    final base = ArcanumResin.gradient(mood: ArcanumMood.neutral);
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.72,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(ArcanumSelection.radius),
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
                  for (final c in base.colors)
                    c.withValues(alpha: _opacidad),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
                    child: SectionLabel('TU CUENTA'),
                  ),
                  _Fila(
                    icono: Icons.person_outline,
                    iconoActivo: Icons.person,
                    rotulo: 'Perfil',
                    ruta: '/perfil',
                  ),
                  _Fila(
                    icono: Icons.tune_outlined,
                    iconoActivo: Icons.tune,
                    rotulo: 'Ajustes',
                    ruta: '/settings',
                  ),
                  // Privacidad sube aqui: estaba a tres toques metida dentro de
                  // Ajustes, y es la pantalla que hay que poder encontrar sin
                  // buscarla.
                  _Fila(
                    icono: Icons.privacy_tip_outlined,
                    iconoActivo: Icons.privacy_tip,
                    rotulo: 'Privacidad y datos',
                    ruta: '/privacy',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila del cajon, con la regla de seleccion de la casa.
///
/// Cero filete. El estado lo llevan el color, el peso y el icono relleno --
/// los tres juntos, como manda [ArcanumSelection]. Aqui "activo" significa que
/// esa pantalla es la que esta abierta detras del cajon.
class _Fila extends StatelessWidget {
  const _Fila({
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
    final estilo = ArcanumSelection.textStyle(aqui, size: 16);

    return Semantics(
      button: true,
      selected: aqui,
      label: rotulo,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          if (!aqui) context.push(ruta);
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
                    ArcanumSelection.icon(aqui, icono, iconoActivo),
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
