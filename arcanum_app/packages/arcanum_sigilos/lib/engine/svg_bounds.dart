// Caja geometrica exacta de los caminos del prototipo (SVG getBBox sin tinta).
import 'dart:math' as math;
import 'dart:ui';

Rect pathBounds(String data) {
  final tokens = RegExp(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?').allMatches(data).map((m) => m[0]!).toList();
  var i = 0, x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  var left = double.infinity, top = double.infinity, right = double.negativeInfinity, bottom = double.negativeInfinity;
  void point(double px, double py) { left = math.min(left, px); top = math.min(top, py); right = math.max(right, px); bottom = math.max(bottom, py); }
  double next() => double.parse(tokens[i++]);
  bool hasNumber() => i < tokens.length && double.tryParse(tokens[i]) != null;
  double curve(double a, double b, double c, double d, double t) {
    final u = 1 - t;
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
  }
  void cubicRoots(double a, double b, double c, double d, void Function(double) add) {
    final p = -a + 3 * b - 3 * c + d, q = 2 * (a - 2 * b + c), r = b - a;
    if (p.abs() < 1e-12) { if (q.abs() > 1e-12) { final t = -r / q; if (t > 0 && t < 1) add(t); } return; }
    final disc = q * q - 4 * p * r;
    if (disc < 0) return;
    final root = math.sqrt(disc);
    for (final t in [(-q + root) / (2 * p), (-q - root) / (2 * p)]) { if (t > 0 && t < 1) add(t); }
  }
  var cmd = '';
  while (i < tokens.length) {
    if (!hasNumber()) cmd = tokens[i++];
    switch (cmd) {
      case 'M': x = next(); y = next(); sx = x; sy = y; point(x, y); cmd = 'L';
      case 'L': x = next(); y = next(); point(x, y);
      case 'H': x = next(); point(x, y);
      case 'V': y = next(); point(x, y);
      case 'C':
        final x1 = next(), y1 = next(), x2 = next(), y2 = next(), ex = next(), ey = next();
        point(x, y); point(ex, ey);
        void at(double t) => point(curve(x, x1, x2, ex, t), curve(y, y1, y2, ey, t));
        cubicRoots(x, x1, x2, ex, at); cubicRoots(y, y1, y2, ey, at);
        x = ex; y = ey;
      case 'Q':
        final cx = next(), cy = next(), ex = next(), ey = next();
        point(x, y); point(ex, ey);
        final tx = (x - cx) / (x - 2 * cx + ex), ty = (y - cy) / (y - 2 * cy + ey);
        if (tx > 0 && tx < 1) { final u = 1 - tx; point(u * u * x + 2 * u * tx * cx + tx * tx * ex, u * u * y + 2 * u * tx * cy + tx * tx * ey); }
        if (ty > 0 && ty < 1) { final u = 1 - ty; point(u * u * x + 2 * u * ty * cx + ty * ty * ex, u * u * y + 2 * u * ty * cy + ty * ty * ey); }
        x = ex; y = ey;
      case 'A':
        var rx = next().abs(), ry = next().abs();
        final rotation = next(), large = next() != 0, sweep = next() != 0, ex = next(), ey = next();
        point(x, y); point(ex, ey);
        if (rx == 0 || ry == 0 || rotation.abs() > 1e-9) { x = ex; y = ey; break; }
        final hx = (x - ex) / 2, hy = (y - ey) / 2;
        final lambda = hx * hx / (rx * rx) + hy * hy / (ry * ry);
        if (lambda > 1) { final factor = math.sqrt(lambda); rx *= factor; ry *= factor; }
        final factor = (large == sweep ? -1.0 : 1.0) * math.sqrt(math.max(0, (1 - math.min(lambda, 1)) / math.max(lambda, 1e-15)));
        final cx = (x + ex) / 2 + factor * rx * hy / ry, cy = (y + ey) / 2 - factor * ry * hx / rx;
        final start = math.atan2((y - cy) / ry, (x - cx) / rx), end = math.atan2((ey - cy) / ry, (ex - cx) / rx);
        var delta = end - start;
        if (sweep && delta < 0) delta += 2 * math.pi;
        if (!sweep && delta > 0) delta -= 2 * math.pi;
        for (final angle in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
          var distance = angle - start;
          if (sweep) { while (distance < 0) { distance += 2 * math.pi; } if (distance <= delta + 1e-9) point(cx + rx * math.cos(angle), cy + ry * math.sin(angle)); }
          else { while (distance > 0) { distance -= 2 * math.pi; } if (distance >= delta - 1e-9) point(cx + rx * math.cos(angle), cy + ry * math.sin(angle)); }
        }
        x = ex; y = ey;
      case 'Z': x = sx; y = sy; point(x, y); cmd = '';
      default: throw FormatException('Comando SVG desconocido: $cmd');
    }
  }
  return left.isFinite ? Rect.fromLTRB(left, top, right, bottom) : const Rect.fromLTWH(0, 0, 1, 1);
}
