/// Pantalla encendida mientras se respira (Samuel, 08-oct).
///
/// Una practica de varios minutos no puede quedarse a oscuras a medias. Solo
/// mientras corre: en pausa, al terminar o al salir, el apagado vuelve al
/// sistema. Si el aparato no lo permite, la practica sigue igual y el fallo se
/// reporta: no es imprescindible, pero callarlo esconderia un aparato roto.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenAwake {
  Future<void> keep(bool on);
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> keep(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'respiracion',
          context: ErrorDescription('al mantener la pantalla encendida'),
        ),
      );
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);
