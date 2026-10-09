import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si la cabecera de la portada esta a la vista.
///
/// La cabecera vive en el shell (lleva la clave unica del Sendero para el
/// menu y no puede repetirse dentro de la lista), pero se comporta como un
/// `SliverAppBar` flotante: se va al bajar y vuelve al subir un poco. La lista
/// de la portada lo decide con [PortadaHeaderScroll]; el shell solo escucha.
class PortadaHeaderShown extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool shown) {
    if (state != shown) state = shown;
  }
}

final portadaHeaderShownProvider = NotifierProvider<PortadaHeaderShown, bool>(
  PortadaHeaderShown.new,
);

/// Envuelve la lista de la portada y traduce su scroll en mostrar u ocultar
/// la cabecera. Solo la lista principal (profundidad 0) cuenta.
class PortadaHeaderScroll extends ConsumerWidget {
  const PortadaHeaderScroll({super.key, required this.child});

  final Widget child;

  /// Arriba del todo la cabecera siempre se ve.
  static const _top = 24.0;

  /// Movimiento minimo para decidir: un temblor del dedo no la esconde.
  static const _slop = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
          final delta = n.scrollDelta ?? 0;
          final header = ref.read(portadaHeaderShownProvider.notifier);
          if (n.metrics.pixels <= _top) {
            header.set(true);
          } else if (delta > _slop) {
            header.set(false);
          } else if (delta < -_slop) {
            header.set(true);
          }
          return false;
        },
        child: child,
      );
}
