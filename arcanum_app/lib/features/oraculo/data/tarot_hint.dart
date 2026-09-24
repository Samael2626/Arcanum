import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Si ya se enseno el gesto de voltear la carta.
///
/// Vive en el DISPOSITIVO y no en la cuenta, igual que `onboarding_completed`:
/// es aprendizaje motriz de quien sostiene el telefono, no un dato de usuario.
/// Por eso la clave NO lleva `userId` y NO entra en la lista que borra
/// `clearOnboardingLocalData()`: quien ya aprendio a voltear una carta no
/// necesita que se lo vuelvan a ensenar por haber cerrado sesion.
class TarotHintController extends Notifier<bool> {
  static const _kSeen = 'tarot_eye_hint_seen';

  @override
  bool build() {
    // Lo guardado llega un frame despues: se arranca por "no visto" y se
    // corrige al restaurar. El riesgo de equivocarse es un pulso de mas, y la
    // primera carta no se voltea hasta que alguien la toca -- mucho despues de
    // ese frame. Bloquear la tirada por leer un bool no compensa.
    _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_kSeen) ?? false;
    } catch (error) {
      // Sin preferencias la carta se voltea igual. Perder la pista solo cuesta
      // un pulso de mas; no puede impedir una lectura.
      debugPrint('ARCANUM tarot: no se pudo leer la pista del ojo ($error).');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeen, state);
    } catch (error) {
      debugPrint(
        'ARCANUM tarot: no se pudo guardar la pista del ojo ($error).',
      );
    }
  }

  /// La pista ya se mostro: no se repite en este dispositivo.
  void markSeen() {
    if (state) return;
    state = true;
    _persist();
  }
}

/// `true` cuando el gesto YA se enseno. La carta pulsa cuando es `false`.
final tarotHintSeenProvider = NotifierProvider<TarotHintController, bool>(
  TarotHintController.new,
);
