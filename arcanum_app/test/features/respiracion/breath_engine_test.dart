// Motor puro con reloj inyectado: fase, ciclo, progreso, nivel, cuenta,
// restante, pausa y fin, sin un solo frame de Flutter.
import 'package:arcanum_app/features/respiracion/domain/breath_engine.dart';
import 'package:arcanum_app/features/respiracion/domain/breath_pattern.dart';
import 'package:arcanum_app/features/respiracion/domain/breath_phase.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  Duration now = Duration.zero;
  void advance(double seconds) =>
      now += Duration(microseconds: (seconds * 1e6).round());
  Duration call() => now;
}

BreathEngine _engine(
  _Clock clock, {
  String id = 'regardie',
  bool retention = false,
  double tempo = 1,
  int cycles = 2,
}) => BreathEngine(
  phases: buildPhases(
    breathPatternById(id),
    retention: retention,
    tempo: tempo,
  ),
  cycles: cycles,
  clock: clock.call,
);

void main() {
  test('antes de empezar esta parado y no corre el tiempo', () {
    final c = _Clock();
    final e = _engine(c);
    expect(e.status, BreathStatus.idle);
    c.advance(5);
    expect(e.elapsed, 0);
  });

  test('total y duracion de ciclo', () {
    final e = _engine(_Clock(), cycles: 3);
    expect(e.cycleSeconds, 8);
    expect(e.totalSeconds, 24);
  });

  test('fase, ciclo y progreso segun el tiempo transcurrido', () {
    final c = _Clock();
    final e = _engine(c)..start();
    var f = e.tick();
    expect(f.index, 0);
    expect(f.phase.kind, BreathKind.inhale);
    expect(f.cycle, 0);
    expect(f.progress, 0);
    expect(f.phaseChanged, isTrue);

    c.advance(2);
    f = e.tick();
    expect(f.index, 0);
    expect(f.progress, closeTo(0.5, 1e-9));
    expect(f.phaseRemaining, closeTo(2, 1e-9));
    expect(f.phaseChanged, isFalse);

    c.advance(3);
    f = e.tick();
    expect(f.phase.kind, BreathKind.exhale);
    expect(f.index, 1);
    expect(f.phaseChanged, isTrue);

    c.advance(4);
    f = e.tick();
    expect(f.cycle, 1);
    expect(f.index, 0);
    expect(f.phaseChanged, isTrue);
    expect(f.left, closeTo(7, 1e-9));
  });

  test('el nivel sube al inhalar, baja al exhalar y es suave', () {
    final c = _Clock();
    final e = _engine(c)..start();
    expect(e.tick().level, 0);
    c.advance(2);
    expect(e.tick().level, closeTo(0.5, 1e-9));
    c.advance(1);
    final mid = e.tick().level;
    expect(mid, greaterThan(0.75));
    expect(mid, lessThan(1));
    c.advance(3);
    expect(e.tick().level, closeTo(0.5, 1e-9));
  });

  test('la cuenta va de 1 a n dentro de cada fase', () {
    final c = _Clock();
    final e = _engine(c, tempo: 1.5)..start();
    expect(e.tick().beat, 1);
    c.advance(1.4);
    expect(e.tick().beat, 1);
    c.advance(0.2);
    expect(e.tick().beat, 2);
    c.advance(4.3);
    expect(e.tick().beat, 4);
  });

  test('el giro de una cuenta se recorre y luego viene la fase siguiente', () {
    final c = _Clock();
    final e = _engine(c, id: 'gd')..start();
    var f = e.tick();
    expect(f.phase.kind, BreathKind.turn);
    expect(f.beat, 1);
    c.advance(1);
    f = e.tick();
    expect(f.phase.kind, BreathKind.inhale);
    expect(f.level, closeTo(0.1, 1e-9));
  });

  test('pausar congela y reanudar sigue donde estaba', () {
    final c = _Clock();
    final e = _engine(c)..start();
    c.advance(3);
    e.pause();
    expect(e.status, BreathStatus.paused);
    c.advance(100);
    var f = e.tick();
    expect(f.elapsed, closeTo(3, 1e-9));
    expect(f.index, 0);
    e.resume();
    expect(e.status, BreathStatus.running);
    c.advance(2);
    f = e.tick();
    expect(f.elapsed, closeTo(5, 1e-9));
    expect(f.index, 1);
  });

  test('pausar dos veces o reanudar sin pausa no hace nada', () {
    final c = _Clock();
    final e = _engine(c)..start();
    c.advance(1);
    e
      ..resume()
      ..pause();
    c.advance(1);
    e.pause();
    c.advance(1);
    e.resume();
    expect(e.elapsed, closeTo(1, 1e-9));
  });

  test('tras reanudar se vuelve a anunciar la fase', () {
    final c = _Clock();
    final e = _engine(c)..start();
    e.tick();
    c.advance(1);
    expect(e.tick().phaseChanged, isFalse);
    e
      ..pause()
      ..resume();
    expect(e.tick().phaseChanged, isTrue);
  });

  test('al llegar al total termina y no pasa de ahi', () {
    final c = _Clock();
    final e = _engine(c, cycles: 1)..start();
    c.advance(7.9);
    expect(e.tick().finished, isFalse);
    c.advance(0.1);
    final f = e.tick();
    expect(f.finished, isTrue);
    expect(f.left, 0);
    expect(e.status, BreathStatus.finished);
    c.advance(50);
    expect(e.tick().elapsed, 8);
    e.pause();
    expect(e.status, BreathStatus.finished);
  });

  test('parar deja de contar', () {
    final c = _Clock();
    final e = _engine(c)..start();
    c.advance(2);
    e.stop();
    c.advance(5);
    expect(e.status, BreathStatus.stopped);
    expect(e.elapsed, closeTo(2, 1e-9));
  });

  test('un motor sin fases es un error', () {
    expect(
      () =>
          BreathEngine(phases: const [], cycles: 1, clock: () => Duration.zero),
      throwsArgumentError,
    );
  });

  group('observar el aliento', () {
    test('empieza entrando, el toque cambia el sentido y cuenta', () {
      final c = _Clock();
      final s = ObserveSession(minutes: 1, clock: c.call)..start();
      var f = s.frame();
      expect(f.inhale, isTrue);
      expect(f.level, 0);
      expect(f.left, 60);
      c.advance(3.5);
      expect(s.frame().level, closeTo(1, 1e-9));
      expect(s.tap(), isTrue);
      f = s.frame();
      expect(f.inhale, isFalse);
      expect(f.level, closeTo(1, 1e-9));
      c.advance(3.5);
      expect(s.frame().level, closeTo(0, 1e-9));
      s.tap();
      expect(s.frame().breaths, 1);
    });

    test('en pausa el toque no cuenta y el tiempo no corre', () {
      final c = _Clock();
      final s = ObserveSession(minutes: 1, clock: c.call)..start();
      c.advance(10);
      s.pause();
      c.advance(30);
      expect(s.tap(), isFalse);
      expect(s.frame().taps, 0);
      expect(s.frame().left, closeTo(50, 1e-9));
      s.resume();
      c.advance(5);
      expect(s.frame().left, closeTo(45, 1e-9));
    });

    test('termina al cumplir los minutos', () {
      final c = _Clock();
      final s = ObserveSession(minutes: 1, clock: c.call)..start();
      c.advance(60);
      final f = s.frame();
      expect(f.finished, isTrue);
      expect(f.left, 0);
      expect(s.tap(), isFalse);
    });
  });
}
