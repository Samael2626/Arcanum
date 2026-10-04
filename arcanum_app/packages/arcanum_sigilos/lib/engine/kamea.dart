// Familia Kamea: tablas planetarias de Agrippa y el trazo de un nombre sobre
// la tabla (puerto de js/kamea.js; el prototipo es la fuente de verdad).
// Fuente: Agrippa, De occulta philosophia (1533), lib. II, cap. 22 [HP].
// Tablas transcritas de las laminas de la ed. inglesa de 1651 (ed. digital de
// J. H. Peterson, esotericarchives.com) y comprobadas por codigo.
// Erratas de esa edicion, resueltas por aritmetica y declaradas en pantalla:
//  - Luna, fila 1, col. 8: impreso «45» (ya esta en la fila 9 y la fila
//    sumaria 360). El unico numero que falta es 54.
//  - Kedemel: impreso «157»; su hebreo suma 175 (la linea de Venus).
//  - Bne Seraphim: transcrito בסי; solo בני da el 1252 impreso.
// Agrippa usa valores mayores para las finales (Bne Seraphim y
// Schedbarschemoth solo cuadran asi). Y NO explica como se trazan los sellos:
// «el buscador sabio lo descubrira». El trazado es reconstruccion [RC].
import 'dart:math' as math;

import 'hebrew.dart';
import 'layers.dart';
import 'js_num.dart';
import 'letter_sigil.dart' show kC, kSize;
import 'scene.dart';
import 'style.dart';

/// Nombre de inteligencia o espiritu que da Agrippa para una tabla.
class KameaName {
  final String role, latin, hebrew;

  /// Numero que Agrippa le da (cuenta las finales de 500 a 900).
  final int sum;

  /// Lamina de Agrippa en esotericarchives.com.
  final String plate;

  /// Si el trazo coincide con el caracter de Agrippa: si, parcial o no.
  final String verdict;
  const KameaName(this.role, this.latin, this.hebrew, this.sum, this.plate, this.verdict);
}

class KameaDef {
  final String id, name, sym;
  final List<List<int>> rows;
  final List<KameaName> names;
  const KameaDef(this.id, this.name, this.sym, this.rows, this.names);
  int get n => rows.length;
}

