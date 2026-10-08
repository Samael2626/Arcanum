// Sello nuevo a partir de una de las tres familias. Los formatos historicos
// sirven de referencia visual; esta composicion es reconstruccion [RC].
import 'dart:math' as math;
import 'dart:ui';

import 'js_num.dart';
import 'kamea.dart';
import 'layers.dart';
import 'letter_sigil.dart' show kC;
import 'rosa.dart';
import 'scene.dart';
import 'sigil_doc.dart';
import 'style.dart';
import 'svg_bounds.dart';

const kPersonalFormats = {
  'goetia':
      'los 72 sellos de la Goetia (ed. 1904): doble anillo con el nombre en letras latinas repartidas por el borde',
  'pentaculo':
      'los pentáculos de la Clave de Salomón: banda con el nombre en hebreo entre dos círculos',
  'agrippa':
      'los caracteres planetarios de Agrippa (1651): la figura sola, con su rótulo',
};
const kPersonalSources = {
  'letters': 'Sigilo de letras',
  'rosa': 'Rosa-Cruz',
  'kamea': 'Kamea',
};
const kPersonalRulers = [
  'sun',
  'moon',
  'mars',
  'mercury',
  'jupiter',
  'venus',
  'saturn',
];

String? _svgGroup(String svg, String layer) {
  final open = svg.indexOf('<g data-layer="$layer"');
  if (open < 0) return null;
  final tags = RegExp(r'<g(?:\s|>)|</g>').allMatches(svg, open);
  var depth = 0;
  for (final tag in tags) {
    depth += tag.group(0) == '</g>' ? -1 : 1;
    if (depth == 0) return svg.substring(open, tag.end);
  }
  throw const FormatException('Grupo SVG sin cierre');
}

Rect _markupBounds(String markup) {
  final cached = _boundsCache[markup];
  if (cached != null) return cached;
  Rect? bounds;
  for (final m in RegExp(r'<path\b[^>]*\bd="([^"]+)"').allMatches(markup)) {
    final b = pathBounds(m.group(1)!);
    bounds = bounds == null ? b : bounds.expandToInclude(b);
  }
  return _boundsCache[markup] = bounds ?? const Rect.fromLTWH(0, 0, 1, 1);
}

final _boundsCache = <String, Rect>{};

class PersonalDoc {
  String source, template, name, planetChoice, view;
  int day;
  bool transparent;
  List<Layer> layers;
  final SigilDoc letters;
  final RosaDoc rosa;
  final KameaDoc kamea;

  PersonalDoc({
    this.source = 'letters',
    this.template = 'goetia',
    this.name = '',
    this.planetChoice = 'auto',
    this.view = 'paper',
    int? day,
    this.transparent = false,
    List<Layer>? layers,
    SigilDoc? letters,
    RosaDoc? rosa,
    KameaDoc? kamea,
  }) : day = day ?? DateTime.now().weekday % 7,
       layers = layers ?? presetLayers('goetia'),
       letters = letters ?? SigilDoc(),
       rosa = rosa ?? RosaDoc(),
       kamea = kamea ?? KameaDoc();

  static List<Layer> presetLayers(String template) => switch (template) {
    'goetia' => [Layer.create('p1', LayerType.ringLatin)..symbol = 'auto'],
    'pentaculo' => [Layer.create('p1', LayerType.ringHebrew)..symbol = 'auto'],
    'agrippa' => [Layer.create('p1', LayerType.caption)],
    _ => [],
  };

  void setTemplate(String value) {
    template = value;
    layers = presetLayers(value);
  }

  String get planet => source == 'kamea'
      ? kamea.planet
      : planetChoice == 'auto'
      ? kPersonalRulers[day]
      : planetChoice;
  String get displayedName => name.trim().isNotEmpty
      ? name.trim()
      : switch (source) {
          'letters' => letters.sigil.intention,
          'rosa' => rosa.name,
          _ => kamea.name,
        };
  bool get ready => switch (source) {
    'letters' => letters.sigil.prims.isNotEmpty,
    'rosa' => rosa.trace.isNotEmpty,
    _ => kamea.words.isNotEmpty,
  };
  String get _ink => view == 'metal' ? '#2b2116' : '#1b1612';
  String get _name => displayedName.isEmpty ? 'SIN NOMBRE' : displayedName;
  String get _formatText => kPersonalFormats.containsKey(template)
      ? 'en formato de ${kPersonalFormats[template]} (capas: ${layers.where((l) => l.visible).map((l) => l.name).join(', ').isEmpty ? 'sin capas' : layers.where((l) => l.visible).map((l) => l.name).join(', ')})'
      : 'con capas elegidas por ti (${layers.where((l) => l.visible).map((l) => l.name).join(', ')})';
  LayerCtx get _ctx => LayerCtx(
    text: _name,
    title: 'Sello de $_name',
    sub:
        '${kameaById(planet).sym}︎ ${kameaById(planet).name} · ${kPlanetMetal[planet]}',
    planet: planet,
  );
  LayerLayout get layout => layoutLayers(layers, _ctx);

