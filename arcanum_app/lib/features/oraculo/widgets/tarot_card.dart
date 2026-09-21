import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';

const _roman = [
  '0',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
  'X',
  'XI',
  'XII',
  'XIII',
  'XIV',
  'XV',
  'XVI',
  'XVII',
  'XVIII',
  'XIX',
  'XX',
  'XXI',
];

// ── Firma esotérica de los 22 Mayores (atribución Golden Dawn, orden RWS:
//    Fuerza=VIII, Justicia=XI). Independiente del seed: aunque el backend no
//    haya poblado hebrew_letter/astro_correspondence, la cara se dibuja fiel.
//    Glifos astrológicos para planeta/signo; elemento (0,12,20) va vectorial.
const _majorGlyph = <int, String>{
  1: '☿',
  2: '☽',
  3: '♀',
  4: '♈',
  5: '♉',
  6: '♊',
  7: '♋',
  8: '♌',
  9: '♍',
  10: '♃',
  11: '♎',
  13: '♏',
  14: '♐',
  15: '♑',
  16: '♂',
  17: '♒',
  18: '♓',
  19: '☉',
  21: '♄',
};
const _majorElement = <int, String>{0: 'aire', 12: 'agua', 20: 'fuego'};
const _majorHebGlyph = <int, String>{
  0: 'א',
  1: 'ב',
  2: 'ג',
  3: 'ד',
  4: 'ה',
  5: 'ו',
  6: 'ז',
  7: 'ח',
  8: 'ט',
  9: 'י',
  10: 'כ',
  11: 'ל',
  12: 'מ',
  13: 'נ',
  14: 'ס',
  15: 'ע',
  16: 'פ',
  17: 'צ',
  18: 'ק',
  19: 'ר',
  20: 'ש',
  21: 'ת',
};
const _majorHebName = <int, String>{
  0: 'ALEPH',
  1: 'BETH',
  2: 'GIMEL',
  3: 'DALETH',
  4: 'HEH',
  5: 'VAV',
  6: 'ZAYIN',
  7: 'CHETH',
  8: 'TETH',
  9: 'YOD',
  10: 'KAPH',
  11: 'LAMED',
  12: 'MEM',
  13: 'NUN',
  14: 'SAMEKH',
  15: 'AYIN',
  16: 'PEH',
  17: 'TZADDI',
  18: 'QOPH',
  19: 'RESH',
  20: 'SHIN',
  21: 'TAV',
};

const _suits = {'bastos', 'copas', 'espadas', 'oros'};
const _suitElement = <String, String>{
  'bastos': 'fuego',
  'copas': 'agua',
  'espadas': 'aire',
  'oros': 'tierra',
};
const _courtWords = <String, String>{
  'princesa': 'Princesa',
  'principe': 'Príncipe',
  'príncipe': 'Príncipe',
  'reina': 'Reina',
  'rey': 'Rey',
  'caballero': 'Caballero',
  'caballo': 'Caballero',
  'sota': 'Sota',
  'paje': 'Paje',
  'queen': 'Reina',
  'king': 'Rey',
  'knight': 'Caballero',
  'page': 'Paje',
  'prince': 'Príncipe',
  'princess': 'Princesa',
};

// Disposición clásica de pips (coordenadas normalizadas dentro del naipe).
const _pipLayouts = <int, List<Offset>>{
  1: [Offset(.5, .5)],
  2: [Offset(.5, .30), Offset(.5, .70)],
  3: [Offset(.5, .26), Offset(.5, .5), Offset(.5, .74)],
  4: [Offset(.35, .30), Offset(.65, .30), Offset(.35, .70), Offset(.65, .70)],
  5: [
    Offset(.35, .28),
    Offset(.65, .28),
    Offset(.5, .5),
    Offset(.35, .72),
    Offset(.65, .72),
  ],
  6: [
    Offset(.35, .26),
    Offset(.65, .26),
    Offset(.35, .5),
    Offset(.65, .5),
    Offset(.35, .74),
    Offset(.65, .74),
  ],
  7: [
    Offset(.35, .24),
    Offset(.65, .24),
    Offset(.5, .38),
    Offset(.35, .52),
    Offset(.65, .52),
    Offset(.35, .76),
    Offset(.65, .76),
  ],
  8: [
    Offset(.35, .22),
    Offset(.65, .22),
    Offset(.5, .36),
    Offset(.35, .49),
    Offset(.65, .49),
    Offset(.5, .63),
    Offset(.35, .78),
    Offset(.65, .78),
  ],
  9: [
    Offset(.35, .22),
    Offset(.65, .22),
    Offset(.35, .40),
    Offset(.65, .40),
    Offset(.5, .5),
    Offset(.35, .60),
    Offset(.65, .60),
    Offset(.35, .78),
    Offset(.65, .78),
  ],
  10: [
    Offset(.35, .20),
    Offset(.65, .20),
    Offset(.5, .31),
    Offset(.35, .41),
    Offset(.65, .41),
    Offset(.35, .59),
    Offset(.65, .59),
    Offset(.5, .69),
    Offset(.35, .80),
    Offset(.65, .80),
  ],
};

enum TarotFaceKind { major, pip, court, fallback }

/// Datos resueltos de una carta para dibujar su cara (y su encabezado).
class TarotFace {
  final TarotFaceKind kind;
  final int? majorNum; // 0..21 para mayores
  final String? suit; // bastos|copas|espadas|oros
  final int? number; // 1..10 para pips
  final String element; // fuego|agua|aire|tierra (deriva del palo si falta)
  final String? court; // rango de figura (Reina, Caballero…)
  final String name;
  final String slug; // el del mazo en la base: tambien nombra su lamina
  // Datos astrales de los Mayores (ADITIVO): cuando el backend los puebla, la
  // atmósfera de la carta deriva del dato real; si vienen null, cae a la tabla
  // canónica hardcodeada. Así el Mayor se enriquece solo al llegar el dato.
  final String? astro; // e.g. 'Mercurio ☿', 'Luna ☽'
  final String? zodiac; // e.g. 'Aries', 'Piscis'

  const TarotFace._({
    required this.kind,
    required this.element,
    required this.name,
    this.slug = '',
    this.majorNum,
    this.suit,
    this.number,
    this.court,
    this.astro,
    this.zodiac,
  });

  Color get accent => _elementColor(element);

  /// La lamina Rider-Waite-Smith de esta carta, o null si no le toca ninguna.
  ///
  /// Las 78 se llaman como su slug, asi que no hace falta tabla: el mazo de la
  /// base y el manifest de `docs/licencias-tarot-rws/` comparten nombre. Si el
  /// backend devolviera un slug que no existe, `Image.asset` falla y la carta
  /// se queda en su cara vectorial -- que es una cara legitima, no un error.
  String? get rwsAsset => slug.isEmpty ? null : 'assets/tarot/$slug.webp';

  /// Encabezado textual bajo el naipe (numeral / rango).
  String get numeral {
    switch (kind) {
      case TarotFaceKind.major:
        final n = majorNum!;
        return n < _roman.length ? _roman[n] : '$n';
      case TarotFaceKind.pip:
        return number != null ? '$number' : '';
      case TarotFaceKind.court:
        return court ?? '';
      case TarotFaceKind.fallback:
        return '';
    }
  }

  static TarotFace resolve(Map<String, dynamic> c) {
    final name = (c['name'] as String?) ?? '';
    final slug = ((c['slug'] as String?) ?? '').toLowerCase();
    final id = (c['id'] as num?)?.toInt();
    final numRaw = (c['number'] as num?)?.toInt();
    final arcana = (c['arcana'] as String?)?.toLowerCase();

    // Palo: del campo, o inferido del slug (robustez con deck legacy).
    var suit = (c['suit'] as String?)?.toLowerCase();
    if (suit == null || !_suits.contains(suit)) {
      suit = _suits.firstWhere((s) => slug.contains(s), orElse: () => '');
      if (suit.isEmpty) suit = null;
    }

    final element = _normElement(
      (c['element'] as String?) ?? (suit != null ? _suitElement[suit] : null),
    );

    // Figura (corte): por palabra de rango en nombre/slug.
    String? court;
    final hay = '$slug $name'.toLowerCase();
    for (final entry in _courtWords.entries) {
      if (hay.contains(entry.key)) {
        court = entry.value;
        break;
      }
    }

    if (suit != null) {
      if (court != null) {
        return TarotFace._(
          kind: TarotFaceKind.court,
          element: element,
          name: name,
          slug: slug,
          suit: suit,
          court: court,
        );
      }
      final n = numRaw;
      if (n != null && n >= 1 && n <= 10) {
        return TarotFace._(
          kind: TarotFaceKind.pip,
          element: element,
          name: name,
          slug: slug,
          suit: suit,
          number: n,
        );
      }
      // Palo sin número claro → pip con un solo emblema.
      return TarotFace._(
        kind: TarotFaceKind.pip,
        element: element,
        name: name,
        slug: slug,
        suit: suit,
        number: 1,
      );
    }

    // Mayor: por arcana, o por id/number en 0..21 (deck legacy).
    final maj = arcana == 'major' ? (numRaw ?? id) : (id ?? numRaw);
    if ((arcana == 'major' || arcana == null) &&
        maj != null &&
        maj >= 0 &&
        maj <= 21) {
      final astro = (c['astro_correspondence'] as String?)?.trim();
      final zodiac = (c['zodiac'] as String?)?.trim();
      final mel = _majorElement[maj] ?? 'aire';
      return TarotFace._(
        kind: TarotFaceKind.major,
        element: mel,
        name: name,
        slug: slug,
        majorNum: maj,
        astro: (astro != null && astro.isNotEmpty) ? astro : null,
        zodiac: (zodiac != null && zodiac.isNotEmpty) ? zodiac : null,
      );
    }

    return TarotFace._(
      kind: TarotFaceKind.fallback,
      element: 'aire',
      name: name,
      slug: slug,
    );
  }
}