const kKameas = <KameaDef>[
  KameaDef('saturn', 'Saturno', '♄', [[4, 9, 2], [3, 5, 7], [8, 1, 6]], [
    KameaName('Inteligencia', 'Agiel', 'אגיאל', 45, 'op2_30.gif', 'si'),
    KameaName('Espíritu', 'Zazel', 'זאזל', 45, 'op2_31.gif', 'parcial'),
  ]),
  KameaDef('jupiter', 'Júpiter', '♃', [[4, 14, 15, 1], [9, 7, 6, 12], [5, 11, 10, 8], [16, 2, 3, 13]], [
    KameaName('Inteligencia', 'Iofiel', 'יהפיאל', 136, 'op2_35.jpeg', 'parcial'),
    KameaName('Espíritu', 'Hismael', 'הסמאל', 136, 'op2_36.gif', 'si'),
  ]),
  KameaDef('mars', 'Marte', '♂', [[11, 24, 7, 20, 3], [4, 12, 25, 8, 16], [17, 5, 13, 21, 9], [10, 18, 1, 14, 22], [23, 6, 19, 2, 15]], [
    KameaName('Inteligencia', 'Grafiel', 'גראפיאל', 325, 'op2_40.gif', 'no'),
    KameaName('Espíritu', 'Barzabel', 'ברצבאל', 325, 'op2_41.gif', 'si'),
  ]),
  KameaDef('sun', 'Sol', '☉', [
    [6, 32, 3, 34, 35, 1], [7, 11, 27, 28, 8, 30], [19, 14, 16, 15, 23, 24], [18, 20, 22, 21, 17, 13], [25, 29, 10, 9, 26, 12], [36, 5, 33, 4, 2, 31],
  ], [
    KameaName('Inteligencia', 'Najiel', 'נכיאל', 111, 'op2_45.gif', 'si'),
    KameaName('Espíritu', 'Sorath', 'סורת', 666, 'op2_46.gif', 'si'),
  ]),
  KameaDef('venus', 'Venus', '♀', [
    [22, 47, 16, 41, 10, 35, 4], [5, 23, 48, 17, 42, 11, 29], [30, 6, 24, 49, 18, 36, 12], [13, 31, 7, 25, 43, 19, 37],
    [38, 14, 32, 1, 26, 44, 20], [21, 39, 8, 33, 2, 27, 45], [46, 15, 40, 9, 34, 3, 28],
  ], [
    KameaName('Inteligencia', 'Haguiel', 'הגיאל', 49, 'op2_50.gif', 'parcial'),
    KameaName('Espíritu', 'Kedemel', 'קדמאל', 175, 'op2_51.gif', 'si'),
    KameaName('Inteligencias', 'Bne Serafim', 'בני שרפים', 1252, 'op2_52.gif', 'parcial'),
  ]),
  KameaDef('mercury', 'Mercurio', '☿', [
    [8, 58, 59, 5, 4, 62, 63, 1], [49, 15, 14, 52, 53, 11, 10, 56], [41, 23, 22, 44, 45, 19, 18, 48], [32, 34, 35, 29, 28, 38, 39, 25],
    [40, 26, 27, 37, 36, 30, 31, 33], [17, 47, 46, 20, 21, 43, 42, 24], [9, 55, 54, 12, 13, 51, 50, 16], [64, 2, 3, 61, 60, 6, 7, 57],
  ], [
    KameaName('Inteligencia', 'Tiriel', 'טיריאל', 260, 'op2_56.gif', 'parcial'),
    KameaName('Espíritu', 'Taftartarat', 'תפתרתרת', 2080, 'op2_57.gif', 'si'),
  ]),
  KameaDef('moon', 'Luna', '☽', [
    [37, 78, 29, 70, 21, 62, 13, 54, 5], [6, 38, 79, 30, 71, 22, 63, 14, 46], [47, 7, 39, 80, 31, 72, 23, 55, 15],
    [16, 48, 8, 40, 81, 32, 64, 24, 56], [57, 17, 49, 9, 41, 73, 33, 65, 25], [26, 58, 18, 50, 1, 42, 74, 34, 66],
    [67, 27, 59, 10, 51, 2, 43, 75, 35], [36, 68, 19, 60, 11, 52, 3, 44, 76], [77, 28, 69, 20, 61, 12, 53, 4, 45],
  ], [
    KameaName('Espíritu', 'Hasmodai', 'חשמודאי', 369, 'op2_61.gif', 'si'),
    KameaName('Espíritu de los espíritus', 'Shedbarshemot Shartatán', 'שדברשהמעת שרתתן', 3321, 'op2_62.gif', 'parcial'),
  ]),
];

const kVerdictText = {
  'si': 'El trazo coincide con el carácter que dibuja Agrippa.',
  'parcial': 'Coincide la estructura (tramos, horquillas y extremos), pero no del todo la orientación del dibujo de Agrippa.',
  'no': 'El carácter de Agrippa no sale de esta tabla con ningún método conocido; se muestra el trazo, no su figura.',
};

KameaDef kameaById(String id) => kKameas.firstWhere((k) => k.id == id);

const kAgrippaUrl = 'http://www.esotericarchives.com/agrippa/agripp2b.htm';

/// Valor de letra como lo cuenta Agrippa: finales de 500 a 900.
int kameaValue(String ch) => kGadolFinal[ch] ?? kHebValue[baseLetter(ch)] ?? 0;