  String get sourceMarkup {
    if (!ready) return '';
    final svg = switch (source) {
      'letters' => () {
        final old = letters.transparent;
        letters.transparent = true;
        try { return letters.buildSVG(); } finally { letters.transparent = old; }
      }(),
      'rosa' => () {
        final oldDiagram = rosa.diagram, oldTransparent = rosa.transparent;
        rosa.diagram = false;
        rosa.transparent = true;
        try { return rosa.buildSVG(); } finally { rosa.diagram = oldDiagram; rosa.transparent = oldTransparent; }
      }(),
      _ => () {
        final oldGrid = kamea.grid, oldTransparent = kamea.transparent;
        kamea.grid = false;
        kamea.transparent = true;
        try { return kamea.buildSVG(); } finally { kamea.grid = oldGrid; kamea.transparent = oldTransparent; }
      }(),
    };
    final parts = <String>[];
    for (final layer in switch (source) {
      'letters' => ['core', 'terminals'],
      'rosa' => ['rose'],
      _ => ['kamea'],
    }) {
      final group = _svgGroup(svg, layer);
      if (group != null) {
        parts.add(
          group
              .replaceAll(
                RegExp(r'<linearGradient\b[^>]*>.*?</linearGradient>'),
                '',
              )
              .replaceAllMapped(
                RegExp(r'\b(stroke|fill)="([^"]+)"'),
                (m) => '${m[1]}="${m[2] == 'none' ? 'none' : 'currentColor'}"',
              ),
        );
      }
    }
    return parts.join();
  }

  SigilStyle get style => switch (source) {
    'letters' => letters.style,
    'rosa' => rosa.style,
    _ => kamea.style,
  };
  set style(SigilStyle value) {
    letters.style = value;
    rosa.style = value;
    kamea.style = value;
  }

  Rect get sourceBounds => _markupBounds(sourceMarkup);
  double get sourceScale {
    final b = sourceBounds;
    return math.min(
      2 * layout.contentR / math.sqrt(b.width * b.width + b.height * b.height),
      2.2,
    );
  }

  (double, double) get sourceOffset {
    final b = sourceBounds, s = sourceScale;
    return (kC - b.center.dx * s, kC - b.center.dy * s);
  }

  List<SceneGroup> _kameaFigureScene() {
    final oldGrid = kamea.grid;
    kamea.grid = false;
    try { return kamea.scene(transparent: true).fg; } finally { kamea.grid = oldGrid; }
  }