Color _elementColor(String element) {
  switch (element) {
    case 'fuego':
      return ArcanumColors.elementFire;
    case 'agua':
      return ArcanumColors.elementWater;
    case 'tierra':
      return ArcanumColors.elementEarth;
    case 'aire':
    default:
      return ArcanumColors.elementAir;
  }
}

String _normElement(String? e) {
  switch ((e ?? '').toLowerCase()) {
    case 'fuego':
    case 'fire':
      return 'fuego';
    case 'agua':
    case 'water':
      return 'agua';
    case 'tierra':
    case 'earth':
      return 'tierra';
    case 'aire':
    case 'air':
      return 'aire';
    default:
      return 'aire';
  }
}

// ── Atmósferas internas (fondo vivo por elemento / mayor) ──────────────────

/// Ornamento geométrico de fondo afín al elemento.
enum _Orn { rays, ripples, wind, lattice, stars }

/// Skin de una carta: el "material" y la luz de su fondo interno.
class _CardSkin {
  final Color edge; // borde oscuro que funde con el naipe
  final Color core; // centro tintado (foco de luz)
  final Color glow; // bruma saturada del elemento
  final Color accent; // color del emblema (más brillante)
  final _Orn orn;
  final double lightY; // posición vertical de la luz (0 arriba, 1 abajo)
  const _CardSkin(
    this.edge,
    this.core,
    this.glow,
    this.accent,
    this.orn,
    this.lightY,
  );
}

const _skinFire = _CardSkin(
  ArcanumColors.fireEdge,
  ArcanumColors.fireCore,
  ArcanumColors.fireGlow,
  ArcanumColors.fireAccent,
  _Orn.rays,
  0.70,
);
const _skinWater = _CardSkin(
  ArcanumColors.waterEdge,
  ArcanumColors.waterCore,
  ArcanumColors.waterGlow,
  ArcanumColors.waterAccent,
  _Orn.ripples,
  0.32,
);
const _skinAir = _CardSkin(
  ArcanumColors.airEdge,
  ArcanumColors.airCore,
  ArcanumColors.airGlow,
  ArcanumColors.airAccent,
  _Orn.wind,
  0.30,
);
const _skinEarth = _CardSkin(
  ArcanumColors.earthEdge,
  ArcanumColors.earthCore,
  ArcanumColors.earthGlow,
  ArcanumColors.earthAccent,
  _Orn.lattice,
  0.70,
);
const _skinMoon = _CardSkin(
  ArcanumColors.moonEdge,
  ArcanumColors.moonCore,
  ArcanumColors.moonGlow,
  ArcanumColors.moonAccent,
  _Orn.stars,
  0.30,
);
const _skinSun = _CardSkin(
  ArcanumColors.sunEdge,
  ArcanumColors.sunCore,
  ArcanumColors.sunGlow,
  ArcanumColors.sunAccent,
  _Orn.rays,
  0.46,
);

_CardSkin _skinForElement(String element) {
  switch (element) {
    case 'fuego':
      return _skinFire;
    case 'agua':
      return _skinWater;
    case 'tierra':
      return _skinEarth;
    case 'aire':
    default:
      return _skinAir;
  }
}

// Elemento canónico de cada Mayor (atribución Golden Dawn por planeta/signo).
// Fallback cuando el backend aún no pobló astro/zodiac.
const _majorElem = <int, String>{
  0: 'aire',
  1: 'aire',
  2: 'agua',
  3: 'tierra',
  4: 'fuego',
  5: 'tierra',
  6: 'aire',
  7: 'agua',
  8: 'fuego',
  9: 'tierra',
  10: 'aire',
  11: 'aire',
  12: 'agua',
  13: 'agua',
  14: 'fuego',
  15: 'tierra',
  16: 'fuego',
  17: 'aire',
  18: 'agua',
  19: 'fuego',
  20: 'fuego',
  21: 'tierra',
};

// Deriva elemento de un texto astral libre (signo o planeta) → enriquecimiento
// automático cuando el dato del backend llega.
String? _elementFromAstro(String? s) {
  if (s == null) return null;
  final t = s.toLowerCase();
  bool has(List<String> ks) => ks.any(t.contains);
  if (has(['aries', 'leo', 'sagit', 'marte', '♈', '♌', '♐', '♂'])) {
    return 'fuego';
  }
  if (has(['cáncer', 'cancer', 'escorpi', 'piscis', 'pisces', '♋', '♏', '♓'])) {
    return 'agua';
  }
  if (has(['tauro', 'virgo', 'capricor', 'saturno', '♉', '♍', '♑', '♄'])) {
    return 'tierra';
  }
  if (has([
    'géminis',
    'geminis',
    'libra',
    'acuario',
    'mercurio',
    'júpiter',
    'jupiter',
    '♊',
    '♎',
    '♒',
    '☿',
    '♃',
  ])) {
    return 'aire';
  }
  return null;
}

_CardSkin _skinForFace(TarotFace f) {
  switch (f.kind) {
    case TarotFaceKind.major:
      final n = f.majorNum!;
      // Héroes con atmósfera propia (icónicos).
      if (n == 19) return _skinSun; // El Sol
      if (n == 18 || n == 2 || n == 17) {
        return _skinMoon; // Luna, Sacerdotisa, Estrella
      }
      // Elemento: prioriza dato del backend (astro/zodiac); si null, tabla canónica.
      final el =
          _elementFromAstro(f.astro) ??
          _elementFromAstro(f.zodiac) ??
          _majorElem[n] ??
          'aire';
      return _skinForElement(el);
    case TarotFaceKind.pip:
    case TarotFaceKind.court:
      return _skinForElement(f.element);
    case TarotFaceKind.fallback:
      return _skinAir;
  }
}

// ── Painter de la cara ─────────────────────────────────────────────────────

/// Dibuja la cara vectorial de un naipe con FONDO INTERNO vivo: atmósfera
/// elemental (gradiente + ornamento + bruma), grano de material, viñeta de
/// profundidad, marco dorado biselado con esquinas, y el emblema esotérico
/// grabado según el tipo de carta. Vector original, cacheable (shouldRepaint
/// compara identidad). [detail] false → versión ligera para miniaturas.
class TarotFacePainter extends CustomPainter {
  final TarotFace face;
  final bool detail;
  const TarotFacePainter(this.face, {this.detail = true});