/// Numero mayor que la ultima casilla: dos reducciones en uso [RC].
enum KameaReduce {
  agrippa('Como Agrippa',
      'Hasta la tabla del Sol (6×6) se reduce a la cámara (200 → 2); desde Venus (7×7), se quitan ceros (200 → 20). Es la regla que reproduce sus figuras: Barzabel y Sorath por un lado; Kedemel, Tiriel, Taftartarat y Hasmodai por otro. Ningún texto la enuncia.'),
  zeros('Quitar ceros', 'Se divide entre 10 hasta que cabe en la tabla (200 → 20 → 2 según el tamaño).'),
  aiq('Aiq Bekar (nueve cámaras)', 'Se reduce a su cámara: unidades, decenas y centenas de la misma cifra comparten casilla (200 → 2, 30 → 3).');

  final String label, rule;
  const KameaReduce(this.label, this.rule);
}

/// Remates del trazo: circulo en los dos extremos (Agrippa) o barra (Aurora Dorada).
enum KameaEnds { agrippa, gd }

({int cell, bool reduced}) kameaCell(int v, int max, KameaReduce method) {
  if (v <= max) return (cell: v, reduced: false);
  if (method == KameaReduce.agrippa) method = max <= 36 ? KameaReduce.aiq : KameaReduce.zeros;
  var c = v;
  if (method == KameaReduce.aiq) {
    while (c >= 10) {
      c ~/= 10;
    }
    return (cell: c, reduced: true);
  }
  while (c > max && c % 10 == 0) {
    c ~/= 10;
  }
  while (c > max) {
    c ~/= 10;
  }
  return (cell: c, reduced: true);
}

/// Geometria de la tabla en el lienzo.
const double kKameaSize = 560;

class KameaGeom {
  final int n;
  final double cell, x0, y0;
  final Map<int, ({double x, double y, int r, int c})> pos;
  const KameaGeom(this.n, this.cell, this.x0, this.y0, this.pos);
}

KameaGeom kameaGeom(KameaDef k) {
  final n = k.n, cell = kKameaSize / n, x0 = kC - kKameaSize / 2, y0 = kC - kKameaSize / 2;
  final pos = <int, ({double x, double y, int r, int c})>{};
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      pos[k.rows[r][c]] = (x: x0 + (c + .5) * cell, y: y0 + (r + .5) * cell, r: r, c: c);
    }
  }
  return KameaGeom(n, cell, x0, y0, pos);
}

/// Una letra sobre la tabla: su valor, su casilla y su centro.
class KameaStep {
  final String ch;
  final int v, cell;
  final bool reduced;
  final double x, y;
  const KameaStep(this.ch, this.v, this.cell, this.reduced, this.x, this.y);
  KameaStep at(double nx, double ny) => KameaStep(ch, v, cell, reduced, nx, ny);
}

/// Recorrido: una palabra, un sigilo (como en la Rosa).
List<List<KameaStep>> kameaTrace(String heb, KameaDef k, KameaReduce method) {
  final g = kameaGeom(k), max = g.n * g.n;
  final out = <List<KameaStep>>[];
  for (final word in heb.split(' ').where((w) => w.isNotEmpty)) {
    final steps = <KameaStep>[];
    for (final ch in word.split('')) {
      final v = kameaValue(ch);
      if (v == 0) continue;
      final r = kameaCell(v, max, method), p = g.pos[r.cell]!;
      steps.add(KameaStep(ch, v, r.cell, r.reduced, p.x, p.y));
    }
    out.add(steps);
  }
  return out;
}

class KameaLook {
  final double line, mark, lane, endR;
  const KameaLook(this.line, this.mark, this.lane, this.endR);
}

/// Medidas: finas sobre la tabla (construccion); en lamina, tinta gruesa y
/// circulos marcados, como los caracteres grabados de Agrippa.
KameaLook kameaLook(bool grid) => grid ? const KameaLook(3.2, 2.4, 14, 9) : const KameaLook(10, 7, 22, 16);

