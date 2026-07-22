import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import 'engraving_manifest_loader.dart' show normalizeMateriaSlug;

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
      return 9;
    case 'stone':
      return 23;
    case 'metal':
      return 7;
    case 'incense':
      return 12;
    case 'oil':
      return 8;
    case 'resin':
      return 5;
    case 'planet':
    case 'angel':
      return 7;
    case 'sign':
      return 12;
    default:
      return 1;
  }
}

// Los materiales ampliados codifican morfologia (4 bits bajos) e identidad
// de catalogo (bits altos). Conservan una forma fisica reconocible y reciben
// vetas, inclusiones, humo o recipiente irrepetibles por slug.
bool _isMaterialVariant(int variant) => variant >= 16;
int _materialBase(int variant) =>
    _isMaterialVariant(variant) ? (variant - 16) & 0x0f : variant;
int _materialIdentity(int variant) =>
    _isMaterialVariant(variant) ? (variant - 16) >> 4 : variant;

/// Índice de variante ESTABLE para un ítem (mismo slug → mismo grabado siempre).
///
/// Hash tipo DJB2 con multiplicador pequeño (33) y máscara 31-bit en cada paso:
/// los productos quedan muy por debajo de 2^53, así el resultado es idéntico en
/// VM y en web (dart2js compila `int` a `double` de JS — un FNV de 32 bits
/// desborda el entero seguro y colapsa todas las variantes a 0).
int materiaVariant(String slug, String type) {
  final key = normalizeMateriaSlug(slug);
  const semantic = <String, int>{
    // Seis hierbas fundacionales: silueta botánica propia.
    'romero': 0, 'lavanda': 4, 'rosa': 5, 'canela': 6,
    'artemisa': 7, 'salvia': 8,
    // Piedras: el corte sigue la morfología reconocible del material.
    'turmalina-negra': 20, 'labradorita': 39, 'lapislazuli': 49,
    'hematita': 65, 'citrino': 83, 'malaquita': 102,
    'agata-musgo': 118, 'onix-negro': 135, 'jade': 151,
    'rodocrosita': 167, 'sodalita': 183, 'ojo-de-tigre': 198,
    'piedra-luna': 213, 'granate': 224, 'esmeralda': 240,
    'zafiro': 256, 'rubi': 272, 'perla': 293,
    'cuarzo-ahumado': 307, 'cuarzo-claro': 323, 'cuarzo': 323,
    'amatista': 340, 'obsidiana': 353, 'cornalina': 369,
    // Siete metales planetarios y su forma alquímica dominante.
    'oro': 1, 'plata': 1, 'hierro': 5, 'estano': 0, 'plomo': 6,
    'mercurio-metal': 3, 'cobre': 4,
    // Inciensos: resina, madera, raíz/hierba o cristal aromático.
    'copal': 18, 'benjui': 34, 'sangre-de-drago': 50,
    'sandalo-blanco': 67, 'estoraque': 84, 'galbano': 98,
    'opoponax': 114, 'nardo': 132, 'cipres-resina': 147,
    'canfora': 165, 'olibano': 178, 'mirra': 194,
    // Aceites: ocho recipientes rituales individuales.
    'aceite-oliva-sagrado': 16, 'aceite-solar': 33,
    'aceite-lunar': 50, 'aceite-mercurial': 67,
    'aceite-venusino': 84, 'aceite-marcial': 101,
    'aceite-jovial': 118, 'aceite-saturnino': 135,
    // Resinas: forma de exudacion o recipiente propia.
    'resina-pino': 16, 'trementina': 33, 'resina-elemi': 50,
    'resina-labdano': 67, 'resina-mastix': 84,
    // Regentes, inteligencias y signos conservan su orden tradicional.
    'planeta-sol': 0, 'planeta-luna': 1, 'planeta-marte': 2,
    'planeta-mercurio': 3, 'planeta-jupiter': 4, 'planeta-venus': 5,
    'planeta-saturno': 6,
    'arcangel-miguel': 0, 'arcangel-gabriel': 1,
    'arcangel-samael': 2, 'arcangel-rafael': 3,
    'arcangel-sachiel': 4, 'arcangel-anael': 5,
    'arcangel-cassiel': 6,
    'signo-aries': 0, 'signo-tauro': 1, 'signo-geminis': 2,
    'signo-cancer': 3, 'signo-leo': 4, 'signo-virgo': 5,
    'signo-libra': 6, 'signo-escorpio': 7, 'signo-sagitario': 8,
    'signo-capricornio': 9, 'signo-acuario': 10, 'signo-piscis': 11,
  };
  final chosen = semantic[key];
  if (chosen != null) return chosen;
  final n = _variantCount(type);
  if (n <= 1) return 0;
  var h = 5381;
  for (final c in key.codeUnits) {
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
  void circle(double cx, double cy, double r) => path.addOval(
    Rect.fromCircle(center: Offset(_x(cx), _y(cy)), radius: r * s),
  );
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
        case 3:
          _herbRoot(pen);
          break;
        case 4:
          _herbLavender(pen);
          break;
        case 5:
          _herbRose(pen);
          break;
        case 6:
          _herbCinnamon(pen);
          break;
        case 7:
          _herbMugwort(pen);
          break;
        default:
          _herbSage(pen);
      }
      break;
    case 'stone':
      final base = _materialBase(variant);
      switch (base) {
        case 0:
          _stoneGem(pen);
          break;
        case 1:
          _stonePebble(pen);
          break;
        case 2:
          _stoneGeode(pen);
          break;
        case 3:
          _stonePoint(pen);
          break;
        case 4:
          _stoneCluster(pen);
          break;
        case 5:
          _stoneSphere(pen);
          break;
        case 6:
          _stoneBanded(pen);
          break;
        default:
          _stoneCabochon(pen);
      }
      if (_isMaterialVariant(variant)) {
        _stoneSignature(pen, _materialIdentity(variant));
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
        case 2:
          _metalNugget(pen);
          break;
        case 3:
          _metalMercury(pen);
          break;
        case 4:
          _metalCopper(pen);
          break;
        case 5:
          _metalIron(pen);
          break;
        default:
          _metalLead(pen);
      }
      break;
    case 'incense':
      final base = _materialBase(variant);
      switch (base) {
        case 0:
          _incenseSmoke(pen);
          break;
        case 1:
          _incenseCenser(pen);
          break;
        case 2:
          _incenseResin(pen);
          break;
        case 3:
          _incenseWood(pen);
          break;
        case 4:
          _incenseBundle(pen);
          break;
        default:
          _incenseCrystal(pen);
      }
      if (_isMaterialVariant(variant)) {
        _incenseSignature(pen, _materialIdentity(variant));
      }
      break;
    case 'oil':
      _oilVessel(pen, _materialBase(variant));
      break;
    case 'resin':
      _resinVessel(pen, _materialBase(variant));
      break;
    case 'element':
      _emblemTriangle(pen);
      break;
    case 'color':
      _emblemAura(pen);
      break;
    case 'planet':
      _emblemPlanet(pen, variant);
      break;
    case 'angel':
      _emblemWings(pen, variant);
      break;
    case 'sign':
      _emblemZodiac(pen, variant);
      break;
    default:
      _emblemStar(pen);
  }
  return pen.path;
}

