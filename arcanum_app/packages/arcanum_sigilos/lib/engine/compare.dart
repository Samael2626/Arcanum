// Lamina didactica [AR]: tres motores distintos para el mismo nombre.
import 'dart:math' as math;

import 'js_num.dart';
import 'kamea.dart';
import 'layers.dart';
import 'letter_sigil.dart' show ComposeMode, kC;
import 'personal.dart';
import 'reduction.dart';
import 'rosa.dart';
import 'scene.dart';
import 'sigil_doc.dart';

const _dayRulers = [
  'sun',
  'moon',
  'mars',
  'mercury',
  'jupiter',
  'venus',
  'saturn',
];

class CompareDoc {
  String name, planetChoice;
  int day;
  bool transparent;
  final SigilDoc letters;
  final RosaDoc rosa;
  final KameaDoc kamea;

  CompareDoc({
    this.name = '',
    this.planetChoice = 'auto',
    int? day,
    this.transparent = false,
    SigilDoc? letters,
    RosaDoc? rosa,
    KameaDoc? kamea,
  }) : day = day ?? DateTime.now().weekday % 7,
       letters = letters ?? SigilDoc(),
       rosa = rosa ?? RosaDoc(),
       kamea = kamea ?? KameaDoc();

  String get planet => planetChoice == 'auto' ? _dayRulers[day] : planetChoice;
  bool get ready =>
      letters.sigil.prims.isNotEmpty &&
      rosa.trace.isNotEmpty &&
      kamea.words.isNotEmpty;

  void generate(String value) {
    name = value.trim();
    if (name.isEmpty) return;
    letters.sigil
      ..method = ReductionMethod.unique
      ..mode = ComposeMode.fusion;
    letters.generate(name);
    rosa.setName(name);
    kamea
      ..planet = planet
      ..setName(name);
  }

  PersonalDoc _source(String src) =>
      PersonalDoc(source: src, letters: letters, rosa: rosa, kamea: kamea);