/// En lamina el caracter llena el cuadro, como en el libro: misma forma,
/// escalada y centrada (la tabla sigue siendo la referencia exacta). Varias
/// palabras: una columna por palabra, de derecha a izquierda como se lee el
/// hebreo (lamina de la Luna: Schedbarschemoth a la derecha).
List<List<KameaStep>> kameaFit(List<List<KameaStep>> words) {
  final n = words.where((w) => w.isNotEmpty).length, cols = n == 0 ? 1 : n, colW = 470 / cols;
  var col = 0;
  return [
    for (final ws in words)
      if (ws.isEmpty)
        ws
      else
        () {
          final xs = ws.map((q) => q.x), ys = ws.map((q) => q.y);
          final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max), y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
          final w = x1 - x0, h = y1 - y0;
          final k = [w != 0 ? (colW - (cols > 1 ? 40 : 0)) / w : double.infinity, h != 0 ? 430 / h : double.infinity, 3.0].reduce(math.min);
          final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, ox = kC + 235 - colW * (col++ + .5);
          return [for (final q in ws) q.at(ox + (q.x - cx) * k, kC + 8 + (q.y - cy) * k)];
        }(),
  ];
}

/// Dos segmentos casi colineales que se solapan: uno esconderia al otro.
bool kameaOverlap(({double x, double y}) c, ({double x, double y}) d, ({double x, double y}) a, ({double x, double y}) b) {
  final dx = d.x - c.x, dy = d.y - c.y, l = hypot(dx, dy);
  if (l < 1) return false;
  final ux = dx / l, uy = dy / l;
  double off(({double x, double y}) p) => ((p.x - c.x) * uy - (p.y - c.y) * ux).abs();
  if (off(a) > 4 || off(b) > 4) return false;
  double t(({double x, double y}) p) => (p.x - c.x) * ux + (p.y - c.y) * uy;
  return math.min(math.max(t(a), t(b)), l) - math.max(math.min(t(a), t(b)), 0) > 10;
}

/// Una marca del trazo: linea, circulo inicial, remate o lazo de repeticion.
class KameaShape {
  final String mark, d;
  const KameaShape(this.mark, this.d);
}

class _Vert {
  final KameaStep s;
  int repeat = 1;
  _Vert(this.s);
  double get x => s.x;
  double get y => s.y;
  int get cell => s.cell;
}

class _Seg {
  final _Vert a, b;
  final double ux, uy;
  final ({double x, double y}) A, B;
  const _Seg(this.a, this.b, this.ux, this.uy, this.A, this.B);
}

String _circle(double x, double y, double r) =>
    'M ${f2(x + r)} ${f2(y)} A ${jsNum(r)} ${jsNum(r)} 0 1 0 ${f2(x - r)} ${f2(y)} A ${jsNum(r)} ${jsNum(r)} 0 1 0 ${f2(x + r)} ${f2(y)} Z';

