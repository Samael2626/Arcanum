import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';

/// Grabados vectoriales de la Materia Arcana — lámina de herbario s.XVII.
///
/// Trazo monolínea fino, sin relleno sólido, tinta-oro sobre la atmósfera del
/// regente: cada categoría tiene su emblema (con variantes estables por ítem)
/// dibujado como una plancha de museo alquímico, no como clipart.
///
/// El arte se compone en un lienzo unidad de 100×100 y se escala al recuadro.
/// El [progress] permite el "dibujado" del trazo (PathMetrics) en el héroe.

// ── Derivación del signo zodiacal ───────────────────────────────────────────

/// Clave del signo asociado a un ítem: usa el [explicit] (properties.zodiac) si
/// viene; si no, lo DERIVA del domicilio clásico del planeta, desambiguando los
/// planetas de doble domicilio por el elemento del ítem. Sin planeta → null.
String? materiaZodiacKey(String? planet, String? element, {String? explicit}) {
  if (explicit != null && explicit.isNotEmpty) {
    final k = explicit.toLowerCase().trim();
    return signGlyph.containsKey(k) ? k : null;
  }
  if (planet == null || planet.isEmpty) return null;
  final e = element?.toLowerCase().trim();
  final water = e == 'water' || e == 'agua';
  final earth = e == 'earth' || e == 'tierra';
  final air = e == 'air' || e == 'aire';
  switch (planet.toLowerCase()) {
    case 'sun':
      return 'leo';
    case 'moon':
      return 'cancer';
    case 'mars':
      return water ? 'scorpio' : 'aries'; // agua→Escorpio, resto→Aries
    case 'venus':
      return air ? 'libra' : 'taurus'; // aire→Libra, resto→Tauro
    case 'mercury':
      return earth ? 'virgo' : 'gemini'; // tierra→Virgo, resto→Géminis
    case 'jupiter':
      return water ? 'pisces' : 'sagittarius'; // agua→Piscis, resto→Sagitario
    case 'saturn':
      return air ? 'aquarius' : 'capricorn'; // aire→Acuario, resto→Capricornio
    default:
      return null;
  }
}

// ── Variante estable por ítem ───────────────────────────────────────────────

int _variantCount(String type) {
  switch (type) {
    case 'herb':
      return 4;
    case 'stone':
      return 4;
    case 'metal':
      return 3;
    case 'incense':
      return 3;
    default:
      return 1;
  }
}

/// Índice de variante ESTABLE para un ítem (mismo slug → mismo grabado siempre).
///
/// Hash tipo DJB2 con multiplicador pequeño (33) y máscara 31-bit en cada paso:
/// los productos quedan muy por debajo de 2^53, así el resultado es idéntico en
/// VM y en web (dart2js compila `int` a `double` de JS — un FNV de 32 bits
/// desborda el entero seguro y colapsa todas las variantes a 0).
int materiaVariant(String slug, String type) {
  final n = _variantCount(type);
  if (n <= 1) return 0;
  var h = 5381;
  for (final c in slug.codeUnits) {
    h = ((h * 33) + c) & 0x7fffffff;
  }
  return h % n;
}

// ── Lápiz de trazado en lienzo unidad (0..100) ──────────────────────────────

class _Pen {
  _Pen(this.s);
  final double s; // escala box/100
  final Path path = Path();
  double _x(double x) => x * s;
  double _y(double y) => y * s;
  void move(double x, double y) => path.moveTo(_x(x), _y(y));
  void line(double x, double y) => path.lineTo(_x(x), _y(y));
  void cubic(double a, double b, double c, double d, double x, double y) =>
      path.cubicTo(_x(a), _y(b), _x(c), _y(d), _x(x), _y(y));
  void quad(double a, double b, double x, double y) =>
      path.quadraticBezierTo(_x(a), _y(b), _x(x), _y(y));
  void circle(double cx, double cy, double r) =>
      path.addOval(Rect.fromCircle(center: Offset(_x(cx), _y(cy)), radius: r * s));
  void close() => path.close();
}

