/// Motor de respiracion PURO: sin Flutter, sin temporizadores propios.
///
/// Quien lo usa le pasa un reloj y le pide un [BreathFrame] cuando quiere
/// pintar. Asi el motor se prueba con un reloj falso y la pantalla decide el
/// ritmo de refresco (un Ticker en la app).
library;

import 'dart:math' as math;

import 'breath_phase.dart';

/// Tiempo monotono. En la app, el del Ticker; en los tests, uno a mano.
typedef BreathClock = Duration Function();

enum BreathStatus { idle, running, paused, finished, stopped }

double _seconds(Duration d) => d.inMicroseconds / 1e6;

/// Lo que hay que pintar en un instante.
class BreathFrame {
  const BreathFrame({
    required this.phase,
    required this.index,
    required this.cycle,
    required this.progress,
    required this.level,
    required this.beat,
    required this.phaseRemaining,
    required this.elapsed,
    required this.left,
    required this.finished,
    required this.phaseChanged,
  });

  final BreathPhase phase;

  /// Indice de la fase dentro del ciclo.
  final int index;

  /// Ciclo en curso, desde 0.
  final int cycle;

  /// 0..1 dentro de la fase.
  final double progress;

  /// Llenado 0..1, continuo entre fases.
  final double level;

  /// Cuenta en curso, de 1 a `phase.count`.
  final int beat;
  final double phaseRemaining;
  final double elapsed;

  /// Segundos que faltan para terminar.
  final double left;
  final bool finished;

  /// Primera vez que se ve esta fase (o se reanudo): momento de avisar.
  final bool phaseChanged;
}

class BreathEngine {
  BreathEngine({
    required List<BreathPhase> phases,
    required this.cycles,
    required this.clock,
  }) : phases = List.unmodifiable(phases) {
    if (phases.isEmpty) {
      throw ArgumentError.value(phases, 'phases', 'sin fases no hay ritmo');
    }
    cycleSeconds = phases.fold(0.0, (a, p) => a + p.seconds);
    totalSeconds = cycleSeconds * cycles;
  }

  final List<BreathPhase> phases;
  final int cycles;
  final BreathClock clock;
  late final double cycleSeconds;
  late final double totalSeconds;

  BreathStatus _status = BreathStatus.idle;
  Duration _start = Duration.zero;
  Duration _pausedAt = Duration.zero;
  Duration _pausedTotal = Duration.zero;
  Duration? _stoppedAt;
  String? _lastKey;

  BreathStatus get status => _status;

  void start() {
    _start = clock();
    _pausedTotal = Duration.zero;
    _stoppedAt = null;
    _lastKey = null;
    _status = BreathStatus.running;
  }

  void pause() {
    if (_status != BreathStatus.running) return;
    _pausedAt = clock();
    _status = BreathStatus.paused;
  }

  void resume() {
    if (_status != BreathStatus.paused) return;
    _pausedTotal += clock() - _pausedAt;
    _status = BreathStatus.running;
    // al volver se repite el aviso de la fase en curso
    _lastKey = null;
  }

  void stop() {
    if (_status == BreathStatus.idle) return;
    _stoppedAt ??= _status == BreathStatus.paused ? _pausedAt : clock();
    _status = BreathStatus.stopped;
  }

  /// Segundos de practica, sin contar las pausas. Nunca pasa del total.
  double get elapsed {
    final now = switch (_status) {
      BreathStatus.idle => _start,
      BreathStatus.paused => _pausedAt,
      BreathStatus.stopped => _stoppedAt ?? _start,
      _ => clock(),
    };
    final e = _seconds(now - _start - _pausedTotal);
    return e.clamp(0.0, totalSeconds);
  }

  /// Estado de ahora. Si se ha cumplido el total, el motor pasa a terminado.
  BreathFrame tick() {
    final f = frameAt(elapsed);
    if (f.finished && _status == BreathStatus.running) {
      _status = BreathStatus.finished;
    }
    final key = '${f.cycle}:${f.index}';
    final changed = key != _lastKey;
    _lastKey = key;
    return f._withChanged(changed);
  }

