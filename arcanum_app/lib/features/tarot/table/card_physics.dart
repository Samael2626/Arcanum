/// Fisica de las cartas, sin widgets: el volteo tirando de la esquina y el
/// peso al arrastrar. Numeros del prototipo, ya ajustados a mano con Samuel.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'table_geometry.dart';

/// Volteo por la esquina. La carta gira sobre una bisagra en el borde
/// contrario a la esquina agarrada, y el angulo sale de cuanto se ha alejado
/// la esquina de su sitio: cos(angulo) = lo que queda de carta entre la
/// bisagra y el dedo.
class Peel {
  Peel({required Offset startLocal, required this.cardScale})
    : corner = startLocal.dx.sign == 0 ? -1 : startLocal.dx.sign,
      cy = startLocal.dy.sign == 0 ? 1 : startLocal.dy.sign,
      _start = startLocal;

  /// Pasado este angulo, soltar termina de voltear; antes, la carta vuelve.
  static const double commitDegrees = 70;

  /// -1 esquina izquierda, 1 derecha.
  final double corner;

  /// -1 esquina de arriba, 1 de abajo.
  final double cy;
  final double cardScale;
  final Offset _start;

  double _angle = 0;

  /// Angulo actual en grados, 0..180.
  double get angle => _angle;

  /// Levanta la carta a mitad de giro, en unidades de mesa.
  double get lift => _bump(_angle / 180) * 6;

  /// Cabeceo lateral a mitad de giro, en grados.
  double get tilt => cy * 12 * _bump(_angle / 180);

  /// La bisagra, en unidades locales de la carta (x): el borde contrario.
  double get hingeX => -corner * TableGeometry.cardW / 2;

  bool get commits => _angle > commitDegrees;

  /// `local` es el dedo en coordenadas locales normalizadas a [-1, 1].
  /// Cuenta todo lo que aleja la esquina de su sitio: hacia el borde
  /// contrario, hacia arriba o en diagonal (el prototipo solo contaba hacia el
  /// borde y la esquina no respondia a medio gesto).
  double update(Offset local) {
    final hw = TableGeometry.cardW * cardScale / 2,
        hh = TableGeometry.cardH * cardScale / 2;
    final mx = -(local.dx - _start.dx) * hw * corner;
    final my = -(local.dy - _start.dy) * hh * cy;
    final d = math.max(0.0, mx) + my.abs() * .9 + math.max(0.0, -mx) * .6;
    final c = (1 - d / (hw * 2)).clamp(-1.0, 1.0);
    _angle = math.acos(c) * 180 / math.pi;
    return _angle;
  }

  static double _bump(double t) => math.sin(math.pi * t.clamp(0.0, 1.0));
}

/// Peso al arrastrar: la carta se inclina hacia donde va y se endereza con
/// retraso. Es un muelle que persigue a la velocidad.
class Wobble {
  /// Inclinacion maxima en grados.
  static const double maxTilt = 15;

  double tx = 0, ty = 0; // inclinacion actual (grados, sobre x y sobre y)
  double _vx = 0, _vy = 0;
  double _targetX = 0, _targetY = 0;
  bool dragging = false;

  /// El dedo se movio `delta` unidades de mesa desde el frame anterior.
  void push(Offset delta) {
    dragging = true;
    _targetY = (delta.dx * 1.3).clamp(-maxTilt, maxTilt);
    _targetX = (-delta.dy * 1.3).clamp(-maxTilt, maxTilt);
  }

  void release() => dragging = false;

  /// Un paso de 60 Hz. Devuelve false cuando ya esta quieto y se puede olvidar.
  bool step() {
    if (!dragging) {
      _targetX *= .8;
      _targetY *= .8;
    }
    _vx = _vx * .74 + (_targetX - tx) * .16;
    _vy = _vy * .74 + (_targetY - ty) * .16;
    tx += _vx;
    ty += _vy;
    if (!dragging && tx.abs() + ty.abs() + _vx.abs() + _vy.abs() < .05) {
      tx = ty = _vx = _vy = 0;
      return false;
    }
    return true;
  }
}
