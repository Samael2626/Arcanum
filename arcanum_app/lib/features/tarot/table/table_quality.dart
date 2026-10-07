/// Medidor de fotogramas de la mesa y calidad adaptativa (especificacion §6).
///
/// La mesa mide con `FrameTiming` (lo que de verdad tarda el motor, como la
/// prueba de rendimiento de la fase 4) en ventanas de 2 s. Con eso:
/// - fuera de release deja una linea en el log por ventana con fps, montaje
///   p90 y dibujo p90 (la tabla de la fase 4), para medir en el GN2200 con
///   `adb logcat -s flutter | findstr "mesa fps"`;
/// - por debajo de 40 fps baja un nivel de calidad: primero quita los brillos
///   caros; despues pone los efectos a medio ritmo y quita las huellas.
///
/// La mesa solo pide fotogramas cuando algo se mueve: quieta no dibuja nada.
/// Por eso los fps se cuentan sobre el tiempo EN MOVIMIENTO (los huecos de
/// mas de [idleGap] entre fotogramas no cuentan), y una ventana con menos de
/// [minFrames] fotogramas no decide nada: una mesa quieta no baja la calidad.
library;

import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Un fotograma medido, en microsegundos (lo que da `FrameTiming`).
class FrameSample {
  const FrameSample({
    required this.vsyncStart,
    required this.build,
    required this.raster,
    required this.total,
  });

  factory FrameSample.of(FrameTiming t) => FrameSample(
    vsyncStart: t.timestampInMicroseconds(FramePhase.vsyncStart),
    build: t.buildDuration.inMicroseconds,
    raster: t.rasterDuration.inMicroseconds,
    total: t.totalSpan.inMicroseconds,
  );

  final int vsyncStart;
  final int build;
  final int raster;
  final int total;
}

/// Resumen de una ventana: lo que se apunta en la tabla de la fase 7.
class FrameWindow {
  const FrameWindow({
    required this.frames,
    required this.activeSeconds,
    required this.buildP90,
    required this.rasterP90,
    required this.slow,
  });

  static const empty = FrameWindow(
    frames: 0,
    activeSeconds: 0,
    buildP90: 0,
    rasterP90: 0,
    slow: 0,
  );

  final int frames;

  /// Tiempo con la mesa en movimiento, sin los ratos quieta.
  final double activeSeconds;
  final double buildP90, rasterP90;

  /// Fotogramas que pasaron de 16,7 ms (60 Hz).
  final int slow;

  double get fps => activeSeconds <= 0 ? 0 : frames / activeSeconds;

  /// Hubo movimiento suficiente para juzgar la ventana.
  bool get meaningful => frames >= FrameMeter.minFrames;
}

double _p90(List<int> us) {
  if (us.isEmpty) return 0;
  final s = [...us]..sort();
  return s[math.min(s.length - 1, (s.length * .9).floor())] / 1000;
}

/// Resume los fotogramas de una ventana.
FrameWindow summarize(List<FrameSample> samples) {
  if (samples.isEmpty) return FrameWindow.empty;
  final s = [...samples]..sort((a, b) => a.vsyncStart.compareTo(b.vsyncStart));
  const gap = FrameMeter.idleGap;
  const period = 1000000 ~/ 60;
  var active = 0;
  for (var i = 1; i < s.length; i++) {
    final d = s[i].vsyncStart - s[i - 1].vsyncStart;
    // un hueco largo es la mesa quieta: cuenta como un fotograma, no como espera
    active += d > gap.inMicroseconds ? period : d;
  }
  // el ultimo fotograma tambien ocupa su periodo
  active += period;
  return FrameWindow(
    frames: s.length,
    activeSeconds: active / 1e6,
    buildP90: _p90([for (final f in s) f.build]),
    rasterP90: _p90([for (final f in s) f.raster]),
    slow: s.where((f) => f.total > period).length,
  );
}

/// Nivel de calidad de la mesa: 0 entera, 1 sin brillos caros, 2 ademas con
/// los efectos a medio ritmo y sin huellas.
class TableQuality extends ValueNotifier<int> {
  TableQuality() : super(0);

  /// Por debajo de esto baja un nivel (especificacion §6).
  static const double lowFps = 40;

  /// «Vuelve a subir tras un rato holgado»: ventanas seguidas a 55 fps o mas.
  static const double easyFps = 55;
  static const int easyWindows = 3;