/// Trazo al estilo de los caracteres de Agrippa: circulo en ambos extremos; si
/// el trazo vuelve por una linea ya dibujada, va en paralelo y el giro se
/// redondea en horquilla (Inteligencias de Saturno y Jupiter).
List<KameaShape> kameaShapes(List<KameaStep> steps, KameaEnds ends, KameaLook look) {
  // letras seguidas en la misma casilla: un solo vertice con repeticion
  final verts = <_Vert>[];
  for (final s in steps) {
    if (verts.isNotEmpty && verts.last.cell == s.cell) {
      verts.last.repeat++;
      continue;
    }
    verts.add(_Vert(s));
  }
  if (verts.isEmpty) return const [];
  if (verts.length == 1) return [KameaShape('start', _circle(verts[0].x, verts[0].y, look.endR))];
  // cada segmento va en su carril: tantos carriles como veces se repasa la misma linea
  final segs = <_Seg>[];
  for (var i = 0; i < verts.length - 1; i++) {
    final a = verts[i], b = verts[i + 1];
    final lane = segs.where((s) => kameaOverlap((x: s.a.x, y: s.a.y), (x: s.b.x, y: s.b.y), (x: a.x, y: a.y), (x: b.x, y: b.y))).length;
    final dx = b.x - a.x, dy = b.y - a.y, l = hypot(dx, dy) == 0 ? 1.0 : hypot(dx, dy), ux = dx / l, uy = dy / l;
    // carril a la izquierda del sentido de avance
    final ox = -uy * lane * look.lane, oy = ux * lane * look.lane;
    segs.add(_Seg(a, b, ux, uy, (x: a.x + ox, y: a.y + oy), (x: b.x + ox, y: b.y + oy)));
  }
  String pt(({double x, double y}) p) => '${f2(p.x)} ${f2(p.y)}';
  final first = segs.first, last = segs.last;
  // la linea sale del borde del circulo inicial
  final start = (x: first.A.x + first.ux * look.endR, y: first.A.y + first.uy * look.endR);
  final d = StringBuffer('M ${pt(start)}');
  for (var i = 0; i < segs.length; i++) {
    final s = segs[i];
    if (i == segs.length - 1) {
      final e = ends == KameaEnds.agrippa ? (x: s.B.x - s.ux * look.endR, y: s.B.y - s.uy * look.endR) : s.B;
      d.write(' L ${pt(e)}');
      continue;
    }
    final next = segs[i + 1];
    final reverse = s.ux * next.ux + s.uy * next.uy < -0.97;
    if (reverse) {
      // horquilla: se frena antes del vertice y gira en curva al carril de vuelta
      final k = look.lane * .9;
      final p = (x: s.B.x - s.ux * k, y: s.B.y - s.uy * k);
      final q = (x: next.A.x + next.ux * k, y: next.A.y + next.uy * k);
      d.write(' L ${pt(p)} C ${pt((x: p.x + s.ux * k * 1.4, y: p.y + s.uy * k * 1.4))} ${pt((x: q.x - next.ux * k * 1.4, y: q.y - next.uy * k * 1.4))} ${pt(q)}');
    } else {
      d.write(' L ${pt(s.B)}');
    }
  }
  final shapes = <KameaShape>[
    KameaShape('line', d.toString()),
    KameaShape('start', _circle(first.A.x, first.A.y, look.endR)),
  ];
  if (ends == KameaEnds.agrippa) {
    shapes.add(KameaShape('end', _circle(last.B.x, last.B.y, look.endR)));
  } else {
    final n = (x: -last.uy * 11, y: last.ux * 11);
    shapes.add(KameaShape('end', 'M ${pt((x: last.B.x + n.x, y: last.B.y + n.y))} L ${pt((x: last.B.x - n.x, y: last.B.y - n.y))}'));
  }
  // letras repetidas en la misma casilla: pequeno lazo sobre el vertice;
  // tambien en los extremos: el gancho inicial de Sorath son dos letras en la casilla 6
  for (final v in verts.where((v) => v.repeat > 1)) {
    shapes.add(KameaShape('repeat', _circle(v.x, v.y - 16, 5)));
  }
  return shapes;
}

/// Rotulo de lamina, como en Agrippa («Of the Spirit of Saturn»).
({String title, String sub})? kameaCaption(KameaDef k, String hebrew, String name) {
  if (hebrew.isEmpty) return null;
  final preset = k.names.where((n) => n.hebrew == hebrew).firstOrNull;
  final title = preset?.latin ?? (name.trim().isNotEmpty ? name.trim() : hebrew);
  return (title: title, sub: preset != null ? '${preset.role} de ${k.name}' : 'Sobre la tabla de ${k.name}');
}

/// Documento de la familia Kamea: planeta, nombre en hebreo y decisiones de
/// trazo. Lo demas (palabras, SVG) se deriva y es determinista.
class KameaDoc {
  String planet, hebrew, name;
  KameaReduce reduce;
  KameaEnds ends;
  bool grid, transparent;
  SigilStyle style;