/// Construye el grabado de [type]/[variant] en un recuadro cuadrado de lado [box].
Path buildEngraving(String type, int variant, double box) {
  final pen = _Pen(box / 100);
  switch (type) {
    case 'herb':
      switch (variant) {
        case 0:
          _herbSprig(pen);
          break;
        case 1:
          _herbFlower(pen);
          break;
        case 2:
          _herbLeaf(pen);
          break;
        default:
          _herbRoot(pen);
      }
      break;
    case 'stone':
      switch (variant) {
        case 0:
          _stoneGem(pen);
          break;
        case 1:
          _stonePebble(pen);
          break;
        case 2:
          _stoneGeode(pen);
          break;
        default:
          _stonePoint(pen);
      }
      break;
    case 'metal':
      switch (variant) {
        case 0:
          _metalIngot(pen);
          break;
        case 1:
          _metalDisc(pen);
          break;
        default:
          _metalNugget(pen);
      }
      break;
    case 'incense':
      switch (variant) {
        case 0:
          _incenseSmoke(pen);
          break;
        case 1:
          _incenseCenser(pen);
          break;
        default:
          _incenseResin(pen);
      }
      break;
    case 'oil':
      _emblemDroplet(pen);
      break;
    case 'resin':
      _emblemResinTear(pen);
      break;
    case 'element':
      _emblemTriangle(pen);
      break;
    case 'color':
      _emblemAura(pen);
      break;
    default:
      _emblemStar(pen);
  }
  return pen.path;
}

// ── HIERBAS ──────────────────────────────────────────────────────────────────

void _herbSprig(_Pen p) {
  // Ramita de agujas (romero/pino): tallo en S con pares de agujas ascendentes.
  p.move(50, 92);
  p.cubic(45, 74, 55, 58, 50, 42);
  p.cubic(47, 32, 51, 22, 50, 12);
  for (var i = 0; i < 6; i++) {
    final y = 80.0 - i * 11.5;
    final len = 20.0 - i * 2.2; // más cortas hacia el ápice
    p.move(50, y);
    p.line(50 - len, y - len * 0.55);
    p.move(50, y - 4);
    p.line(50 + len, y - 4 - len * 0.55);
  }
}

void _herbFlower(_Pen p) {
  // Flor abierta de cinco pétalos sobre tallo con dos hojas.
  p.move(50, 94);
  p.quad(45, 72, 50, 52);
  // hojas
  p.move(50, 74);
  p.quad(30, 74, 26, 63);
  p.quad(38, 66, 50, 71);
  p.move(50, 66);
  p.quad(70, 66, 74, 55);
  p.quad(62, 58, 50, 63);
  // pétalos alrededor del centro (50,38), r base 7 → punta 24
  const cx = 50.0, cy = 38.0;
  for (var k = 0; k < 5; k++) {
    final a = -math.pi / 2 + k * 2 * math.pi / 5;
    final da = 0.36;
    final b1x = cx + 7 * math.cos(a - da), b1y = cy + 7 * math.sin(a - da);
    final b2x = cx + 7 * math.cos(a + da), b2y = cy + 7 * math.sin(a + da);
    final tx = cx + 24 * math.cos(a), ty = cy + 24 * math.sin(a);
    final c1x = cx + 20 * math.cos(a - da * 1.4),
        c1y = cy + 20 * math.sin(a - da * 1.4);
    final c2x = cx + 20 * math.cos(a + da * 1.4),
        c2y = cy + 20 * math.sin(a + da * 1.4);
    p.move(b1x, b1y);
    p.quad(c1x, c1y, tx, ty);
    p.quad(c2x, c2y, b2x, b2y);
  }
  p.circle(cx, cy, 6);
}

void _herbLeaf(_Pen p) {
  // Hoja dentada con nervadura central y venas; dientes como ticks al borde.
  p.move(50, 90);
  p.cubic(24, 74, 24, 34, 50, 10); // borde izquierdo
  p.cubic(76, 34, 76, 74, 50, 90); // borde derecho
  p.move(50, 84);
  p.line(50, 16); // nervio central
  for (var i = 0; i < 5; i++) {
    final t = (i + 1) / 6;
    final y = 82 - t * 62;
    final spread = 24 * math.sin(t * math.pi); // ancho de la hoja a esa altura
    p.move(50, y + 3);
    p.line(50 - spread, y - 2); // vena izquierda
    p.move(50, y + 3);
    p.line(50 + spread, y - 2); // vena derecha
    // diente al borde
    p.move(50 - spread, y - 2);
    p.line(50 - spread - 3.5, y - 5.5);
    p.move(50 + spread, y - 2);
    p.line(50 + spread + 3.5, y - 5.5);
  }
}

