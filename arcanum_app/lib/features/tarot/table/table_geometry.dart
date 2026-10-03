/// Medidas de la mesa y de las cartas en UNIDADES DE MESA, las del prototipo.
///
/// Todo lo que se coloca (montones, huecos, cartas) vive en este plano de
/// 600 x 900. La camara lo proyecta a pantalla; ningun calculo de juego usa
/// pixeles de pantalla.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../domain/table_models.dart';

abstract final class TableGeometry {
  static const double width = 600;
  static const double height = 900;
  static const double cardW = 110;
  // la proporcion del naipe de la app (1:1,6), no la del prototipo (1:1,73):
  // asi la lamina RWS no se deforma
  static const double cardH = cardW * 1.6;

  /// Distancia de la camara (perspectiva CSS del prototipo).
  static const double perspective = 1000;

  /// Por encima de esta linea estan los mazos sin abrir (el estante).
  static const double shelfY = 168;

  /// El paño, dentro del marco: donde se juega (especificacion, §1).
  static const Rect cloth = Rect.fromLTRB(18, 172, 582, 882);

  /// Zona de la tirada: los huecos se dan en fraccion de este rectangulo.
  static const Rect spreadArea = Rect.fromLTWH(36, 200, 528, 470);

  /// Donde se pone el mazo en juego y la linea del abanico.
  static const Offset homeSpot = Offset(470, 782);
  static const double fanY = 782;

  static const double deckScale = .62;
  static const double fanScale = .55;
  static const double freeScale = .7;

  /// Radio minimo del iman de un hueco.
  static const double snapMin = 46;
}

/// Posicion, giro (grados) y escala de algo sobre la mesa.
class TablePose {
  const TablePose(this.x, this.y, {this.rot = 0, this.scale = 1});

  final double x;
  final double y;
  final double rot;
  final double scale;

  Offset get offset => Offset(x, y);

  @override
  bool operator ==(Object other) =>
      other is TablePose &&
      other.x == x &&
      other.y == y &&
      other.rot == rot &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(x, y, rot, scale);

  @override
  String toString() => 'TablePose($x, $y, rot: $rot, scale: $scale)';
}

/// Donde cae el hueco `i` de la tirada.
TablePose slotPose(SpreadDef spread, int i) {
  final s = spread.slots[i];
  const a = TableGeometry.spreadArea;
  return TablePose(
    a.left + s.x * a.width,
    a.top + s.y * a.height,
    rot: s.rotation.toDouble(),
    scale: spread.cardScale,
  );
}

