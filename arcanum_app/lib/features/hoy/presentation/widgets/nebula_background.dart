import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

class NebulaBackground extends StatefulWidget {
  final Widget child;

  const NebulaBackground({required this.child, Key? key}) : super(key: key);

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        children: [
          Container(
            color: const Color(0xFF0a0a0f),
            child: CustomPaint(
              painter: NebulaPainter(_controller.value),
              child: Container(),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class NebulaPainter extends CustomPainter {
  final double time;
  NebulaPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    // Carga shader
    final shader = _buildShader(size);
    if (shader != null) {
      final paint = Paint()..shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } else {
      // Fallback: gradiente si shader falla
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(size.width, size.height),
            [
              const Color(0xFF1a0a2e),
              const Color(0xFF16213e),
              const Color(0xFF0f3460),
            ],
          ),
      );
    }
  }

  ui.Shader? _buildShader(Size size) {
    // Implementación simplificada: gradiente con pulsing
    // (Shader compilado GLSL requiere engine support en Flutter)
    final time = this.time * 3.14159 * 2;
    final pulse = 0.5 + 0.5 * sin(time);

    return ui.Gradient.radial(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.8,
      [
        Color.lerp(
          const Color(0xFF1a0a2e),
          const Color(0xFF6b0080),
          pulse * 0.3,
        )!,
        const Color(0xFF16213e),
      ],
      [0.0, 1.0],
    );
  }

  @override
  bool shouldRepaint(NebulaPainter oldDelegate) => oldDelegate.time != time;
}