  _CardSkin get _skin => _skinForFace(face);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.10),
    );
    final sk = _skin;
    final bounds = Offset.zero & size;
    final cx = w * 0.5, cy = h * 0.46;
    final light = Offset(w * 0.5, h * sk.lightY);

    canvas.save();
    canvas.clipRRect(rrect);

    // 1 · Atmósfera base: gradiente radial desde la luz (core → edge).
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((light.dx / w) * 2 - 1, (light.dy / h) * 2 - 1),
          radius: 0.95,
          colors: [sk.core, sk.edge],
        ).createShader(bounds),
    );

    // 2 · Ornamento geométrico afín al elemento (muy tenue).
    if (detail) _paintOrnament(canvas, size, sk, Offset(cx, cy));

    // 3 · Light-leak asimétrico (fuga de luz esquina sup-izquierda).
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.75),
          radius: 1.1,
          colors: [sk.accent.withValues(alpha: 0.13), Colors.transparent],
          stops: const [0.0, 0.6],
        ).createShader(bounds),
    );

    // 4 · Bruma + bloom del elemento tras el emblema.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                sk.glow.withValues(alpha: 0.40),
                sk.glow.withValues(alpha: 0.14),
                Colors.transparent,
              ],
              stops: const [0.0, 0.42, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.62),
            ),
    );

    // 5 · Grano de material (estipulado determinista → textil/pergamino).
    if (detail) _paintGrain(canvas, size);

    // 6 · Viñeta interior suave: solo el borde exterior cae a sombra.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            RadialGradient(
              colors: const [Colors.transparent, Color(0x66000000)],
              stops: const [0.62, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: h * 0.66),
            ),
    );

    canvas.restore();

    // 7 · Marco dorado biselado + esquinas ornamentadas.
    _paintFrame(canvas, size, sk);

    switch (face.kind) {
      case TarotFaceKind.major:
        _paintMajor(canvas, size);
        break;
      case TarotFaceKind.pip:
        _paintPip(canvas, size);
        break;
      case TarotFaceKind.court:
        _paintCourt(canvas, size);
        break;
      case TarotFaceKind.fallback:
        _paintFallback(canvas, size);
        break;
    }
  }

  // ── Capas de atmósfera ────────────────────────────────────────────────

  /// Ornamento geométrico de fondo, distinto por elemento. Alfa muy bajo:
  /// da textura temática sin robar protagonismo al emblema.
  void _paintOrnament(Canvas canvas, Size size, _CardSkin sk, Offset c) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..color = sk.glow.withValues(alpha: 0.10);
    switch (sk.orn) {
      case _Orn.rays: // Fuego/Sol: rayos radiales
        for (var i = 0; i < 20; i++) {
          final a = i * math.pi / 10;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * (w * 0.14), c + d * (w * 0.92), p);
        }
        break;
      case _Orn.ripples: // Agua: ondas concéntricas
        for (var i = 1; i <= 6; i++) {
          canvas.drawCircle(c, w * 0.14 * i, p);
        }
        break;
      case _Orn.wind: // Aire: corrientes horizontales
        for (var i = 0; i < 9; i++) {
          final y = h * 0.12 + i * h * 0.09;
          final path = Path()
            ..moveTo(w * 0.14, y)
            ..cubicTo(w * 0.4, y - 6, w * 0.6, y + 6, w * 0.86, y);
          canvas.drawPath(path, p);
        }
        break;
      case _Orn.lattice: // Tierra: retícula rómbica
        final st = w * 0.16;
        final path = Path();
        for (var yy = -h; yy < h * 2; yy += st) {
          path.moveTo(0, yy);
          path.lineTo(w, yy + w);
          path.moveTo(0, yy);
          path.lineTo(w, yy - w);
        }
        canvas.drawPath(path, p);
        break;
      case _Orn.stars: // Luna/nocturno: estrellas dispersas
        final dot = Paint()..color = sk.accent.withValues(alpha: 0.45);
        const pts = [
          Offset(.2, .2),
          Offset(.8, .18),
          Offset(.72, .58),
          Offset(.28, .72),
          Offset(.5, .30),
          Offset(.86, .5),
          Offset(.14, .55),
          Offset(.6, .84),
        ];
        for (final o in pts) {
          canvas.drawCircle(Offset(o.dx * w, o.dy * h), w * 0.008, dot);
        }
        break;
    }
  }

  /// Grano determinista: motas claras/oscuras que rompen el vector limpio y
  /// evocan un material impreso. Semilla fija → estable entre repaints.
  void _paintGrain(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = (w * h / 62).clamp(120, 620).toInt();
    var seed = 99;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final light = Paint()..color = const Color(0xFFFFF0D6);
    final dark = Paint()..color = Colors.black;
    for (var i = 0; i < n; i++) {
      final px = rnd() * w, py = rnd() * h, br = rnd();
      if (br > 0.5) {
        light.color = const Color(0xFFFFF0D6).withValues(alpha: 0.020 * br);
        canvas.drawRect(Rect.fromLTWH(px, py, 1, 1), light);
      } else {
        dark.color = Colors.black.withValues(alpha: 0.035 * (1 - br));
        canvas.drawRect(Rect.fromLTWH(px, py, 1, 1), dark);
      }
    }
  }

  /// Marco dorado con relieve: filete exterior con inner-glow, highlight
  /// bisel arriba-izq + sombra abajo-der (lee como oro grabado), filete
  /// interior tintado del elemento, y florituras en las esquinas.
  void _paintFrame(Canvas canvas, Size size, _CardSkin sk) {
    final w = size.width, h = size.height;
    final gold = ArcanumColors.gold;
    RRect fr(double inset, double rf) => RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * inset,
        h * inset,
        w * (1 - inset * 2),
        h * (1 - inset * 2),
      ),
      Radius.circular(w * 0.10 * rf),
    );

    // Inner-glow del filete exterior.
    canvas.drawRRect(
      fr(0.045, 0.72),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.013
        ..color = gold.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Bisel: highlight y sombra ligeramente desplazados.
    final outer = fr(0.045, 0.72);
    canvas.save();
    canvas.translate(-w * 0.004, -h * 0.003);
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..color = const Color(0xFFF0DFA0).withValues(alpha: 0.55),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(w * 0.004, h * 0.003);
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.restore();
    // Filete exterior maestro.
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.010
        ..color = gold.withValues(alpha: 0.72),
    );
    // Hilo intermedio dorado tenue.
    canvas.drawRRect(
      fr(0.062, 0.64),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..color = ArcanumColors.goldMuted.withValues(alpha: 0.50),
    );
    // Filete interior con tinte del elemento.
    canvas.drawRRect(
      fr(0.082, 0.56),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..color = sk.accent.withValues(alpha: 0.44),
    );
    // Florituras de esquina.
    _paintCorners(canvas, size);
  }

  void _paintCorners(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = ArcanumColors.gold;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round
      ..color = gold.withValues(alpha: 0.55);
    final dot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.005
      ..color = gold.withValues(alpha: 0.55);
    final m = w * 0.115, len = w * 0.085;
    final corners = <List<double>>[
      [m, m, 1, 1],
      [w - m, m, -1, 1],
      [m, h - m, 1, -1],
      [w - m, h - m, -1, -1],
    ];
    for (final cc in corners) {
      final x = cc[0], y = cc[1], sx = cc[2], sy = cc[3];
      canvas.drawPath(
        Path()
          ..moveTo(x + sx * len, y)
          ..lineTo(x, y)
          ..lineTo(x, y + sy * len),
        p,
      );
      canvas.drawCircle(
        Offset(x + sx * len * 0.5, y + sy * len * 0.5),
        w * 0.012,
        dot,
      );
    }
  }

  /// Asiento del medallón: oscurece suavemente el disco central para que el
  /// emblema descanse sobre la atmósfera (no flote), con inner-glow del
  /// elemento y un reflejo especular superior que le da volumen físico.
  void _medallionSeat(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _skin.edge.withValues(alpha: 0.62),
            _skin.edge.withValues(alpha: 0.0),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Inner-glow del elemento en el borde interior del medallón.
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..color = _skin.glow.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.10),
    );
    // Reflejo especular: arco de luz en la parte superior del aro.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF3D6).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  /// Sombra bajo el emblema central → sensación de bajo relieve grabado.
  void _emblemShadow(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c.translate(0, r * 0.12),
      r * 0.82,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.30),
    );
  }

  // ── Mayores: glifo astral en medallón + hebreo + numeral ──────────────
  void _paintMajor(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.5, h * 0.46);
    final gold = ArcanumColors.gold;

    // Numeral romano arriba.
    _text(
      canvas,
      _roman[face.majorNum!.clamp(0, 21)],
      Offset(w * 0.5, h * 0.155),
      w * 0.13,
      ArcanumColors.goldMuted,
      style: _serif,
      spacing: 2,
    );

    // Medallón.
    final r = w * 0.30;
    _medallionSeat(canvas, center, r);
    _emblemShadow(canvas, center, r * 0.62);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010
      ..color = gold.withValues(alpha: 0.65);
    final ringFaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.35);
    canvas.drawCircle(center, r, ring);
    canvas.drawCircle(center, r * 0.86, ringFaint);

    // Emblema central: elemento (vectorial) o glifo astral (fuente).
    final el = _majorElement[face.majorNum!];
    if (el != null) {
      _drawElement(canvas, el, center, r * 0.62, _elementColor(el));
    } else {
      final glyph = _majorGlyph[face.majorNum!] ?? '✦';
      _text(canvas, glyph, center, r * 1.15, gold);
    }

    // Hebreo: glifo + transliteración.
    final heb = _majorHebGlyph[face.majorNum!];
    if (heb != null) {
      _text(canvas, heb, Offset(w * 0.5, h * 0.775), w * 0.16, gold);
    }
    final hname = _majorHebName[face.majorNum!];
    if (hname != null) {
      _text(
        canvas,
        hname,
        Offset(w * 0.5, h * 0.87),
        w * 0.075,
        ArcanumColors.goldMuted,
        style: _serif,
        spacing: 3,
      );
    }
  }

  // ── Menores pip: emblemas del palo repetidos + numeral de esquina ─────
  void _paintPip(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = (face.number ?? 1).clamp(1, 10);
    final accent = _skin.accent;

    // El As protagoniza: emblema grande en medallón (como los Mayores).
    if (n == 1) {
      final center = Offset(w * 0.5, h * 0.48);
      final r = w * 0.30;
      _medallionSeat(canvas, center, r);
      _emblemShadow(canvas, center, r * 0.55);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.010
          ..color = accent.withValues(alpha: 0.65),
      );
      canvas.drawCircle(
        center,
        r * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.006
          ..color = ArcanumColors.goldMuted.withValues(alpha: 0.35),
      );
      _drawSuit(canvas, face.suit!, center, w * 0.20, accent);
      _cornerIndex(canvas, size, '1', accent);
      return;
    }

    final layout = _pipLayouts[n]!;
    // Escala del emblema según densidad.
    final s = w * (n <= 3 ? 0.135 : (n <= 6 ? 0.100 : 0.082));

    for (final p in layout) {
      _drawSuit(
        canvas,
        face.suit!,
        Offset(p.dx * size.width, p.dy * size.height),
        s,
        accent,
      );
    }

    // Índice de esquina (como un naipe real): numeral + palo mini.
    _cornerIndex(canvas, size, '$n', accent);
  }

  // ── Menores corte: emblema grande + corona/rango ──────────────────────
  void _paintCourt(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.5, h * 0.52);
    final accent = _skin.accent;

    // Corona/insignia de rango sobre el emblema.
    _drawRankMark(
      canvas,
      face.court ?? '',
      Offset(w * 0.5, h * 0.24),
      w * 0.14,
    );

    // Emblema grande del palo, sentado sobre la atmósfera.
    _emblemShadow(canvas, center, w * 0.22);
    _drawSuit(canvas, face.suit!, center, w * 0.24, accent);

    // Rango en versalitas abajo.
    _text(
      canvas,
      (face.court ?? '').toUpperCase(),
      Offset(w * 0.5, h * 0.84),
      w * 0.085,
      ArcanumColors.goldMuted,
      style: _serif,
      spacing: 2,
    );

    _cornerIndex(canvas, size, (face.court ?? ' ').characters.first, accent);
  }

  // ── Fallback: sello dorado neutro ─────────────────────────────────────
  void _paintFallback(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.5, h * 0.46);
    final gold = ArcanumColors.gold;
    final r = w * 0.26;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010
      ..color = gold.withValues(alpha: 0.6);
    canvas.drawCircle(center, r, ring);
    // Rosetón de 8 rayos.
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..color = gold.withValues(alpha: 0.5);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * (r * 0.3),
        center + Offset(math.cos(a), math.sin(a)) * (r * 0.9),
        ray,
      );
    }
    _text(canvas, '✦', center, r * 0.9, gold);
    final id = _romanIfPossible(face);
    if (id != null) {
      _text(
        canvas,
        id,
        Offset(w * 0.5, h * 0.82),
        w * 0.12,
        ArcanumColors.goldMuted,
        style: _serif,
        spacing: 2,
      );
    }
  }

  String? _romanIfPossible(TarotFace f) => null;

  // ── Emblemas de palo (vectoriales) ────────────────────────────────────
  void _drawSuit(Canvas canvas, String suit, Offset c, double s, Color color) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35);
    canvas.drawCircle(c, s * 0.9, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color.withValues(alpha: 0.18);

    switch (suit) {
      case 'bastos': // vara con nudos
        canvas.drawLine(Offset(c.dx, c.dy - s), Offset(c.dx, c.dy + s), stroke);
        final knob = Paint()..color = color;
        canvas.drawCircle(Offset(c.dx, c.dy - s), s * 0.16, knob);
        canvas.drawCircle(Offset(c.dx, c.dy + s), s * 0.16, knob);
        // brotes
        canvas.drawLine(
          Offset(c.dx, c.dy - s * 0.3),
          Offset(c.dx - s * 0.5, c.dy - s * 0.6),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy - s * 0.3),
          Offset(c.dx + s * 0.5, c.dy - s * 0.6),
          stroke,
        );
        break;
      case 'copas': // cáliz
        final bowl = Path()
          ..moveTo(c.dx - s * 0.7, c.dy - s * 0.55)
          ..quadraticBezierTo(
            c.dx,
            c.dy + s * 0.45,
            c.dx + s * 0.7,
            c.dy - s * 0.55,
          )
          ..close();
        canvas.drawPath(bowl, fill);
        canvas.drawPath(bowl, stroke);
        // pie
        canvas.drawLine(
          Offset(c.dx, c.dy + s * 0.15),
          Offset(c.dx, c.dy + s * 0.75),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - s * 0.5, c.dy + s * 0.85),
          Offset(c.dx + s * 0.5, c.dy + s * 0.85),
          stroke,
        );
        break;
      case 'espadas': // espada vertical
        final blade = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx - s * 0.17, c.dy + s * 0.25)
          ..lineTo(c.dx + s * 0.17, c.dy + s * 0.25)
          ..close();
        canvas.drawPath(blade, fill);
        canvas.drawPath(blade, stroke);
        canvas.drawLine(
          Offset(c.dx - s * 0.55, c.dy + s * 0.3),
          Offset(c.dx + s * 0.55, c.dy + s * 0.3),
          stroke,
        ); // guarda
        canvas.drawLine(
          Offset(c.dx, c.dy + s * 0.3),
          Offset(c.dx, c.dy + s * 0.8),
          stroke,
        );
        canvas.drawCircle(
          Offset(c.dx, c.dy + s * 0.9),
          s * 0.13,
          Paint()..color = color,
        );
        break;
      case 'oros': // pentáculo
      default:
        canvas.drawCircle(c, s * 0.85, fill);
        canvas.drawCircle(c, s * 0.85, stroke);
        final star = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final p = c + Offset(math.cos(a), math.sin(a)) * (s * 0.62);
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        // pentagrama unicursal (salto de 2)
        final pts = List.generate(5, (i) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          return c + Offset(math.cos(a), math.sin(a)) * (s * 0.62);
        });
        final penta = Path()..moveTo(pts[0].dx, pts[0].dy);
        var idx = 0;
        for (var i = 0; i < 5; i++) {
          idx = (idx + 2) % 5;
          penta.lineTo(pts[idx].dx, pts[idx].dy);
        }
        penta.close();
        canvas.drawPath(penta, stroke);
        break;
    }
  }

  // Símbolos elementales vectoriales (triángulos alquímicos).
  void _drawElement(
    Canvas canvas,
    String element,
    Offset c,
    double s,
    Color color,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color.withValues(alpha: 0.16);
    final up = element == 'fuego' || element == 'aire';
    final dy = up ? -1.0 : 1.0;
    final tri = Path()
      ..moveTo(c.dx, c.dy + dy * s)
      ..lineTo(c.dx - s * 0.9, c.dy - dy * s * 0.7)
      ..lineTo(c.dx + s * 0.9, c.dy - dy * s * 0.7)
      ..close();
    canvas.drawPath(tri, fill);
    canvas.drawPath(tri, stroke);
    // Aire/Tierra llevan barra horizontal.
    if (element == 'aire' || element == 'tierra') {
      final by = c.dy - dy * s * 0.15;
      canvas.drawLine(
        Offset(c.dx - s * 0.45, by),
        Offset(c.dx + s * 0.45, by),
        stroke,
      );
    }
  }

  void _drawRankMark(Canvas canvas, String court, Offset c, double s) {
    final gold = ArcanumColors.gold;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.12
      ..strokeJoin = StrokeJoin.round
      ..color = gold;
    final royalty = court == 'Reina' || court == 'Rey';
    if (royalty) {
      // Corona de tres puntas.
      final crown = Path()
        ..moveTo(c.dx - s, c.dy + s * 0.5)
        ..lineTo(c.dx - s, c.dy - s * 0.4)
        ..lineTo(c.dx - s * 0.5, c.dy + s * 0.1)
        ..lineTo(c.dx, c.dy - s * 0.6)
        ..lineTo(c.dx + s * 0.5, c.dy + s * 0.1)
        ..lineTo(c.dx + s, c.dy - s * 0.4)
        ..lineTo(c.dx + s, c.dy + s * 0.5)
        ..close();
      canvas.drawPath(crown, Paint()..color = gold.withValues(alpha: 0.14));
      canvas.drawPath(crown, stroke);
    } else {
      // Caballero/Paje: galón (chevron).
      final ch = Path()
        ..moveTo(c.dx - s * 0.8, c.dy + s * 0.4)
        ..lineTo(c.dx, c.dy - s * 0.4)
        ..lineTo(c.dx + s * 0.8, c.dy + s * 0.4);
      canvas.drawPath(ch, stroke);
    }
  }

  void _cornerIndex(Canvas canvas, Size size, String label, Color accent) {
    final w = size.width;
    _text(
      canvas,
      label,
      Offset(w * 0.16, size.height * 0.13),
      w * 0.11,
      ArcanumColors.goldMuted,
      style: _serif,
    );
    // Espejo abajo-derecha.
    canvas.save();
    canvas.translate(w * 0.84, size.height * 0.87);
    canvas.rotate(math.pi);
    _text(
      canvas,
      label,
      Offset.zero,
      w * 0.11,
      ArcanumColors.goldMuted,
      style: _serif,
    );
    canvas.restore();
  }

  // Glifo/texto centrado en `center` vía TextPainter.
  void _text(
    Canvas canvas,
    String s,
    Offset center,
    double fontSize,
    Color color, {
    bool style = false,
    double spacing = 0,
  }) {
    final ts = style
        ? ArcanumText.heading(
            fontSize,
            color: color,
          ).copyWith(letterSpacing: spacing, height: 1.0)
        : TextStyle(
            fontSize: fontSize,
            color: color,
            height: 1.0,
            letterSpacing: spacing,
            // El respaldo de glifos, que la rama `style: true` ya tenia por
            // venir de `ArcanumText`. Por aqui pasan TODOS los glifos de la
            // carta -- los 22 mayores de `_majorGlyph` son planetas y signos,
            // y el 6 es el ♊ de Los Enamorados -- asi que sin esto los pinta
            // la fuente del sistema y en varios Android salen como emoji a
            // color. Un `TextPainter` no hereda el tema: hay que decirselo.
            fontFamilyFallback: kGlyphFallback,
          );
    final tp = TextPainter(
      text: TextSpan(text: s, style: ts),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  static const bool _serif = true;

  @override
  bool shouldRepaint(covariant TarotFacePainter old) =>
      old.face.name != face.name ||
      old.face.kind != face.kind ||
      old.face.number != face.number ||
      old.face.majorNum != face.majorNum ||
      old.face.astro != face.astro ||
      old.face.zodiac != face.zodiac ||
      old.detail != detail;
}

// ── Naipe estático reutilizable (mini-panel, previews) ─────────────────────

/// Naipe con cara vectorial, tamaño fijo. Reutilizable: mini-panel usa el
/// mismo trazo que el bloque de lectura, garantizando coherencia visual.
class TarotNaipe extends StatelessWidget {
  final Map<String, dynamic> card;
  final double width;
  final bool reversed;
  final bool active;

  const TarotNaipe({
    super.key,
    required this.card,
    this.width = 150,
    this.reversed = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = width * 1.6;
    final radius = width * 0.10;
    // Miniaturas (mini-panel) usan versión ligera del fondo: sin grano ni
    // ornamento, conservando atmósfera + bruma + marco. Cuida 60fps con 10
    // naipes en pantalla.
    Widget face = CustomPaint(
      size: Size(width, h),
      painter: TarotFacePainter(TarotFace.resolve(card), detail: width >= 96),
    );
    if (reversed) {
      face = Transform.rotate(angle: math.pi, child: face);
    }
    return RepaintBoundary(
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
            if (active)
              BoxShadow(
                color: ArcanumColors.gold.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
          // La carta activa ya se distingue por su halo y su escala; el
          // filete era un tercer aviso para lo mismo.
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: face,
        ),
      ),
    );
  }
}

// ── Bloque de lectura: naipe animado (deal + volteo por palo + tilt) ───────

/// Como se voltea cada familia de cartas.
///
/// El palo no es decoracion: cada elemento se mueve como se mueve su materia,
/// y el gesto ya dice de que palo es la carta antes de que se lea el nombre.
/// El fuego es seco y rapido y tiembla al parar; el agua entra con rebote y
/// deja estela; el aire corta en diagonal y no vuelve; la tierra es lenta y
/// pesa al aterrizar; los Mayores se toman su tiempo porque se lo han ganado.
enum TarotFlipStyle { mayor, bastos, copas, espadas, oros, llano }

/// Los numeros de un volteo. Todo sale de aqui: sin constantes sueltas
/// repartidas por el `build`, y sin una rama por palo dentro de la animacion.
@immutable
class _FlipSpec {
  /// Duracion del giro dorso->cara.
  final int flipMs;

  /// Curva del giro. `easeOutBack` rebota; las demas no.
  final Curve curve;

  /// Ventana de ASENTAMIENTO, posterior al giro. Ahi viven el rebote de
  /// escala, el temblor, la reverencia de las figuras, el halo residual y la
  /// contraccion de la sombra. Al acabar, la carta queda en reposo absoluto:
  /// cero frames programados, que es lo que exige el test de rendimiento.
  final int settleMs;

  /// Escala de mas al asentarse (Mayores: 1.0 -> 1.03 -> 1.0).
  final double overshoot;

  /// Escala de menos al asentarse (Oros: 1.0 -> 0.98 -> 1.0).
  final double squash;

  /// Franja de luz dorada al pasar por el canto.
  final bool flash;

  /// Halo tenue en el borde que se apaga despues del giro.
  final bool halo;

  /// Temblor de +-2 grados que se disipa (Bastos).
  final bool tremor;

  /// Motas doradas que suben del borde inferior (Bastos).
  final bool motes;

  /// Barrido especular en el canto, con traza que tarda mas (Copas).
  final bool sweep;

  /// Giro en Z DURANTE el volteo, en radianes: el corte diagonal de Espadas.
  final double diagonal;

  /// Linea de 1 px de esquina a esquina en el instante del corte (Espadas).
  final bool cut;

  /// Sobreancho de sombra que se contrae al aterrizar (Oros).
  final double shadowSpread;

  const _FlipSpec({
    required this.flipMs,
    required this.curve,
    required this.settleMs,
    this.overshoot = 0,
    this.squash = 0,
    this.flash = false,
    this.halo = false,
    this.tremor = false,
    this.motes = false,
    this.sweep = false,
    this.diagonal = 0,
    this.cut = false,
    this.shadowSpread = 0,
  });

  static const _mayor = _FlipSpec(
    flipMs: 700,
    curve: Curves.easeInOutCubic,
    settleMs: 1500, // lo marca el halo, que es lo ultimo en apagarse
    overshoot: 0.03,
    flash: true,
    halo: true,
  );

  static const _bastos = _FlipSpec(
    flipMs: 250,
    curve: Curves.easeInOut, // sin rebote: el fuego no vuelve sobre sus pasos
    settleMs: 420,
    tremor: true,
    motes: true,
  );

  static const _copas = _FlipSpec(
    flipMs: 430,
    curve: Curves.easeOutBack, // rebote suave: el agua se mece al posarse
    settleMs: 620,
    sweep: true,
  );

  static const _espadas = _FlipSpec(
    flipMs: 200, // la mas rapida de las cinco
    curve: Curves.easeInOut,
    settleMs: 300,
    diagonal: 0.26, // ~15 grados
    cut: true,
  );

  static const _oros = _FlipSpec(
    flipMs: 500, // la mas lenta despues de los Mayores
    curve: Curves.easeInOut,
    settleMs: 460,
    squash: 0.02,
    shadowSpread: 14,
  );

  static const _llano = _FlipSpec(
    flipMs: 620,
    curve: Curves.easeOutBack,
    settleMs: 300,
  );

  /// El estilo de una carta ya resuelta. `TarotFace` conoce el palo y el tipo:
  /// aqui no se vuelve a inferir nada del `slug`.
  static TarotFlipStyle styleOf(TarotFace face) {
    if (face.kind == TarotFaceKind.major) return TarotFlipStyle.mayor;
    switch (face.suit) {
      case 'bastos':
        return TarotFlipStyle.bastos;
      case 'copas':
        return TarotFlipStyle.copas;
      case 'espadas':
        return TarotFlipStyle.espadas;
      case 'oros':
        return TarotFlipStyle.oros;
      default:
        return TarotFlipStyle.llano;
    }
  }

  static _FlipSpec of(TarotFlipStyle style) => switch (style) {
    TarotFlipStyle.mayor => _mayor,
    TarotFlipStyle.bastos => _bastos,
    TarotFlipStyle.copas => _copas,
    TarotFlipStyle.espadas => _espadas,
    TarotFlipStyle.oros => _oros,
    TarotFlipStyle.llano => _llano,
  };
}

/// Las tres caras de un naipe, en el orden en que se descubren.
///
/// El dorso solo se ve una vez: descubierta una carta, ya no se vuelve a
/// tapar. A partir de ahi el toque alterna entre las dos caras, que son dos
/// lecturas de lo mismo -- la nuestra y la de 1909.
enum TarotCara { dorso, vectorial, rws }

/// Estado del ojo bajo la carta: cuanto ve la carta de si misma.
///
/// [iluminado] es el grabado Rider-Waite-Smith. Se dibujo en la Fase 1 sin
/// usarlo, esperando a que hubiera arte real detras; ya lo hay.
///
/// El ojo vive FUERA del naipe, en una tira bajo la carta. Estuvo en la
/// esquina mientras la cara era nuestra y le reservabamos sitio oscuro. Sobre
/// el RWS no se podia: medido en cuatro cartas, el oro contra esa esquina daba
/// entre 1,02:1 y 1,28:1 -- y no por el dibujo de Smith sino por el borde
/// crema del naipe de 1909, que es casi blanco en las 78. Taparlo con un velo
/// lo arreglaba (3,9:1 al 62%) a cambio de ensuciar el grabado.
///
/// Fuera del naipe el numero no depende de que carta sea: 8,15:1 el oro pleno
/// y 3,87:1 el `goldMuted`, los dos contra el `surface` de la app, y el
/// grabado se queda limpio.
enum TarotEyeState { cerrado, abierto, iluminado }

/// Carta de tarot con presencia fisica: reparto con peso (easeOutBack),
/// volteo 3D dorso->cara DIFERENCIADO POR PALO y disparado por el toque,
/// tilt hacia el puntero y glow pulsante cuando esta activa. La cara es
/// VECTORIAL (TarotFacePainter).
///
/// PURO PRESENTACIONAL: no altera los datos del draw ni el orden, y NO conoce
/// Riverpod. La pista del gesto entra por [pulseHint] y sale por [onHintShown]
/// porque quien sabe si ya se enseno es la pantalla, no el naipe.
class TarotCardView extends StatefulWidget {
  final Map<String, dynamic> card;
  final int index;
  final bool active;
  final VoidCallback onToggle;

  /// Cuando es `true`, el ojo pulsa un par de veces tras abrirse para ensenar
  /// que la carta se toca. Lo decide la pantalla leyendo la preferencia.
  final bool pulseHint;

  /// Se llama UNA vez, cuando la pista ya se ha ensenado entera.
  final VoidCallback? onHintShown;

  const TarotCardView({
    super.key,
    required this.card,
    required this.index,
    required this.active,
    required this.onToggle,
    this.pulseHint = false,
    this.onHintShown,
  });

  @override
  State<TarotCardView> createState() => _TarotCardViewState();
}

class _TarotCardViewState extends State<TarotCardView>
    with TickerProviderStateMixin {
  static const double _w = 158;
  static const double _h = _w * 1.6;

  /// Tres pulsos de 600 ms. Mas seria insistir.
  static const int _pulseMs = 1800;

  late final AnimationController _deal;
  late final AnimationController _flip;
  late final AnimationController _settle;
  late final AnimationController _engage;
  late final AnimationController _pulse;

  Timer? _dealTimer;

  Offset _tilt = Offset.zero;
  bool _hovering = false;
  bool _pressing = false;
  bool _hintDone = false;

  /// La cara a la que se va, y la que se deja atras. El giro siempre lleva de
  /// una a otra: `_flip` va de 0 a 1 UNA VEZ POR TOQUE y se reinicia.
  TarotCara _cara = TarotCara.dorso;
  TarotCara _previa = TarotCara.dorso;

  late final TarotFace _face = TarotFace.resolve(widget.card);
  late final TarotFlipStyle _style = _FlipSpec.styleOf(_face);
  late final _FlipSpec _spec = _FlipSpec.of(_style);

  /// Las 16 figuras hacen una reverencia breve DESPUES del volteo de su palo.
  /// Los numerales no: una carta de corte tiene a quien inclinarse.
  bool get _isCourt => _face.kind == TarotFaceKind.court;

  bool get _reducedMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Si ya se paso el canto del giro (90 grados). El corte esta ahi y no en el
  /// toque: entre el dedo y el medio giro la carta sigue ensenando la cara de
  /// antes, y todo lo que cuelga de ella tiene que creerselo.
  bool get _cruzado => _spec.curve.transform(_flip.value) >= 0.5;

  /// La cara que se esta viendo AHORA MISMO, a mitad de giro incluido.
  TarotCara get _caraVisible => _cruzado ? _cara : _previa;

  /// Descubierta una carta ya no se vuelve a tapar.
  bool get _descubierta => _cara != TarotCara.dorso;

  double get _baseTilt {
    final sign = widget.index.isEven ? 1.0 : -1.0;
    return sign * (0.011 + (widget.index % 3) * 0.004);
  }

  @override
  void initState() {
    super.initState();
    _deal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _flip = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _spec.flipMs),
    );
    _settle = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _spec.settleMs),
    );
    _engage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _pulseMs),
    );

    _flip.addStatusListener(_onFlipStatus);
    _pulse.addStatusListener(_onPulseStatus);

    // El reparto SI es automatico: la carta llega sola a su sitio, boca abajo.
    // Lo que ya no se dispara solo es el volteo -- eso lo pide el dedo.
    _dealTimer = Timer(Duration(milliseconds: 90 + widget.index * 110), () {
      if (mounted) _deal.forward();
    });

    if (widget.active) _engage.value = 1;
  }

  @override
  void didUpdateWidget(covariant TarotCardView old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _engage.forward();
    } else if (!widget.active && old.active) {
      if (!_hovering && !_pressing) _engage.reverse();
    }
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _flip.removeStatusListener(_onFlipStatus);
    _pulse.removeStatusListener(_onPulseStatus);
    _deal.dispose();
    _flip.dispose();
    _settle.dispose();
    _engage.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onFlipStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _settle.forward(from: 0);
    // La pista solo se ensena al descubrir, no en cada vuelta de cara.
    if (widget.pulseHint && !_hintDone && _cara == TarotCara.vectorial) {
      _pulse.forward(from: 0);
    }
  }

  void _onPulseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _markHintShown();
  }

  void _markHintShown() {
    if (_hintDone) return;
    _hintDone = true;
    widget.onHintShown?.call();
  }

  /// El toque lleva la carta a su cara siguiente.
  ///
  ///   boca abajo -> vectorial -> RWS -> vectorial -> RWS...
  ///
  /// El dorso solo sale del ciclo: descubierta una carta, ya no se vuelve a
  /// tapar. Y cada naipe va por su cuenta: no hay interruptor que las voltee
  /// todas.
  ///
  /// El giro es SIEMPRE el de su palo, tambien el segundo: que Espadas corte
  /// en diagonal y Oros aterrice pesado no es cosa de descubrir la carta, es
  /// cosa de la carta.
  void _handleTap() {
    final siguiente = switch (_cara) {
      TarotCara.dorso => TarotCara.vectorial,
      TarotCara.vectorial => TarotCara.rws,
      TarotCara.rws => TarotCara.vectorial,
    };

    // Una carta ya descubierta tambien enfoca al tocarla: es lo que el toque
    // hacia antes de que hubiera tercera cara, y se pierde si no se pide aqui.
    if (_descubierta) widget.onToggle();

    setState(() {
      _previa = _cara;
      _cara = siguiente;
    });

    if (_reducedMotion) {
      // Preferencia de movimiento reducido: la carta CAMBIA de cara, no se
      // mueve. Y la pista se da por vista: sin animacion no hay gesto que
      // ensenar, y nadie quiere que se lo recuerden en cada tirada.
      _flip.value = 1;
      _settle.value = 1;
      _markHintShown();
      return;
    }
    _settle.value = 0;
    _flip.forward(from: 0);
  }

  bool get _engaged => widget.active || _hovering || _pressing;

  void _syncEngage() {
    if (_engaged) {
      _engage.forward();
    } else {
      _engage.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversed = widget.card['drawn_upright'] == false;

    final naipe = MouseRegion(
      onEnter: (_) {
        _hovering = true;
        _syncEngage();
      },
      onHover: (e) {
        // localPosition ya está en el espacio del naipe (_w × _h), no del
        // Column entero: usarlo hace que el parallax enganche de verdad en web.
        final p = e.localPosition;
        setState(() {
          _tilt = Offset(
            (p.dx / _w - 0.5).clamp(-0.5, 0.5),
            (p.dy / _h - 0.5).clamp(-0.5, 0.5),
          );
        });
      },
      onExit: (_) {
        _hovering = false;
        setState(() => _tilt = Offset.zero);
        _syncEngage();
      },
      child: GestureDetector(
        onTapDown: (_) {
          _pressing = true;
          _syncEngage();
        },
        onTapUp: (_) {
          _pressing = false;
          _syncEngage();
        },
        onTapCancel: () {
          _pressing = false;
          _syncEngage();
        },
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_deal, _flip, _settle, _engage, _pulse]),
          builder: (context, _) => _buildAnimated(reversed),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        children: [
          Text(
            ((widget.card['position'] as String?) ?? '').toUpperCase(),
            textAlign: TextAlign.center,
            style: ArcanumText.label(),
          ),
          const SizedBox(height: 10),
          // Tanto el rotulo como lo que va debajo del naipe cambian en el
          // MISMO instante en que la cara queda arriba, no al tocar: mientras
          // la carta gira, sigue estando boca abajo.
          AnimatedBuilder(
            animation: _flip,
            builder: (context, child) => Semantics(
              button: true,
              label: switch (_caraVisible) {
                TarotCara.dorso => 'Descubrir la carta',
                TarotCara.vectorial => 'Ver el grabado de 1909',
                TarotCara.rws => 'Volver al trazo de ARCANUM',
              },
              child: child,
            ),
            child: naipe,
          ),
          // El ojo, en su tira bajo el naipe. Aqui el fondo es el de la app y
          // el contraste no depende de que traiga cada carta en su esquina.
          AnimatedBuilder(
            animation: Listenable.merge([_flip, _pulse]),
            builder: (context, _) => SizedBox(
              height: _eyeStrip,
              width: _w,
              child: Center(
                child: CustomPaint(
                  size: const Size(_eyeW, _eyeW * 0.62),
                  painter: _EyePainter(
                    state: switch (_caraVisible) {
                      TarotCara.dorso => TarotEyeState.cerrado,
                      TarotCara.vectorial => TarotEyeState.abierto,
                      TarotCara.rws => TarotEyeState.iluminado,
                    },
                    pulse: _pulseShape(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // El significado solo aparece cuando la cara ya esta arriba: leerlo
          // antes destriparia el naipe y el volteo no significaria nada. En su
          // sitio, mientras tanto, la invitacion a tocarla -- sin ella el
          // gesto existe pero nadie lo descubre.
          AnimatedBuilder(
            animation: _flip,
            builder: (context, _) => _caraVisible == TarotCara.dorso
                ? const _TapToReveal()
                : _readingText(reversed),
          ),
        ],
      ),
    );
  }

  /// Rampa 0..1 de los primeros [lenMs] de la ventana de asentamiento.
  double _window(double ms, double lenMs) => (ms / lenMs).clamp(0.0, 1.0);

  /// Ida y vuelta: 0 -> 1 -> 0. Sirve para todo lo que sube y se deshace.
  double _bump(double u) => math.sin(math.pi * u);

  Widget _buildAnimated(bool reversed) {
    final d = _deal.value.clamp(0.0, 1.0);
    final de = Curves.easeOutBack.transform(d);
    final opacity = Curves.easeOut.transform(d);
    final dealDy = (1 - de) * 34;
    final dealScale = 0.93 + 0.07 * de;

    final fe = _spec.curve.transform(_flip.value);
    final angle = (1 - fe) * math.pi;
    final cruzado = _cruzado;

    // 1 exactamente en el canto (90 grados), 0 en las dos caras.
    final crossing = (1 - (fe - 0.5).abs() / 0.5).clamp(0.0, 1.0);

    final settleMs = _settle.value * _spec.settleMs;
    final landed = _flip.value; // 0 antes de tocar, 1 con la cara arriba

    final eng = Curves.easeOut.transform(_engage.value);
    const maxTilt = 0.20;

    // Parallax solo durante interacción. En reposo la carta queda estable y
    // conserva una inclinación física propia sin consumir frames.
    final rotX = -_tilt.dy * maxTilt * eng;
    final rotY = _tilt.dx * maxTilt * eng;
    final bt = _baseTilt * (1 - eng);
    final lift = 1 + 0.03 * eng;

    // Asentamiento: rebote de los Mayores y aplastamiento de Oros, en la misma
    // curva de ida y vuelta. Solo uno de los dos es distinto de cero.
    final settleScale =
        1 + (_spec.overshoot - _spec.squash) * _bump(_window(settleMs, 260));

    // Fuego: temblor que se disipa. Oscilacion amortiguada, no un rebote.
    final tremor = _spec.tremor
        ? 0.035 * math.sin(settleMs / 28) * math.exp(-settleMs / 140)
        : 0.0;

    // Figuras: una reverencia de ~2,5 grados que se revierte en ~150 ms.
    final bow = _isCourt ? 0.044 * _bump(_window(settleMs, 300)) : 0.0;

    // Aire: el giro no es sobre el eje vertical, sino en diagonal. Maximo en
    // el canto y cero en las dos caras, para no dejar la carta torcida.
    final diagonal = _spec.diagonal * _bump(fe);

    final scale = dealScale * lift * settleScale;

    final matrix = Matrix4.identity()
      ..setEntry(
        3,
        2,
        0.0019,
      ) // perspectiva más honda: el tilt se lee como 3D real
      ..translateByDouble(0.0, dealDy - 8 * eng, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0)
      ..rotateX(rotX + bow)
      ..rotateY(angle + rotY)
      ..rotateZ(bt + tremor + diagonal);

    // Tierra: la sombra llega mas ancha de lo que le toca y se contrae.
    final spread = _spec.shadowSpread * (1 - _window(settleMs, 460)) * landed;

    // Mayores: halo residual en el borde. Es un `BoxShadow`, no un glow con
    // desenfoque sobre el contenido: la sombra de una caja no lee lo que hay
    // detras y no fuerza `saveLayer`. Esa es la unica forma barata de hacerlo.
    final halo = _spec.halo ? 0.30 * (1 - _settle.value) * landed : 0.0;

    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_w * 0.10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12 + 20 * eng + spread,
                spreadRadius: spread * 0.35,
                offset: Offset(0, 6 + 12 * eng),
              ),
              if (widget.active)
                BoxShadow(
                  color: ArcanumColors.gold.withValues(alpha: 0.28),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              if (halo > 0.004)
                BoxShadow(
                  color: ArcanumColors.gold.withValues(alpha: halo),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_w * 0.10),
            child: Stack(
              children: [
                // Pasado el canto se ve la cara a la que se va; antes, la que
                // se deja. La de antes viaja con el naipe girado mas de 90
                // grados, asi que saldria EN ESPEJO: se le deshace el espejo
                // aqui. Es un `Transform` mas, sin capa nueva.
                if (cruzado)
                  _caraWidget(_cara, reversed)
                else
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _caraWidget(_previa, reversed),
                  ),

                // Copas: barrido especular en el canto con traza que se apaga
                // mas tarde que el propio barrido. Gradiente pintado, no
                // shader: `arcanum_resin.dart` tampoco lo es.
                if (_spec.sweep && landed > 0)
                  CustomPaint(
                    size: const Size(_w, _h),
                    painter: _SweepPainter(
                      progress: _window(settleMs, 300),
                      trace: (1 - _window(settleMs, 620)) * 0.5,
                    ),
                  ),

                // Espadas: el corte. Una linea de 1 px de esquina a esquina
                // que aparece en el canto y se va en lo que queda de giro
                // (100 ms de los 200 del volteo).
                if (_spec.cut && fe > 0.5)
                  CustomPaint(
                    size: const Size(_w, _h),
                    painter: _CutPainter(1 - (fe - 0.5) / 0.5),
                  ),

                // Mayores: la franja de luz que cruza la carta justo cuando
                // esta de canto. `crossing` al cubo la concentra en el
                // instante en vez de repartirla por todo el giro.
                if (_spec.flash && crossing > 0.05)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.40, 0.50, 0.60],
                          colors: [
                            const Color(0x00000000),
                            ArcanumColors.gold.withValues(
                              alpha: 0.85 * math.pow(crossing, 3).toDouble(),
                            ),
                            const Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Bastos: dos o tres motas que suben del borde de abajo y se
                // apagan. Widgets sueltos con color y posicion animados: no
                // hay sistema de particulas, ni falta.
                if (_spec.motes && landed > 0) ..._buildMotes(settleMs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _eyeW = 22;

  /// Alto de la tira donde vive el ojo, bajo el naipe. 26 pt dejan sitio al
  /// pulso de la pista (el ojo crece un 22%) sin mover nada de su sitio.
  static const double _eyeStrip = 26;

  /// La cara pedida, lista para meter en el naipe.
  ///
  /// Solo se construye la que se ve: la otra no existe en el arbol, asi que
  /// una carta en su cara vectorial no tiene ninguna imagen decodificada
  /// esperando por si acaso.
  Widget _caraWidget(TarotCara cara, bool reversed) {
    if (cara == TarotCara.dorso) {
      return const RepaintBoundary(
        child: CustomPaint(size: Size(_w, _h), painter: _TarotBackPainter()),
      );
    }
    Widget cara_ = cara == TarotCara.rws
        ? _rwsWidget()
        : RepaintBoundary(
            child: CustomPaint(
              size: const Size(_w, _h),
              painter: TarotFacePainter(_face),
            ),
          );
    if (reversed) cara_ = Transform.rotate(angle: math.pi, child: cara_);
    return cara_;
  }

  /// El grabado de 1909, DENTRO del marco.
  ///
  /// A sangre el naipe dejaba de parecer el mismo objeto que estaba boca abajo
  /// un segundo antes: sin bisel no hay continuidad entre las tres caras. El
  /// marco cuesta 7 pt de arte por lado, y la lamina ya viene recortada a la
  /// proporcion del naipe (1:1,60 desde el 1:1,72 del escaneo), asi que aqui
  /// no se recorta nada mas.
  Widget _rwsWidget() {
    final asset = _face.rwsAsset;
    if (asset == null) return _vectorial();

    // `cacheWidth` no es un detalle: sin el, Flutter decodifica la lamina a sus
    // 440x704 px reales y se queda 1,18 MB en cache POR CARTA. Pidiendola al
    // tamano en que se va a ver, el naipe paga lo que ocupa y ni un byte mas.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final ancho = math.min(_rwsAssetWidth, (_w * dpr).round());

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D1A24), Color(0xFF121019)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ArcanumColors.gold.withValues(alpha: 0.55),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              asset,
              width: _w,
              height: _h,
              fit: BoxFit.cover,
              cacheWidth: ancho,
              filterQuality: FilterQuality.medium,
              // Sin lamina, la carta se queda en su cara vectorial. Esa cara es
              // legitima, no un hueco: no hay nada que avisar al usuario.
              errorBuilder: (_, _, _) => _vectorial(),
            ),
          ),
        ),
      ),
    );
  }

  /// Ancho real de las laminas en `assets/tarot/`. Vive aqui para que
  /// `cacheWidth` nunca pida MAS de lo que el fichero tiene.
  static const int _rwsAssetWidth = 440;

  Widget _vectorial() => RepaintBoundary(
    child: CustomPaint(
      size: const Size(_w, _h),
      painter: TarotFacePainter(_face),
    ),
  );

  /// Tres medios senos seguidos: el ojo late tres veces y se para solo.
  double _pulseShape() {
    if (_pulse.value == 0 || _pulse.isCompleted) return 0;
    final k = _pulse.value * 3;
    return math.sin(math.pi * (k - k.floorToDouble()));
  }

  List<Widget> _buildMotes(double settleMs) {
    const seeds = [0.30, 0.52, 0.71];
    final motes = <Widget>[];
    for (var i = 0; i < seeds.length; i++) {
      final u = ((_window(settleMs, 420) - i * 0.10) / 0.72).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      motes.add(
        Positioned(
          left: _w * seeds[i],
          bottom: 6 + 28 * u,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ArcanumColors.gold.withValues(alpha: _bump(u) * 0.85),
            ),
          ),
        ),
      );
    }
    return motes;
  }

  Widget _readingText(bool reversed) {
    final c = widget.card;
    final numeral = _face.numeral;
    // Título SOLO en español: usa name_es; cae a name si el dict es legacy.
    final es = (c['name_es'] as String?)?.trim();
    final title = (es != null && es.isNotEmpty)
        ? es
        : ((c['name'] as String?) ?? '');
    return Column(
      children: [
        if (numeral.isNotEmpty)
          Text(
            numeral,
            style: ArcanumText.heading(20, color: ArcanumColors.goldMuted),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: ArcanumText.heading(26),
        ),
        const SizedBox(height: 4),
        Text(
          reversed ? 'Invertida' : 'Al derecho',
          style: ArcanumText.body(
            13,
            color: reversed
                ? ArcanumColors.burgundyLight
                : ArcanumColors.goldMuted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          (c['meaning'] as String?) ?? '',
          textAlign: TextAlign.center,
          style: ArcanumText.body(16),
        ),
      ],
    );
  }
}

