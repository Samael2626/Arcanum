/// Sonido de la mesa (especificacion §7).
///
/// Elegido por Samuel el 07-oct tras tres vueltas de prototipo: la version
/// «para altavoz de movil» (lo grave una octava arriba, sala de 1,6 s), con
/// sacar sin nota, encajar con la nota de su hueco, desvelar segun palo y
/// sentido (Bastos en bronce), barajar que acelera, el acorde de la lectura,
/// lo nuevo que cede ante lo que aun suena y la invertida velada.
///
/// Los ficheros los escribe `tools/build_mesa_sonidos.py`. Aqui solo se decide
/// QUE suena, cuando, a que volumen y a que velocidad; reproducirlo es cosa de
/// [SoundPlayer]. Asi la logica se prueba sin audio.
///
/// A diferencia del prototipo, la nota de una carta no se sortea: sale de la
/// propia carta. Cada carta suena siempre igual y se aprende de oido, y dos
/// lecturas con las mismas cartas cierran con el mismo acorde.
library;

import 'dart:math' as math;

import '../domain/table_state.dart';

/// Un fichero que suena: cuando (desde ahora), a que volumen y a que velocidad
/// (1 = tono original).
class SoundHit {
  const SoundHit(
    this.file, {
    this.delay = Duration.zero,
    this.volume = 1,
    this.speed = 1,
  });

  final String file;
  final Duration delay;
  final double volume;
  final double speed;

  @override
  String toString() =>
      'SoundHit($file, +${delay.inMilliseconds} ms, v=$volume, x$speed)';
}

/// Quien hace sonar los ficheros de `assets/sounds/mesa/`.
abstract interface class SoundPlayer {
  Future<void> prepare(Iterable<String> files);
  void play(SoundHit hit);
  Future<void> dispose();
}

/// No suena nada: el de los tests y el de antes de tener audio.
class SilentPlayer implements SoundPlayer {
  const SilentPlayer();

  @override
  Future<void> prepare(Iterable<String> files) async {}

  @override
  void play(SoundHit hit) {}

  @override
  Future<void> dispose() async {}
}

class TableSound {
  TableSound({
    this.player = const SilentPlayer(),
    this.vary = true,
    math.Random? random,
    Duration Function()? clock,
  }) : _random = random ?? math.Random(),
       _clock = clock ?? _stopwatchClock();

  final SoundPlayer player;

  /// Variar tono (±5 %) y volumen (±3 dB) en cada disparo, para que nada suene
  /// a maquina. Los tests lo apagan para comparar cifras exactas.
  final bool vary;
  final math.Random _random;
  final Duration Function() _clock;

  /// Volumen base: los ficheros llegan a -3 dBFS y la variacion sube hasta
  /// +3 dB; con 0,7 el pico no pasa de 1.
  static const level = .7;

  /// Separacion entre cartas al desvelar varias a la vez.
  static const cascade = Duration(milliseconds: 300);

  /// Lo que dura el cuenco de un Mayor: mientras, lo demas entra mas bajo.
  static const majorRing = Duration(milliseconds: 2200);
  static const duckGain = .55;

  /// Mismo sonido antes de este tiempo: cada repeticion, un 30 % mas bajo,
  /// hasta la mitad. Sin suelo, en el reparto (una carta cada 110 ms) las
  /// notas de los ultimos huecos no se oirian.
  static const repeatWindow = Duration(milliseconds: 250);
  static const repeatGain = .7;
  static const _repeatFloor = 2;

  static const _chordStep = Duration(milliseconds: 100);
  static const _defaultChord = [0, 3, 5, 6, 8];
  static const _bells = 11;

  /// Segunda nota de cada timbre, como en el prototipo.
  static const _gap = {
    'bastos': Duration(milliseconds: 110),
    'copas': Duration(milliseconds: 130),
    'espadas': Duration(milliseconds: 90),
    'oros': Duration(milliseconds: 120),
  };

  static const _suits = {
    'wands': 'bastos', 'bastos': 'bastos', //
    'cups': 'copas', 'copas': 'copas',
    'swords': 'espadas', 'espadas': 'espadas',
    'pentacles': 'oros', 'disks': 'oros', 'oros': 'oros',
  };

  /// Todos los ficheros que puede pedir la mesa (sin extension).
  static final List<String> files = List.unmodifiable([
    for (final s in _gap.keys)
      for (var d = 2; d <= 7; d++) ...['${s}_$d', '${s}_${d}_v'],
    'mayor', 'mayor_v', //
    for (var d = 0; d < _bells; d++) 'campana_$d',
    for (var d = 0; d <= 8; d++) 'acorde_$d',
    'encajar', 'sacar', 'cortar', 'barajar', 'sellar', 'romper',
  ]);

