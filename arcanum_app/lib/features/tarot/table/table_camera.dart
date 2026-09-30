/// Camara de la mesa: el `fitCam` / `applyCam` / `toTable` del prototipo.
///
/// La mesa se ve inclinada (theta) y girada (yaw) con perspectiva de 1000.
/// Tiene un estado ACTUAL y un DESTINO: los gestos mueven el destino y
/// `step` acerca el actual con suavidad, que es lo que da la inercia.
///
/// Mutable a proposito: se actualiza en cada frame y no forma parte de lo que
/// se deshace (en la foto de la mesa solo entra su destino).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/table_state.dart';
import 'table_geometry.dart';

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

class TableCamera {
  TableCamera({TableCameraState? from}) {
    if (from != null) jumpTo(from);
  }

  /// Inclinacion de reposo; el encuadre se calcula siempre con ella, asi que
  /// inclinar la mesa no cambia el zoom.
  static const double baseTheta = 30;
  static const double minTheta = 16, maxTheta = 56;
  static const double maxYaw = 40;
  static const double minZoom = 1, maxZoom = 2.6;

  // actual
  double theta = baseTheta, yaw = 0, zoom = 1, panX = 0, panY = 0;
  // destino
  double tTheta = baseTheta, tYaw = 0, tZoom = 1, tPanX = 0, tPanY = 0;

  // encuadre: escala base y desplazamiento vertical para centrar la mesa
  double _k = 1, _oy = 0;
  Size _viewport = Size.zero;

  Size get viewport => _viewport;

  TableCameraState get state => TableCameraState(
    theta: tTheta,
    yaw: tYaw,
    zoom: tZoom,
    panX: tPanX,
    panY: tPanY,
  );

  void jumpTo(TableCameraState s) {
    theta = tTheta = s.theta;
    yaw = tYaw = s.yaw;
    zoom = tZoom = s.zoom;
    panX = tPanX = s.panX;
    panY = tPanY = s.panY;
  }

  /// Ajusta el encuadre a la pantalla: la mesa entra entera a lo alto y el
  /// paño (sin el marco de madera, que puede recortarse) a lo ancho.
  void fit(Size viewport) {
    if (viewport == _viewport) return;
    _viewport = viewport;
    const p = TableGeometry.perspective, th = TableGeometry.height;
    const contentW = TableGeometry.width - 44;
    final t = baseTheta * math.pi / 180, s = math.sin(t), c = math.cos(t);
    var k = 1.0;
    double top = 0, bottom = 0;
    // la escala cambia la perspectiva y la perspectiva la escala: se itera
    for (var i = 0; i < 7; i++) {
      final a = k * th / 2;
      bottom = a * c * p / (p - a * s);
      top = a * c * p / (p + a * s);
      final kh = k * (viewport.height - 24) / (bottom + top);
      final kw = (viewport.width - 8) / (contentW * p / (p - a * s));
      k = math.min(math.min(kh, kw), 1.5);
    }
    final a = k * th / 2;
    bottom = a * c * p / (p - a * s);
    top = a * c * p / (p + a * s);
    _k = k;
    _oy = (top - bottom) / 2;
  }

  /// Matriz de mesa a pantalla. La perspectiva se aplica desde el centro de
  /// la mesa en pantalla, como el `perspective-origin` del prototipo.
  Matrix4 matrix() {
    final k = _k * zoom;
    final ox = _viewport.width / 2 + panX,
        oy = _viewport.height / 2 + panY + _oy;
    // La perspectiva se MULTIPLICA como matriz propia. Poner la entrada (3, 2)
    // sobre una matriz ya trasladada no es lo mismo: deja el punto de fuga en
    // la esquina de la pantalla y la mesa sale sesgada hacia un lado.
    final perspective = Matrix4.identity()
      ..setEntry(3, 2, -1 / TableGeometry.perspective);
    return Matrix4.identity()
      ..translateByDouble(ox, oy, 0, 1)
      ..multiply(perspective)
      ..scaleByDouble(k, k, k, 1)
      ..rotateX(theta * math.pi / 180)
      ..rotateZ(yaw * math.pi / 180)
      ..translateByDouble(
        -TableGeometry.width / 2,
        -TableGeometry.height / 2,
        0,
        1,
      );
  }

  /// Punto de la mesa (z = 0) a pantalla.
  Offset toScreen(Offset table, {double z = 0}) {
    final m = matrix().storage;
    final x = table.dx, y = table.dy;
    final w = m[3] * x + m[7] * y + m[11] * z + m[15];
    return Offset(
      (m[0] * x + m[4] * y + m[8] * z + m[12]) / w,
      (m[1] * x + m[5] * y + m[9] * z + m[13]) / w,
    );
  }