/// La invitacion a tocar la carta, en el hueco donde luego ira el significado.
///
/// Mismo molde que `_TermHint` en Cielos ("Toca cualquier termino para saber
/// que significa"): cuerpo pequeno, cursiva y `ivoryMuted`. Y el mismo verbo
/// que la etiqueta de accesibilidad del naipe -- aqui las cartas se DESCUBREN,
/// que es como habla el resto de la app.
///
/// No se desvanece por su cuenta: desaparece en el canto del giro, con la
/// carta. Una animacion propia competiria con el volteo, que es el gesto que
/// se esta ensenando.
class _TapToReveal extends StatelessWidget {
  const _TapToReveal();

  @override
  Widget build(BuildContext context) => Text(
    'Toca la carta para descubrirla.',
    textAlign: TextAlign.center,
    style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted, italic: true),
  );
}

/// Copas: barrido especular que recorre la carta, y su traza.
///
/// Dos bandas de gradiente sobre el mismo eje: la que va delante es el
/// barrido, la que se queda detras es lo que el agua tarda en olvidarlo. No
/// hay `saveLayer` aqui: son dos `drawRect` con `shader`.
class _SweepPainter extends CustomPainter {
  final double progress;
  final double trace;

  const _SweepPainter({required this.progress, required this.trace});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (trace > 0.01) {
      final resto = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0x00000000),
            ArcanumColors.ivory.withValues(alpha: 0.10 * trace),
            const Color(0x00000000),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, resto);
    }

    if (progress <= 0 || progress >= 1) return;
    // El barrido cruza de arriba a abajo; el centro de la banda va en
    // `progress` y la banda ocupa un 24 % de la carta.
    final centro = progress;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [
          (centro - 0.12).clamp(0.0, 1.0),
          centro,
          (centro + 0.12).clamp(0.0, 1.0),
        ],
        colors: [
          const Color(0x00000000),
          ArcanumColors.ivory.withValues(alpha: 0.28 * _bump(progress)),
          const Color(0x00000000),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  static double _bump(double u) => math.sin(math.pi * u);

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.progress != progress || old.trace != trace;
}