  Duration _busyUntil = Duration.zero;
  final Map<String, ({Duration at, int count})> _last = {};

  Future<void> prepare() => player.prepare(files);

  Future<void> dispose() => player.dispose();

  void shuffle() => _cue('shuffle', [const SoundHit('barajar')]);

  void cut() => _cue('cut', [const SoundHit('cortar')]);

  /// Sacar una carta: solo papel. Diez campanitas en una Cruz Celta cansan.
  /// `after`: cuando sale de verdad (en el reparto, escalonadas).
  void slide({Duration after = Duration.zero}) =>
      _cue('slide', [SoundHit('sacar', delay: after)]);

  /// Madera y la nota de su hueco: la tirada se oye avanzar. `after`: lo que
  /// le queda de vuelo a la carta; suena al aterrizar, no al salir.
  void snap(int slot, {Duration after = Duration.zero}) => _cue('snap', [
    SoundHit('encajar', delay: after),
    SoundHit(
      'campana_${slot.clamp(0, _bells - 1)}',
      delay: after + const Duration(milliseconds: 20),
    ),
  ]);

  void seal() => _cue('seal', [const SoundHit('sellar')]);

  void breakSeal() => _cue('breakSeal', [const SoundHit('romper')]);

  void reveal(Iterable<TableCard> cards) {
    final hits = <SoundHit>[];
    var at = Duration.zero;
    var major = false;
    for (final c in cards) {
      final v = _voice(c);
      major |= v.major;
      hits.addAll([
        for (final h in v.hits) SoundHit(h.file, delay: at + h.delay),
      ]);
      at += cascade;
    }
    _cue('reveal', hits);
    if (major) _busyUntil = _clock() + majorRing;
  }

  /// La tonica y la nota final de cada carta desvelada, sin repetir y de grave
  /// a agudo. Sin cartas, el acorde de siempre.
  void closeCircle(Iterable<TableCard> revealed) {
    final own = {for (final c in revealed) _finalDegree(c)}.toList()..sort();
    final degrees = own.isEmpty
        ? _defaultChord
        : [0, ...own.where((d) => d != 0)];
    _cue('closeCircle', [
      for (var i = 0; i < degrees.length; i++)
        SoundHit('acorde_${degrees[i]}', delay: _chordStep * i),
    ]);
  }

  // ---------- la voz de cada carta ----------

  static bool _isMajor(TableCard c) => c.face.arcana == 'major';

  /// Grado de partida de una menor (2..5): sale de su numero, o del nombre si
  /// no lo trae.
  static int _base(TableCard c) {
    final n =
        c.face.number ?? c.face.slug.codeUnits.fold<int>(0, (a, b) => a + b);
    return 2 + (n - 1) % 4;
  }

  /// La nota con la que termina: la que entra en el acorde.
  static int _finalDegree(TableCard c) {
    if (_isMajor(c)) return c.reversed ? 0 : 5;
    return c.reversed ? _base(c) : _base(c) + 2;
  }

  static ({List<SoundHit> hits, bool major}) _voice(TableCard c) {
    if (_isMajor(c)) {
      return (hits: [SoundHit(c.reversed ? 'mayor_v' : 'mayor')], major: true);
    }
    final suit = _suits[c.face.suit?.toLowerCase()] ?? 'copas';
    final i = _base(c);
    // al derecho sube; invertida baja y velada
    final (a, b) = c.reversed ? (i + 2, i) : (i, i + 2);
    final v = c.reversed ? '_v' : '';
    return (
      hits: [
        SoundHit('${suit}_$a$v'),
        SoundHit('${suit}_$b$v', delay: _gap[suit]!),
      ],
      major: false,
    );
  }

  // ---------- mezcla ----------

  void _cue(String key, List<SoundHit> hits) {
    final now = _clock();
    final prev = _last[key];
    final count = prev != null && now - prev.at < repeatWindow
        ? prev.count + 1
        : 0;
    _last[key] = (at: now, count: count);
    // una sola variacion por momento: las notas de una carta van juntas
    final speed = vary ? .95 + _random.nextDouble() * .1 : 1.0;
    final gain = vary
        ? math.pow(10, (_random.nextDouble() * 6 - 3) / 20).toDouble()
        : 1.0;
    final base =
        level * gain * math.pow(repeatGain, math.min(count, _repeatFloor));
    for (final h in hits) {
      final ducked = now + h.delay < _busyUntil ? duckGain : 1.0;
      player.play(
        SoundHit(
          h.file,
          delay: h.delay,
          volume: math.min(1, base * ducked),
          speed: speed,
        ),
      );
    }
  }

  static Duration Function() _stopwatchClock() {
    final w = Stopwatch()..start();
    return () => w.elapsed;
  }
}
