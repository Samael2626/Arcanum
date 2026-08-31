import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/privacy/consent_policy.dart';
import '../../core/theme/arcanum_theme.dart';
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
    setState(() => _busy = true);
    try {
      await ref
          .read(arcanumApiProvider)
          .recordConsent(
            kind: 'datos_sensibles',
            policyVersion: sensitiveDataConsentPolicyVersion,
            granted: false,
          );
      await ref.read(authRepositoryProvider).updateProfile({
        'birth_date': null,
        'birth_time': null,
        'birth_lat': null,
        'birth_lon': null,
        'birth_city': null,
        'birth_timezone': null,
        'preferred_tradition': null,
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _granted = Future.value(false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autorización revocada y datos sensibles borrados.'),
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
                'Autorizaste el uso de tus datos natales y de práctica.',
                style: ArcanumText.body(16),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _busy ? null : _revoke,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  _busy ? 'Revocando…' : 'Revocar y borrar datos sensibles',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
