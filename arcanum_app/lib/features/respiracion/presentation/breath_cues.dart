/// Senales al cambiar de fase: hoy solo vibracion.
///
/// PUNTO DE ENGANCHE DEL SONIDO: el motor de audio (otra rama) entra como
/// otra [BreathCue] en [breathCuesProvider]. La pantalla de practica no sabe
/// cuantas senales hay; las llama todas en cada cambio de fase y al terminar.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/breath_settings.dart';
import '../domain/breath_pattern.dart';

abstract interface class BreathCue {
  /// Empieza una fase (en «Observar», cada toque es una entrada o salida).
  Future<void> phase(BreathKind kind);

  /// La practica ha terminado.
  Future<void> finish();
}

/// Vibracion con `HapticFeedback`, el patron de la mesa de tarot.
///
/// El prototipo da milisegundos (`navigator.vibrate`); `HapticFeedback` solo
/// tiene golpes fijos, asi que cada pulso se traduce a un golpe y los
/// patrones (golpe, pausa, golpe) se respetan con una espera. Si el aparato
/// tiene la respuesta tactil apagada, no vibra.
class HapticBreathCue implements BreathCue {
  const HapticBreathCue();

  /// Un pulso distinto por fase: los del prototipo.
  static const Map<BreathKind, List<int>> patterns = {
    BreathKind.inhale: [40],
    BreathKind.hold: [20, 70, 20],
    BreathKind.exhale: [90],
    BreathKind.empty: [20, 60, 20, 60, 20],
    BreathKind.turn: [15],
  };
  static const List<int> finishPattern = [60, 80, 60];

  @override
  Future<void> phase(BreathKind kind) => play(patterns[kind]!);

  @override
  Future<void> finish() => play(finishPattern);

  static Future<void> play(List<int> p) async {
    for (var i = 0; i < p.length; i += 2) {
      if (i > 0) {
        // la pausa del patron y lo que dura el golpe anterior
        await Future<void>.delayed(Duration(milliseconds: p[i - 1] + p[i - 2]));
      }
      await hit(p[i]);
    }
  }

  static Future<void> hit(int ms) => ms <= 5
      ? HapticFeedback.selectionClick()
      : ms <= 15
      ? HapticFeedback.lightImpact()
      : ms <= 40
      ? HapticFeedback.mediumImpact()
      : HapticFeedback.heavyImpact();
}

/// La vibracion de la app. Los tests la cambian por una que apunta.
final breathHapticCueProvider = Provider<BreathCue>(
  (_) => const HapticBreathCue(),
);

/// Las senales activas segun los ajustes.
final breathCuesProvider = Provider<List<BreathCue>>((ref) {
  final s = ref.watch(breathSettingsProvider);
  return [
    if (s.vibration) ref.watch(breathHapticCueProvider),
    // aqui entra el sonido cuando llegue el motor de audio
  ];
});
