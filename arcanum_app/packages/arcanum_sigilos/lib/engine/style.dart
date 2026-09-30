// Estilo: tinta, soporte, trazo y efectos (puerto de js/estilo.js).
// Procedencia:
//  - Colores planetarios: escala del Rey de la Aurora Dorada, los mismos de la
//    Rosa-Cruz (letra del planeta). [OM]
//  - Relampagueantes: Flying Roll XIV, "A flashing tablet is one made in the
//    complementary colours" (rojo-verde, azul-naranja, amarillo-violeta).
//    Campo en el color del planeta y signo en su complementario. [OM] El indigo
//    de Saturno no esta en esos pares: su ambar es reconstruccion. [RC]
//  - Metales de los planetas: Goetia, p. 48. [HP]
//  - Tintas, soportes y efectos: decisiones del taller. [AR]
import 'dart:math' as math;

import 'js_num.dart';
import 'letter_sigil.dart' show kC, kSize;
import 'scene.dart';

const kPlanetOrder = ['saturn', 'jupiter', 'mars', 'sun', 'venus', 'mercury', 'moon'];
const kPlanetNames = {'saturn': 'Saturno', 'jupiter': 'Júpiter', 'mars': 'Marte', 'sun': 'Sol', 'venus': 'Venus', 'mercury': 'Mercurio', 'moon': 'Luna'};

/// Color del planeta en la escala del Rey (letra hebrea del planeta en la Rosa).
const kPlanetColor = {
  'saturn': ('índigo', '#3c2b8f'), 'jupiter': ('violeta', '#7b31b3'), 'mars': ('escarlata', '#de2a1f'), 'sun': ('naranja', '#f28a1c'),
  'venus': ('verde esmeralda', '#1d9a58'), 'mercury': ('amarillo', '#f2cf1d'), 'moon': ('azul', '#2f63d6'),
};

/// Complementario segun los pares de Flying Roll XIV (Saturno: reconstruccion).
const kFlashColor = {
  'mars': ('verde esmeralda', '#1d9a58'), 'venus': ('escarlata', '#de2a1f'), 'sun': ('azul', '#2f63d6'), 'moon': ('naranja', '#f28a1c'),
  'mercury': ('violeta', '#7b31b3'), 'jupiter': ('amarillo', '#f2cf1d'), 'saturn': ('ámbar', '#f0aa1a'),
};

const kPlanetMetal = {'saturn': 'plomo', 'jupiter': 'estaño', 'mars': 'hierro', 'sun': 'oro', 'venus': 'cobre', 'mercury': 'mercurio', 'moon': 'plata'};
const kMetalTone = {
  'plomo': ('#8d9096', '#5c6066'), 'estaño': ('#c3c8cc', '#8f969c'), 'hierro': ('#9a9da0', '#5e6264'), 'oro': ('#e7c35a', '#a8801f'),
  'cobre': ('#d99365', '#8f4f2a'), 'mercurio': ('#dfe5ea', '#98a4ad'), 'plata': ('#e4e6ea', '#a3a8b0'),
};

/// Regente del dia (domingo = Sol), con DateTime.weekday (lunes = 1).
String dayRuler(DateTime d) => const ['moon', 'mars', 'mercury', 'jupiter', 'venus', 'saturn', 'sun'][d.weekday - 1];

const kInks = [
  ('Tinta de hollín', '#1b1612'), ('Sepia', '#5b3a1e'), ('Lacre', '#7a1020'), ('Oro', '#c99a1a'),
  ('Plata', '#cfd4db'), ('Azul noche', '#1c2a4a'), ('Hueso', '#f4efe4'),
];
const kGrounds = [('Pergamino', '#efe6d2'), ('Papel', '#f7f3ea'), ('Negro', '#0a080d'), ('Burdeos', '#2a0b12'), ('Azul noche', '#0f1626')];

List<int> hexRGB(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final n = int.parse(h, radix: 16);
  return [n >> 16 & 255, n >> 8 & 255, n & 255];
}