/// Espadas: la linea del corte, de esquina a esquina y de 1 px.
class _CutPainter extends CustomPainter {
  final double alpha;

  const _CutPainter(this.alpha);

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.01) return;
    final paint = Paint()
      ..color = ArcanumColors.ivory.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_CutPainter old) => old.alpha != alpha;
}

/// El ojo de la esquina: cuanto ve la carta de si misma.
///
/// Tres estados y un solo trazo: el parpado de arriba baja hasta juntarse con
/// el de abajo cuando la carta esta boca abajo, y se levanta al descubrirla.
/// [TarotEyeState.iluminado] queda pintado y sin usar hasta la Fase 3.
class _EyePainter extends CustomPainter {
  final TarotEyeState state;

  /// 0..1. Late al ensenar el gesto por primera vez, y solo esa vez.
  final double pulse;

  const _EyePainter({required this.state, this.pulse = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final abierto = state != TarotEyeState.cerrado;
    final encendido = state == TarotEyeState.iluminado;

    // El pulso agranda el ojo desde su centro. Escalar el lienzo cuesta menos
    // que recalcular cada curva, y no anade capa.
    if (pulse > 0) {
      final k = 1 + 0.22 * pulse;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(k, k);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final color = encendido ? ArcanumColors.gold : ArcanumColors.goldMuted;
    final alpha = encendido ? 1.0 : (abierto ? 0.80 : 0.45);

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = color.withValues(alpha: alpha);

    if (encendido) {
      // Aureola del estado de Fase 3: un halo corto alrededor de la almendra.
      canvas.drawCircle(
        Offset(w / 2, cy),
        w * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: 0.35),
      );
    }

    // Parpado de abajo: siempre el mismo arco.
    final abajo = Path()
      ..moveTo(w * 0.06, cy)
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.94, cy);
    canvas.drawPath(abajo, trazo);

    if (!abierto) {
      // Cerrado: el parpado de arriba se apoya sobre el de abajo y salen tres
      // pestanas cortas. Sin iris: no hay nada que mirar todavia.
      canvas.drawLine(Offset(w * 0.06, cy), Offset(w * 0.94, cy), trazo);
      for (final t in const [0.28, 0.5, 0.72]) {
        final x = w * t;
        final y = cy + h * (0.30 - (t - 0.5).abs() * 0.5);
        canvas.drawLine(Offset(x, y), Offset(x, y + h * 0.16), trazo);
      }
      return;
    }

    // Abierto: la almendra completa y el iris.
    final arriba = Path()
      ..moveTo(w * 0.06, cy)
      ..quadraticBezierTo(w * 0.5, -h * 0.02, w * 0.94, cy);
    canvas.drawPath(arriba, trazo);

    final iris = Paint()
      ..color = color.withValues(alpha: encendido ? 0.95 : 0.65)
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w / 2, cy), h * 0.26, iris);
    canvas.drawCircle(
      Offset(w / 2, cy),
      h * 0.11,
      Paint()..color = ArcanumColors.surface.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.state != state || old.pulse != pulse;
}

