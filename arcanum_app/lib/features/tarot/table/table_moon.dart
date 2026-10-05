/// Luz de la Luna sobre la mesa (especificacion §6), el `moonLight` del
/// prototipo: con Luna llena baja una luz plateada desde arriba; con Luna
/// nueva la mesa queda casi a oscuras. La fase se dibuja en la cabecera.
///
/// Es una capa ESTATICA: solo cambia cuando cambia la Luna, con un fundido
/// de 2,5 s. La especificacion (§9) avisa de que una capa animada encima del
/// paño costaba la mitad de los fps en el prototipo.
///
/// Que Luna: la de la lectura si ya se interpreto (la «fase registrada»);
/// si no, la de ahora. Sin dato, no hay luz ni disco.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../shared/widgets/moon_disc.dart';
import '../domain/table_models.dart';

class TableMoon {
  const TableMoon({
    required this.illumination,
    required this.waxing,
    required this.phaseName,
    this.ofReading = false,
  });

  /// Lo que devuelve `/astral/moon` (`lunar_calendar.MoonInfo`).
  static TableMoon? fromApi(Map<String, dynamic> j) {
    final f = (j['illumination'] as num?)?.toDouble();
    if (f == null) return null;
    return TableMoon(
      illumination: f.clamp(0.0, 1.0),
      waxing: j['is_waxing'] as bool? ?? true,
      phaseName: j['phase_name'] as String? ?? '',
    );
  }

  /// La Luna anotada al interpretar. Solo viaja la iluminacion y el nombre
  /// de la fase: si crece o mengua se lee del nombre.
  static TableMoon? fromReading(Interpretation r) {
    final f = r.moonIllumination;
    if (f == null) return null;
    final name = r.moonPhase ?? '';
    return TableMoon(
      illumination: f.clamp(0.0, 1.0),
      waxing: !name.toLowerCase().contains('menguante'),
      phaseName: name,
      ofReading: true,
    );
  }

  /// 0 nueva, 1 llena.
  final double illumination;
  final bool waxing;
  final String phaseName;

  /// Es la de la lectura, no la de ahora.
  final bool ofReading;

  int get percent => (illumination * 100).round();

  /// Lo que se dice al tocar el disco, como en el prototipo.
  String get info =>
      '${phaseName.isEmpty ? 'Luna' : phaseName} · $percent %. '
      'La luz de la mesa sigue a la Luna${ofReading ? ' de esta lectura' : ''}.';
}

/// La Luna de ahora, para la mesa sin lectura. Sin red, sin luz.
final tableMoonNowProvider = FutureProvider.autoDispose<TableMoon?>((
  ref,
) async {
  try {
    return TableMoon.fromApi(await ref.read(arcanumApiProvider).moon());
  } on Object {
    return null;
  }
});

/// La Luna que manda: la de la lectura si la hay; si no, la de ahora.
TableMoon? tableMoonFor(Interpretation? reading, TableMoon? now) =>
    (reading == null ? null : TableMoon.fromReading(reading)) ?? now;

/// La capa de luz. Cambia con un fundido de 2,5 s (de golpe con «reducir
/// movimiento»); entre cambios no pide ningun fotograma.
class MoonlightLayer extends StatelessWidget {
  const MoonlightLayer({super.key, required this.illumination});

  final double illumination;

  static const fade = Duration(milliseconds: 2500);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: illumination),
          duration: still ? Duration.zero : fade,
          builder: (context, f, _) =>
              CustomPaint(size: Size.infinite, painter: MoonlightPainter(f)),
        ),
      ),
    );
  }
}

/// Los dos degradados del prototipo: luz plateada en elipse que baja desde
/// arriba (85 % x 55 %, centrada en 50 %, -5 %, apagada al 70 %) y un velo
/// oscuro parejo que crece cuanto menos luz hay.
class MoonlightPainter extends CustomPainter {
  MoonlightPainter(this.illumination);

  final double illumination;

  /// Opacidad de la luz plateada en el centro.
  double get silver => .2 * illumination;

  /// Opacidad del velo oscuro.
  double get veil => .34 * (1 - illumination);

  @override
  void paint(Canvas canvas, Size size) {
    if (veil > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(3, 3, 10, veil),
      );
    }
    if (silver > 0) {
      final rx = size.width * .85, ry = size.height * .55;
      canvas
        ..save()
        ..translate(size.width / 2, size.height * -.05)
        ..scale(1, ry / rx)
        ..drawCircle(
          Offset.zero,
          rx,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.fromRGBO(205, 218, 255, silver),
                const Color.fromRGBO(205, 218, 255, 0),
              ],
              stops: const [0, .7],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(MoonlightPainter old) => old.illumination != illumination;
}

/// El disco de la fase en la cabecera; tocarlo dice la fase y su luz.
class MoonBadge extends StatelessWidget {
  const MoonBadge({super.key, required this.moon, required this.onTap});

  final TableMoon moon;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Fase lunar',
    onPressed: () => onTap(moon.info),
    icon: Semantics(
      label: '${moon.phaseName}, ${moon.percent} % iluminada',
      child: MoonDisc(
        illumination: moon.illumination,
        waxing: moon.waxing,
        size: 24,
      ),
    ),
  );
}