void _herbRoot(_Pen p) {
  // Raíz principal con radículas y semillas.
  p.move(50, 14);
  p.cubic(56, 34, 44, 52, 52, 70);
  p.cubic(50, 80, 49, 84, 48, 90); // ápice afinado
  // radículas
  p.move(51, 40);
  p.quad(66, 44, 74, 38);
  p.move(48, 54);
  p.quad(33, 60, 26, 54);
  p.move(51, 66);
  p.quad(64, 72, 70, 66);
  p.move(49, 30);
  p.quad(38, 30, 32, 22);
  // semillas
  p.circle(64, 20, 3.4);
  p.circle(72, 27, 2.6);
  p.circle(58, 16, 2.4);
}

// ── PIEDRAS ──────────────────────────────────────────────────────────────────

List<Offset> _hexagon(double cx, double cy, double r, double rot) => List.generate(
    6, (i) {
  final a = rot + i * math.pi / 3;
  return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
});

void _stoneGem(_Pen p) {
  // Corte facetado (rosa): hexágono exterior, mesa interior y radios.
  final outer = _hexagon(50, 50, 34, -math.pi / 2);
  final inner = _hexagon(50, 50, 15, -math.pi / 2);
  p.move(outer[0].dx, outer[0].dy);
  for (var i = 1; i <= 6; i++) {
    final o = outer[i % 6];
    p.line(o.dx, o.dy);
  }
  p.move(inner[0].dx, inner[0].dy);
  for (var i = 1; i <= 6; i++) {
    final o = inner[i % 6];
    p.line(o.dx, o.dy);
  }
  for (var i = 0; i < 6; i++) {
    p.move(inner[i].dx, inner[i].dy);
    p.line(outer[i].dx, outer[i].dy);
  }
}

void _stonePebble(_Pen p) {
  // Canto rodado: contorno orgánico cerrado + bandas internas.
  p.move(28, 52);
  p.cubic(26, 34, 44, 24, 60, 28);
  p.cubic(76, 32, 80, 50, 72, 64);
  p.cubic(64, 78, 40, 78, 32, 68);
  p.cubic(28, 62, 28, 58, 28, 52);
  p.close();
  // bandas de veta (diagonales suaves, no arcos simétricos)
  p.move(34, 54);
  p.cubic(44, 48, 58, 50, 68, 46);
  p.move(36, 63);
  p.cubic(46, 59, 58, 61, 66, 57);
}

void _stoneGeode(_Pen p) {
  // Drusa/geoda: cáscara exterior, cavidad y cristales interiores.
  p.move(24, 50);
  p.cubic(22, 30, 44, 20, 62, 26);
  p.cubic(82, 32, 82, 58, 70, 72);
  p.cubic(56, 84, 34, 80, 26, 66);
  p.cubic(23, 60, 24, 56, 24, 50);
  p.close();
  // cavidad
  p.move(36, 50);
  p.cubic(36, 38, 50, 34, 60, 38);
  p.cubic(70, 44, 68, 60, 58, 66);
  p.cubic(46, 72, 36, 62, 36, 50);
  p.close();
  // cristales apuntando al centro (fila inferior de la cavidad)
  for (var i = 0; i < 4; i++) {
    final x = 42.0 + i * 6.0;
    p.move(x, 63);
    p.line(x + 3, 55);
    p.line(x + 6, 63);
  }
}

void _stonePoint(_Pen p) {
  // Punta de cuarzo terminada: prisma hexagonal alargado con ápice piramidal.
  p.move(38, 84); // base izq
  p.line(38, 40); // arista izq
  p.line(44, 22); // faceta izq del ápice
  p.line(50, 14); // vértice
  p.line(56, 22); // faceta der del ápice
  p.line(62, 40); // arista der
  p.line(62, 84); // base der
  p.line(38, 84);
  p.close();
  // aristas internas del ápice
  p.move(44, 22);
  p.line(50, 40);
  p.line(56, 22);
  p.move(50, 14);
  p.line(50, 40);
  // arista frontal del prisma
  p.move(50, 40);
  p.line(50, 84);
}

