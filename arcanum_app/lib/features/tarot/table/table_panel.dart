/// Paneles compactos anclados a lo que se toco (D7): leer una carta, la
/// pregunta y las lecturas guardadas. Salen encima de la pieza, debajo si
/// arriba no caben, y nunca se salen de la pantalla. La mesa sigue a la vista.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';

class TablePanel extends StatelessWidget {
  const TablePanel({
    super.key,
    required this.anchor,
    required this.title,
    required this.child,
    required this.onClose,
  });

  /// Lo que se toco, en coordenadas de la mesa en pantalla.
  final Rect anchor;
  final String title;
  final Widget child;
  final VoidCallback onClose;

  static const double margin = 8;
  static const double gap = 10;
  static const double maxWidth = 360;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        // tocar fuera lo cierra; el toque no llega a la mesa
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Semantics(
              label: 'Cerrar',
              button: true,
              onTap: onClose,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: PanelLayout(anchor),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.scale(scale: .94 + .06 * v, child: child),
              ),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: _Frame(title: title, child: child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Coloca el panel: centrado sobre el ancla y encima; si no cabe, debajo;
/// siempre dentro de la pantalla con su margen.
class PanelLayout extends SingleChildLayoutDelegate {
  const PanelLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints(
      minWidth: 0,
      maxWidth: math.min(
        TablePanel.maxWidth,
        size.width - 2 * TablePanel.margin,
      ),
      maxHeight: math.max(
        0,
        math.min(size.height * .6, size.height - 2 * TablePanel.margin),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final child = childSize;
    var top = anchor.top - TablePanel.gap - child.height;
    if (top < TablePanel.margin) top = anchor.bottom + TablePanel.gap;
    final left = anchor.center.dx - child.width / 2;
    return Offset(
      _clamp(
        left,
        TablePanel.margin,
        size.width - child.width - TablePanel.margin,
      ),
      _clamp(
        top,
        TablePanel.margin,
        size.height - child.height - TablePanel.margin,
      ),
    );
  }

  static double _clamp(double v, double lo, double hi) =>
      hi < lo ? lo : v.clamp(lo, hi);

  @override
  bool shouldRelayout(PanelLayout old) => old.anchor != anchor;
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: ArcanumColors.surface.withValues(alpha: .97),
    elevation: 12,
    shadowColor: Colors.black,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: ArcanumColors.gold.withValues(alpha: .35)),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: ArcanumColors.gold,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    ),
  );
}
