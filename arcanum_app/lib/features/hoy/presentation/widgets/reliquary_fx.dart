import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/arcanum_colors.dart';

/// Reloj del «Atlas de reliquias»: UN solo ticker para toda la portada.
///
/// Los cuatro efectos del prototipo (aurora 14 s ida y vuelta, orbe 6 s,
/// destello 7 s y pasada de luz 8 s) se leen de la misma fase: el ciclo dura
/// 168 s, el minimo comun de 28, 6, 7 y 8, asi que ninguno salta al repetir.
///
/// Con `MediaQuery.disableAnimations` no hay ticker: [of] devuelve null y cada
/// efecto se queda en su pose de reposo (sin destellos). Fuera de la pantalla
/// el `TickerMode` del shell lo silencia solo.
class ReliquaryClock extends StatefulWidget {
  const ReliquaryClock({super.key, required this.child});

  final Widget child;

  static const cycleSeconds = 168.0;

  /// Interruptor de la vida ambiental. Solo lo apaga la suite de tests
  /// (`test/flutter_test_config.dart`): un ticker sin fin no deja asentarse a
  /// `pumpAndSettle` en ninguna prueba que pase por la portada. Los tests del
  /// propio movimiento lo vuelven a encender.
  @visibleForTesting
  static bool ambientMotion = true;

  static bool _still(BuildContext context) =>
      !ambientMotion || MediaQuery.disableAnimationsOf(context);

  /// Segundos dentro del ciclo, o null si el movimiento esta apagado.
  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReliquaryScope>()?.animation;

  @override
  State<ReliquaryClock> createState() => _ReliquaryClockState();
}

class _ReliquaryClockState extends State<ReliquaryClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 168),
  );
  late final Animation<double> _seconds = _c.drive(
    Tween(begin: 0, end: ReliquaryClock.cycleSeconds),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ReliquaryClock._still(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ReliquaryScope(
    animation: ReliquaryClock._still(context) ? null : _seconds,
    child: widget.child,
  );
}

class _ReliquaryScope extends InheritedWidget {
  const _ReliquaryScope({required this.animation, required super.child});

  final Animation<double>? animation;

  @override
  bool updateShouldNotify(_ReliquaryScope old) => old.animation != animation;
}

/// Fase 0..1 de un efecto de periodo [period] dentro del reloj.
double _phase(double seconds, double period) => (seconds % period) / period;

/// Construye [builder] con los segundos del reloj (o null en reposo). El
/// repintado queda encerrado en su propia capa: el resto de la placa no se
/// vuelve a pintar a cada fotograma.
class _Ticking extends StatelessWidget {
  const _Ticking({required this.builder});

  final Widget Function(double? seconds) builder;

  @override
  Widget build(BuildContext context) {
    final clock = ReliquaryClock.of(context);
    if (clock == null) return builder(null);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: clock,
        builder: (_, _) => builder(clock.value),
      ),
    );
  }
}

