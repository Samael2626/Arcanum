/// Patrones de respiracion de la tradicion, como datos.
///
/// Fuentes y su estado (comprobado / no comprobado) en el vault:
/// `40-Esoterismo/Respiracion-En-La-Practica-Magica.md`. Los textos `use` y
/// `source` son los del prototipo aprobado el 07-oct-2026; describen lo que la
/// tradicion buscaba, nunca un efecto prometido.
library;

/// Que hace el aire en una fase.
enum BreathKind {
  inhale,
  hold,
  exhale,
  empty,

  /// Sin retencion, cada pausa se cambia por un giro de una cuenta en el que
  /// el aire no se detiene.
  turn;

  bool get isRetention => this == hold || this == empty;
}

/// Una fase del patron tal como la da la fuente: en cuentas, no en segundos.
class PatternPhase {
  const PatternPhase(this.kind, this.count, {this.side});

  final BreathKind kind;
  final int count;

  /// Fosa nasal, solo en la purificacion alterna.
  final String? side;
}

class BreathPattern {
  const BreathPattern({
    required this.id,
    required this.name,
    required this.use,
    required this.source,
    this.phases = const [],
    this.cycles = 0,
    this.minutes = 0,
    this.free = false,
    this.divulgation = false,
    this.advanced = false,
  });

  final String id;
  final String name;
  final String use;
  final String source;
  final List<PatternPhase> phases;

  /// Ciclos por defecto. Los patrones libres usan [minutes].
  final int cycles;
  final int minutes;

  /// Sin cuenta: el practicante marca el cambio de aliento.
  final bool free;

  /// Divulgacion moderna, no tradicion.
  final bool divulgation;
  final bool advanced;

  bool get hasRetention => phases.any((p) => p.kind.isRetention);

  /// Valor por defecto del contador de la pantalla de ajustes.
  int get defaultAmount => free ? minutes : cycles;

  /// Tope del contador: minutos en los libres, ciclos en los demas.
  int get maxAmount => free ? 20 : 40;

  /// Resumen de cuentas para la lista: «4 · 4 · 4 · 4».
  String get summary =>
      free ? 'ritmo propio' : phases.map((p) => p.count).join(' · ');
}

const _in = BreathKind.inhale;
const _hold = BreathKind.hold;
const _out = BreathKind.exhale;
const _empty = BreathKind.empty;

const List<BreathPattern> breathPatterns = [
  BreathPattern(
    id: 'regardie',
    name: 'Ritmo de cuatro tiempos',
    cycles: 12,
    use: 'Para Regardie, la calma alerta que pide la meditación.',
    source:
        'Regardie, «The Middle Pillar» (1938), cap. IV, pp. 127-128: inhalar '
        'y exhalar contando cuatro, sin retener.',
    phases: [PatternPhase(_in, 4), PatternPhase(_out, 4)],
  ),
  BreathPattern(
    id: 'gd',
    name: 'Respiración cuádruple',
    cycles: 8,
    use:
        'En la Golden Dawn, preludio de la meditación del Neófito, dos o tres '
        'minutos.',
    source:
        '«The Golden Dawn», vol. I (Regardie, 1937), Meditación n.º 1, '
        'pp. 104-105. Empieza con los pulmones vacíos. Origen anterior a '
        '1937: no comprobado.',
    phases: [
      PatternPhase(_empty, 4),
      PatternPhase(_in, 4),
      PatternPhase(_hold, 4),
      PatternPhase(_out, 4),
    ],
  ),
  BreathPattern(
    id: 'rv',
    name: 'Proporción uno a dos',
    cycles: 10,
    use:
        'Crowley la daba para caminar, al paso, antes de añadir ninguna '
        'retención.',
    source:
        'Crowley, «Liber RV vel Spiritus» (The Equinox I(7), 1912), tercera '
        'práctica: 4 pasos dentro, 8 fuera, «al principio sin retención».',
    phases: [PatternPhase(_in, 4), PatternPhase(_out, 8)],
  ),
  BreathPattern(
    id: 'pulse',
    name: 'Ritmo de pulso',
    cycles: 8,
    divulgation: true,
    use: 'Divulgación de 1904: la cuenta se toma del propio pulso.',
    source:
        'Yogi Ramacharaka (W. W. Atkinson), «Science of Breath» (1904), '
        'cap. XIII. Divulgación estadounidense, no tradición yóguica.',
    phases: [
      PatternPhase(_in, 6),
      PatternPhase(_hold, 3),
      PatternPhase(_out, 6),
      PatternPhase(_empty, 3),
    ],
  ),
  BreathPattern(
    id: 'nadi',
    name: 'Purificación alterna',
    cycles: 3,
    advanced: true,
    use:
        'En el hatha yoga, purificación de los canales con fosas alternas. '
        'Avanzada.',
    source:
        '«Gheranda Saṃhitā» V.39-45 (trad. Vasu, 1914-15): 16-64-32 '
        'repeticiones de un mantra, fosas alternas. La «Hatha Yoga Pradīpikā» '
        'II no da proporción.',
    phases: [
      PatternPhase(_in, 4, side: 'izquierda'),
      PatternPhase(_hold, 16),
      PatternPhase(_out, 8, side: 'derecha'),
      PatternPhase(_in, 4, side: 'derecha'),
      PatternPhase(_hold, 16),
      PatternPhase(_out, 8, side: 'izquierda'),
    ],
  ),
  BreathPattern(
    id: 'observe',
    name: 'Observar el aliento',
    free: true,
    minutes: 2,
    use: 'Crowley: notar el aliento sin cambiarlo y anotar lo que ocurre.',
    source:
        'Crowley, «Liber RV vel Spiritus» (1912), primera práctica: decir '
        '«entra», «sale», y registrar.',
  ),
  BreathPattern(
    id: 'bardon',
    name: 'Respiración consciente',
    cycles: 7,
    use: 'Bardon: lento y sin prisa, empezando por siete respiraciones.',
    source:
        'Bardon, «Initiation into Hermetics» (1956), Paso I. El ritmo 5 y 5 '
        'es del motor: Bardon no fija cuentas.',
    phases: [PatternPhase(_in, 5), PatternPhase(_out, 5)],
  ),
];

BreathPattern breathPatternById(String id) =>
    breathPatterns.firstWhere((p) => p.id == id);
