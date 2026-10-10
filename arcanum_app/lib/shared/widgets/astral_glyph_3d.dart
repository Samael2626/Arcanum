import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/arcanum_theme.dart';

/// Glifo extruido que sigue la inclinacion del dispositivo y el arrastre.
class AstralGlyph3D extends StatefulWidget {
  const AstralGlyph3D({
    super.key,
    required this.glyph,
    required this.color,
    required this.size,
    this.depth = 14,
  });

  final String glyph;
  final Color color;
  final double size;
  final int depth;

  @override
  State<AstralGlyph3D> createState() => _AstralGlyph3DState();
}

class _AstralGlyph3DState extends State<AstralGlyph3D>
    with WidgetsBindingObserver {
  static const _maxSensorTilt = 0.13;
  static const _maxDragTilt = 0.28;
  StreamSubscription<AccelerometerEvent>? _sensor;
  double? _baselinePitch;
  double? _baselineRoll;
  double _sensorPitch = 0;
  double _sensorRoll = 0;
  double _dragPitch = 0.04;
  double _dragRoll = 0.08;
  Offset? _dragOrigin;
  double _dragPitchOrigin = 0;
  double _dragRollOrigin = 0;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _stopSensor();
      _sensorPitch = 0;
      _sensorRoll = 0;
    } else {
      _startSensor();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSensor();
    } else {
      _stopSensor();
      _baselinePitch = null;
      _baselineRoll = null;
      if (mounted) setState(() => _sensorPitch = _sensorRoll = 0);
    }
  }

  void _startSensor() {
    if (_reducedMotion || _sensor != null) return;
    _sensor = accelerometerEventStream().listen(
      _onSensor,
      onError: (_) => _stopSensor(),
      cancelOnError: true,
    );
  }

  void _onSensor(AccelerometerEvent event) {
    if (!mounted || _reducedMotion) return;
    final pitch = math.atan2(
      -event.x,
      math.sqrt(event.y * event.y + event.z * event.z),
    );
    final roll = math.atan2(event.y, event.z);
    _baselinePitch ??= pitch;
    _baselineRoll ??= roll;
    final targetPitch = (_angleDelta(pitch, _baselinePitch!) * 0.72)
        .clamp(-_maxSensorTilt, _maxSensorTilt)
        .toDouble();
    final targetRoll = (_angleDelta(roll, _baselineRoll!) * 0.72)
        .clamp(-_maxSensorTilt, _maxSensorTilt)
        .toDouble();
    setState(() {
      _sensorPitch += (targetPitch - _sensorPitch) * 0.22;
      _sensorRoll += (targetRoll - _sensorRoll) * 0.22;
    });
  }

  double _angleDelta(double angle, double baseline) =>
      math.atan2(math.sin(angle - baseline), math.cos(angle - baseline));

  void _stopSensor() {
    _sensor?.cancel();
    _sensor = null;
  }

  void _onPanStart(DragStartDetails details) {
    _dragOrigin = details.localPosition;
    _dragPitchOrigin = _dragPitch;
    _dragRollOrigin = _dragRoll;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final origin = _dragOrigin;
    if (origin == null) return;
    setState(() {
      _dragRoll =
          (_dragRollOrigin + (details.localPosition.dx - origin.dx) * 0.008)
              .clamp(-_maxDragTilt, _maxDragTilt)
              .toDouble();
      _dragPitch =
          (_dragPitchOrigin - (details.localPosition.dy - origin.dy) * 0.008)
              .clamp(-_maxDragTilt, _maxDragTilt)
              .toDouble();
    });
  }

  void _onPanEnd(DragEndDetails _) => _dragOrigin = null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSensor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanStart: _onPanStart,
    onPanUpdate: _onPanUpdate,
    onPanEnd: _onPanEnd,
    onPanCancel: () => _dragOrigin = null,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(_dragPitch + _sensorPitch)
        ..rotateY(_dragRoll + _sensorRoll),
      child: _ExtrudedGlyph(
        glyph: widget.glyph,
        color: widget.color,
        size: widget.size,
        depth: widget.depth,
      ),
    ),
  );
}

class _ExtrudedGlyph extends StatelessWidget {
  const _ExtrudedGlyph({
    required this.glyph,
    required this.color,
    required this.size,
    required this.depth,
  });

  final String glyph;
  final Color color;
  final double size;
  final int depth;

  @override
  Widget build(BuildContext context) {
    Text face(Color faceColor) => Text(
      glyph,
      style: TextStyle(
        fontSize: size,
        color: faceColor,
        height: 1,
        fontFamilyFallback: kGlyphFallback,
        shadows: [Shadow(color: color.withValues(alpha: 0.34), blurRadius: 8)],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var layer = depth; layer > 0; layer--)
          Transform.translate(
            offset: Offset(layer * 0.38, layer * 0.48),
            child: face(Color.lerp(const Color(0xFF080910), color, 0.48)!),
          ),
        face(Color.lerp(color, Colors.white, 0.18)!),
      ],
    );
  }
}
