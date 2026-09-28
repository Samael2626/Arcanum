import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/sendero_controller.dart';
import '../domain/sendero_catalog.dart';

class SenderoScreen extends ConsumerStatefulWidget {
  const SenderoScreen({super.key});

  @override
  ConsumerState<SenderoScreen> createState() => _SenderoScreenState();
}

class _SenderoScreenState extends ConsumerState<SenderoScreen> {
  bool _registeredVisit = false;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(senderoControllerProvider).value ?? const {};
    if (!_registeredVisit && ref.watch(senderoControllerProvider).hasValue) {
      _registeredVisit = true;
      if (!progress.containsKey('orientation:1')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(senderoControllerProvider.notifier)
              .advance(journeyId: 'orientation', version: 1, step: 0);
        });
      }
    }
    final completed = senderoJourneys.where((journey) {
      return progress['${journey.id}:${journey.version}']?.isCompleted ?? false;
    }).length;

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
                frame: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('TU RECORRIDO'),
                    const SizedBox(height: 12),
                    Text(
                      completed == 0
                          ? 'Empieza donde sientas curiosidad.'
                          : '$completed de ${senderoJourneys.length} cámaras recorridas.',
                      style: ArcanumText.heading(24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay orden obligatorio. Puedes salir, volver y repetir sin perder nada.',
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

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.journey, this.progress});

  final SenderoJourney journey;
  final SenderoProgress? progress;

  @override
  Widget build(BuildContext context) {
    final completed = progress?.isCompleted ?? false;
    final started = progress != null && !completed;
    return ArcanumCard(
      intensity: completed ? 0.7 : 0.38,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: InkWell(
        onTap: () => context.push('/sendero/${journey.id}'),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle_outline : journey.icon,
              color: ArcanumColors.gold,
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
                      'Continuar desde el paso ${(progress?.step ?? 0) + 1}',
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
              completed ? Icons.replay : Icons.chevron_right,
              color: ArcanumColors.ivoryMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class SenderoLessonScreen extends ConsumerStatefulWidget {
  const SenderoLessonScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  ConsumerState<SenderoLessonScreen> createState() =>
      _SenderoLessonScreenState();
}

class _SenderoLessonScreenState extends ConsumerState<SenderoLessonScreen> {
  int? _step;
  bool _creditAccepted = false;

  @override
  Widget build(BuildContext context) {
    final journey = senderoJourneyById(widget.journeyId);
    if (journey == null) {
      return const Scaffold(body: Center(child: Text('Guía no encontrada')));
    }
    final saved = ref
        .watch(senderoControllerProvider)
        .value?['${journey.id}:${journey.version}'];
    final index = (_step ?? saved?.step ?? 0).clamp(
      0,
      journey.steps.length - 1,
    );
    final step = journey.steps[index];
    final isLast = index == journey.steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(journey.title, style: ArcanumText.heading(24)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Pausar'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PASO ${index + 1} DE ${journey.steps.length}',
                  style: ArcanumText.label(),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (index + 1) / journey.steps.length,
                  color: ArcanumColors.gold,
                  backgroundColor: ArcanumColors.surfaceHigh,
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: SingleChildScrollView(
                    child: ArcanumCard(
                      frame: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            journey.icon,
                            color: ArcanumColors.gold,
                            size: 34,
                          ),
                          const SizedBox(height: 18),
                          Text(step.title, style: ArcanumText.heading(30)),
                          const SizedBox(height: 12),
                          Text(step.body, style: ArcanumText.body(18)),
                          if (step.creditNotice) ...[
                            const SizedBox(height: 22),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _creditAccepted,
                              activeColor: ArcanumColors.gold,
                              checkColor: ArcanumColors.background,
                              title: Text(
                                'Entiendo: una acción real solo ocurre después de aceptar su coste.',
                                style: ArcanumText.body(15),
                              ),
                              onChanged: (value) => setState(
                                () => _creditAccepted = value ?? false,
                              ),
                            ),
                          ],
                          if (step.route != null) ...[
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: () => context.push(step.route!),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Verlo en la app'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _step = index - 1;
                            _creditAccepted = false;
                          }),
                          child: const Text('Anterior'),
                        ),
                      ),
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GoldButton(
                        label: isLast ? 'Cerrar el círculo' : 'Continuar',
                        onPressed: step.creditNotice && !_creditAccepted
                            ? null
                            : () async {
                                final nextStep = isLast ? index : index + 1;
                                await ref
                                    .read(senderoControllerProvider.notifier)
                                    .advance(
                                      journeyId: journey.id,
                                      version: journey.version,
                                      step: nextStep,
                                      status: isLast
                                          ? 'completed'
                                          : 'in_progress',
                                    );
                                if (!context.mounted) return;
                                if (isLast) {
                                  context.pop();
                                } else {
                                  setState(() {
                                    _step = nextStep;
                                    _creditAccepted = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