  /// Punto de pantalla al punto de la mesa que hay debajo del dedo.
  ///
  /// El plano de la mesa (z = 0) se proyecta con una homografia 3x3: las
  /// columnas x, y y traslacion de la matriz 4x4, en las filas x, y y w. Su
  /// inversa lleva cualquier toque a la mesa, con inclinacion, giro y zoom.
  Offset toTable(Offset screen) {
    final m = matrix().storage;
    // h = [[a, b, c], [d, e, f], [g, h, i]] (fila por fila)
    final a = m[0], b = m[4], c = m[12];
    final d = m[1], e = m[5], f = m[13];
    final g = m[3], h = m[7], i = m[15];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    final sx = screen.dx, sy = screen.dy;
    final x = (e * i - f * h) * sx + (c * h - b * i) * sy + (b * f - c * e);
    final y = (f * g - d * i) * sx + (a * i - c * g) * sy + (c * d - a * f);
    final w = (d * h - e * g) * sx + (b * g - a * h) * sy + (a * e - b * d);
    // det y w comparten signo en la zona visible; dividir por w basta
    return det == 0 ? Offset.zero : Offset(x / w, y / w);
  }

  // ---------- gestos ----------

  /// Arrastrar el paño o el marco. Invertido: arrastrar a la derecha gira la
  /// mesa hacia la izquierda (a peticion de Samuel en el prototipo).
  ({double vyaw, double vtheta}) orbitBy(Offset delta) {
    final vyaw = -delta.dx * .22, vth = delta.dy * .2;
    tYaw = _clamp(tYaw + vyaw, -maxYaw, maxYaw);
    tTheta = _clamp(tTheta + vth, minTheta, maxTheta);
    return (vyaw: vyaw, vtheta: vth);
  }

  /// Al soltar, la mesa sigue un poco en la direccion del gesto.
  void releaseOrbit({required double vyaw, required double vtheta}) {
    tYaw = _clamp(tYaw + vyaw * 6, -maxYaw, maxYaw);
    tTheta = _clamp(tTheta + vtheta * 5, minTheta, maxTheta);
  }

  double _pinchD0 = 1, _pinchZ0 = 1;
  Offset _pinchM0 = Offset.zero, _pinchP0 = Offset.zero;

  void startPinch(Offset a, Offset b) {
    _pinchD0 = math.max(1, (a - b).distance);
    _pinchZ0 = zoom;
    _pinchM0 = (a + b) / 2;
    _pinchP0 = Offset(panX, panY);
  }

  /// Pellizcar acerca y separa; mover los dos dedos desplaza. Va directo, sin
  /// suavizado: la mesa tiene que estar pegada a los dedos.
  void updatePinch(Offset a, Offset b) {
    final m = (a + b) / 2;
    zoom = tZoom = _clamp(
      _pinchZ0 * (a - b).distance / _pinchD0,
      minZoom,
      maxZoom,
    );
    panX = _pinchP0.dx + (m.dx - _pinchM0.dx);
    panY = _pinchP0.dy + (m.dy - _pinchM0.dy);
    _clampPan();
    tPanX = panX;
    tPanY = panY;
  }

  /// Doble toque en el paño: vuelta a la vista inicial.
  void reset() {
    tTheta = baseTheta;
    tYaw = 0;
    tZoom = 1;
    tPanX = 0;
    tPanY = 0;
  }

  void _clampPan() {
    final mx = (zoom - 1) * _viewport.width / 2 + 10;
    final my = (zoom - 1) * _viewport.height / 2 + 10;
    panX = _clamp(panX, -mx, mx);
    panY = _clamp(panY, -my, my);
  }

  /// Acerca el estado actual al destino. Devuelve true si se movio (hay que
  /// repintar). Independiente de los fps: el prototipo acercaba un 14 % por
  /// frame a 60 Hz; aqui se escala por el tiempo real transcurrido.
  bool step(Duration dt) {
    final frames = dt.inMicroseconds / 16667;
    double ease(double f) => 1 - math.pow(1 - f, frames).toDouble();
    var moved = false;
    if ((tTheta - theta).abs() > .01) {
      theta += (tTheta - theta) * ease(.14);
      moved = true;
    }
    if ((tYaw - yaw).abs() > .01) {
      yaw += (tYaw - yaw) * ease(.14);
      moved = true;
    }
    if ((tZoom - zoom).abs() > .001) {
      zoom += (tZoom - zoom) * ease(.18);
      moved = true;
    }
    if ((tPanX - panX).abs() > .3 || (tPanY - panY).abs() > .3) {
      panX += (tPanX - panX) * ease(.18);
      panY += (tPanY - panY) * ease(.18);
      _clampPan();
      moved = true;
    }
    return moved;
  }
}
