/// Vibracion de la mesa (especificacion §7), con `HapticFeedback`.
///
/// La especificacion da milisegundos, los del prototipo (`navigator.vibrate`).
/// `HapticFeedback` no admite duraciones: tiene cuatro golpes fijos que
/// Android elige segun el aparato. Se traduce asi, y los patrones (golpe,
/// pausa, golpe) se respetan con una espera entre golpes:
///
/// | ms del prototipo | golpe |
/// |---|---|
/// | hasta 5 | `selectionClick` |
/// | 6–10 | `lightImpact` |
/// | 11–20 | `mediumImpact` |
///
/// Si el aparato tiene la respuesta tactil apagada, Android no vibra.
library;

import 'package:flutter/services.dart';

/// Los momentos de la mesa que vibran.
enum Buzz {
  /// Barajar (la especificacion lo da para la cascada; vale para los tres).
  shuffle([8]),
  cut([12]),

  /// Una carta encaja en un hueco.
  snap([8]),
  reveal([10]),
  revealMajor([12, 40, 12]),
  seal([14]),
  breakSeal([8, 30, 8]),
  closeCircle([10, 60, 10]),

  /// Cambia la opcion del radial bajo el dedo.
  radialHover([4]),

  /// La lupa del abanico pasa a otra carta: un clic, como una muesca.
  fanTick([3]);

  const Buzz(this.pattern);

  /// Vibrar, parar, vibrar... en milisegundos.
  final List<int> pattern;
}

/// Golpe de `HapticFeedback` que corresponde a una vibracion de `ms`.
HapticKind hapticFor(int ms) => ms <= 5
    ? HapticKind.selection
    : ms <= 10
    ? HapticKind.light
    : HapticKind.medium;

enum HapticKind { selection, light, medium }

/// Quien vibra. Los tests lo sustituyen para ver que se pidio.
class TableHaptics {
  const TableHaptics();

  Future<void> play(Buzz buzz) async {
    final p = buzz.pattern;
    for (var i = 0; i < p.length; i += 2) {
      if (i > 0) {
        // la pausa del patron y lo que dura el golpe anterior
        await Future<void>.delayed(Duration(milliseconds: p[i - 1] + p[i - 2]));
      }
      await _hit(hapticFor(p[i]));
    }
  }

  Future<void> _hit(HapticKind k) => switch (k) {
    HapticKind.selection => HapticFeedback.selectionClick(),
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.medium => HapticFeedback.mediumImpact(),
  };
}