// ── METALES ──────────────────────────────────────────────────────────────────

void _metalIngot(_Pen p) {
  // Lingote en perspectiva: cara superior + frontal + destello.
  p.move(24, 56); // frontal
  p.line(30, 40);
  p.line(74, 40);
  p.line(80, 56);
  p.line(72, 72);
  p.line(32, 72);
  p.close();
  // cara superior
  p.move(30, 40);
  p.line(40, 30);
  p.line(84, 30);
  p.line(74, 40);
  p.move(84, 30);
  p.line(80, 56);
  // destello
  p.move(40, 48);
  p.line(58, 48);
}

void _metalDisc(_Pen p) {
  // Disco/moneda acuñada: aro doble + marca radiante + muescas.
  p.circle(50, 50, 30);
  p.circle(50, 50, 24);
  // marca central (pequeño astro)
  p.circle(50, 50, 7);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    p.move(50 + 9 * math.cos(a), 50 + 9 * math.sin(a));
    p.line(50 + 13 * math.cos(a), 50 + 13 * math.sin(a));
  }
}

void _metalNugget(_Pen p) {
  // Pepita/veta: bloque angular de mineral con facetas internas.
  p.move(28, 58);
  p.line(38, 38);
  p.line(56, 32);
  p.line(74, 44);
  p.line(76, 62);
  p.line(60, 74);
  p.line(38, 72);
  p.close();
  // facetas internas (no rayado paralelo)
  p.move(38, 38);
  p.line(52, 52);
  p.line(74, 44);
  p.move(52, 52);
  p.line(60, 74);
  p.move(52, 52);
  p.line(38, 72);
}

// ── INCIENSOS ────────────────────────────────────────────────────────────────

void _incenseSmoke(_Pen p) {
  // Humo ascendente desde una brasa.
  p.move(40, 84);
  p.line(60, 84); // brasa/base
  p.move(50, 82);
  p.cubic(38, 68, 62, 56, 48, 42);
  p.cubic(38, 30, 58, 22, 50, 12);
  p.move(50, 82);
  p.cubic(60, 66, 44, 54, 56, 40);
}

void _incenseCenser(_Pen p) {
  // Brasero/pebetero: cuenco sobre pie + volutas de humo.
  p.move(30, 62);
  p.quad(50, 80, 70, 62); // cuenco
  p.move(30, 62);
  p.line(70, 62); // borde del cuenco
  p.move(44, 74);
  p.line(40, 84);
  p.line(60, 84);
  p.line(56, 74); // pie
  // humo
  p.move(44, 60);
  p.cubic(36, 48, 52, 40, 44, 28);
  p.move(58, 60);
  p.cubic(66, 48, 50, 40, 58, 26);
}

void _incenseResin(_Pen p) {
  // Lágrimas de resina ardiendo + voluta.
  _tear(p, 40, 66, 7);
  _tear(p, 54, 70, 8);
  _tear(p, 62, 62, 6);
  p.move(52, 60);
  p.cubic(44, 48, 60, 40, 50, 26);
}

void _tear(_Pen p, double cx, double by, double r) {
  // Gota/lágrima: punta arriba, panza abajo, centrada en (cx, by-r).
  p.move(cx, by - 2 * r);
  p.cubic(cx + r, by - r, cx + r, by, cx, by);
  p.cubic(cx - r, by, cx - r, by - r, cx, by - 2 * r);
  p.close();
}

// ── EMBLEMAS ÚNICOS ──────────────────────────────────────────────────────────

void _emblemDroplet(_Pen p) {
  // Aceite: gota grande con destello interior.
  _tear(p, 50, 74, 22);
  p.move(42, 60);
  p.quad(40, 68, 46, 72); // destello
}

void _emblemResinTear(_Pen p) {
  // Resina: lágrima facetada colgando de una ramita.
  p.move(50, 16);
  p.quad(48, 30, 50, 40); // ramita
  _tear(p, 50, 82, 20);
  p.move(50, 44);
  p.line(50, 78); // arista
  p.move(42, 60);
  p.line(58, 60); // faceta
}