  KameaDoc({
    this.planet = 'saturn',
    this.hebrew = '',
    this.name = '',
    this.reduce = KameaReduce.agrippa,
    this.ends = KameaEnds.agrippa,
    this.grid = false,
    this.transparent = false,
    this.style = const SigilStyle(),
  });

  KameaDef get def => kameaById(planet);
  SigilTheme get theme => themeFor(style);
  List<List<KameaStep>> get words => kameaTrace(hebrew, def, reduce);

  /// Fija el hebreo: lo que ya es hebreo se limpia; lo latino se transcribe.
  void setHebrew(String h) => hebrew = cleanHebrew(h);

  void setName(String n, {TranslitMethod translit = TranslitMethod.consonantal}) {
    name = n.trim();
    hebrew = hasHebrew(name) ? cleanHebrew(name) : transliterate(name, translit).hebrew;
  }

  /// Suma del nombre contando las finales de 500 a 900.
  int get sum => hebrew.split('').fold(0, (a, ch) => a + kameaValue(ch));
  int get total => def.n * def.n * (def.n * def.n + 1) ~/ 2;
  int get lineSum => def.n * (def.n * def.n + 1) ~/ 2;

  /// «igual al total de la tabla» o «igual a una linea»: curiosidad aritmetica.
  String get echo => sum == total ? 'igual al total de la tabla de ${def.name} ($total)' : sum == lineSum ? 'igual a una línea de la tabla ($lineSum)' : '';

  String buildSVG() {
    final th = theme, g = kameaGeom(def), out = StringBuffer();
    out.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">');
    if (!transparent) out.write(sceneSVG(bgScene(style, th)));
    final ws = words;
    final used = {for (final w in ws) for (final s in w) s.cell};
    if (grid) {
      out.write('<g data-layer="kamea-grid" stroke="${th.faint}" stroke-width="1.2">');
      for (var v = 1; v <= g.n * g.n; v++) {
        final p = g.pos[v]!;
        out.write('<rect x="${f2(p.x - g.cell / 2)}" y="${f2(p.y - g.cell / 2)}" width="${f2(g.cell)}" height="${f2(g.cell)}" fill="${used.contains(v) ? th.faint : 'none'}"/>');
        out.write('<text x="${f2(p.x)}" y="${f2(p.y)}" stroke="none" fill="${th.frame}" text-anchor="middle" dominant-baseline="middle" font-family="Georgia, serif" font-size="${jsNum(jsRound(g.cell * .32))}">$v</text>');
      }
      out.write('</g>');
    }
    final wd = kameaLook(grid), shown = grid ? ws : kameaFit(ws);
    out.write('<g data-layer="kamea" fill="none" stroke="${grid ? th.accent : th.ink}" stroke-linecap="round" stroke-linejoin="round">');
    for (var i = 0; i < shown.length; i++) {
      out.write('<g data-word="${i + 1}">');
      for (final s in kameaShapes(shown[i], ends, wd)) {
        out.write('<path data-mark="${s.mark}" d="${s.d}" stroke-width="${jsNum(s.mark == 'line' ? wd.line : wd.mark)}"/>');
      }
      out.write('</g>');
    }
    out.write('</g>');
    final cap = kameaCaption(def, hebrew, name);
    if (cap != null && !grid) {
      out.write('<g data-layer="caption" fill="${th.ink}" text-anchor="middle" font-family="Georgia, serif"><text x="${jsNum(kC)}" y="72" font-size="26" font-style="italic">${esc(cap.title)}</text>'
          '<text x="${jsNum(kC)}" y="${jsNum(kSize - 44)}" font-size="17" fill="${th.frame}">${esc(cap.sub)}</text></g>');
    }
    out.write('</svg>');
    return out.toString();
  }

