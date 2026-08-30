import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/privacy/ai_consent_service.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';

class AiConsentSettingsCard extends ConsumerStatefulWidget {
  const AiConsentSettingsCard({super.key});

  @override
  ConsumerState<AiConsentSettingsCard> createState() =>
      _AiConsentSettingsCardState();
}

class _AiConsentSettingsCardState extends ConsumerState<AiConsentSettingsCard> {
  String? _loadedUserId;
  Future<AiConsentStatus>? _statusFuture;

  Future<AiConsentStatus> _status(String userId) {
    if (_loadedUserId != userId || _statusFuture == null) {
      _loadedUserId = userId;
      _statusFuture = ref.read(aiConsentServiceProvider).status(userId);
    }
    return _statusFuture!;
  }

  void _setStatus(AiConsentStatus status) {
    setState(() => _statusFuture = Future.value(status));
  }

  Future<void> _review(String userId) async {
    final granted = await ref
        .read(aiConsentServiceProvider)
        .ensureGranted(context, userId: userId, forcePrompt: true);
    if (mounted) {
      _setStatus(granted ? AiConsentStatus.granted : AiConsentStatus.declined);
    }
  }

  Future<void> _revoke(String userId) async {
    await ref.read(aiConsentServiceProvider).revoke(userId);
    if (!mounted) return;
    _setStatus(AiConsentStatus.declined);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Consentimiento de IA revocado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?['id'] as String?;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<AiConsentStatus>(
      future: _status(userId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? AiConsentStatus.unknown;
        final granted = status == AiConsentStatus.granted;
        return ArcanumCard(
          intensity: 0.35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('INTELIGENCIA ARTIFICIAL'),
              const SizedBox(height: 12),
              Text(
                granted
                    ? 'Groq puede procesar tus consultas para generar lecturas.'
                    : 'Groq no procesará consultas hasta que des tu consentimiento.',
                style: ArcanumText.body(16),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: snapshot.connectionState == ConnectionState.waiting
                    ? null
                    : granted
                    ? () => _revoke(userId)
                    : () => _review(userId),
                icon: Icon(
                  granted ? Icons.block_outlined : Icons.fact_check_outlined,
                ),
                label: Text(
                  granted
                      ? 'Revocar consentimiento de IA'
                      : 'Revisar consentimiento de IA',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
