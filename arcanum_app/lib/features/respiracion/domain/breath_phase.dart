import 'breath_pattern.dart';

/// Una fase ya expandida: en segundos y con su nivel de llenado (0..1) al
/// empezar ([l0]) y al terminar ([l1]).
class BreathPhase {
  const BreathPhase({
    required this.kind,
    required this.count,
    required this.seconds,
    required this.l0,
    required this.l1,
    this.side,
    this.from,
  });

  final BreathKind kind;
  final int count;
  final double seconds;
  final double l0;
  final double l1;
  final String? side;

  /// En un giro, la retencion que sustituye.
  final BreathKind? from;

  BreathPhase _withLevels(double a, double b) => BreathPhase(
    kind: kind,
    count: count,
    seconds: seconds,
    l0: a,
    l1: b,
    side: side,
    from: from,
  );
}

/// Expande un patron a fases en segundos.
///
/// Sin [retention], cada retener o vacio se cambia por un giro de una cuenta.
/// Los niveles son continuos: el final de una fase es el principio de la
/// siguiente, tambien al cerrar el ciclo.
List<BreathPhase> buildPhases(
  BreathPattern pattern, {
  required bool retention,
  required double tempo,
}) {
  final raw = <(BreathKind kind, int count, String? side, BreathKind? from)>[
    for (final ph in pattern.phases)
      if (ph.kind.isRetention && !retention)
        (BreathKind.turn, 1, null, ph.kind)
      else
        (ph.kind, ph.count, ph.side, null),
  ];
  if (raw.isEmpty) return const [];

  final first = raw.first;
  // se empieza vacio si lo primero es llenar o quedarse vacio
  var level =
      first.$1 == BreathKind.inhale ||
          first.$1 == BreathKind.empty ||
          first.$4 == BreathKind.empty
      ? 0.0
      : 1.0;

  final out = <BreathPhase>[];
  for (var i = 0; i < raw.length; i++) {
    final (kind, count, side, from) = raw[i];
    final l0 = level;
    switch (kind) {
      case BreathKind.inhale:
        level = 1;
      case BreathKind.exhale:
        level = 0;
      case BreathKind.turn:
        // el giro solo apunta hacia donde va la fase siguiente
        final next = raw[(i + 1) % raw.length].$1;
        final target = next == BreathKind.exhale ? 0.0 : 1.0;
        level = level + (target - level) * 0.1;
      case BreathKind.hold:
      case BreathKind.empty:
        break;
    }
    out.add(
      BreathPhase(
        kind: kind,
        count: count,
        seconds: count * tempo,
        l0: l0,
        l1: level,
        side: side,
        from: from,
      ),
    );
  }
  // cierre del ciclo: el primer nivel casa con el ultimo
  out[0] = out[0]._withLevels(out.last.l1, out[0].l1);
  return List.unmodifiable(out);
}

double cycleSeconds(List<BreathPhase> phases) =>
    phases.fold(0.0, (a, p) => a + p.seconds);

/// Entrada y salida suaves (cuadratica), la del prototipo.
double easeInOut(double x) =>
    x < .5 ? 2 * x * x : 1 - (-2 * x + 2) * (-2 * x + 2) / 2;

/// «45 s», «1 min», «1 min 36 s».
String formatDuration(double seconds) {
  final s = seconds.round();
  final m = s ~/ 60, r = s % 60;
  if (m == 0) return '$r s';
  return r == 0 ? '$m min' : '$m min $r s';
}

/// Cuenta atras «m:ss», redondeando hacia arriba.
String formatClock(double seconds) {
  final s = seconds <= 0 ? 0 : seconds.ceil();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
