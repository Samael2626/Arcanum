import 'dart:async';

import 'package:arcanum_app/features/hoy/presentation/widgets/reliquary_fx.dart';

/// Configuracion comun de la suite.
///
/// La portada vive: un ticker sin fin para aurora, orbe y destellos. Con el
/// encendido, `pumpAndSettle` no se asienta nunca en cualquier prueba que pase
/// por ella. Se apaga aqui para todas; los tests del movimiento lo encienden.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ReliquaryClock.ambientMotion = false;
  await testMain();
}
