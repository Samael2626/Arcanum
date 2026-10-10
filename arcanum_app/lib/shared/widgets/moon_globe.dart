import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'moon_disc.dart';

/// Esfera lunar con fase fija y superficie que gira bajo el dedo.
class MoonGlobe extends StatefulWidget {
  const MoonGlobe({
    super.key,
    required this.illumination,
    required this.waxing,
    required this.phase,
    required this.onTap,
    this.size = 196,
  });

  final double illumination;
  final bool waxing;
  final String phase;
  final VoidCallback onTap;
  final double size;

  @override
  State<MoonGlobe> createState() => _MoonGlobeState();
}

class _MoonGlobeState extends State<MoonGlobe> {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/moon_globe.frag');

  ui.FragmentShader? _shader;
  ui.Image? _colorMap;
  ui.Image? _heightMap;
  double _yaw = 0;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    ui.FragmentShader? shader;
    ui.Image? colorMap;
    ui.Image? heightMap;
    try {
      shader = (await _program).fragmentShader();
      colorMap = await _loadImage('assets/images/moon/lroc_color_2k.jpg');
      heightMap = await _loadImage('assets/images/moon/ldem_3_8bit.jpg');
      if (!mounted) {
        shader.dispose();
        colorMap.dispose();
        heightMap.dispose();
        return;
      }
      setState(() {
        _shader = shader!;
        _colorMap = colorMap!;
        _heightMap = heightMap!;
      });
    } catch (_) {
      shader?.dispose();
      colorMap?.dispose();
      heightMap?.dispose();
      // Mantener una Luna estática si el dispositivo no soporta el shader.
    }
  }

  Future<ui.Image> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant MoonGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase ||
        oldWidget.illumination != widget.illumination ||
        oldWidget.waxing != widget.waxing) {
      _yaw = 0;
      _pitch = 0;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _colorMap?.dispose();
    _heightMap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.illumination * 100).round();
    return Semantics(
      button: true,
      label:
          'Luna: ${widget.phase}, $percent% iluminada. '
          'Toca para abrir; arrastra para girar la superficie.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanUpdate: (details) => setState(() {
          _yaw += details.delta.dx * 0.009;
          _pitch = (_pitch + details.delta.dy * 0.009)
              .clamp(-math.pi / 2 + 0.08, math.pi / 2 - 0.08)
              .toDouble();
        }),
        child: SizedBox.square(
          dimension: widget.size,
          child: _shader == null || _colorMap == null || _heightMap == null
              ? MoonDisc(
                  illumination: widget.illumination,
                  waxing: widget.waxing,
                  size: widget.size,
                )
              : RepaintBoundary(
                  child: CustomPaint(
                    painter: _MoonGlobePainter(
                      shader: _shader!,
                      colorMap: _colorMap!,
                      heightMap: _heightMap!,
                      illumination: widget.illumination,
                      waxing: widget.waxing,
                      yaw: _yaw,
                      pitch: _pitch,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MoonGlobePainter extends CustomPainter {
  const _MoonGlobePainter({
    required this.shader,
    required this.colorMap,
    required this.heightMap,
    required this.illumination,
    required this.waxing,
    required this.yaw,
    required this.pitch,
  });

  final ui.FragmentShader shader;
  final ui.Image colorMap;
  final ui.Image heightMap;
  final double illumination;
  final bool waxing;
  final double yaw;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final fraction = illumination.clamp(0.0, 1.0);
    shader
      ..setImageSampler(0, colorMap, filterQuality: FilterQuality.medium)
      ..setImageSampler(1, heightMap, filterQuality: FilterQuality.medium)
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, 2 * fraction - 1)
      ..setFloat(3, waxing ? 1 : -1)
      ..setFloat(4, yaw)
      ..setFloat(5, pitch);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _MoonGlobePainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.colorMap != colorMap ||
      oldDelegate.heightMap != heightMap ||
      oldDelegate.illumination != illumination ||
      oldDelegate.waxing != waxing ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch;
}
