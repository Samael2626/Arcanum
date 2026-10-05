/// Humo de la mesa (especificacion §6), el `fx.smoke` del prototipo: sale al
/// romperse el sello (16 volutas) y al cerrar el circulo (26, desde el
/// centro del bordado), sube, se ensancha y se apaga en 1,4 a 2,8 s.
///
/// Va en coordenadas de pantalla, encima de la mesa: el humo sube hacia
/// arriba de la pantalla aunque la mesa este girada, como en el prototipo.
/// Cada voluta se calcula por el tiempo, no por fotograma: a 30 o a 60 fps
/// esta en el mismo sitio. Con «reducir movimiento» no hay humo.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'table_quality.dart';

/// Cola de bocanadas pedidas por la mesa. La capa de humo las recoge.
class SmokeEmitter extends ChangeNotifier {
  final List<({Offset at, int count})> _queue = [];

  /// Echa `count` volutas en el punto `at` de la pantalla.
  void puff(Offset at, int count) {
    _queue.add((at: at, count: count));
    notifyListeners();
  }

  List<({Offset at, int count})> take() {
    final out = List.of(_queue);
    _queue.clear();
    return out;
  }
}

/// Una voluta. Los numeros son los del prototipo, por fotograma a 60 Hz.
class SmokeWisp {
  const SmokeWisp({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.dl,
    required this.born,
    required this.phase,
  });

  factory SmokeWisp.at(Offset at, Duration born, math.Random rnd) => SmokeWisp(
    x: at.dx + (rnd.nextDouble() - .5) * 20,
    y: at.dy,
    vx: (rnd.nextDouble() - .5) * .35,
    vy: -.5 - rnd.nextDouble() * .7,
    r: 6 + rnd.nextDouble() * 8,
    dl: .006 + rnd.nextDouble() * .006,
    born: born,
    phase: rnd.nextDouble() * math.pi * 2,
  );

  final double x, y, vx, vy, r, dl;
  final Duration born;
  final double phase;

  /// Fotogramas de 60 Hz desde que salio.
  double framesAt(Duration now) => (now - born).inMicroseconds / 16667;

  /// Vida que le queda (de 1 a 0).
  double lifeAt(Duration now) => 1 - dl * framesAt(now);

  /// Centro y radio en `now`: sube, se mece y se ensancha.
  ({Offset center, double radius}) at(Duration now) {
    final f = framesAt(now);
    return (
      center: Offset(x + vx * f + math.sin(f * 2 / 60 + phase) * 3, y + vy * f),
      radius: r + .22 * f,
    );
  }
}

class SmokePainter extends CustomPainter {
  SmokePainter(this.wisps, this.now);

  final List<SmokeWisp> wisps;
  final Duration now;

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in wisps) {
      final life = w.lifeAt(now);
      if (life <= 0) continue;
      final p = w.at(now);
      canvas.drawCircle(
        p.center,
        p.radius,
        Paint()
          ..shader = ui.Gradient.radial(p.center, p.radius, [
            Color.fromRGBO(215, 205, 190, .22 * life),
            const Color.fromRGBO(215, 205, 190, 0),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(SmokePainter old) =>
      old.now != now || !identical(old.wisps, wisps);
}

/// La capa de humo: escucha al emisor y pinta mientras quede alguna voluta.
class SmokeLayer extends StatefulWidget {
  const SmokeLayer({super.key, required this.emitter, this.random});

  final SmokeEmitter emitter;

  /// Azar inyectable para las pruebas.
  final math.Random? random;

  @override
  State<SmokeLayer> createState() => _SmokeLayerState();
}

class _SmokeLayerState extends State<SmokeLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final math.Random _rnd = widget.random ?? math.Random();
  List<SmokeWisp> _wisps = const [];
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.emitter.addListener(_drain);
  }

  @override
  void didUpdateWidget(SmokeLayer old) {
    super.didUpdateWidget(old);
    if (old.emitter != widget.emitter) {
      old.emitter.removeListener(_drain);
      widget.emitter.addListener(_drain);
    }
  }

  @override
  void dispose() {
    widget.emitter.removeListener(_drain);
    _ticker.dispose();
    super.dispose();
  }

  void _drain() {
    final puffs = widget.emitter.take();
    if (!mounted || puffs.isEmpty) return;
    // con «reducir movimiento» no hay humo, como en el prototipo
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    // el reloj del ticker vuelve a cero al arrancar: lo nuevo nace ahi
    final idle = !_ticker.isActive;
    if (idle) _now = Duration.zero;
    setState(() {
      _wisps = [
        ..._wisps,
        for (final p in puffs)
          for (var i = 0; i < p.count; i++) SmokeWisp.at(p.at, _now, _rnd),
      ];
    });
    if (idle) _ticker.start();
  }

  void _tick(Duration elapsed) {
    final alive = [
      for (final w in _wisps)
        if (w.lifeAt(elapsed) > 0) w,
    ];
    setState(() {
      _now = elapsed;
      _wisps = alive;
    });
    if (alive.isEmpty) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_wisps.isEmpty) return const SizedBox.shrink();
    final half = TableQualityScope.levelOf(context) >= 2;
    // a medio ritmo: el humo cambia cada dos fotogramas
    final shown = half
        ? Duration(microseconds: (_now.inMicroseconds ~/ 33333) * 33333)
        : _now;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: SmokePainter(_wisps, shown),
        ),
      ),
    );
  }
}