// ── HIERBAS ──────────────────────────────────────────────────────────────────

void _herbSprig(_Pen p) {
  // Romero: mata ramificada con agujas opuestas y flores axilares.
  p.move(50, 92);
  p.cubic(45, 74, 55, 58, 50, 42);
  p.cubic(47, 32, 51, 22, 50, 12);
  p.move(48, 68);
  p.cubic(39, 61, 31, 50, 27, 36);
  p.move(52, 61);
  p.cubic(62, 53, 69, 42, 74, 28);
  const branches = <(double, double, double, double)>[
    (50, 84, 50, 14),
    (48, 68, 27, 36),
    (52, 61, 74, 28),
  ];
  for (final (x1, y1, x2, y2) in branches) {
    for (var i = 1; i < 7; i++) {
      final t = i / 7;
      final x = x1 + (x2 - x1) * t;
      final y = y1 + (y2 - y1) * t;
      final dx = (y2 - y1) * .13;
      final dy = (x1 - x2) * .13;
      p.move(x, y);
      p.line(x - dx, y - dy);
      p.move(x + 1, y - 2);
      p.line(x + dx, y + dy - 2);
    }
  }
  p.circle(38, 52, 2.4);
  p.circle(62, 46, 2.4);
  p.circle(47, 31, 2.2);
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

void _herbLavender(_Pen p) {
  // Mata de lavanda: cinco espigas de alturas desiguales y follaje basal.
  for (final x in [28.0, 39.0, 50.0, 61.0, 72.0]) {
    final top = x == 50 ? 12.0 : 24.0;
    p.move(x, 90);
    final bend = (x - 50) * .12;
    p.cubic(x - bend, 68, x + bend, 46, x, top);
    for (var i = 0; i < 6; i++) {
      final y = top + 7 + i * 5.4;
      p.move(x, y);
      p.quad(x - 6, y - 4, x - 8, y);
      p.move(x, y + 2);
      p.quad(x + 6, y - 3, x + 8, y + 2);
    }
  }
  for (final x in [30.0, 40.0, 50.0, 60.0, 70.0]) {
    p.move(50, 88);
    p.quad(x, 80, x + (x < 50 ? -6 : 6), 66);
  }
}

void _herbRose(_Pen p) {
  // Rosa de jardín: corola concéntrica, cáliz, tallo y hojas serradas.
  p.move(50, 94);
  p.cubic(46, 76, 54, 59, 50, 45);
  p.move(50, 74);
  p.quad(32, 72, 25, 61);
  p.quad(37, 62, 50, 70);
  p.move(51, 65);
  p.quad(69, 63, 76, 52);
  p.quad(63, 54, 51, 61);
  p.circle(50, 31, 5);
  for (final r in [11.0, 18.0, 25.0]) {
    final petals = r == 11 ? 5 : (r == 18 ? 7 : 9);
    for (var i = 0; i < petals; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / petals + r * .01;
      final x = 50 + r * math.cos(a);
      final y = 31 + r * .72 * math.sin(a);
      p.move(
        50 + r * .45 * math.cos(a - .35),
        31 + r * .32 * math.sin(a - .35),
      );
      p.quad(
        x,
        y,
        50 + r * .45 * math.cos(a + .35),
        31 + r * .32 * math.sin(a + .35),
      );
    }
  }
}

void _herbCinnamon(_Pen p) {
  // Corteza enrollada y rama de hojas opuestas.
  p.move(24, 72);
  p.line(64, 28);
  p.line(76, 40);
  p.line(36, 84);
  p.close();
  p.move(30, 73);
  p.cubic(38, 82, 45, 77, 42, 69);
  p.move(58, 33);
  p.cubic(67, 25, 75, 31, 70, 40);
  p.move(48, 60);
  p.line(78, 76);
  p.move(58, 65);
  p.quad(65, 51, 72, 50);
  p.quad(75, 60, 62, 68);
  p.move(66, 70);
  p.quad(78, 65, 84, 71);
  p.quad(78, 79, 68, 74);
}

void _herbMugwort(_Pen p) {
  // Artemisa: hoja profundamente lobulada y espiga de cabezuelas.
  p.move(48, 92);
  p.cubic(44, 72, 54, 48, 50, 14);
  for (var i = 0; i < 6; i++) {
    final y = 76.0 - i * 10;
    final spread = 25.0 - i * 2.4;
    p.move(49, y);
    p.quad(38, y - 8, 50 - spread, y - 4);
    p.quad(35, y + 1, 49, y + 3);
    p.move(51, y - 4);
    p.quad(64, y - 12, 50 + spread, y - 9);
    p.quad(65, y - 2, 51, y);
  }
  p.circle(44, 13, 2.6);
  p.circle(51, 9, 2.4);
  p.circle(57, 15, 2.8);
}

void _herbSage(_Pen p) {
  // Salvia: hojas anchas, opuestas y de borde ondulado.
  p.move(50, 94);
  p.cubic(47, 72, 53, 48, 50, 15);
  for (var i = 0; i < 4; i++) {
    final y = 76.0 - i * 15;
    final len = 24.0 - i * 2;
    p.move(50, y);
    p.cubic(38, y - 10, 29, y - 7, 50 - len, y - 2);
    p.cubic(32, y + 6, 41, y + 8, 50, y + 3);
    p.move(50, y - 5);
    p.cubic(62, y - 15, 71, y - 12, 50 + len, y - 7);
    p.cubic(68, y + 1, 59, y + 3, 50, y - 2);
  }
  p.move(50, 23);
  p.quad(42, 12, 38, 17);
  p.move(50, 19);
  p.quad(58, 8, 63, 14);
}

// ── PIEDRAS ──────────────────────────────────────────────────────────────────

List<Offset> _hexagon(double cx, double cy, double r, double rot) =>
    List.generate(6, (i) {
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

void _stoneCluster(_Pen p) {
  // Drusa: cinco puntas de alturas y anchos distintos sobre matriz rocosa.
  const crystals = <(double, double, double)>[
    (28, 50, 15),
    (39, 34, 18),
    (51, 18, 20),
    (63, 38, 16),
    (73, 52, 13),
  ];
  for (final (x, top, half) in crystals) {
    p.move(x - half * .45, 77);
    p.line(x - half * .45, top + 10);
    p.line(x, top);
    p.line(x + half * .45, top + 10);
    p.line(x + half * .45, 77);
    p.move(x, top);
    p.line(x, 77);
  }
  p.move(20, 76);
  p.cubic(34, 68, 65, 70, 82, 78);
  p.line(72, 86);
  p.line(31, 86);
  p.close();
}

void _stoneSphere(_Pen p) {
  // Perla/esfera lunar sobre pequeño pedestal de museo.
  p.circle(50, 45, 27);
  p.move(31, 37);
  p.cubic(36, 25, 46, 18, 57, 19);
  p.move(39, 70);
  p.line(34, 83);
  p.line(66, 83);
  p.line(61, 70);
  p.move(38, 78);
  p.quad(50, 72, 62, 78);
}

void _stoneBanded(_Pen p) {
  // Mineral bandeado: contorno irregular con estratos orgánicos.
  p.move(24, 58);
  p.cubic(22, 37, 39, 22, 60, 25);
  p.cubic(78, 28, 83, 49, 74, 68);
  p.cubic(62, 82, 35, 79, 26, 66);
  p.close();
  p.move(27, 48);
  p.cubic(40, 39, 57, 46, 76, 38);
  p.move(25, 58);
  p.cubic(39, 49, 59, 59, 77, 49);
  p.move(29, 69);
  p.cubic(43, 60, 57, 72, 71, 62);
}

void _stoneCabochon(_Pen p) {
  // Cabujón pulido: gema oval en engaste fino.
  p.move(50, 16);
  p.cubic(74, 18, 82, 39, 75, 61);
  p.cubic(69, 82, 31, 82, 25, 61);
  p.cubic(18, 39, 26, 18, 50, 16);
  p.close();
  p.move(50, 24);
  p.cubic(66, 25, 72, 42, 68, 58);
  p.cubic(62, 71, 38, 71, 32, 58);
  p.cubic(28, 42, 34, 25, 50, 24);
  p.close();
  p.move(34, 36);
  p.quad(43, 27, 52, 28);
}

/// Marca mineralogica individual: veta, inclusion o plano de exfoliacion.
/// La combinacion de motivo y puntos de catalogo es unica para las 23 piedras.
void _stoneSignature(_Pen p, int identity) {
  switch (identity % 5) {
    case 0:
      p.move(32, 53);
      p.cubic(42, 45, 52, 61, 68, 49);
      break;
    case 1:
      p.move(37, 35);
      p.line(62, 67);
      p.move(59, 34);
      p.line(42, 66);
      break;
    case 2:
      p.circle(50, 49, 9);
      p.circle(50, 49, 3);
      break;
    case 3:
      p.move(31, 45);
      p.quad(50, 34, 69, 45);
      p.move(31, 57);
      p.quad(50, 68, 69, 57);
      break;
    default:
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        p.move(50, 50);
        p.line(50 + 17 * math.cos(a), 50 + 17 * math.sin(a));
      }
  }
  final marks = 1 + identity ~/ 5;
  for (var i = 0; i < marks; i++) {
    p.circle(34 + i * 8.0, 87, 1.5);
  }
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

void _metalMercury(_Pen p) {
  // Azogue: gotas coalescentes dentro de una retorta alquímica.
  p.circle(40, 60, 14);
  p.circle(60, 62, 17);
  p.circle(52, 39, 10);
  p.move(47, 29);
  p.line(47, 15);
  p.line(56, 15);
  p.line(56, 30);
  p.move(32, 77);
  p.quad(50, 85, 70, 78);
}

void _metalCopper(_Pen p) {
  // Cobre: espiral conductora sobre lámina martillada.
  p.move(22, 68);
  p.line(30, 28);
  p.line(78, 32);
  p.line(70, 74);
  p.close();
  p.move(51, 50);
  for (var i = 0; i < 3; i++) {
    final r = 7.0 + i * 7;
    p.move(51 + r, 50);
    p.cubic(51 + r, 50 - r, 51 - r, 50 - r, 51 - r, 50);
    p.cubic(51 - r, 50 + r, 51 + r, 50 + r, 51 + r, 50);
  }
}

void _metalIron(_Pen p) {
  // Hierro: hoja forjada y marcas de martillo.
  p.move(50, 12);
  p.line(66, 34);
  p.line(57, 73);
  p.line(50, 88);
  p.line(43, 73);
  p.line(34, 34);
  p.close();
  p.move(50, 18);
  p.line(50, 76);
  p.move(40, 38);
  p.line(60, 38);
  p.move(43, 55);
  p.line(57, 55);
}

void _metalLead(_Pen p) {
  // Plomo: pesa saturnina, densa y estable.
  p.move(39, 24);
  p.quad(50, 14, 61, 24);
  p.line(65, 39);
  p.line(76, 75);
  p.quad(50, 86, 24, 75);
  p.line(35, 39);
  p.close();
  p.circle(50, 28, 6);
  p.move(32, 69);
  p.quad(50, 76, 68, 69);
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

void _incenseWood(_Pen p) {
  // Maderas aromáticas: tres astillas cruzadas y humo tenue.
  p.move(24, 72);
  p.line(70, 42);
  p.line(76, 50);
  p.line(30, 80);
  p.close();
  p.move(28, 48);
  p.line(72, 70);
  p.line(68, 79);
  p.line(24, 57);
  p.close();
  p.move(52, 42);
  p.cubic(42, 31, 61, 25, 52, 14);
}

void _incenseBundle(_Pen p) {
  // Nardo/raíces: haz atado listo para el sahumerio.
  for (final x in [35.0, 43.0, 51.0, 59.0, 67.0]) {
    p.move(x, 80);
    p.cubic(x - 7, 64, x + 7, 46, x - 2, 25 + (x % 3) * 4);
  }
  p.move(28, 61);
  p.cubic(40, 55, 61, 68, 74, 59);
  p.move(29, 66);
  p.cubic(42, 60, 60, 73, 73, 64);
}

void _incenseCrystal(_Pen p) {
  // Alcanfor: cristales aromáticos sublimándose.
  _stoneCluster(p);
  p.move(50, 42);
  p.cubic(39, 31, 62, 24, 51, 12);
  p.move(61, 46);
  p.cubic(72, 35, 58, 29, 67, 20);
}

/// Firma aromatica individual: cada materia conserva su forma de origen y
/// recibe una voluta propia y un numero de granos de catalogo irrepetible.
void _incenseSignature(_Pen p, int identity) {
  switch (identity % 4) {
    case 0:
      p.move(39, 34);
      p.cubic(28, 25, 44, 18, 35, 10);
      break;
    case 1:
      p.move(61, 38);
      p.cubic(73, 29, 57, 21, 67, 12);
      break;
    case 2:
      p.move(38, 39);
      p.cubic(25, 30, 45, 24, 34, 14);
      p.move(62, 37);
      p.cubic(73, 29, 57, 22, 67, 13);
      break;
    default:
      p.move(50, 38);
      p.cubic(35, 28, 65, 23, 48, 10);
      p.circle(65, 22, 2);
  }
  final grains = 1 + identity ~/ 4;
  for (var i = 0; i < grains; i++) {
    p.circle(42 + i * 8.0, 88, 1.6);
  }
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

void _oilVessel(_Pen p, int variant) {
  switch (variant) {
    case 0: // Oliva consagrada: gota primordial.
      _emblemDroplet(p);
      p.move(33, 82);
      p.quad(50, 88, 67, 82);
      break;
    case 1: // Solar: ampolla radiante.
      p.move(42, 17);
      p.line(58, 17);
      p.line(60, 31);
      p.cubic(76, 40, 76, 67, 66, 82);
      p.line(34, 82);
      p.cubic(24, 67, 24, 40, 40, 31);
      p.close();
      p.circle(50, 57, 11);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        p.move(50 + 14 * math.cos(a), 57 + 14 * math.sin(a));
        p.line(50 + 19 * math.cos(a), 57 + 19 * math.sin(a));
      }
      break;
    case 2: // Lunar: matraz redondo con creciente.
      p.move(44, 14);
      p.line(56, 14);
      p.line(56, 31);
      p.cubic(76, 43, 75, 72, 61, 83);
      p.line(39, 83);
      p.cubic(25, 72, 24, 43, 44, 31);
      p.close();
      p.move(57, 47);
      p.cubic(41, 49, 40, 68, 57, 71);
      p.cubic(48, 64, 48, 54, 57, 47);
      break;
    case 3: // Mercurial: vial alto y alado.
      p.move(43, 13);
      p.line(57, 13);
      p.line(57, 68);
      p.quad(50, 83, 43, 68);
      p.close();
      p.move(42, 27);
      p.quad(31, 22, 25, 31);
      p.quad(34, 30, 42, 38);
      p.move(58, 27);
      p.quad(69, 22, 75, 31);
      p.quad(66, 30, 58, 38);
      p.move(38, 18);
      p.line(62, 18);
      break;
    case 4: // Venusino: perfumero de cintura estrecha.
      p.move(40, 19);
      p.quad(50, 11, 60, 19);
      p.line(57, 31);
      p.cubic(72, 42, 72, 69, 63, 82);
      p.quad(50, 75, 37, 82);
      p.cubic(28, 69, 28, 42, 43, 31);
      p.close();
      p.circle(50, 55, 10);
      p.move(50, 65);
      p.line(50, 75);
      p.move(44, 70);
      p.line(56, 70);
      break;
    case 5: // Marcial: frasco angular protegido.
      p.move(41, 16);
      p.line(59, 16);
      p.line(61, 31);
      p.line(74, 45);
      p.line(66, 83);
      p.line(34, 83);
      p.line(26, 45);
      p.line(39, 31);
      p.close();
      p.circle(47, 57, 9);
      p.move(54, 50);
      p.line(65, 39);
      p.line(65, 48);
      break;
    case 6: // Jovial: vaso ancho de abundancia.
      p.move(35, 25);
      p.quad(50, 16, 65, 25);
      p.line(70, 70);
      p.quad(50, 90, 30, 70);
      p.close();
      p.move(28, 35);
      p.quad(19, 48, 32, 58);
      p.move(72, 35);
      p.quad(81, 48, 68, 58);
      p.move(36, 54);
      p.quad(50, 64, 64, 54);
      break;
    default: // Saturnino: botella cuadrada y sellada.
      p.move(39, 15);
      p.line(61, 15);
      p.line(61, 30);
      p.line(72, 39);
      p.line(69, 83);
      p.line(31, 83);
      p.line(28, 39);
      p.line(39, 30);
      p.close();
      p.move(35, 49);
      p.line(65, 49);
      p.move(39, 64);
      p.line(61, 64);
      p.circle(50, 72, 5);
  }
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

void _resinVessel(_Pen p, int variant) {
  switch (variant) {
    case 0:
      _emblemResinTear(p);
      break;
    case 1:
      _incenseResin(p);
      p.move(28, 78);
      p.quad(50, 87, 74, 78);
      break;
    case 2:
      p.move(22, 31);
      p.quad(50, 20, 78, 31);
      p.move(50, 27);
      p.line(50, 50);
      _tear(p, 50, 81, 15);
      _tear(p, 31, 68, 8);
      _tear(p, 69, 68, 8);
      break;
    case 3:
      p.move(31, 35);
      p.line(69, 35);
      p.line(74, 78);
      p.quad(50, 86, 26, 78);
      p.close();
      p.move(36, 27);
      p.line(64, 27);
      p.line(69, 35);
      p.line(31, 35);
      p.close();
      _tear(p, 50, 70, 11);
      break;
    default:
      // Mastic: lagrimas pequenas perladas todavia unidas a la rama.
      p.move(25, 28);
      p.cubic(39, 19, 61, 36, 77, 22);
      for (var i = 0; i < 5; i++) {
        final x = 32.0 + i * 9;
        final y = 32.0 + (i.isEven ? 2 : 8);
        p.move(x, 28 + (i.isEven ? 0 : 5));
        p.line(x, y + 5);
        _tear(p, x, y + 17, 5);
      }
      p.move(28, 78);
      p.quad(50, 87, 72, 78);
  }
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

void _emblemPlanet(_Pen p, int variant) {
  // Sello orbital común; el núcleo porta el glifo geométrico del regente.
  p.move(17, 50);
  p.cubic(24, 25, 76, 25, 83, 50);
  p.cubic(76, 75, 24, 75, 17, 50);
  p.move(50, 17);
  p.cubic(75, 24, 75, 76, 50, 83);
  p.cubic(25, 76, 25, 24, 50, 17);
  p.circle(77, 39, 3);
  switch (variant) {
    case 0: // Sol
      p.circle(50, 50, 13);
      p.circle(50, 50, 2.5);
      break;
    case 1: // Luna
      p.move(57, 36);
      p.cubic(39, 39, 38, 62, 57, 65);
      p.cubic(47, 58, 47, 43, 57, 36);
      break;
    case 2: // Marte
      p.circle(46, 54, 11);
      p.move(54, 46);
      p.line(66, 34);
      p.move(58, 34);
      p.line(66, 34);
      p.line(66, 42);
      break;
    case 3: // Mercurio
      p.circle(50, 49, 9);
      p.move(43, 39);
      p.quad(50, 31, 57, 39);
      p.move(50, 58);
      p.line(50, 68);
      p.move(44, 64);
      p.line(56, 64);
      break;
    case 4: // Júpiter
      p.move(40, 38);
      p.cubic(58, 34, 57, 48, 43, 55);
      p.line(63, 55);
      p.move(56, 36);
      p.line(50, 68);
      break;
    case 5: // Venus
      p.circle(50, 45, 11);
      p.move(50, 56);
      p.line(50, 69);
      p.move(43, 64);
      p.line(57, 64);
      break;
    default: // Saturno
      p.move(45, 33);
      p.line(45, 66);
      p.move(38, 42);
      p.line(54, 42);
      p.cubic(62, 44, 61, 55, 52, 58);
      p.cubic(61, 61, 60, 68, 55, 71);
  }
}

void _emblemWings(_Pen p, int variant) {
  p.circle(50, 31, 8);
  p.move(50, 39);
  p.line(50, 83);
  p.move(48, 48);
  p.cubic(34, 31, 19, 32, 15, 42);
  p.cubic(28, 41, 22, 55, 42, 68);
  p.move(52, 48);
  p.cubic(66, 31, 81, 32, 85, 42);
  p.cubic(72, 41, 78, 55, 58, 68);
  p.move(31, 45);
  p.line(42, 61);
  p.move(69, 45);
  p.line(58, 61);
  // Marca de la inteligencia planetaria: siete terminales irrepetibles.
  final rays = variant + 1;
  for (var i = 0; i < rays; i++) {
    final a = math.pi * (0.15 + 0.7 * i / math.max(1, rays - 1));
    p.move(50 + 11 * math.cos(a), 75 + 6 * math.sin(a));
    p.line(50 + 18 * math.cos(a), 75 + 10 * math.sin(a));
  }
}

void _emblemZodiac(_Pen p, int variant) {
  p.circle(50, 50, 31);
  p.circle(50, 50, 20);
  for (var i = 0; i < 12; i++) {
    final a = -math.pi / 2 + i * math.pi / 6;
    p.move(50 + 22 * math.cos(a), 50 + 22 * math.sin(a));
    p.line(50 + 31 * math.cos(a), 50 + 31 * math.sin(a));
  }
  // El radio iluminado sitúa al signo en su casa dentro de la rueda completa.
  final a = -math.pi / 2 + (variant % 12) * math.pi / 6;
  p.move(50, 50);
  p.line(50 + 29 * math.cos(a), 50 + 29 * math.sin(a));
  p.circle(50 + 25 * math.cos(a), 50 + 25 * math.sin(a), 3.5);
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
/// Pictograma de catálogo sin vetas, rayado ni ornamento interior.
class MateriaGlyph extends StatelessWidget {
  const MateriaGlyph({
    super.key,
    required this.type,
    required this.size,
    required this.variant,
    this.progress = 1,
  });

  final String type;
  final double size;
  final int variant;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(
      ArcanumColors.gold,
      ArcanumColors.ivory,
      0.12,
    )!.withValues(alpha: 0.94);
    final glyph = CustomPaint(
      size: Size.square(size),
      painter: _MinimalGlyphPainter(type: type, variant: variant, color: ink),
    );
    if (progress >= 1) return glyph;
    return RepaintBoundary(
      child: Opacity(
        opacity: Curves.easeOut.transform(progress.clamp(0.0, 1.0)),
        child: glyph,
      ),
    );
  }
}

class _MinimalGlyphPainter extends CustomPainter {
  const _MinimalGlyphPainter({
    required this.type,
    required this.variant,
    required this.color,
  });

  final String type;
  final int variant;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.scale(s, s);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (type) {
      case 'herb':
        _herb(canvas, line, fill, variant % 9);
        break;
      case 'stone':
        _stone(canvas, line, variant % 5);
        break;
      case 'metal':
        _metal(canvas, line, fill, variant % 5);
        break;
      case 'incense':
        _incense(canvas, line, fill, variant % 4);
        break;
      case 'oil':
        _oil(canvas, line, variant % 4);
        break;
      case 'resin':
        _resin(canvas, line, fill, variant % 5);
        break;
      case 'planet':
        canvas.drawCircle(const Offset(50, 50), 27, line);
        canvas.drawCircle(const Offset(50, 50), 5, fill);
        break;
      case 'angel':
        canvas.drawPath(
          Path()
            ..moveTo(50, 72)
            ..quadraticBezierTo(25, 67, 22, 35)
            ..quadraticBezierTo(42, 39, 50, 59)
            ..quadraticBezierTo(58, 39, 78, 35)
            ..quadraticBezierTo(75, 67, 50, 72),
          line,
        );
        break;
      case 'sign':
        canvas.drawPath(
          Path()
            ..moveTo(50, 17)
            ..lineTo(58, 42)
            ..lineTo(83, 50)
            ..lineTo(58, 58)
            ..lineTo(50, 83)
            ..lineTo(42, 58)
            ..lineTo(17, 50)
            ..lineTo(42, 42)
            ..close(),
          line,
        );
        break;
      case 'element':
        canvas.drawPath(
          Path()
            ..moveTo(50, 20)
            ..lineTo(79, 75)
            ..lineTo(21, 75)
            ..close(),
          line,
        );
        break;
      case 'color':
        canvas.drawCircle(const Offset(50, 50), 25, fill);
        break;
      default:
        canvas.drawCircle(const Offset(50, 50), 25, line);
    }

    canvas.restore();
  }

  void _herb(Canvas canvas, Paint line, Paint fill, int v) {
    switch (v) {
      case 0: // ramita
        canvas.drawLine(const Offset(50, 80), const Offset(50, 22), line);
        _leaf(canvas, const Offset(50, 38), const Offset(29, 28), fill);
        _leaf(canvas, const Offset(50, 53), const Offset(72, 42), fill);
        _leaf(canvas, const Offset(50, 67), const Offset(31, 57), fill);
        break;
      case 1: // flor
        canvas.drawLine(const Offset(50, 78), const Offset(50, 38), line);
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + i * math.pi * 2 / 5;
          canvas.drawCircle(
            Offset(50 + math.cos(angle) * 8, 29 + math.sin(angle) * 8),
            5.5,
            fill,
          );
        }
        _leaf(canvas, const Offset(50, 59), const Offset(69, 49), fill);
        break;
      case 2: // hoja
        _leaf(canvas, const Offset(32, 72), const Offset(68, 25), line);
        canvas.drawLine(const Offset(32, 72), const Offset(63, 32), line);
        break;
      case 3: // raíz
        canvas.drawLine(const Offset(50, 20), const Offset(50, 57), line);
        canvas.drawPath(
          Path()
            ..moveTo(50, 53)
            ..lineTo(31, 77)
            ..moveTo(50, 57)
            ..lineTo(50, 82)
            ..moveTo(50, 60)
            ..lineTo(69, 77),
          line,
        );
        _leaf(canvas, const Offset(50, 36), const Offset(68, 27), fill);
        break;
      case 4: // espiga
        canvas.drawLine(const Offset(50, 82), const Offset(50, 20), line);
        _leaf(canvas, const Offset(50, 36), const Offset(37, 27), fill);
        _leaf(canvas, const Offset(50, 48), const Offset(63, 39), fill);
        _leaf(canvas, const Offset(50, 60), const Offset(37, 51), fill);
        break;
      case 5: // rosa
        canvas.drawLine(const Offset(50, 78), const Offset(50, 43), line);
        canvas.drawPath(
          Path()
            ..moveTo(36, 25)
            ..quadraticBezierTo(42, 17, 50, 25)
            ..quadraticBezierTo(58, 17, 64, 25)
            ..quadraticBezierTo(63, 43, 50, 45)
            ..quadraticBezierTo(37, 43, 36, 25)
            ..close(),
          line,
        );
        _leaf(canvas, const Offset(50, 60), const Offset(31, 50), fill);
        _leaf(canvas, const Offset(50, 68), const Offset(68, 58), fill);
        break;
      case 6: // corteza / canela
        canvas.drawLine(const Offset(35, 72), const Offset(55, 25), line);
        canvas.drawLine(const Offset(48, 77), const Offset(68, 30), line);
        canvas.drawLine(const Offset(39, 52), const Offset(61, 61), line);
        break;
      case 7: // artemisa
        canvas.drawLine(const Offset(50, 80), const Offset(50, 25), line);
        canvas.drawLine(const Offset(50, 46), const Offset(31, 34), line);
        canvas.drawLine(const Offset(50, 57), const Offset(70, 43), line);
        canvas.drawLine(const Offset(50, 68), const Offset(33, 61), line);
        canvas.drawCircle(const Offset(50, 22), 4, fill);
        break;
      default: // hoja ancha / salvia
        canvas.drawPath(
          Path()
            ..moveTo(50, 79)
            ..cubicTo(22, 64, 27, 31, 50, 20)
            ..cubicTo(73, 31, 78, 64, 50, 79)
            ..close(),
          line,
        );
        canvas.drawLine(const Offset(50, 76), const Offset(50, 28), line);
    }
  }

  void _stone(Canvas canvas, Paint line, int v) {
    final path = switch (v) {
      0 =>
        Path()
          ..moveTo(50, 18)
          ..lineTo(79, 43)
          ..lineTo(68, 78)
          ..lineTo(32, 78)
          ..lineTo(21, 43)
          ..close(),
      1 =>
        Path()
          ..moveTo(50, 16)
          ..lineTo(72, 39)
          ..lineTo(61, 82)
          ..lineTo(39, 82)
          ..lineTo(28, 39)
          ..close(),
      2 =>
        Path()
          ..moveTo(50, 15)
          ..lineTo(78, 66)
          ..lineTo(64, 80)
          ..lineTo(36, 80)
          ..lineTo(22, 66)
          ..close(),
      3 =>
        Path()
          ..moveTo(28, 72)
          ..quadraticBezierTo(20, 43, 43, 24)
          ..quadraticBezierTo(70, 19, 78, 48)
          ..quadraticBezierTo(80, 73, 28, 72)
          ..close(),
      _ =>
        Path()
          ..moveTo(21, 73)
          ..lineTo(28, 39)
          ..lineTo(42, 52)
          ..lineTo(50, 20)
          ..lineTo(59, 51)
          ..lineTo(73, 36)
          ..lineTo(79, 73)
          ..close(),
    };
    canvas.drawPath(path, line);
  }

  void _metal(Canvas canvas, Paint line, Paint fill, int v) {
    switch (v) {
      case 0:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 34, 56, 34),
            const Radius.circular(7),
          ),
          line,
        );
        canvas.drawLine(const Offset(34, 51), const Offset(66, 51), line);
        break;
      case 1:
        canvas.drawCircle(const Offset(50, 50), 27, line);
        canvas.drawCircle(const Offset(50, 50), 4, fill);
        break;
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(25, 65)
            ..quadraticBezierTo(18, 39, 39, 27)
            ..quadraticBezierTo(66, 18, 78, 45)
            ..quadraticBezierTo(82, 73, 25, 65)
            ..close(),
          line,
        );
        break;
      case 3:
        _drop(canvas, line, 50, 16, 25);
        break;
      default:
        canvas.drawArc(
          const Rect.fromLTWH(22, 22, 56, 56),
          0.35,
          math.pi * 1.75,
          false,
          line,
        );
    }
  }

  void _incense(Canvas canvas, Paint line, Paint fill, int v) {
    if (v == 1) {
      canvas.drawLine(const Offset(35, 75), const Offset(55, 37), line);
      canvas.drawCircle(const Offset(34, 77), 4, fill);
      canvas.drawPath(
        Path()
          ..moveTo(57, 34)
          ..cubicTo(44, 27, 66, 22, 56, 15),
        line,
      );
      return;
    }
    if (v == 2) {
      canvas.drawLine(const Offset(38, 75), const Offset(42, 28), line);
      canvas.drawLine(const Offset(50, 77), const Offset(50, 24), line);
      canvas.drawLine(const Offset(62, 75), const Offset(58, 28), line);
      canvas.drawLine(const Offset(34, 53), const Offset(66, 53), line);
      return;
    }
    if (v == 3) {
      canvas.drawCircle(const Offset(37, 64), 8, line);
      canvas.drawCircle(const Offset(54, 66), 9, line);
      canvas.drawCircle(const Offset(66, 59), 7, line);
      canvas.drawPath(
        Path()
          ..moveTo(51, 49)
          ..cubicTo(37, 39, 64, 32, 50, 20),
        line,
      );
      return;
    }
    canvas.drawArc(
      const Rect.fromLTWH(25, 45, 50, 28),
      0,
      math.pi,
      false,
      line,
    );
    canvas.drawLine(const Offset(33, 60), const Offset(67, 60), line);
    canvas.drawPath(
      Path()
        ..moveTo(50, 43)
        ..cubicTo(37, 35, 63, 28, 50, 18),
      line,
    );
  }

  void _oil(Canvas canvas, Paint line, int v) {
    final neck = v == 1 ? 37.0 : (v == 2 ? 44.0 : 41.0);
    final rightNeck = 100 - neck;
    final side = v == 3 ? 25.0 : (v == 1 ? 35.0 : 30.0);
    final shoulder = v == 2 ? 45.0 : 39.0;
    canvas.drawPath(
      Path()
        ..moveTo(neck, 21)
        ..lineTo(rightNeck, 21)
        ..lineTo(rightNeck, 33)
        ..quadraticBezierTo(100 - side, shoulder, 100 - side, 55)
        ..lineTo(100 - side - 3, 77)
        ..lineTo(side + 3, 77)
        ..lineTo(side, 55)
        ..quadraticBezierTo(side, shoulder, neck, 33)
        ..close(),
      line,
    );
  }

  void _resin(Canvas canvas, Paint line, Paint fill, int v) {
    switch (v) {
      case 0:
        _drop(canvas, line, 50, 18, 21);
        break;
      case 1:
        canvas.drawCircle(const Offset(35, 61), 11, line);
        canvas.drawCircle(const Offset(53, 55), 14, line);
        canvas.drawCircle(const Offset(68, 65), 9, line);
        break;
      case 2:
        canvas.drawOval(const Rect.fromLTWH(22, 35, 56, 38), line);
        break;
      case 3:
        _drop(canvas, line, 38, 27, 15);
        _drop(canvas, line, 64, 38, 12);
        break;
      default:
        canvas.drawArc(
          const Rect.fromLTWH(23, 45, 54, 30),
          0,
          math.pi,
          false,
          line,
        );
        canvas.drawCircle(const Offset(50, 50), 8, fill);
    }
  }

  void _drop(Canvas canvas, Paint line, double cx, double top, double r) {
    canvas.drawPath(
      Path()
        ..moveTo(cx, top)
        ..cubicTo(
          cx - r * 0.4,
          top + r,
          cx - r,
          top + r * 1.45,
          cx - r,
          top + r * 2,
        )
        ..cubicTo(cx - r, top + r * 3, cx + r, top + r * 3, cx + r, top + r * 2)
        ..cubicTo(cx + r, top + r * 1.45, cx + r * 0.4, top + r, cx, top)
        ..close(),
      line,
    );
  }

  void _leaf(Canvas canvas, Offset stem, Offset tip, Paint paint) {
    final delta = tip - stem;
    final normal = Offset(-delta.dy, delta.dx) * 0.24;
    canvas.drawPath(
      Path()
        ..moveTo(stem.dx, stem.dy)
        ..quadraticBezierTo(
          stem.dx + delta.dx * 0.55 + normal.dx,
          stem.dy + delta.dy * 0.55 + normal.dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          stem.dx + delta.dx * 0.55 - normal.dx,
          stem.dy + delta.dy * 0.55 - normal.dy,
          stem.dx,
          stem.dy,
        )
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimalGlyphPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.variant != variant ||
      oldDelegate.color != color;
}

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
    final ink = Color.lerp(
      mood.accent,
      ArcanumColors.ivory,
      0.34,
    )!.withValues(alpha: 0.92);
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
        border: Border.all(
          color: mood.accent.withValues(alpha: 0.42),
          width: 0.9,
        ),
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