double luminance(String hex) {
  final c = hexRGB(hex);
  return (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;
}

String hexA(String hex, double a) => 'rgba(${hexRGB(hex).join(',')},${jsFixedNum(a, 3).replaceFirst(RegExp(r'^0\.'), '.')})';

String shade(String hex, double k) => '#${hexRGB(hex).map((v) => jsRound(v * k).toInt().toRadixString(16).padLeft(2, '0')).join()}';

class SigilStyle {
  final String preset, ink, bg, texture, line, cap;
  final String? metal, metalPlanet;
  final double width;
  final bool relief, glow;
  const SigilStyle({this.preset = 'pergamino', this.ink = '#1b1612', this.bg = '#efe6d2', this.metal, this.metalPlanet, this.texture = 'pergamino',
      this.width = 100, this.line = 'single', this.cap = 'round', this.relief = false, this.glow = false});

  SigilStyle copyWith({String? preset, String? ink, String? bg, String? metal, String? metalPlanet, bool clearMetal = false, String? texture,
          double? width, String? line, String? cap, bool? relief, bool? glow}) =>
      SigilStyle(preset: preset ?? this.preset, ink: ink ?? this.ink, bg: bg ?? this.bg, metal: clearMetal ? null : metal ?? this.metal,
          metalPlanet: clearMetal ? null : metalPlanet ?? this.metalPlanet, texture: texture ?? this.texture, width: width ?? this.width,
          line: line ?? this.line, cap: cap ?? this.cap, relief: relief ?? this.relief, glow: glow ?? this.glow);

  Map<String, Object?> toJson() => {'preset': preset, 'ink': ink, 'bg': bg, 'metal': metal, 'metalPlanet': metalPlanet, 'texture': texture,
        'width': width, 'line': line, 'cap': cap, 'relief': relief, 'glow': glow};
  factory SigilStyle.fromJson(Map<String, dynamic> j) => SigilStyle(
      preset: j['preset'] as String? ?? 'propio', ink: j['ink'] as String, bg: j['bg'] as String, metal: j['metal'] as String?,
      metalPlanet: j['metalPlanet'] as String?, texture: j['texture'] as String? ?? 'none', width: (j['width'] as num? ?? 100).toDouble(),
      line: j['line'] as String? ?? 'single', cap: j['cap'] as String? ?? 'round', relief: j['relief'] as bool? ?? false, glow: j['glow'] as bool? ?? false);
}

const kStylePresetLabels = {
  'pergamino': 'Pergamino', 'papel': 'Papel limpio', 'lacre': 'Lacre', 'oro': 'Oro y negro', 'burdeos': 'Oro y burdeos',
  'plata': 'Plata lunar', 'metal': 'Grabado en metal',
};

SigilStyle flashStyle(String planet) => SigilStyle(preset: 'flash-$planet', ink: kFlashColor[planet]!.$2, bg: kPlanetColor[planet]!.$2, texture: 'none');

/// La tinta es el mismo metal, mas hondo: un grabado se lee por sombra.
SigilStyle metalStyle(String planet) {
  final m = kPlanetMetal[planet]!, tone = kMetalTone[m]!;
  return SigilStyle(preset: 'metal', metal: m, metalPlanet: planet, bg: tone.$1, ink: shade(tone.$2, .42), texture: 'none', relief: true);
}

/// Estilo listo. «metal» usa el regente del dia de [today].
SigilStyle presetStyle(String key, {DateTime? today}) {
  if (key.startsWith('flash-')) return flashStyle(key.substring(6));
  return switch (key) {
    'pergamino' => const SigilStyle(),
    'papel' => const SigilStyle(preset: 'papel', bg: '#f7f3ea', texture: 'none'),
    'lacre' => const SigilStyle(preset: 'lacre', ink: '#7a1020'),
    'oro' => const SigilStyle(preset: 'oro', ink: '#c99a1a', bg: '#0a080d', texture: 'none', glow: true),
    'burdeos' => const SigilStyle(preset: 'burdeos', ink: '#c99a1a', bg: '#2a0b12', texture: 'none'),
    'plata' => const SigilStyle(preset: 'plata', ink: '#cfd4db', bg: '#0f1626', texture: 'none', glow: true),
    'metal' => metalStyle(dayRuler(today ?? DateTime.now())),
    _ => throw ArgumentError('estilo desconocido: $key'),
  };
}

class SigilTheme {
  final String bg, ink, faint, frame, accent, ui;
  const SigilTheme(this.bg, this.ink, this.faint, this.frame, this.accent, this.ui);
}

SigilTheme themeFor(SigilStyle st) {
  final dark = luminance(st.bg) < .45;
  return SigilTheme(st.bg, st.ink, hexA(st.ink, .16), hexA(st.ink, .55),
      // acento de la obra: la tinta, salvo el rojo de construccion sobre papel claro
      st.ink == '#1b1612' && !dark ? '#9b1c2e' : st.ink,
      // marcas de edicion (solo pantalla): siempre contrastan con el fondo
      dark ? '#f3d27a' : '#9b1c2e');
}

// ── Soporte ─────────────────────────────────────────────────────
final _bgCache = <String, List<SceneGroup>>{};
List<SceneGroup> bgScene(SigilStyle st, SigilTheme th) {
  // el soporte solo cambia con el estilo: las fibras no se regeneran por frame
  final key = '${st.bg}|${st.ink}|${st.metal}|${st.texture}';
  return _bgCache.putIfAbsent(key, () => _bgScene(st, th));
}

List<SceneGroup> _bgScene(SigilStyle st, SigilTheme th) {
  const full = 'M 0 0 H 800 V 800 H 0 Z';
  final g = <SceneGroup>[];
  if (st.metal != null) {
    final tone = kMetalTone[st.metal]!;
    g.add(SceneGroup(layer: 'bg', color: tone.$2, items: [
      PathItem(full, grad: Grad.linear('soporteMetal', 0, 0, kSize, kSize, [(0, tone.$1, 1), (.5, tone.$2, 1), (1, tone.$1, 1)])),
    ]));
    // cepillado del metal
    final lines = [for (var y = 5; y < kSize; y += 6) 'M 0 $y H 800'];
    g.add(SceneGroup(layer: 'bg-cepillado', color: '#ffffff', w: 1, items: [PathItem(lines.join(' '), op: .07)]));
    return g;
  }
  g.add(SceneGroup(layer: 'bg', color: th.bg, items: const [PathItem(full, fill: true)]));
  if (st.texture == 'pergamino') {
    // fibras y viñeta con semilla fija: el mismo pergamino siempre
    var seed = 7;
    double rnd() => (seed = seed * 16807 % 2147483647) / 2147483647;
    final fib = <String>[];
    for (var i = 0; i < 110; i++) {
      final x = rnd() * kSize, y = rnd() * kSize, a = rnd() * kPi, l = 12 + rnd() * 46;
      // el orden de las llamadas a rnd() es el del prototipo
      final qx = math.cos(a) * l / 2 + (rnd() - .5) * 8, qy = math.sin(a) * l / 2 + (rnd() - .5) * 8;
      fib.add('M ${f2(x)} ${f2(y)} q ${f2(qx)} ${f2(qy)} ${f2(math.cos(a) * l)} ${f2(math.sin(a) * l)}');
    }
    g.add(SceneGroup(layer: 'bg-fibras', color: th.ink, w: .8, items: [PathItem(fib.join(' '), op: .07)]));
    g.add(SceneGroup(layer: 'bg-vineta', color: th.ink, items: [
      PathItem(full, grad: Grad.radial('soporteVineta', kC, kC, kSize * .72, [(.55, st.ink, 0), (1, st.ink, .2)])),
    ]));
  }
  return g;
}

// ── Efectos: se resuelven en grupos normales antes de emitir ─────
List<SceneGroup> applyFx(List<SceneGroup> groups, SigilStyle st, SigilTheme th) {
  final out = <SceneGroup>[];
  for (final g in groups) {
    var seq = [g];
    if (st.line == 'double' && g.layer == 'core') seq = [g.copyWith(w: g.w! * 1.9), g.copyWith(layer: 'core-hueco', color: th.bg, w: g.w! * .7)];
    if (st.glow && g.sigil) seq = [g.copyWith(layer: '${g.layer}-halo', w: g.w! * 3.4, op: .12), g.copyWith(layer: '${g.layer}-halo2', w: g.w! * 2, op: .2), ...seq];
    if (st.relief) {
      seq = [
        for (final q in seq) q.copyWith(layer: '${q.layer}-sombra', color: '#000000', op: (q.op ?? 1) * .35, dx: 1.6, dy: 1.6),
        for (final q in seq) q.copyWith(layer: '${q.layer}-luz', color: '#ffffff', op: (q.op ?? 1) * .45, dx: -1.1, dy: -1.1),
        ...seq,
      ];
    }
    out.addAll(seq);
  }
  return out;
}
