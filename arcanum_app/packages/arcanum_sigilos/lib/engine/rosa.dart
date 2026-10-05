// Familia Rosa-Cruz: el Lamen, el nombre en hebreo y su trazo sobre los 22
// petalos (puerto de js/rosa.js; el prototipo es la fuente de verdad).
// Fuentes (verificadas el 26-sep-2026):
//  [OM] Mathers (G.H. Frater D.D.C.F.), manuscrito F «Sigils from the Rose»:
//       circulo en la letra inicial y linea de letra en letra; dos letras
//       iguales seguidas = quiebro u onda; letra del nombre por la que la
//       linea pasa (Resh en Metatron) = lazo. El texto no habla de marca
//       final, pero sus figuras (Metatron, Elohim) acaban en barra corta.
//  [OM] Documento 5=6 «The Rose Cross Lamen»: madres; dobles en el orden Peh
//       Resh Beth Daleth Gimel Tav Kaph; zodiaco con Heh arriba.
//  Wikimedia Commons, Rose_Cross_Lamen.svg: posiciones y sentido antihorario.
// Nunca se mezcla con el sigilo de letras latinas.
import 'dart:math' as math;

import 'arcane_glyphs.dart';
import 'hebrew.dart';
import 'js_num.dart';
import 'kamea.dart' show segmentsOverlap;
import 'layers.dart';
import 'letter_sigil.dart' show kC;
import 'scene.dart';
import 'style.dart';

/// Anillo del Lamen, en orden de lectura: angulo de la primera letra y paso
/// (negativo = antihorario en pantalla, como en el Lamen).
class RoseRing {
  final String id, label;
  final int r, r0, r1;
  final double start, step;
  final List<String> letters;
  const RoseRing(this.id, this.label, this.r, this.r0, this.r1, this.start, this.step, this.letters);
}

const kRoseRings = <RoseRing>[
  RoseRing('mother', 'Madres', 105, 62, 148, -90, -120, ['א', 'מ', 'ש']),
  RoseRing('double', 'Dobles', 186, 148, 224, -90 - 360 / 14, -360 / 7, ['פ', 'ר', 'ב', 'ד', 'ג', 'ת', 'כ']),
  RoseRing('simple', 'Simples', 261, 224, 298, -90, -30, ['ה', 'ו', 'ז', 'ח', 'ט', 'י', 'ל', 'נ', 'ס', 'ע', 'צ', 'ק']),
];

/// Nombre de la letra, su correspondencia y su simbolo (vacio en las madres).
const kRoseInfo = <String, (String, String, String)>{
  'א': ('Álef', 'Aire', ''), 'מ': ('Mem', 'Agua', ''), 'ש': ('Shin', 'Fuego', ''),
  'ב': ('Bet', 'Mercurio', '☿'), 'ג': ('Guímel', 'Luna', '☽'), 'ד': ('Dálet', 'Venus', '♀'), 'כ': ('Kaf', 'Júpiter', '♃'),
  'פ': ('Pe', 'Marte', '♂'), 'ר': ('Resh', 'Sol', '☉'), 'ת': ('Tav', 'Saturno', '♄'),
  'ה': ('He', 'Aries', '♈'), 'ו': ('Vav', 'Tauro', '♉'), 'ז': ('Zain', 'Géminis', '♊'), 'ח': ('Jet', 'Cáncer', '♋'),
  'ט': ('Tet', 'Leo', '♌'), 'י': ('Yod', 'Virgo', '♍'), 'ל': ('Lámed', 'Libra', '♎'), 'נ': ('Nun', 'Escorpio', '♏'),
  'ס': ('Sámej', 'Sagitario', '♐'), 'ע': ('Ayin', 'Capricornio', '♑'), 'צ': ('Tsadi', 'Acuario', '♒'), 'ק': ('Qof', 'Piscis', '♓'),
};

