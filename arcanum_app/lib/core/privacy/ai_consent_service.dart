import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/arcanum_api.dart';
import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import 'consent_policy.dart';

enum AiConsentStatus { unknown, granted, declined }

/// La persona no autorizo mandar sus datos al proveedor de IA.
///
/// Es un tipo propio y no un booleano porque quien lo recibe tiene que poder
/// distinguirlo de un fallo de red: no autorizar no es un error que reintentar,
/// y la pantalla no debe ofrecer "volver a intentarlo" ante una negativa.
class ConsentDeclined implements Exception {
  const ConsentDeclined();
  @override
  String toString() => 'ConsentDeclined';
}

class AiConsentService {
  AiConsentService([this._api]);

  final ArcanumApi? _api;
  static const _keyPrefix = 'groq_ai_consent_';

  String _key(String userId) =>
      '$_keyPrefix${aiConsentPolicyVersion}_$userId';

  Future<AiConsentStatus> status(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getBool(_key(userId));
    if (localValue != null) {
      return localValue ? AiConsentStatus.granted : AiConsentStatus.declined;
    }
    try {
      final consents = await _api?.userConsents();
      final matching = consents?.where(
        (consent) =>
            consent['kind'] == 'ia' &&
            consent['policy_version'] == aiConsentPolicyVersion,
      );
      if (matching != null && matching.isNotEmpty) {
        final granted = matching.first['granted'] == true;
        await prefs.setBool(_key(userId), granted);
        return granted ? AiConsentStatus.granted : AiConsentStatus.declined;
      }
    } catch (_) {
      // Sin red: el consentimiento no se presume.
    }
    return switch (localValue) {
      true => AiConsentStatus.granted,
      false => AiConsentStatus.declined,
      null => AiConsentStatus.unknown,
    };
  }

  Future<bool> ensureGranted(
    BuildContext context, {
    required String userId,
    bool forcePrompt = false,
  }) async {
    final current = await status(userId);
    if (!context.mounted) return false;
    if (current == AiConsentStatus.granted && !forcePrompt) return true;
    if (current == AiConsentStatus.declined && !forcePrompt) {
      _showDisabledMessage(context);
      return false;
    }
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: ArcanumColors.surfaceHigh,
          title: Text('Consulta con IA', style: ArcanumText.heading(25)),
          // Nombra a la empresa REAL y su pais: Apple 5.1.2(i) exige divulgar
          // con quien se comparte antes de compartir, y salir de Colombia o del
          // EEE es una transferencia internacional que hay que declarar.
          // Nombrar a Anthropic aqui seria decir que los datos van a donde no
          // van; el error ya se cometio una vez en la investigacion legal.
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para generar tu lectura, $kAiProvider ($kAiProviderCountry) '
                'recibirá tu consulta, un resumen de tu carta natal, las cartas '
                'de la tirada y tu nombre visible. No enviaremos tu correo, tu '
                'identificador ni el contenido de tu grimorio.',
                style: ArcanumText.body(16),
              ),
              const SizedBox(height: 12),
              // Deber de informacion del art. 6 de la Ley 1581 de 2012: hay que
              // decirle que puede negarse, no solo dejarle negarse.
              Text(
                'No estás obligado a autorizarlo. Si dices que no, el Oráculo '
                'queda desactivado y el resto de ARCANUM sigue funcionando.',
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Acepto'),
            ),
          ],
        ),
      ),
    );

    final accepted = granted == true;
    try {
      await _api?.recordConsent(
        kind: 'ia',
        policyVersion: aiConsentPolicyVersion,
        granted: accepted,
      );
    } catch (_) {
      if (accepted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No pudimos guardar tu consentimiento. Inténtalo de nuevo.',
              ),
            ),
          );
        }
        return false;
      }
    }
    await (await SharedPreferences.getInstance()).setBool(
      _key(userId),
      accepted,
    );
    if (!accepted && context.mounted) _showDisabledMessage(context);
    return accepted;
  }

  Future<void> revoke(String userId) async {
    await _api?.recordConsent(
      kind: 'ia',
      policyVersion: aiConsentPolicyVersion,
      granted: false,
    );
    await (await SharedPreferences.getInstance()).setBool(_key(userId), false);
  }

  void _showDisabledMessage(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La IA queda desactivada. Puedes revisar tu decisión en Ajustes.',
        ),
      ),
    );
  }
}

final aiConsentServiceProvider = Provider<AiConsentService>(
  (ref) => AiConsentService(ref.read(arcanumApiProvider)),
);