  /// Calculo sin estado: que toca en el segundo [e] de la practica.
  BreathFrame frameAt(double e) {
    final finished = e >= totalSeconds;
    final t = finished ? totalSeconds : math.max(0.0, e);
    var cycle = (t / cycleSeconds).floor();
    var r = t - cycle * cycleSeconds;
    if (cycle >= cycles) {
      // justo en el final: se queda en el ultimo instante del ultimo ciclo
      cycle = cycles - 1;
      r = cycleSeconds;
    }
    var i = 0;
    while (i < phases.length - 1 && r >= phases[i].seconds) {
      r -= phases[i].seconds;
      i++;
    }
    final p = phases[i];
    final progress = math.min(1.0, r / p.seconds);
    final beatLen = p.seconds / p.count;
    return BreathFrame(
      phase: p,
      index: i,
      cycle: cycle,
      progress: progress,
      level: p.l0 + (p.l1 - p.l0) * easeInOut(progress),
      beat: math.min(p.count, (r / beatLen + 1e-9).floor() + 1),
      phaseRemaining: math.max(0.0, p.seconds - r),
      elapsed: t,
      left: math.max(0.0, totalSeconds - t),
      finished: finished,
      phaseChanged: false,
    );
  }
}

extension on BreathFrame {
  BreathFrame _withChanged(bool changed) => BreathFrame(
    phase: phase,
    index: index,
    cycle: cycle,
    progress: progress,
    level: level,
    beat: beat,
    phaseRemaining: phaseRemaining,
    elapsed: elapsed,
    left: left,
    finished: finished,
    phaseChanged: changed,
  );
}

/// Estado de «Observar el aliento» en un instante.
class ObserveFrame {
  const ObserveFrame({
    required this.inhale,
    required this.level,
    required this.left,
    required this.taps,
    required this.finished,
  });

  final bool inhale;
  final double level;
  final double left;
  final int taps;
  final bool finished;

  /// Cada entrada y salida marcadas son una respiracion.
  int get breaths => taps ~/ 2;
}

/// «Observar el aliento»: sin cuenta. El practicante toca cuando el aliento
/// cambia y el nivel va hacia lleno o vacio en [easeSeconds].
class ObserveSession {
  ObserveSession({
    required int minutes,
    required this.clock,
    this.easeSeconds = 3.5,
  }) : totalSeconds = minutes * 60.0;

  final double totalSeconds;
  final double easeSeconds;
  final BreathClock clock;

  BreathStatus _status = BreathStatus.idle;
  Duration _start = Duration.zero;
  Duration _pausedAt = Duration.zero;
  Duration _pausedTotal = Duration.zero;
  bool _inhale = true;
  double _from = 0;
  double _changedAt = 0;
  int _taps = 0;

  BreathStatus get status => _status;

  void start() {
    _start = clock();
    _pausedTotal = Duration.zero;
    _inhale = true;
    _from = 0;
    _changedAt = 0;
    _taps = 0;
    _status = BreathStatus.running;
  }

  void pause() {
    if (_status != BreathStatus.running) return;
    _pausedAt = clock();
    _status = BreathStatus.paused;
  }

  void resume() {
    if (_status != BreathStatus.paused) return;
    _pausedTotal += clock() - _pausedAt;
    _status = BreathStatus.running;
  }

  void stop() => _status = BreathStatus.stopped;

  double get _active {
    final now = _status == BreathStatus.paused ? _pausedAt : clock();
    return math.min(totalSeconds, _seconds(now - _start - _pausedTotal));
  }

  double _levelAt(double t) {
    final k = math.min(1.0, (t - _changedAt) / easeSeconds);
    final target = _inhale ? 1.0 : 0.0;
    return _from + (target - _from) * easeInOut(k);
  }

  /// Marca un cambio de aliento. Devuelve si conto.
  bool tap() {
    if (_status != BreathStatus.running) return false;
    final t = _active;
    if (t >= totalSeconds) return false;
    _from = _levelAt(t);
    _inhale = !_inhale;
    _changedAt = t;
    _taps++;
    return true;
  }

  ObserveFrame frame() {
    final t = _status == BreathStatus.idle ? 0.0 : _active;
    final finished = t >= totalSeconds;
    if (finished && _status == BreathStatus.running) {
      _status = BreathStatus.finished;
    }
    return ObserveFrame(
      inhale: _inhale,
      level: _levelAt(t),
      left: math.max(0.0, totalSeconds - t),
      taps: _taps,
      finished: finished,
    );
  }
}
