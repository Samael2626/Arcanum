import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/name_resonance.dart';
import '../domain/threshold_bridge.dart';
import 'reading_identity_controller.dart';

/// La unica puerta por la que Tarot, Cielos y Oraculo pueden ver algo del
/// perfil privado.
///
/// Devuelve null salvo que se cumplan las dos condiciones a la vez: hay un
/// nombre de pila guardado y la persona encendio ESE puente concreto. Un
/// puente apagado no se distingue de un perfil vacio, que es exactamente
/// como debe verse: ausencia, no invitacion.
final nameResonanceProvider = Provider.family<NameResonance?, ThresholdBridge>((
  ref,
  bridge,
) {
  final profile = ref.watch(readingIdentityProvider).value;
  if (profile == null || !profile.allows(bridge)) return null;
  return NameResonance.fromProfile(profile);
});
