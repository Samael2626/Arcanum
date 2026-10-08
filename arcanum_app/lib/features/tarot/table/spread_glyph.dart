// Icono de cada tirada dibujado desde sus huecos, sin widgets: lo usa el
// director al montar el radial de tiradas.
import 'dart:math' as math;

import '../domain/table_models.dart';

/// Icono de una tirada a partir de sus huecos: un rectangulo de carta por
/// hueco, en su sitio y con su giro (la carta cruzada de la Cruz Celta, el
/// abanico de la Herradura). Asi las siete tiradas se distinguen, y una tirada
/// nueva trae su icono sin dibujarlo a mano.
String? spreadGlyph(SpreadDef spread) {
  final slots = spread.slots;
  if (slots.isEmpty) return null; // sin huecos: el icono generico
  // tamano de carta: lo que deje libre el vecino mas cercano (sin contar los
  // huecos que coinciden, como el cruce de la Cruz Celta)
  var near = 1.0;
  for (var i = 0; i < slots.length; i++) {
    for (var j = i + 1; j < slots.length; j++) {
      final d = math.sqrt(math.pow(slots[i].x - slots[j].x, 2) + math.pow(slots[i].y - slots[j].y, 2));
      if (d > .01 && d < near) near = d;
    }
  }
  final h = math.min(.42, near * .8) * 20, w = h * .62;
  String n(double v) => v.toStringAsFixed(1);
  final out = StringBuffer();
  for (final s in slots) {
    final cx = 2 + s.x * 20, cy = 2 + s.y * 20, a = s.rotation * math.pi / 180;
    final c = math.cos(a), sn = math.sin(a);
    final pts = [for (final (dx, dy) in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]) (cx + dx * c - dy * sn, cy + dx * sn + dy * c)];
    out.write('<path d="M${n(pts[0].$1)} ${n(pts[0].$2)}');
    for (final p in pts.skip(1)) {
      out.write('L${n(p.$1)} ${n(p.$2)}');
    }
    out.write('Z"/>');
  }
  return out.toString();
}