void _emblemTriangle(_Pen p) {
  // Elemento: triángulo alquímico con círculo interior.
  p.move(50, 20);
  p.line(78, 74);
  p.line(22, 74);
  p.close();
  p.circle(50, 56, 9);
}

void _emblemAura(_Pen p) {
  // Color: aura radiante (anillos + rayos).
  p.circle(50, 50, 14);
  p.circle(50, 50, 24);
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    p.move(50 + 27 * math.cos(a), 50 + 27 * math.sin(a));
    p.line(50 + 34 * math.cos(a), 50 + 34 * math.sin(a));
  }
}

void _emblemStar(_Pen p) {
  // Sello por defecto: estrella de siete puntas (heptagrama sutil) + halo.
  final pts = List.generate(7, (i) {
    final a = -math.pi / 2 + i * 2 * math.pi / 7;
    return Offset(50 + 30 * math.cos(a), 50 + 30 * math.sin(a));
  });
  p.move(pts[0].dx, pts[0].dy);
  for (var i = 1; i <= 7; i++) {
    final o = pts[(i * 3) % 7]; // salto {7/3}
    p.line(o.dx, o.dy);
  }
  p.close();
  p.circle(50, 50, 34);
}

// ── Pintor + widget ─────────────────────────────────────────────────────────

/// Extrae la fracción [t] (0..1) del recorrido total de [source] (dibujado).
Path _partialPath(Path source, double t) {
  if (t >= 1.0) return source;
  if (t <= 0.0) return Path();
  final metrics = source.computeMetrics().toList();
  final total = metrics.fold<double>(0, (s, m) => s + m.length);
  var budget = total * t;
  final dst = Path();
  for (final m in metrics) {
    if (budget <= 0) break;
    final take = budget < m.length ? budget : m.length;
    dst.addPath(m.extractPath(0, take), Offset.zero);
    budget -= take;
  }
  return dst;
}

class _EngravingPainter extends CustomPainter {
  _EngravingPainter({
    required this.type,
    required this.variant,
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  final String type;
  final int variant;
  final Color color;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final box = size.shortestSide;
    final path = buildEngraving(type, variant, box);
    final drawn = _partialPath(path, progress);
    // centrado
    canvas.save();
    canvas.translate((size.width - box) / 2, (size.height - box) / 2);
    // sombra de plancha (hueco de la línea grabada)
    canvas.drawPath(
      drawn.shift(const Offset(0, 0.9)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.28),
    );
    // línea principal
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EngravingPainter old) =>
      old.type != type ||
      old.variant != variant ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.progress != progress;
}

/// Grabado de una categoría de Materia Arcana, tinta-oro sobre la atmósfera.
///
/// [progress] < 1 dibuja el trazo parcialmente (héroe animado). La tinta se
/// mezcla del acento del [mood] con marfil para leer como grabado antiguo.
class MateriaArt extends StatelessWidget {
  const MateriaArt({
    super.key,
    required this.type,
    required this.variant,
    required this.mood,
    required this.size,
    this.progress = 1.0,
    this.strokeWidth = 1.5,
  });

  final String type;
  final int variant;
  final ArcanumMood mood;
  final double size;
  final double progress;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(mood.accent, ArcanumColors.ivory, 0.34)!
        .withValues(alpha: 0.92);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _EngravingPainter(
          type: type,
          variant: variant,
          color: ink,
          strokeWidth: strokeWidth,
          progress: progress.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

/// Sello de esquina: glifo (planeta o signo) en un disco de hairline, sutil,
/// como la marca de catálogo de una lámina de herbario.
class MateriaSeal extends StatelessWidget {
  const MateriaSeal({
    super.key,
    required this.glyph,
    required this.mood,
    this.size = 26,
  });

  final String glyph;
  final ArcanumMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mood.glow.withValues(alpha: 0.10),
        border: Border.all(color: mood.accent.withValues(alpha: 0.42), width: 0.9),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          fontSize: size * 0.56,
          height: 1,
          color: mood.accent.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}
