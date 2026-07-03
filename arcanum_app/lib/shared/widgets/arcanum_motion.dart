import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

/// Envuelve cualquier panel con la VIDA de las cartas del Oráculo:
/// tilt-hacia-el-puntero (parallax con perspectiva real), sway de reposo
/// (respiración lenta siempre presente) y glow pulsante opcional.
///
/// Destilado del movimiento de `TarotCardView`. Amplitudes por defecto más
/// contenidas que en una carta (un panel no debe bailar tanto). PRESENTACIONAL:
/// no altera el layout ni el hijo.
class ArcanumTilt extends StatefulWidget {
  final Widget child;

  /// Fase del sway (desfasa paneles hermanos para que no laten al unísono).
  final int phase;

  /// Amplitud máxima del tilt al puntero (rad). Paneles ~0.05, cartas ~0.20.
  final double maxTilt;

  /// Glow dorado pulsante cuando [glowing] es true (foco activo).
  final bool glowing;

  /// Color del glow (por defecto oro). Úsalo para teñir con el humor del panel.
  final Color glowColor;

  final BorderRadius? borderRadius;

  const ArcanumTilt({
    super.key,
    required this.child,
    this.phase = 0,
    this.maxTilt = 0.05,
    this.glowing = false,
    this.glowColor = ArcanumColors.gold,
    this.borderRadius,
  });

  @override
  State<ArcanumTilt> createState() => _ArcanumTiltState();
}

class _ArcanumTiltState extends State<ArcanumTilt>
    with TickerProviderStateMixin {
  late final AnimationController _engage;
  late final AnimationController _glow;
  late final AnimationController _idle;

  Offset _tilt = Offset.zero;
  bool _hovering = false;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _engage = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _glow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..repeat();
    if (widget.glowing) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ArcanumTilt old) {
    super.didUpdateWidget(old);
    if (widget.glowing && !old.glowing) {
      _glow.repeat(reverse: true);
    } else if (!widget.glowing && old.glowing) {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void dispose() {
    _engage.dispose();
    _glow.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _sync() {
    if (_hovering) {
      _engage.forward();
    } else {
      _engage.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onEnter: (_) {
            _hovering = true;
            _sync();
          },
          onHover: (e) {
            final p = e.localPosition;
            final w = _size.width, h = _size.height;
            if (w <= 0 || h <= 0) return;
            setState(() {
              _tilt = Offset(
                (p.dx / w - 0.5).clamp(-0.5, 0.5),
                (p.dy / h - 0.5).clamp(-0.5, 0.5),
              );
            });
          },
          onExit: (_) {
            _hovering = false;
            setState(() => _tilt = Offset.zero);
            _sync();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_engage, _glow, _idle]),
            builder: (context, child) => _build(child!),
            child: widget.child,
          ),
        );
      },
    );
  }

  Widget _build(Widget child) {
    final eng = Curves.easeOut.transform(_engage.value);

    // Sway de reposo: respiración desfasada por `phase`; cede al parallax.
    final it = _idle.value * 2 * math.pi;
    final swayY = math.sin(it + widget.phase * 0.9);
    final swayX = math.sin(it * 0.73 + widget.phase * 1.4);
    final idleRotY = swayY * 0.010;
    final idleRotX = swayX * 0.007;

    final rotX = -_tilt.dy * widget.maxTilt * eng + idleRotX * (1 - eng);
    final rotY = _tilt.dx * widget.maxTilt * eng + idleRotY * (1 - eng);
    final lift = 1 + 0.012 * eng;
    final pulse = widget.glowing ? _glow.value : 0.0;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..translateByDouble(0.0, -3.0 * eng, 0.0, 1.0)
      ..scaleByDouble(lift, lift, lift, 1.0)
      ..rotateX(rotX)
      ..rotateY(rotY);

    Widget content = child;
    if (widget.glowing) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: 0.08 + 0.22 * pulse),
              blurRadius: 20 + 20 * pulse,
              spreadRadius: 1 + 2 * pulse,
            ),
          ],
        ),
        child: child,
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: content,
    );
  }
}
