import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';

enum AiConsentStatus { unknown, granted, declined }

class AiConsentService {
  static const _keyPrefix = 'groq_ai_consent_';

  String _key(String userId) => '$_keyPrefix$userId';

  Future<AiConsentStatus> status(String userId) async {
    final value = (await SharedPreferences.getInstance()).getBool(_key(userId));
    return switch (value) {
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
          content: Text(
            'Para generar tu lectura, Groq recibirá tu consulta, un resumen de tu carta natal y tu nombre visible. No enviaremos tu correo ni el contenido de tu grimorio.',
            style: ArcanumText.body(16),
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
    await (await SharedPreferences.getInstance()).setBool(
      _key(userId),
      accepted,
    );
    if (!accepted && context.mounted) _showDisabledMessage(context);
    return accepted;
  }

  Future<void> revoke(String userId) async {
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
  (ref) => AiConsentService(),
);
