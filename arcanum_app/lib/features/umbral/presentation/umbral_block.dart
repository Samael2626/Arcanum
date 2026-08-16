import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../application/umbral_controller.dart';
import '../domain/umbral_reading.dart';

/// Bloque breve de la Lectura del Umbral en Hoy.
///
/// Muestra el hecho del día y una sola puerta a la lectura completa. No repite
/// la lectura entera: si Hoy la cuenta toda, abrir el Oráculo deja de tener
/// sentido y la pantalla se convierte en un muro.
class UmbralBlock extends ConsumerWidget {
  const UmbralBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(umbralProvider);

    return state.when(
      loading: () => const _UmbralShell(
        child: Text('Situando el cielo del día…'),
      ),
      // Sin lectura ni caché no se inventa nada: se dice que no hay.
      error: (_, _) => const _UmbralShell(
        child: Text(
          'La Lectura del Umbral no está disponible ahora mismo. '
          'No se sustituye por otra: vuelve cuando haya red.',
        ),
      ),
      data: (reading) {
        if (reading == null) return const SizedBox.shrink();
        return _UmbralBlockCard(reading: reading);
      },
    );
  }
}

class _UmbralShell extends StatelessWidget {
  final Widget child;
  const _UmbralShell({required this.child});

  @override
  Widget build(BuildContext context) => ArcanumCard(
    intensity: 0.32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('LECTURA DEL UMBRAL'),
        const SizedBox(height: 12),
        DefaultTextStyle(
          style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          child: child,
        ),
      ],
    ),
  );
}

class _UmbralBlockCard extends StatelessWidget {
  final UmbralReading reading;
  const _UmbralBlockCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final degraded = reading.degradedReason;

    return ArcanumCard(
      intensity: 0.32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('LECTURA DEL UMBRAL'),
          const SizedBox(height: 10),
          Text(
            reading.situation,
            style: ArcanumText.body(13, color: ArcanumColors.goldMuted),
          ),
          const SizedBox(height: 14),
          if (reading.hasReading)
            Text(reading.headline!, style: ArcanumText.body(16))
          else
            Text(
              'Todavía no se puede situar tu día.',
              style: ArcanumText.body(16),
            ),
          if (degraded != null) ...[
            const SizedBox(height: 12),
            Text(
              degraded,
              style: ArcanumText.body(
                13,
                italic: true,
                color: ArcanumColors.ivoryMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Badges(reading: reading),
          if (reading.hasReading) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/oraculo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                minimumSize: const Size(double.infinity, 0),
                side: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.55),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Abrir la lectura',
                style: ArcanumText.body(15, color: ArcanumColors.gold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiquetas de estado. Nunca decorativas: cada una dice algo que cambia cómo
/// hay que leer el texto de arriba.
class _Badges extends StatelessWidget {
  final UmbralReading reading;
  const _Badges({required this.reading});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      reading.precision.label,
      if (!reading.isPersonalized) 'No personalizada',
      if (reading.stale) 'No actualizada',
      if (reading.tension) 'Dos hechos en tensión',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ArcanumColors.gold.withValues(alpha: 0.32),
              ),
            ),
            child: Text(
              chip,
              style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
            ),
          ),
      ],
    );
  }
}
