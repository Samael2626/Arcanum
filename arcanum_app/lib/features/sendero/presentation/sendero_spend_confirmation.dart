import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/monetization/saldo.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../application/sendero_guide_controller.dart';

Future<bool> confirmSenderoSpend(
  BuildContext context,
  WidgetRef ref, {
  required String target,
  required String action,
  String? spread,
}) async {
  if (ref.read(senderoGuideProvider)?.current.target != target) return true;

  await ref.read(saldoProvider.notifier).refrescar();
  if (!context.mounted) return false;
  final balance = ref.read(saldoProvider).value;
  final quota = balance?.cupoDe(action);
  final cost = spread == null ? null : balance?.costeDe(spread);
  final bool? usesCredits = spread == null
      ? quota?.siguienteGastaCredito
      : cost == null
      ? null
      : balance?.gastaCredito(action, spread);
  final detail = switch (usesCredits) {
    false => 'Esta acción usa tu cupo diario.',
    true when cost != null =>
      'Esta acción gasta $cost ${cost == 1 ? 'crédito' : 'créditos'} de tu saldo.',
    true => 'Esta acción puede gastar créditos de tu saldo.',
    null => 'No pudimos verificar el cupo. Esta acción puede gastar créditos.',
  };

  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Antes de continuar', style: ArcanumText.heading(25)),
          content: Text(
            '$detail ¿Quieres continuar?',
            style: ArcanumText.body(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aceptar y continuar'),
            ),
          ],
        ),
      ) ??
      false;
}