  /// La misma obra para el lienzo: soporte y grupos de dibujo. Los caminos son
  /// los que escribe [buildSVG]; la cuadricula se pinta con la opacidad de la
  /// tinta (el SVG usa rgba) y los numeros como texto.
  ({List<SceneGroup> bg, List<SceneGroup> fg}) scene({bool? transparent}) {
    final th = theme, g = kameaGeom(def), ws = words, fg = <SceneGroup>[];
    final used = {for (final w in ws) for (final s in w) s.cell};
    if (grid) {
      String rect(double x, double y, double w) => 'M ${f2(x)} ${f2(y)} H ${f2(x + w)} V ${f2(y + w)} H ${f2(x)} Z';
      final cells = [for (var v = 1; v <= g.n * g.n; v++) (v, g.pos[v]!)];
      fg.add(SceneGroup(layer: 'kamea-grid-fill', color: th.ink, op: .16, items: [
        for (final (v, p) in cells)
          if (used.contains(v)) PathItem(rect(p.x - g.cell / 2, p.y - g.cell / 2, g.cell), fill: true),
      ]));
      fg.add(SceneGroup(layer: 'kamea-grid', color: th.ink, w: 1.2, op: .16, items: [
        for (final (_, p) in cells) PathItem(rect(p.x - g.cell / 2, p.y - g.cell / 2, g.cell)),
      ]));
      fg.add(SceneGroup(layer: 'kamea-numbers', color: th.ink, prims: [
        for (final (v, p) in cells) TextPrim(p.x, p.y, 0, jsRound(g.cell * .32), '$v', 'Georgia, serif', .55),
      ]));
    }
    final wd = kameaLook(grid), shown = grid ? ws : kameaFit(ws), ink = grid ? th.accent : th.ink;
    for (final mark in ['line', 'start', 'end', 'repeat']) {
      final items = [
        for (final w in shown)
          for (final sh in kameaShapes(w, ends, wd))
            if (sh.mark == mark) PathItem(sh.d),
      ];
      if (items.isNotEmpty) fg.add(SceneGroup(layer: 'kamea-$mark', color: ink, w: mark == 'line' ? wd.line : wd.mark, cap: 'round', sigil: true, items: items));
    }
    final cap = kameaCaption(def, hebrew, name);
    if (cap != null && !grid) {
      fg.add(SceneGroup(layer: 'caption', color: th.ink, prims: [
        TextPrim(kC, 72, 0, 26, cap.title, 'italic Georgia, serif', 1),
        TextPrim(kC, kSize - 44, 0, 17, cap.sub, 'Georgia, serif', .55),
      ]));
    }
    return (bg: (transparent ?? this.transparent) ? const [] : bgScene(style, th), fg: fg);
  }

  // ── Guardado ────────────────────────────────────────────────────
  // Se guarda lo que decide el usuario; el trazo y el SVG se regeneran.
  static const kVersion = 1;

  Map<String, Object?> toJson() => {
        'v': kVersion,
        'family': 'kamea',
        'planet': planet,
        'hebrew': hebrew,
        'name': name,
        'reduce': reduce.name,
        'ends': ends.name,
        'grid': grid,
        'transparent': transparent,
        'style': style.toJson(),
      };

  factory KameaDoc.fromJson(Map<String, dynamic> j) {
    final v = j['v'] as int? ?? 0;
    if (v > kVersion) throw FormatException('Kamea guardada con una version mas nueva ($v) que esta app ($kVersion).');
    final planet = j['planet'] as String? ?? 'saturn';
    if (!kKameas.any((k) => k.id == planet)) throw FormatException('Planeta desconocido: $planet');
    return KameaDoc(
      planet: planet,
      hebrew: cleanHebrew(j['hebrew'] as String? ?? ''),
      name: j['name'] as String? ?? '',
      reduce: KameaReduce.values.byName(j['reduce'] as String? ?? 'agrippa'),
      ends: KameaEnds.values.byName(j['ends'] as String? ?? 'agrippa'),
      grid: j['grid'] as bool? ?? false,
      transparent: j['transparent'] as bool? ?? false,
      style: j['style'] == null ? const SigilStyle() : SigilStyle.fromJson(j['style'] as Map<String, dynamic>),
    );
  }
}