/// Hueco mas cercano a `p` si esta dentro del iman, o null.
///
/// El iman crece con el tamaño de carta de la tirada: en la Rueda del año
/// las cartas son pequeñas y el minimo de 46 evita que haya que acertar al
/// milimetro.
int? nearestSlot(SpreadDef spread, Offset p) {
  int? best;
  var bestD = double.infinity;
  for (var i = 0; i < spread.cardCount; i++) {
    final d = (slotPose(spread, i).offset - p).distance;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  final radius = math.max(
    TableGeometry.snapMin,
    TableGeometry.cardH * spread.cardScale * .55,
  );
  return bestD < radius ? best : null;
}

/// Posicion de la aclaratoria numero `i` de una carta: asoma por su lado
/// derecho, un poco girada, y cada una mas afuera que la anterior.
TablePose clarifierPose(TablePose host, int i) {
  final hw = TableGeometry.cardW * host.scale / 2;
  final hh = TableGeometry.cardH * host.scale / 2;
  final a = host.rot * math.pi / 180;
  final ox = hw * .78 + i * hw * .55, oy = hh * .3;
  return TablePose(
    host.x + ox * math.cos(a) - oy * math.sin(a),
    host.y + ox * math.sin(a) + oy * math.cos(a),
    rot: host.rot + 9,
    scale: host.scale * .82,
  );
}

/// Punto `p` de la mesa en coordenadas locales de una pieza, normalizado a
/// [-1, 1] en cada eje (0,0 es el centro; -1 en y es el borde de arriba).
/// Con esto la gramatica de gestos decide si se agarro una esquina o un borde.
Offset localNormalized(
  TablePose piece,
  Offset p, {
  double w = TableGeometry.cardW,
  double h = TableGeometry.cardH,
}) {
  final a = -piece.rot * math.pi / 180;
  final d = p - piece.offset;
  final lx = d.dx * math.cos(a) - d.dy * math.sin(a);
  final ly = d.dx * math.sin(a) + d.dy * math.cos(a);
  return Offset(lx / (w * piece.scale / 2), ly / (h * piece.scale / 2));
}

/// Donde espera cada mazo en el estante, por orden del catalogo.
TablePose shelfPose(int index, int total) {
  if (total <= 1) {
    return const TablePose(300, 84, scale: TableGeometry.deckScale);
  }
  final step = 240 / (total - 1);
  return TablePose(180 + step * index, 84, scale: TableGeometry.deckScale);
}

/// Cartas del abanico a lo largo de su linea, con una leve comba: la primera
/// junto al monton y la ultima donde se solto el dedo.
List<TablePose> fanPoses(Offset start, Offset end, int count) {
  final d = end - start;
  final len = d.distance == 0 ? 1.0 : d.distance;
  final ang = math.atan2(d.dy, d.dx) * 180 / math.pi + (d.dx < 0 ? 180 : 0);
  final perp = Offset(-d.dy / len, d.dx / len);
  return [
    for (var i = 0; i < count; i++)
      () {
        final t = count > 1 ? i / (count - 1) : 0.0;
        final sag = math.sin(math.pi * t) * len * .07;
        final p = start + d * t + perp * sag;
        return TablePose(p.dx, p.dy, rot: ang, scale: TableGeometry.fanScale);
      }(),
  ];
}

/// Rectangulo de mesa (alineado con los ejes) que ocupa una carta en `p`,
/// girada incluida, con `w` x `h` de tamaño base.
Rect poseRect(
  TablePose p, {
  double w = TableGeometry.cardW,
  double h = TableGeometry.cardH,
}) {
  final hw = w * p.scale / 2, hh = h * p.scale / 2;
  final a = p.rot * math.pi / 180;
  final c = math.cos(a).abs(), s = math.sin(a).abs();
  return Rect.fromCenter(
    center: p.offset,
    width: 2 * (hw * c + hh * s),
    height: 2 * (hw * s + hh * c),
  );
}

double _overlap(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width <= 0 || i.height <= 0 ? 0 : i.width * i.height;
}

/// Centro de un sitio para una pieza de `size` dentro de `area` que pise lo
/// menos posible lo ocupado (`taken`), y entre los igual de libres, el mas
/// cercano a `near`.
///
/// Es lo que evita que las cartas sueltas caigan todas en el mismo punto,
/// encima de la tirada, como se vio en el GN2200 el 03-oct. Si no queda sitio
/// libre, elige el que menos tapa: nunca devuelve algo fuera de `area`.
Offset freeSpot({
  required Size size,
  required Iterable<Rect> taken,
  required Rect area,
  required Offset near,
  double gap = 6,
  double step = 10,
}) {
  final boxes = [for (final r in taken) r.inflate(gap)];
  final hw = size.width / 2, hh = size.height / 2;
  final x0 = area.left + hw, x1 = area.right - hw;
  final y0 = area.top + hh, y1 = area.bottom - hh;
  if (x1 < x0 || y1 < y0) return area.center;
  Offset? best;
  var bestCost = double.infinity, bestD = double.infinity;
  for (var y = y0; y <= y1 + 1e-9; y += step) {
    for (var x = x0; x <= x1 + 1e-9; x += step) {
      final r = Rect.fromCenter(
        center: Offset(x, y),
        width: size.width,
        height: size.height,
      );
      var cost = 0.0;
      for (final b in boxes) {
        cost += _overlap(r, b);
        if (cost > bestCost) break;
      }
      final d = (Offset(x, y) - near).distanceSquared;
      if (cost < bestCost - 1e-6 ||
          (cost - bestCost).abs() <= 1e-6 && d < bestD) {
        best = Offset(x, y);
        bestCost = cost;
        bestD = d;
      }
    }
  }
  return best ?? area.center;
}