/// Fondo de la portada: tinta con dos brumas fijas -- agua lunar arriba y vino
/// abajo a la derecha. Estatico: se pinta una vez.
class ReliquaryBackdrop extends StatelessWidget {
  const ReliquaryBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
    child: CustomPaint(painter: _BackdropPainter(), size: Size.infinite),
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  void _haze(Canvas canvas, Offset c, Size r, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, r.height / r.width);
    final radius = r.width;
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ArcanumColors.background,
    );
    // elipses del prototipo: azul a 50 % / 15 %, vino a 80 % / 78 %
    _haze(
      canvas,
      Offset(size.width * .5, size.height * .15),
      Size(size.width * .62, size.height * .5),
      ArcanumColors.elementWater.withValues(alpha: .30),
    );
    _haze(
      canvas,
      Offset(size.width * .8, size.height * .78),
      Size(size.width * .7, size.height * .42),
      ArcanumColors.burgundy.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

final _auroraCore = ArcanumColors.moonGlow.withValues(alpha: .11);
final _auroraEdge = ArcanumColors.moonGlow.withValues(alpha: 0);

/// Bruma lunar que cruza el cielo vivo (14 s de ida y otros tantos de vuelta).
class ReliquaryAurora extends StatelessWidget {
  const ReliquaryAurora({super.key});

  @override
  Widget build(BuildContext context) => _Ticking(
    builder: (s) {
      // reposo: a medio camino, como queda el prototipo sin movimiento
      final double p;
      if (s == null) {
        p = .5;
      } else {
        final raw = _phase(s, 28) * 2;
        p = Curves.easeInOut.transform(raw <= 1 ? raw : 2 - raw);
      }
      return LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth * .75;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -box.maxWidth * .25 + w * (-.22 + .97 * p),
                top: -box.maxHeight * .65,
                width: w,
                height: box.maxHeight * 2.1,
                child: Transform.rotate(
                  angle: -18 * math.pi / 180,
                  child: Opacity(
                    opacity: .45 + .25 * p,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: .65,
                          colors: [_auroraCore, _auroraEdge],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// El instrumento de la Luna: tres aros de oro que respiran (6 s) con la fase
/// real dentro.
class ReliquaryOrb extends StatelessWidget {
  const ReliquaryOrb({super.key, required this.child, this.size = 76});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => _Ticking(
    builder: (s) {
      final b = s == null ? 0.0 : math.pow(math.sin(math.pi * _phase(s, 6)), 2);
      return Transform.scale(
        scale: 1 + .025 * b,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ArcanumColors.gold.withValues(alpha: .47),
            ),
            boxShadow: [
              BoxShadow(
                color: ArcanumColors.gold.withValues(alpha: .4),
                blurRadius: 40 - 8 * b.toDouble(),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(9),
                child: _ring(ArcanumColors.gold.withValues(alpha: .33)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _ring(ArcanumColors.goldLight.withValues(alpha: .27)),
              ),
              child,
            ],
          ),
        ),
      );
    },
  );

  static Widget _ring(Color c) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: c),
    ),
    child: const SizedBox.expand(),
  );
}

/// Destello de la Mesa: un hilo de luz que recorre el canto superior (7 s) y
/// una pasada de luz muy tenue por la placa (8 s). En reposo no hay ninguno.
class ReliquaryGlint extends StatelessWidget {
  const ReliquaryGlint({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _Ticking(
      builder: (s) => s == null
          ? const SizedBox.expand()
          : CustomPaint(painter: _GlintPainter(s), size: Size.infinite),
    ),
  );
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    // pasada de luz: entre el 25 y el 46 % del ciclo de 8 s
    final l = _phase(seconds, 8);
    if (l > .25 && l < .46) {
      final t = (l - .25) / .21;
      final opacity = t < .33 ? t / .33 : 1 - (t - .33) / .67;
      final band = size.width * 2.2;
      // el centro de la banda cruza de derecha a izquierda
      final x = size.width * (1.5 - 2.0 * t);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-1, -.36),
            end: const Alignment(1, .36),
            colors: [
              Colors.transparent,
              ArcanumColors.goldLight.withValues(alpha: .05 * opacity),
              Colors.transparent,
            ],
            stops: const [.25, .46, .65],
          ).createShader(Rect.fromLTWH(x - band / 2, 0, band, size.height)),
      );
    }
    // hilo del canto: entre el 18 y el 35 % del ciclo de 7 s
    final g = _phase(seconds, 7);
    if (g > .18 && g < .35) {
      final t = (g - .18) / .17;
      final opacity = t < .3 ? t / .3 * .9 : .9 * (1 - (t - .3) / .7);
      final w = size.width * .55;
      final left = size.width * (-.8 + 2.0 * t);
      final rect = Rect.fromLTWH(left, 0, w, 2);
      final shader = LinearGradient(
        colors: [
          Colors.transparent,
          ArcanumColors.goldLight.withValues(alpha: .67 * opacity),
          ArcanumColors.ivory.withValues(alpha: opacity),
          Colors.transparent,
        ],
        stops: const [0, .45, .6, 1],
      ).createShader(rect);
      canvas.drawRect(
        rect.inflate(3),
        Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRect(rect, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.seconds != seconds;
}

/// Marcas de las placas, dibujadas (nada de caracteres de fuente: cada
/// Android pinta los suyos). Trazo fino sobre 24.
enum ReliquaryMark {
  sparkle(
    '<path d="M12 3l1.6 6.9L20.5 12l-6.9 1.6L12 20.5l-1.6-6.9L3.5 12l6.9-2.1z"/>',
  ),
  crescent('<path d="M15.5 4.5a8 8 0 1 0 4 12.7 6.4 6.4 0 1 1-4-12.7z"/>'),
  quill(
    '<path d="M4 20l3.2-.8L19 7.4a1.9 1.9 0 0 0-2.7-2.7L4.6 16.6z"/><path d="M14.8 6.3l2.8 2.8"/>',
  ),
  asterisk(
    '<path d="M12 3.5v17M3.5 12h17M6 6l12 12M18 6L6 18"/><circle cx="12" cy="12" r="1.6"/>',
  ),
  star(
    '<path d="M12 3l2.2 6.8L21 12l-6.8 2.2L12 21l-2.2-6.8L3 12l6.8-2.2z" fill="#000"/>',
  );

  const ReliquaryMark(this.paths);
  final String paths;

  Widget draw({double size = 18, Color color = ArcanumColors.goldLight}) =>
      SvgPicture.string(
        '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.4" '
        'stroke-linecap="round" stroke-linejoin="round">$paths</svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

/// Matriz que desatura a [saturation] (1 = intacto) y multiplica el alfa por
/// [alpha]. Un solo filtro: grabados y laminas a medio tono sin dos capas.
ColorFilter reliquaryTone({double saturation = 1, double alpha = 1}) {
  const r = .2126, g = .7152, b = .0722;
  final s = saturation, i = 1 - s;
  return ColorFilter.matrix([
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, alpha, 0, //
  ]);
}