/// Colores de las letras: escala del Rey de la Golden Dawn, caminos 11-32
/// (Alef..Tav). Coinciden con los que da el manuscrito F para Metatron: azul,
/// verde-amarillo, naranja, rojo-naranja y verde-azul (Mem, Tet, Resh, Vav,
/// Nun). El tono exacto de cada nombre es eleccion del taller.
const kRoseColors = <String, (String, String)>{
  'א': ('amarillo pálido brillante', '#f3eb9a'), 'ב': ('amarillo', '#f2cf1d'), 'ג': ('azul', '#2f63d6'), 'ד': ('verde esmeralda', '#1d9a58'),
  'ה': ('escarlata', '#de2a1f'), 'ו': ('rojo anaranjado', '#ef5a1c'), 'ז': ('naranja', '#f28a1c'), 'ח': ('ámbar', '#f0aa1a'),
  'ט': ('amarillo verdoso', '#c9d21c'), 'י': ('verde amarillento', '#9acb1f'), 'כ': ('violeta', '#7b31b3'), 'ל': ('verde esmeralda', '#1d9a58'),
  'מ': ('azul profundo', '#1c3fa3'), 'נ': ('verde azulado', '#1a8c8c'), 'ס': ('azul', '#2f63d6'), 'ע': ('índigo', '#3c2b8f'),
  'פ': ('escarlata', '#de2a1f'), 'צ': ('violeta', '#7b31b3'), 'ק': ('carmesí', '#b3123c'), 'ר': ('naranja', '#f28a1c'),
  'ש': ('naranja escarlata brillante', '#f0431c'), 'ת': ('índigo', '#3c2b8f'),
};

/// Rotulo del petalo: el simbolo si lo hay (con selector de texto), si no la correspondencia.
String roseLabel(String he) {
  final (_, corr, sym) = kRoseInfo[he]!;
  return sym.isNotEmpty ? '$sym︎' : corr;
}

class Petal {
  final String he;
  final RoseRing ring;
  final double a, x, y;
  const Petal(this.he, this.ring, this.a, this.x, this.y);
}

final Map<String, Petal> kPetals = {
  for (final ring in kRoseRings)
    for (final (i, he) in ring.letters.indexed)
      he: () {
        final a = ring.start + ring.step * i;
        return Petal(he, ring, a, kC + cosD(a) * ring.r, kC + sinD(a) * ring.r);
      }(),
};

// ── Gematria ────────────────────────────────────────────────────
/// Valor estandar y valor «mayor» (finales de 500 a 900).
({int std, int gadol}) gematria(String heb) {
  var std = 0, gadol = 0;
  for (final ch in heb.split('')) {
    final v = kHebValue[baseLetter(ch)];
    if (v == null) continue;
    std += v;
    gadol += kGadolFinal[ch] ?? v;
  }
  return (std: std, gadol: gadol);
}

// ── Trazo segun el manuscrito F ─────────────────────────────────
const double kNooseMaxTurn = 15; // grados: por debajo, la linea «pasa» recta
const double kOverlapShift = 20; // px que se aparta un trazo que repasa otro

/// Letra del nombre por la que pasa un trazo: el manuscrito dobla la linea
/// hasta ella y la marca con lazo. Regla calibrada con las 8 laminas del
/// manuscrito F [AR]: solo si la letra aun no se ha visitado y no es la
/// primera ni la ultima (ya llevan circulo y barra). Haniel la cumple (40 px);
/// Hagiel pasa a 56 px y Tzabaoth pasa por un Alef ya visitado: sin lazo.
const double kPassDist = 48;

