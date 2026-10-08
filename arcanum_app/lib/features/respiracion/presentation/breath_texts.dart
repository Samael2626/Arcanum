import '../domain/breath_pattern.dart';

/// Textos de fase que ve el usuario, los del prototipo.
const Map<BreathKind, String> phaseLabel = {
  BreathKind.inhale: 'Inhala',
  BreathKind.hold: 'Retén',
  BreathKind.exhale: 'Exhala',
  BreathKind.empty: 'Quédate vacío',
  BreathKind.turn: 'Gira',
};

const Map<BreathKind, String> phaseHint = {
  BreathKind.inhale: '',
  BreathKind.hold: 'lleno, sin apretar',
  BreathKind.exhale: 'despacio',
  BreathKind.empty: 'sin forzar',
  BreathKind.turn: 'sin detener el aire',
};

/// «Inhala por la izquierda».
String phaseText(BreathKind kind, String? side) =>
    phaseLabel[kind]! + (side == null ? '' : ' por la $side');

const retentionWarning =
    'Retener el aire no es para todo el mundo. Si notas mareo, ansiedad u '
    'opresión, suelta y respira a tu ritmo. Si tienes alguna condición '
    'respiratoria o cardiaca, o estás embarazada, practica sin retención.';

String cyclesDoneText(int n) =>
    'Has completado $n ${n == 1 ? 'ciclo' : 'ciclos'}. Vuelve a respirar a tu '
    'ritmo antes de levantarte.';

String observedText(int breaths) =>
    '$breaths ${breaths == 1 ? 'respiración observada' : 'respiraciones observadas'}. '
    'Anota lo que notaste, si quieres.';
