/// Revelado (D7): una pieza por pantalla, en vertical. El fondo de cada pieza
/// funde con el de la siguiente, cada pieza entra al llegar a ella y una franja
/// de contexto arriba dice donde estas. Con «reducir movimiento», sin animar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

class RevealPager extends StatefulWidget {
  const RevealPager({
    super.key,
    required this.count,
    required this.page,
    required this.background,
    this.header,
    this.headerHeight = 0,
  });

  final int count;

  /// Pieza `i`; `active` es true mientras es la que se ve.
  final Widget Function(BuildContext context, int i, bool active) page;
  final Widget Function(BuildContext context, int i) background;

  /// Franja de contexto: recibe la pieza actual y como saltar a otra.
  final Widget Function(
    BuildContext context,
    int current,
    ValueChanged<int> go,
  )?
  header;
  final double headerHeight;

  @override
  State<RevealPager> createState() => RevealPagerState();
}

class RevealPagerState extends State<RevealPager> {
  final _pages = PageController();
  int _current = 0;

  int get current => _current;

  void go(int i) {
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          top: widget.headerHeight,
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 900),
            child: KeyedSubtree(
              key: ValueKey(_current),
              child: widget.background(context, _current),
            ),
          ),
        ),
        Positioned.fill(
          top: widget.headerHeight,
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: widget.count,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => widget.page(context, i, i == _current),
          ),
        ),
        if (widget.header case final header?)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: widget.headerHeight,
            child: header(context, _current, go),
          ),
      ],
    );
  }
}

/// Entra al llegar a su pieza: sube un poco y aparece, con un retraso por
/// orden (`step`) para que el texto se revele por partes.
class RevealIn extends StatefulWidget {
  const RevealIn({
    super.key,
    required this.active,
    required this.child,
    this.step = 0,
  });

  final bool active;
  final int step;
  final Widget child;

  @override
  State<RevealIn> createState() => _RevealInState();
}

class _RevealInState extends State<RevealIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 700 + widget.step * 140),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(first: true);
  }

  @override
  void didUpdateWidget(RevealIn old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync({bool first = false}) {
    if (!widget.active) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!first || _c.value == 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.step * 140 / (700 + widget.step * 140);
    final t = CurvedAnimation(
      parent: _c,
      curve: Interval(lead, 1, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// La pieza se voltea al llegar a ella (de canto a de frente). `reversed` la
/// deja boca abajo: una carta invertida entra invertida.
class RevealFlip extends StatefulWidget {
  const RevealFlip({
    super.key,
    required this.active,
    required this.child,
    this.reversed = false,
  });

  final bool active;
  final bool reversed;
  final Widget child;

  @override
  State<RevealFlip> createState() => _RevealFlipState();
}

class _RevealFlipState extends State<RevealFlip>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(first: true);
  }

  @override
  void didUpdateWidget(RevealFlip old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync({bool first = false}) {
    if (!widget.active) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!first || _c.value == 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: const Cubic(.2, .8, .2, 1));
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0016)
          ..rotateY((1 - t.value) * math.pi * .49)
          ..rotateZ(widget.reversed ? math.pi : 0),
        child: Opacity(opacity: t.value.clamp(0, 1), child: child),
      ),
    );
  }
}

/// Mantener pulsado `hold` para confirmar, con un anillo que se llena: el
/// mismo gesto que el bordado del paño. Soltar antes no hace nada.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.hold = const Duration(milliseconds: 1300),
    this.size = 104,
  });

  final String label;
  final VoidCallback onConfirm;
  final Duration hold;
  final double size;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onConfirm();
    });

  void _start() => _c.forward(from: 0);
  void _stop() {
    if (!_c.isCompleted) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    // el lector de pantalla no mantiene: su doble toque confirma
    onTap: widget.onConfirm,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _Ring(_c.value),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    color: ArcanumColors.goldLight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Ring extends CustomPainter {
  const _Ring(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas
      ..drawCircle(
        c,
        r,
        Paint()..color = ArcanumColors.background.withValues(alpha: .55),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: .35),
      );
    if (t > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = ArcanumColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.t != t;
}
