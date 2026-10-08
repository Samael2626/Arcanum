import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../../../shared/widgets/arcane_currency_emblem.dart';
import '../application/sendero_controller.dart';
import '../application/sendero_guide_controller.dart';
import '../domain/sendero_catalog.dart';

class SenderoScreen extends ConsumerStatefulWidget {
  const SenderoScreen({super.key});

  @override
  ConsumerState<SenderoScreen> createState() => _SenderoScreenState();
}

class _SenderoScreenState extends ConsumerState<SenderoScreen> {
  bool _checkedFirstVisit = false;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(senderoControllerProvider);
    final progress = result.value ?? const <String, SenderoProgress>{};
    if (!_checkedFirstVisit && result.hasValue) {
      _checkedFirstVisit = true;
      if (progress.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final orientation = senderoJourneys.first;
          ref.read(senderoGuideProvider.notifier).start(orientation);
          context.go('/hoy');
        });
      }
    }
    final available = senderoJourneys.where((journey) => journey.available);
    final completed = available
        .where(
          (journey) =>
              progress['${journey.id}:${journey.version}']?.isCompleted ??
              false,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sendero', style: ArcanumText.heading(24)),
        actions: [
          TextButton(
            key: const ValueKey('sendero_leave'),
            onPressed: () => context.go('/hoy'),
            child: const Text('Salir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const ArcanumHeader(subtitle: 'Una guía que espera tu paso'),
              const SizedBox(height: 24),
              ArcanumCard(
                key: const ValueKey('sendero_summary_card'),
                frame: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('A TU LADO'),
                    const SizedBox(height: 12),
                    Text(
                      completed == 0
                          ? 'Aprende mientras recorres ARCANUM.'
                          : '$completed de ${available.length} recorridos explorados.',
                      style: ArcanumText.heading(24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sendero ilumina una función a la vez. Tú decides cuándo seguir.',
                      style: ArcanumText.body(
                        16,
                        color: ArcanumColors.ivoryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (final journey in senderoJourneys) ...[
                _JourneyCard(
                  journey: journey,
                  progress: progress['${journey.id}:${journey.version}'],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyCard extends ConsumerWidget {
  const _JourneyCard({required this.journey, this.progress});

  final SenderoJourney journey;
  final SenderoProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = progress?.isCompleted ?? false;
    final started = progress?.status == 'in_progress';
    return ArcanumCard(
      intensity: completed ? 0.7 : 0.38,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: InkWell(
        onTap: journey.available
            ? () {
                ref
                    .read(senderoGuideProvider.notifier)
                    .start(journey, saved: progress);
                final active = ref.read(senderoGuideProvider);
                context.go(
                  active?.current.route ?? journey.steps.first.route ?? '/hoy',
                );
              }
            : null,
        child: Row(
          children: [
            if (journey.id == 'fragmentos')
              const ArcaneCurrencyEmblem(
                currency: ArcaneCurrency.fragment,
                size: 26,
              )
            else
              Icon(
                completed ? Icons.check_circle_outline : journey.icon,
                color: journey.available
                    ? ArcanumColors.gold
                    : ArcanumColors.ivoryMuted,
                size: 26,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(journey.title, style: ArcanumText.heading(22)),
                  const SizedBox(height: 3),
                  Text(
                    journey.subtitle,
                    style: ArcanumText.body(
                      14,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                  if (started) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Continuar el recorrido',
                      style: ArcanumText.body(
                        13,
                        color: ArcanumColors.goldLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              journey.available
                  ? completed
                        ? Icons.replay
                        : Icons.chevron_right
                  : Icons.lock_clock_outlined,
              color: ArcanumColors.ivoryMuted,
            ),
          ],
        ),
      ),
    );
  }
}