({double d, double t}) _distToSegment(Petal p, RoseVert a, RoseVert b) {
  final dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
  final t = l2 != 0 ? math.max(0.0, math.min(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0.0;
  return (d: hypot(p.x - a.x - t * dx, p.y - a.y - t * dy), t: t);
}

typedef Dir = ({double x, double y});

/// Letra visitada por el trazo, con las marcas que le tocan.
class RoseVert {
  final String he, ch;
  double x, y;
  int repeat = 1;
  bool shifted = false, noose = false, crook = false;
  ({String he, double d, double t})? pass;
  Dir? inDir, outDir;
  double? turn;
  RoseVert(this.he, this.ch, this.x, this.y);
}

List<RoseVert> roseTrace(String word) {
  final verts = <RoseVert>[];
  for (final ch in word.split('')) {
    final b = baseLetter(ch), p = kPetals[b];
    if (p == null) continue;
    if (verts.isNotEmpty && verts.last.he == b) {
      verts.last.repeat++;
      continue;
    }
    verts.add(RoseVert(b, ch, p.x, p.y));
  }
  if (verts.isEmpty) return verts;
  final letters = [for (final v in verts) v.he], first = letters.first, lastL = letters.last;
  for (var k = 0; k < verts.length - 1; k++) {
    final a = verts[k], b = verts[k + 1];
    final visited = {for (final v in verts.take(k + 2)) v.he};
    ({String he, double d, double t})? best;
    for (final he in letters.toSet()) {
      if (he == first || he == lastL || visited.contains(he)) continue;
      final m = _distToSegment(kPetals[he]!, a, b);
      if (m.d < kPassDist && m.t > 0 && m.t < 1 && (best == null || m.d < best.d)) best = (he: he, d: m.d, t: m.t);
    }
    // el lazo va sobre la linea, en el punto mas cercano a la letra: en la
    // lamina de Haniel el lazo y el vertice del Alef son puntos distintos
    if (best != null) a.pass = best;
  }
  // Un trazo que repasa otro ya dibujado se separa un poco, como en las
  // figuras del manuscrito (Elohim: Alef, Lamed y He comparten eje y el
  // original los dibuja en zigzag). Sin esto la linea queda escondida.
  for (var k = 1; k < verts.length - 1; k++) {
    final a = verts[k], b = verts[k + 1];
    final hides = [for (var j = 0; j < k; j++) j].any((j) => segmentsOverlap((x: verts[j].x, y: verts[j].y), (x: verts[j + 1].x, y: verts[j + 1].y), (x: a.x, y: a.y), (x: b.x, y: b.y)));
    if (!hides) continue;
    final dx = b.x - a.x, dy = b.y - a.y, l = hypot(dx, dy) == 0 ? 1.0 : hypot(dx, dy);
    b.x += -dy / l * kOverlapShift;
    b.y += dx / l * kOverlapShift;
    b.shifted = true;
  }
  final dirs = <Dir>[
    for (var i = 1; i < verts.length; i++)
      () {
        final dx = verts[i].x - verts[i - 1].x, dy = verts[i].y - verts[i - 1].y, l = hypot(dx, dy) == 0 ? 1.0 : hypot(dx, dy);
        return (x: dx / l, y: dy / l);
      }(),
  ];
  for (final (i, v) in verts.indexed) {
    v.inDir = i > 0 ? dirs[i - 1] : null;
    v.outDir = i < dirs.length ? dirs[i] : null;
    final a = v.inDir, b = v.outDir;
    v.turn = a != null && b != null ? math.atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y).abs() * 180 / math.pi : null;
    v.noose = v.turn != null && v.turn! < kNooseMaxTurn;
    v.crook = v.repeat > 1;
  }
  return verts;
}

// Geometria unica del sello (lienzo y SVG la comparten)
const int _startR = 13, _nooseR = 7;
const double _crookL = 30, _crookA = 12;

({double x, double y}) _p(RoseVert p, Dir d, double t, [double n = 0]) => (x: p.x + d.x * t - d.y * n, y: p.y + d.y * t + d.x * n);
String _pt(({double x, double y}) v) => '${f2(v.x)} ${f2(v.y)}';
String _ring(double cx, double cy, int r) =>
    'M ${f2(cx + r)} ${f2(cy)} A $r $r 0 1 0 ${f2(cx - r)} ${f2(cy)} A $r $r 0 1 0 ${f2(cx + r)} ${f2(cy)} Z';

/// Un tramo suelto del sello, de letra en letra, con el quiebro incluido.
class RoseSegment {
  final String d, from, to;
  final double x1, y1, x2, y2;
  const RoseSegment(this.d, this.from, this.to, this.x1, this.y1, this.x2, this.y2);
}

List<RoseSegment> roseSegments(List<RoseVert> verts) {
  final segs = <RoseSegment>[];
  for (var i = 1; i < verts.length; i++) {
    final a = verts[i - 1], v = verts[i], di = v.inDir!;
    final from = i == 1 ? _p(a, a.outDir!, _startR.toDouble()) : (x: a.x, y: a.y);
    final d = StringBuffer('M ${_pt(from)}');
    if (i == 1 && a.crook) {
      d.write(' C ${_pt(_p(a, a.outDir!, _startR + _crookL / 3, _crookA))} ${_pt(_p(a, a.outDir!, _startR + 2 * _crookL / 3, -_crookA))} ${_pt(_p(a, a.outDir!, _startR + _crookL))}');
    }
    if (v.crook) {
      d.write(' L ${_pt(_p(v, di, -_crookL))} C ${_pt(_p(v, di, -2 * _crookL / 3, _crookA))} ${_pt(_p(v, di, -_crookL / 3, -_crookA))} ${_pt((x: v.x, y: v.y))}');
    } else {
      d.write(' L ${_pt((x: v.x, y: v.y))}');
    }
    segs.add(RoseSegment(d.toString(), a.he, v.he, from.x, from.y, v.x, v.y));
  }
  return segs;
}

class RoseShape {
  final String mark, d;
  const RoseShape(this.mark, this.d);
}

List<RoseShape> roseSigilShapes(List<RoseVert> verts, bool endBar) {
  if (verts.isEmpty) return const [];
  final shapes = <RoseShape>[RoseShape('start', _ring(verts[0].x, verts[0].y, _startR))];
  if (verts.length > 1 || verts[0].crook) {
    final v0 = verts[0], d0 = v0.outDir ?? (x: 1.0, y: 0.0);
    // la linea sale del borde del circulo inicial
    final d = StringBuffer('M ${_pt(_p(v0, d0, _startR.toDouble()))}');
    // letra inicial repetida: quiebro justo al salir
    if (v0.crook) {
      d.write(' C ${_pt(_p(v0, d0, _startR + _crookL / 3, _crookA))} ${_pt(_p(v0, d0, _startR + 2 * _crookL / 3, -_crookA))} ${_pt(_p(v0, d0, _startR + _crookL))}');
    }
    for (var i = 1; i < verts.length; i++) {
      final v = verts[i], di = v.inDir!;
      if (v.crook) {
        // quiebro (onda) en la linea al llegar a la letra repetida
        d.write(' L ${_pt(_p(v, di, -_crookL))} C ${_pt(_p(v, di, -2 * _crookL / 3, _crookA))} ${_pt(_p(v, di, -_crookL / 3, -_crookA))} ${_pt((x: v.x, y: v.y))}');
      } else {
        d.write(' L ${_pt((x: v.x, y: v.y))}');
      }
    }
    shapes.add(RoseShape('line', d.toString()));
  }
  for (final (i, v) in verts.indexed) {
    final pass = v.pass;
    if (pass != null) {
      // punto del segmento mas cercano a la letra (tras apartar trazos)
      final nx = verts[i + 1], d = v.outDir!;
      final px = v.x + (nx.x - v.x) * pass.t, py = v.y + (nx.y - v.y) * pass.t;
      shapes.add(RoseShape('noose', _ring(px - d.y * _nooseR, py + d.x * _nooseR, _nooseR)));
    }
    if (!v.noose) continue;
    final di = v.inDir!;
    shapes.add(RoseShape('noose', _ring(v.x - di.y * _nooseR, v.y + di.x * _nooseR, _nooseR)));
  }
  if (endBar && verts.length > 1) {
    final e = verts.last, de = e.inDir!;
    shapes.add(RoseShape('end', 'M ${_pt(_p(e, de, 0, -10))} L ${_pt(_p(e, de, 0, 10))}'));
  }
  return shapes;
}

/// Petalo del diagrama: cuna entre radios.
String petalPath(Petal p) {
  final h = p.ring.step.abs() / 2, a0 = rad(p.a - h), a1 = rad(p.a + h), r0 = p.ring.r0, r1 = p.ring.r1;
  String at(int r, double a) => '${f2(kC + math.cos(a) * r)} ${f2(kC + math.sin(a) * r)}';
  final large = h * 2 > 180 ? 1 : 0;
  return 'M ${at(r0, a0)} L ${at(r1, a0)} A $r1 $r1 0 $large 1 ${at(r1, a1)} L ${at(r0, a1)} A $r0 $r0 0 $large 0 ${at(r0, a0)} Z';
}

/// Documento de la familia Rosa-Cruz: el nombre, su hebreo y las decisiones de
/// dibujo. Lo demas (palabras, SVG) se deriva y es determinista.
class RosaDoc {
  String name, hebrew;
  TranslitMethod method;
  bool colors, diagram, endBar, transparent;
  SigilStyle style;

  RosaDoc({
    this.name = '',
    this.hebrew = '',
    this.method = TranslitMethod.consonantal,
    this.colors = false,
    this.diagram = true,
    this.endBar = true,
    this.transparent = false,
    this.style = const SigilStyle(),
  });

  SigilTheme get theme => themeFor(style);

  /// Una palabra, un sigilo: el manuscrito traza YHVH y TZABAOTH por separado.
  List<List<RoseVert>> get words => [for (final w in hebrew.split(' ').where((w) => w.isNotEmpty)) roseTrace(w)];
  List<RoseVert> get trace => [for (final w in words) ...w];

  void setHebrew(String h) => hebrew = cleanHebrew(h);

  /// Latino: se transcribe; hebreo: se limpia y se usa tal cual.
  void setName(String n, {TranslitMethod? translit}) {
    name = n.trim();
    method = translit ?? method;
    hebrew = hasHebrew(name) ? cleanHebrew(name) : cleanHebrew(transliterate(name, method).hebrew);
  }

  /// Transcripcion letra a letra, solo si el hebreo es la que salio del nombre.
  Transliteration? get tokens {
    if (name.isEmpty || hasHebrew(name)) return null;
    final t = transliterate(name, method);
    return cleanHebrew(t.hebrew) == hebrew ? t : null;
  }

  // ── Lectura ───────────────────────────────────────────────────
  String get recorrido => words.map((w) => w.map((v) => '${v.he} ${kRoseInfo[v.he]!.$2}${v.pass != null ? ' (pasa junto a ${v.pass!.he})' : ''}').join(' → ')).join(' | ');

  String get gematriaText {
    final g = gematria(hebrew);
    return '${g.std} (estándar)${g.gadol != g.std ? ' · ${g.gadol} (mayor: las letras finales valen de 500 a 900)' : ''}';
  }

  /// Marcas del dibujo, en palabras.
  List<String> get marks {
    final ws = words, out = <String>[];
    String nm(String he) => kRoseInfo[he]!.$1;
    for (final (i, w) in ws.indexed) {
      if (w.isEmpty) continue;
      final pre = ws.length > 1 ? 'palabra ${i + 1}: ' : '';
      out.add('${pre}círculo en ${w[0].he} (inicio)');
      for (final v in w.where((v) => v.crook)) {
        out.add('${pre}quiebro en ${v.he} (${nm(v.he)}, ${v.repeat} veces seguidas)');
      }
      for (final v in w.where((v) => v.pass != null)) {
        out.add('${pre}lazo junto a ${v.pass!.he} (${nm(v.pass!.he)}): el trazo pasa a ${jsRound(v.pass!.d).toInt()} px de ella antes de visitarla');
      }
      for (final v in w.where((v) => v.noose)) {
        out.add('${pre}lazo en ${v.he} (${nm(v.he)}): la línea pasa casi recta, gira ${v.turn!.toStringAsFixed(1)}°');
      }
      for (final v in w.where((v) => v.shifted)) {
        out.add('${pre}trazo hacia ${v.he} (${nm(v.he)}) apartado para no tapar otro');
      }
      if (endBar && w.length > 1) out.add('${pre}barra en ${w.last.he} (final)');
    }
    return out;
  }

  /// Letras distintas del recorrido, con su color de la escala del Rey.
  List<String> get usedLetters => {for (final v in trace) v.he}.toList();

  // ── SVG ───────────────────────────────────────────────────────
  String buildSVG() {
    final th = theme, ws = words, used = {for (final w in ws) for (final v in w) v.he}, out = StringBuffer();
    out.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">');
    if (!transparent) out.write(sceneSVG(bgScene(style, th)));
    if (diagram) {
      out.write('<g data-layer="rose-diagram" stroke="${th.faint}" stroke-width="1.2">');
      for (final p in kPetals.values) {
        final u = used.contains(p.he), label = roseLabel(p.he);
        out.write(colors
            ? '<path d="${petalPath(p)}" fill="${kRoseColors[p.he]!.$2}" fill-opacity="${u ? '0.55' : '0.22'}"/>'
            : '<path d="${petalPath(p)}" fill="${u ? th.faint : 'none'}"/>');
        out.write('<text x="${f2(p.x)}" y="${f2(p.y - 4)}" stroke="none" text-anchor="middle" dominant-baseline="middle" font-family="Arial Hebrew, Segoe UI, serif" font-size="20" fill="${th.ink}">${p.he}</text>');
        out.write(hasGlyph(label)
            ? glyphSVG(label, p.x, p.y + 15, 12, 0, th.frame, 1, ' stroke-width="1"')
            : '<text x="${f2(p.x)}" y="${f2(p.y + 15)}" stroke="none" text-anchor="middle" dominant-baseline="middle" font-family="Georgia, serif" font-size="11" fill="${th.frame}">${esc(label)}</text>');
      }
      out.write('</g>');
    }
    out.write('<g data-layer="rose" fill="none" stroke="${th.accent}" stroke-linecap="round" stroke-linejoin="round">');
    for (final (i, w) in ws.indexed) {
      out.write('<g data-word="${i + 1}">');
      final shapes = roseSigilShapes(w, endBar);
      if (colors) {
        for (final (j, g) in roseSegments(w).indexed) {
          final id = 'rg${i}_$j';
          out.write('<linearGradient id="$id" gradientUnits="userSpaceOnUse" x1="${f2(g.x1)}" y1="${f2(g.y1)}" x2="${f2(g.x2)}" y2="${f2(g.y2)}"><stop offset="0" stop-color="${kRoseColors[g.from]!.$2}"/><stop offset="1" stop-color="${kRoseColors[g.to]!.$2}"/></linearGradient>');
          out.write('<path data-mark="segment" d="${g.d}" stroke="url(#$id)" stroke-width="4.2"/>');
        }
        for (final s in shapes) {
          if (s.mark == 'line') continue;
          final he = s.mark == 'start' ? w.first.he : s.mark == 'end' ? w.last.he : null;
          out.write('<path data-mark="${s.mark}" d="${s.d}" stroke="${he != null ? kRoseColors[he]!.$2 : th.accent}" stroke-width="3"/>');
        }
      } else {
        for (final s in shapes) {
          out.write('<path data-mark="${s.mark}" d="${s.d}" stroke-width="${s.mark == 'line' ? '3.2' : '2.4'}"/>');
        }
      }
      out.write('</g>');
    }
    out.write('</g></svg>');
    return out.toString();
  }

  // ── Lienzo ────────────────────────────────────────────────────
  /// La misma obra para el lienzo. Los caminos son los que escribe [buildSVG];
  /// el texto va aparte (capa `rose-text`) porque cada lado pone su fuente.
  ({List<SceneGroup> bg, List<SceneGroup> fg}) scene({bool? transparent}) {
    final th = theme, ws = words, used = {for (final w in ws) for (final v in w) v.he}, fg = <SceneGroup>[];
    if (diagram) {
      final petals = kPetals.values.toList();
      if (colors) {
        for (final p in petals) {
          fg.add(SceneGroup(layer: 'rose-petal', color: kRoseColors[p.he]!.$2, op: used.contains(p.he) ? .55 : .22, items: [PathItem(petalPath(p), fill: true)]));
        }
      } else {
        fg.add(SceneGroup(layer: 'rose-petal', color: th.ink, op: .16, items: [for (final p in petals) if (used.contains(p.he)) PathItem(petalPath(p), fill: true)]));
      }
      fg.add(SceneGroup(layer: 'rose-diagram', color: th.ink, w: 1.2, op: .16, items: [for (final p in petals) PathItem(petalPath(p))]));
      fg.add(SceneGroup(layer: 'rose-text', color: th.ink, prims: [
        for (final p in petals) TextPrim(p.x, p.y - 4, 0, 20, p.he, 'Arial Hebrew, Segoe UI, serif', 1),
        for (final p in petals)
          if (!hasGlyph(roseLabel(p.he))) TextPrim(p.x, p.y + 15, 0, 11, roseLabel(p.he), 'Georgia, serif', .55),
      ]));
      fg.add(SceneGroup(layer: 'rose-glyphs', color: th.ink, prims: [
        for (final p in petals)
          if (hasGlyph(roseLabel(p.he))) GlyphLayerPrim(p.x, p.y + 15, 0, 12, roseLabel(p.he), .55),
      ]));
    }
    for (final (i, w) in ws.indexed) {
      final shapes = roseSigilShapes(w, endBar);
      if (colors) {
        final segs = roseSegments(w);
        fg.add(SceneGroup(layer: 'rose-segment', color: th.accent, w: 4.2, cap: 'round', sigil: true, items: [
          for (final (j, g) in segs.indexed)
            PathItem(g.d, strokeGrad: Grad.linear('rg${i}_$j', g.x1, g.y1, g.x2, g.y2, [(0, kRoseColors[g.from]!.$2, 1), (1, kRoseColors[g.to]!.$2, 1)])),
        ]));
        for (final s in shapes) {
          if (s.mark == 'line') continue;
          final he = s.mark == 'start' ? w.first.he : s.mark == 'end' ? w.last.he : null;
          fg.add(SceneGroup(layer: 'rose-${s.mark}', color: he != null ? kRoseColors[he]!.$2 : th.accent, w: 3, cap: 'round', sigil: true, items: [PathItem(s.d)]));
        }
      } else {
        for (final s in shapes) {
          fg.add(SceneGroup(layer: 'rose-${s.mark}', color: th.accent, w: s.mark == 'line' ? 3.2 : 2.4, cap: 'round', sigil: true, items: [PathItem(s.d)]));
        }
      }
    }
    return (bg: (transparent ?? this.transparent) ? const [] : bgScene(style, th), fg: fg);
  }

  // ── Guardado ──────────────────────────────────────────────────
  static const kVersion = 1;

  Map<String, Object?> toJson() => {
        'v': kVersion,
        'family': 'rosa',
        'name': name,
        'method': method.name,
        'hebrew': hebrew,
        'colors': colors,
        'diagram': diagram,
        'endBar': endBar,
        'transparent': transparent,
        'style': style.toJson(),
      };

  factory RosaDoc.fromJson(Map<String, dynamic> j) {
    final v = j['v'] as int? ?? 0;
    if (v > kVersion) throw FormatException('Rosa-Cruz guardada con una version mas nueva ($v) que esta app ($kVersion).');
    return RosaDoc(
      name: j['name'] as String? ?? '',
      method: TranslitMethod.values.byName(j['method'] as String? ?? 'consonantal'),
      hebrew: cleanHebrew(j['hebrew'] as String? ?? ''),
      colors: j['colors'] as bool? ?? false,
      diagram: j['diagram'] as bool? ?? true,
      endBar: j['endBar'] as bool? ?? true,
      transparent: j['transparent'] as bool? ?? false,
      style: j['style'] == null ? const SigilStyle() : SigilStyle.fromJson(j['style'] as Map<String, dynamic>),
    );
  }
}
