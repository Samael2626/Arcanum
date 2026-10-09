import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/privacy/consent_policy.dart';
import '../../core/theme/arcanum_theme.dart';
import '../onboarding/application/onboarding_controller.dart';
import '../onboarding/application/pending_profile_store.dart';
import '../sendero/application/sendero_controller.dart';
import '../../shared/widgets/arcanum_card.dart';

class SensitiveDataConsentSettingsCard extends ConsumerStatefulWidget {
  const SensitiveDataConsentSettingsCard({super.key});

  @override
  ConsumerState<SensitiveDataConsentSettingsCard> createState() =>
      _SensitiveDataConsentSettingsCardState();
}

class _SensitiveDataConsentSettingsCardState
    extends ConsumerState<SensitiveDataConsentSettingsCard> {
  late Future<bool> _granted = _load();
  bool _busy = false;

  Future<bool> _load() async {
    try {
      final consents = await ref.read(arcanumApiProvider).userConsents();
      return consents.any(
        (consent) =>
            consent['kind'] == 'datos_sensibles' &&
            consent['policy_version'] == sensitiveDataConsentPolicyVersion &&
            consent['granted'] == true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revocar autorización'),
        content: const Text(
          'Se borrarán para siempre tu perfil natal, las lecturas, las conversaciones, el Grimorio y los pasajes guardados. Tu cuenta y tus créditos seguirán disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revocar y borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(arcanumApiProvider)
          .recordConsent(
            kind: 'datos_sensibles',
            policyVersion: sensitiveDataConsentPolicyVersion,
            granted: false,
          );
      var localCleared = true;
      try {
        final userId = ref.read(authProvider).user?['id']?.toString();
        if (userId == null) throw StateError('Missing user id');
        final pendingStore = ref.read(pendingProfileStoreProvider);
        if (await pendingStore.readFor(userId) != null) {
          await pendingStore.clear();
        }
        await clearSenderoLocalData(userId: userId);
      } catch (_) {
        localCleared = false;
      }
      ref.invalidate(onboardingProvider);
      ref.invalidate(senderoControllerProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _granted = Future.value(false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localCleared
                ? 'Autorización revocada e historial borrado.'
                : 'Historial borrado en el servidor. No se pudieron limpiar todos los datos de este dispositivo.',
          ),
        ),
      );
      try {
        await ref.read(authProvider.notifier).refreshUser();
      } catch (_) {
        // La revocacion y el borrado ya quedaron persistidos en el backend.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo revocar la autorización. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _granted,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return ArcanumCard(
          intensity: 0.35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('DATOS SENSIBLES'),
              const SizedBox(height: 12),
              Text(
                'Autorizaste el uso de tus datos natales y de práctica. Al revocar, se borrarán tus lecturas, conversaciones, Grimorio y perfil natal. La cuenta y los créditos se conservan.',
                style: ArcanumText.body(16),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _busy ? null : _revoke,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  _busy ? 'Revocando…' : 'Revocar y borrar historial',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