/// Dorso de la carta: sello geométrico oculto. Un heptagrama {7/3}
/// (los siete planetas clásicos) inscrito en un medallón, sobre un campo
/// de líneas radiales — digno de verse durante todo el barajado.
class _TarotBackPainter extends CustomPainter {
  const _TarotBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.10),
    );

    final field = Paint()
      ..shader = RadialGradient(
        colors: const [ArcanumColors.surfaceHigh, ArcanumColors.surface],
        radius: 0.9,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, field);

    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.34;

    final gold = ArcanumColors.gold;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = gold.withValues(alpha: 0.55);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.30);

    final frame = rrect.deflate(8);
    canvas.drawRRect(frame, faint);
    canvas.drawRRect(rrect.deflate(12), faint);

    const spokes = 24;
    for (var i = 0; i < spokes; i++) {
      final a = i * 2 * math.pi / spokes;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (r * 1.18);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (r * 1.5);
      canvas.drawLine(p1, p2, faint);
    }

    canvas.drawCircle(center, r, thin);
    canvas.drawCircle(center, r * 0.9, faint);

    final pts = <Offset>[];
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 7;
      pts.add(center + Offset(math.cos(a), math.sin(a)) * (r * 0.82));
    }
    final star = Path();
    var idx = 0;
    star.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < 7; i++) {
      idx = (idx + 3) % 7;
      star.lineTo(pts[idx].dx, pts[idx].dy);
    }
    star.close();
    canvas.drawPath(star, thin);

    final dot = Paint()..color = gold.withValues(alpha: 0.85);
    for (final p in pts) {
      canvas.drawCircle(p, 1.6, dot);
    }

    canvas.drawCircle(center, r * 0.14, thin);
    canvas.drawCircle(center, 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant _TarotBackPainter oldDelegate) => false;
}

/// Mazo que se baraja mientras el oráculo consulta. Loop sobrio de corte
/// (dos mitades que se desplazan y giran). Sirve de estado de carga.
class ShuffleDeck extends StatefulWidget {
  const ShuffleDeck({super.key});

  @override
  State<ShuffleDeck> createState() => _ShuffleDeckState();
}

class _ShuffleDeckState extends State<ShuffleDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 118.0, h = 176.0;
    return Column(
      children: [
        SizedBox(
          height: h + 40,
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * 2 * math.pi;
                return SizedBox(
                  width: w + 80,
                  height: h + 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: List.generate(5, (i) {
                      final phase = i * (math.pi / 5);
                      final side = i.isEven ? 1.0 : -1.0;
                      final s = math.sin(t + phase);
                      final dx = side * (18 + 22 * s.abs()) * s.sign;
                      final dy = -s * 6;
                      final rot = side * 0.10 * s;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translateByDouble(dx, dy, 0.0, 1.0)
                          ..rotateZ(rot),
                        child: Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomPaint(
                              painter: const _TarotBackPainter(),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Barajando el oráculo…',
          style: ArcanumText.body(
            15,
            italic: true,
            color: ArcanumColors.ivoryMuted,
          ),
        ),
      ],
    );
  }
}