  String buildSVG() {
    if (!ready) return '';
    final ink = '#1b1612', k = kameaById(planet);
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">',
    );
    out.write(
      '<title>${esc('$name en tres sistemas')}</title><desc>${esc('El nombre «$name» trazado con el método de la palabra (letras únicas, fusión), sobre la Rosa-Cruz de la Golden Dawn y sobre la kamea de ${k.name} de Agrippa.')}</desc>',
    );
    out.write(
      '<style>.cmp *{vector-effect:non-scaling-stroke;stroke-width:4px}</style>',
    );
    if (!transparent) {
      out.write('<rect width="800" height="800" fill="#efe6d2"/>');
    }
    final cells = [
      (
        'letters',
        20,
        60,
        'Letras (Spare)',
        letters.sigil.letters.map((l) => l.ch).join(' '),
      ),
      ('rosa', 410, 60, 'Rosa-Cruz', rosa.hebrew),
      (
        'kamea',
        20,
        440,
        'Kamea de ${k.name}',
        kamea.words.map((w) => w.map((s) => s.cell).join('·')).join(' | '),
      ),
    ];
    out.write(
      '<text x="${jsNum(kC)}" y="38" text-anchor="middle" font-family="Georgia, serif" font-style="italic" font-size="26" fill="$ink">${esc(name)}</text>',
    );
    for (final (src, x, y, title, sub) in cells) {
      final doc = _source(src), b = doc.sourceBounds;
      final scale = math.min(math.min(262 / b.width, 262 / b.height), 1.6);
      final cx = x + 185, cy = y + 184;
      out.write('<g data-layer="compare-$src">');
      out.write(
        '<rect x="$x" y="$y" width="370" height="370" rx="6" fill="none" stroke="$ink" stroke-opacity=".18"/>',
      );
      out.write(
        '<g class="cmp" color="$ink" transform="translate(${f2(cx - b.center.dx * scale)} ${f2(cy - b.center.dy * scale)}) scale(${scale.toStringAsFixed(4)})">${doc.sourceMarkup}</g>',
      );
      out.write(
        '<text x="$cx" y="${y + 350}" text-anchor="middle" font-family="Georgia, serif" font-size="17" fill="$ink">${esc(title)}</text>',
      );
      out.write(
        '<text x="$cx" y="${y + 22}" text-anchor="middle" font-family="Georgia, Arial Hebrew, serif" font-size="15" fill="$ink" fill-opacity=".7"${src == 'rosa' ? ' direction="rtl"' : ''}>${esc(sub)}</text>',
      );
      out.write('</g>');
    }
    final notes = [
      'Letras: ${letters.sigil.letters.length} letras únicas del nombre latino.',
      'Hebreo: ${rosa.hebrew} (gematría ${gematria(rosa.hebrew).std}).',
      'Rosa-Cruz: ${rosa.trace.length} pétalos recorridos.',
      'Kamea: ${kamea.words.expand((w) => w).length} casillas de ${k.n}×${k.n}.',
      'Mismo nombre, tres artefactos:',
      'cada sistema cifra otra cosa.',
    ];
    out.write(
      '<g data-layer="compare-notes" font-family="Georgia, serif" font-size="16" fill="$ink">',
    );
    for (final (i, note) in notes.indexed) {
      out.write(
        '<text x="430" y="${490 + i * 34}"${i >= 4 ? ' font-style="italic"' : ''}>${esc(note)}</text>',
      );
    }
    out.write('</g></svg>');
    return out.toString();
  }

  ({List<SceneGroup> bg, List<SceneGroup> fg}) scene({
    bool includeText = true,
  }) {
    if (!ready) return (bg: const [], fg: const []);
    const ink = '#1b1612';
    final fg = <SceneGroup>[];
    if (includeText) {
      fg.add(
        SceneGroup(
          layer: 'compare-title',
          color: ink,
          prims: [TextPrim(400, 28.9, 0, 26, name, 'italic Georgia, serif', 1)],
        ),
      );
    }
    for (final (src, x, y, title, sub) in [
      (
        'letters',
        20,
        60,
        'Letras (Spare)',
        letters.sigil.letters.map((l) => l.ch).join(' '),
      ),
      ('rosa', 410, 60, 'Rosa-Cruz', rosa.hebrew),
      (
        'kamea',
        20,
        440,
        'Kamea de ${kamea.def.name}',
        kamea.words.map((w) => w.map((s) => s.cell).join('·')).join(' | '),
      ),
    ]) {
      final personal = _source(src), b = personal.sourceBounds;
      final sc = math.min(math.min(262 / b.width, 262 / b.height), 1.6);
      final dx = x + 185 - b.center.dx * sc, dy = y + 184 - b.center.dy * sc;
      final rect =
          'M ${x + 6} $y H ${x + 364} Q ${x + 370} $y ${x + 370} ${y + 6} V ${y + 364} Q ${x + 370} ${y + 370} ${x + 364} ${y + 370} H ${x + 6} Q $x ${y + 370} $x ${y + 364} V ${y + 6} Q $x $y ${x + 6} $y Z';
      fg.add(
        SceneGroup(
          layer: 'compare-$src-frame',
          color: ink,
          op: .18,
          w: 1,
          items: [PathItem(rect)],
        ),
      );
      final sourceGroups = switch (src) {
        'letters' =>
          letters
              .scene(transparent: true)
              .fg
              .where((g) => {'core', 'terminals'}.contains(g.layer)),
        'rosa' =>
          rosa
              .scene(transparent: true)
              .fg
              .where(
                (g) =>
                    g.layer.startsWith('rose-') &&
                    !{
                      'rose-petal',
                      'rose-diagram',
                      'rose-text',
                      'rose-glyphs',
                    }.contains(g.layer),
              ),
        _ => _kameaFigureScene(),
      };
      fg.addAll(
        sourceGroups.map(
          (g) => g.copyWith(
            layer: 'compare-$src-${g.layer}',
            color: ink,
            dx: dx,
            dy: dy,
            scale: sc,
            w: g.w == null || g.w == 0 ? g.w : 4 / sc,
          ),
        ),
      );
      if (includeText) {
        fg.add(
          SceneGroup(
            layer: 'compare-$src-label',
            color: ink,
            prims: [
              TextPrim(
                x + 185.0,
                y + 344.05,
                0,
                17,
                title,
                'Georgia, serif',
                1,
              ),
              TextPrim(x + 185.0, y + 16.75, 0, 15, sub, 'Georgia, serif', .7),
            ],
          ),
        );
      }
    }
    if (includeText) {
      final notes = [
        'Letras: ${letters.sigil.letters.length} letras únicas del nombre latino.',
        'Hebreo: ${rosa.hebrew} (gematría ${gematria(rosa.hebrew).std}).',
        'Rosa-Cruz: ${rosa.trace.length} pétalos recorridos.',
        'Kamea: ${kamea.words.expand((w) => w).length} casillas de ${kamea.def.n}×${kamea.def.n}.',
        'Mismo nombre, tres artefactos:',
        'cada sistema cifra otra cosa.',
      ];
      fg.add(
        SceneGroup(
          layer: 'compare-notes',
          color: ink,
          prims: [
            for (final (i, note) in notes.indexed)
              TextPrim(
                430,
                490 + i * 34 - 5.6,
                0,
                16,
                note,
                i >= 4 ? 'italic Georgia, serif' : 'Georgia, serif',
                1,
                alignStart: true,
              ),
          ],
        ),
      );
    }
    final bg = transparent
        ? <SceneGroup>[]
        : <SceneGroup>[
            const SceneGroup(
              layer: 'compare-bg',
              color: '#efe6d2',
              items: [PathItem('M 0 0 H 800 V 800 H 0 Z', fill: true)],
            ),
          ];
    return (bg: bg, fg: fg);
  }

  Iterable<SceneGroup> _kameaFigureScene() {
    final oldGrid = kamea.grid;
    kamea.grid = false;
    try {
      return kamea
          .scene(transparent: true)
          .fg
          .where(
            (g) =>
                g.layer.startsWith('kamea-') &&
                !{
                  'kamea-grid',
                  'kamea-grid-fill',
                  'kamea-numbers',
                }.contains(g.layer),
          )
          .toList();
    } finally {
      kamea.grid = oldGrid;
    }
  }

  static const kVersion = 1;
  Map<String, Object?> toJson() => {
    'v': kVersion,
    'family': 'compare',
    'name': name,
    'planet': planetChoice,
    'day': day,
    'transparent': transparent,
    'letters': letters.toJson(),
    'rosa': rosa.toJson(),
    'kamea': kamea.toJson(),
  };
  factory CompareDoc.fromJson(Map<String, dynamic> j) {
    final version = j['v'] as int? ?? 0;
    if (version > kVersion) {
      throw FormatException(
        'Comparar guardado con una version mas nueva ($version) que esta app ($kVersion).',
      );
    }
    return CompareDoc(
      name: j['name'] as String? ?? '',
      planetChoice: j['planet'] as String? ?? 'auto',
      day: j['day'] as int?,
      transparent: j['transparent'] as bool? ?? false,
      letters: SigilDoc.fromJson(j['letters'] as Map<String, dynamic>),
      rosa: RosaDoc.fromJson(j['rosa'] as Map<String, dynamic>),
      kamea: KameaDoc.fromJson(j['kamea'] as Map<String, dynamic>),
    );
  }
}
