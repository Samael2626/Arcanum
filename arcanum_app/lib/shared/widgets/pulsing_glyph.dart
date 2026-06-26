import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

/// Glifo con un sutil pulso/brillo dorado en bucle — foco visual premium.
class PulsingGlyph extends StatefulWidget {
  final String glyph;
  final double size;
  final Color color;
  const PulsingGlyph(
    this.glyph, {
    super.key,
    this.size = 64,
    this.color = ArcanumColors.gold,
  });

  @override
  State<PulsingGlyph> createState() => _PulsingGlyphState();
}

class _PulsingGlyphState extends State<PulsingGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + 0.30 * t),
                blurRadius: 10 + 22 * t,
                spreadRadius: 1 + 4 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Text(
        widget.glyph,
        style: TextStyle(fontSize: widget.size, color: widget.color),
      ),
    );
  }
}