  /// Recaidas tras las que ya no se intenta subir en esta mesa.
  static const int maxRelapses = 3;

  int _easy = 0;

  /// Caidas despues de haber subido: cada una dobla la espera (6, 12, 24 s).
  /// Decidido por Samuel (07-oct): sin espera creciente, en un movil flojo
  /// los brillos iban y venian, porque quitarlos dejaba la escena holgada y a
  /// los 6 s volvian a tumbarla.
  int _relapses = 0;
  bool _recovered = false;

  int get _needed => easyWindows << _relapses;

  /// Lo que dice una ventana de 2 s.
  void onWindow(FrameWindow w) {
    if (!w.meaningful) return;
    if (w.fps < lowFps) {
      _easy = 0;
      if (_recovered) {
        _relapses++;
        _recovered = false;
      }
      if (value < 2) value = value + 1;
      return;
    }
    if (w.fps >= easyFps && value > 0 && _relapses < maxRelapses) {
      if (++_easy >= _needed) {
        _easy = 0;
        _recovered = true;
        value = value - 1;
      }
    } else {
      _easy = 0;
    }
  }

  /// Sin brillos caros (resplandores con desenfoque).
  bool get glow => value < 1;

  /// Huellas del palo al desvelar.
  bool get imprints => value < 2;

  /// Efectos a medio ritmo: se repintan a 30 por segundo.
  bool get halfRate => value >= 2;
}

/// Pone el nivel de calidad a la vista de las piezas de la mesa.
class TableQualityScope extends InheritedNotifier<TableQuality> {
  const TableQualityScope({
    super.key,
    required TableQuality quality,
    required super.child,
  }) : super(notifier: quality);

  /// Nivel actual (0 si no hay ambito, como en las pruebas de una pieza sola).
  static int levelOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TableQualityScope>()
          ?.notifier
          ?.value ??
      0;
}

/// Un efecto a medio ritmo: el valor de la animacion se queda quieto la mitad
/// de los fotogramas, y su pintor (que compara el valor) no repinta.
double halfRate(double t, Duration length) {
  final steps = math.max(1, length.inMilliseconds ~/ 33);
  return (t * steps).floor() / steps;
}

/// Escucha los fotogramas del motor y resume cada 2 s.
class FrameMeter {
  FrameMeter({required this.quality, this.scene, this.log = !kReleaseMode});

  static const window = Duration(seconds: 2);
  static const idleGap = Duration(milliseconds: 100);
  static const minFrames = 30;

  final TableQuality quality;

  /// Que estaba pasando en la mesa (para el log), o null.
  final String Function()? scene;
  final bool log;

  final List<FrameSample> _samples = [];
  final Map<String, int> _scenes = {};
  int? _windowStart;
  bool _on = false;

  /// La ultima ventana resumida.
  FrameWindow last = FrameWindow.empty;

  void start() {
    if (_on) return;
    _on = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_on) return;
    _on = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _samples.clear();
    _scenes.clear();
    _windowStart = null;
  }

  /// Anota lo que se ve en este fotograma (lo llama la mesa al construir).
  void note() {
    final s = scene?.call();
    if (s != null) _scenes[s] = (_scenes[s] ?? 0) + 1;
  }

  void _onTimings(List<FrameTiming> timings) =>
      add([for (final t in timings) FrameSample.of(t)]);

  /// Entrada de fotogramas (publica para probar sin motor).
  void add(List<FrameSample> samples) {
    for (final f in samples) {
      final start = _windowStart ??= f.vsyncStart;
      if (f.vsyncStart - start >= window.inMicroseconds) _close();
      _windowStart ??= f.vsyncStart;
      _samples.add(f);
    }
  }

  void _close() {
    final w = summarize(_samples);
    last = w;
    if (w.meaningful) {
      quality.onWindow(w);
      if (log) {
        final top = _scenes.entries.isEmpty
            ? 'mesa'
            : _scenes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        debugPrint(
          '[mesa fps] escena=$top fotogramas=${w.frames} '
          'fps=${w.fps.toStringAsFixed(1)} '
          'montaje_p90=${w.buildP90.toStringAsFixed(1)}ms '
          'dibujo_p90=${w.rasterP90.toStringAsFixed(1)}ms '
          'lentos=${w.slow} calidad=${quality.value}',
        );
      }
    }
    _samples.clear();
    _scenes.clear();
    _windowStart = null;
  }
}