  String buildSVG() {
    if (!ready) return '';
    final k = kameaById(planet),
        metal = kPlanetMetal[planet]!,
        metalView = view == 'metal',
        lay = layout;
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">',
    );
    out.write('<title>${esc('Sello personal de $_name')}</title>');
    out.write(
      '<desc>${esc('Sello nuevo creado en ARCANUM $_formatText. No es un sello histórico. Sigilo: ${kPersonalSources[source]}. Planeta: ${k.name}; metal: $metal (tabla de metales de la Goetia, p. 48).')}</desc>',
    );
    if (!transparent) {
      out.write(
        '<rect width="800" height="800" fill="${metalView ? '#1a1612' : '#efe6d2'}"/>',
      );
    }
    if (metalView) {
      final tone = kMetalTone[metal]!,
          outer = lay.parts.where((p) => p.r != null).firstOrNull;
      out.write(
        '<defs><radialGradient id="metal" cx="38%" cy="32%" r="80%"><stop offset="0" stop-color="${tone.$1}"/><stop offset="1" stop-color="${tone.$2}"/></radialGradient></defs>',
      );
      out.write(
        outer != null &&
                {
                  LayerType.circle,
                  LayerType.ringLatin,
                  LayerType.ringHebrew,
                }.contains(outer.layer.type)
            ? '<circle cx="${f2(outer.g.center.$1)}" cy="${f2(outer.g.center.$2)}" r="${f2(outer.r! + 18)}" fill="url(#metal)"/>'
            : '<rect x="48" y="48" width="704" height="704" rx="18" fill="url(#metal)"/>',
      );
    }
    for (final p in lay.parts.where((p) => p.layer.type != LayerType.symbol)) {
      final layer =
          {
            LayerType.ringLatin,
            LayerType.ringHebrew,
            LayerType.caption,
          }.contains(p.layer.type)
          ? 'personal-name'
          : p.layer.type.name;
      out.write('<g data-layer="$layer">${primsSVG(p.g.prims, _ink)}</g>');
    }
    final s = sourceScale, offset = sourceOffset;
    out.write(
      '<g data-layer="personal-sigil" color="$_ink" transform="translate(${f2(offset.$1)} ${f2(offset.$2)}) scale(${s.toStringAsFixed(4)})">$sourceMarkup</g>',
    );
    for (final p in lay.parts.where((p) => p.layer.type == LayerType.symbol)) {
      out.write('<g data-layer="symbol">${primsSVG(p.g.prims, _ink)}</g>');
    }
    out.write('</svg>');
    return out.toString();
  }

  ({List<SceneGroup> bg, List<SceneGroup> fg}) scene() {
    if (!ready) return (bg: const [], fg: const []);
    final lay = layout, ink = _ink, offset = sourceOffset, s = sourceScale;
    final fg = <SceneGroup>[];
    if (view == 'metal') {
      final metal = kPlanetMetal[planet]!,
          tone = kMetalTone[metal]!,
          outer = lay.parts.where((p) => p.r != null).firstOrNull;
      final circle =
          outer != null &&
          {
            LayerType.circle,
            LayerType.ringLatin,
            LayerType.ringHebrew,
          }.contains(outer.layer.type);
      final d = circle
          ? 'M ${f2(outer.g.center.$1 + outer.r! + 18)} ${f2(outer.g.center.$2)} A ${f2(outer.r! + 18)} ${f2(outer.r! + 18)} 0 1 0 ${f2(outer.g.center.$1 - outer.r! - 18)} ${f2(outer.g.center.$2)} A ${f2(outer.r! + 18)} ${f2(outer.r! + 18)} 0 1 0 ${f2(outer.g.center.$1 + outer.r! + 18)} ${f2(outer.g.center.$2)} Z'
          : 'M 66 48 L 734 48 Q 752 48 752 66 L 752 734 Q 752 752 734 752 L 66 752 Q 48 752 48 734 L 48 66 Q 48 48 66 48 Z';
      fg.add(
        SceneGroup(
          layer: 'metal',
          color: ink,
          items: [
            PathItem(
              d,
              grad: Grad.radial('metal', 400, 400, 400, [
                (0, tone.$1, 1),
                (1, tone.$2, 1),
              ]),
            ),
          ],
        ),
      );
    }
    for (final p in lay.parts.where((p) => p.layer.type != LayerType.symbol)) {
      fg.add(
        SceneGroup(layer: p.layer.type.name, color: ink, prims: p.g.prims),
      );
    }
    final src = switch (source) {
      'letters' =>
        letters
            .scene(transparent: true)
            .fg
            .where((g) => g.layer == 'core' || g.layer == 'terminals'),
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
      _ =>
        _kameaFigureScene().where(
              (g) =>
                  g.layer.startsWith('kamea-') &&
                  !{
                    'kamea-grid',
                    'kamea-grid-fill',
                    'kamea-numbers',
                  }.contains(g.layer),
            ),
    };
    fg.addAll(
      src.map(
        (g) => g.copyWith(color: ink, dx: offset.$1, dy: offset.$2, scale: s),
      ),
    );
    for (final p in lay.parts.where((p) => p.layer.type == LayerType.symbol)) {
      fg.add(SceneGroup(layer: 'symbol', color: ink, prims: p.g.prims));
    }
    final bg = transparent
        ? <SceneGroup>[]
        : [
            SceneGroup(
              layer: 'personal-bg',
              color: view == 'metal' ? '#1a1612' : '#efe6d2',
              items: const [PathItem('M 0 0 H 800 V 800 H 0 Z', fill: true)],
            ),
          ];
    return (bg: bg, fg: fg);
  }

  static const kVersion = 1;
  Map<String, Object?> toJson() => {
    'v': kVersion,
    'family': 'personal',
    'source': source,
    'template': template,
    'name': name,
    'planet': planetChoice,
    'view': view,
    'day': day,
    'transparent': transparent,
    'layers': [for (final l in layers) l.toJson()],
    'letters': letters.toJson(),
    'rosa': rosa.toJson(),
    'kamea': kamea.toJson(),
  };
  factory PersonalDoc.fromJson(Map<String, dynamic> j) {
    final version = j['v'] as int? ?? 0;
    if (version > kVersion) {
      throw FormatException(
        'Sello guardado con una version mas nueva ($version) que esta app ($kVersion).',
      );
    }
    return PersonalDoc(
      source: j['source'] as String? ?? 'letters',
      template: j['template'] as String? ?? 'goetia',
      name: j['name'] as String? ?? '',
      planetChoice: j['planet'] as String? ?? 'auto',
      view: j['view'] as String? ?? 'paper',
      day: j['day'] as int?,
      transparent: j['transparent'] as bool? ?? false,
      layers: [
        for (final l in j['layers'] as List? ?? const [])
          Layer.fromJson(l as Map<String, dynamic>),
      ],
      letters: SigilDoc.fromJson(j['letters'] as Map<String, dynamic>),
      rosa: RosaDoc.fromJson(j['rosa'] as Map<String, dynamic>),
      kamea: KameaDoc.fromJson(j['kamea'] as Map<String, dynamic>),
    );
  }
}
