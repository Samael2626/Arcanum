import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../application/bridge_resonance.dart';
import '../domain/threshold_bridge.dart';

/// Tarjeta que acompana una tirada o una carta natal cuando el puente de ese
/// modulo esta encendido.
///
/// Con el puente apagado se colapsa a [SizedBox.shrink]: el modulo receptor
/// no tiene que saber nada de consentimiento, solo colocar el widget donde
/// corresponda. Va siempre DESPUES del contenido propio del modulo, nunca
/// antes ni intercalada, para que se lea como acompanamiento y no como clave
/// de lectura.
class ThresholdResonanceCard extends ConsumerWidget {
  final ThresholdBridge bridge;

  const ThresholdResonanceCard({super.key, required this.bridge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resonance = ref.watch(nameResonanceProvider(bridge));
    if (resonance == null) return const SizedBox.shrink();

    final gematria = resonance.gematriaLine;
    final limit = resonance.editorialLimit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: ArcanumCard(
        intensity: 0.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('RESONANCIA DEL NOMBRE'),
            const SizedBox(height: 12),
            Text(resonance.prose, style: ArcanumText.body(16)),
            if (gematria != null) ...[
              const SizedBox(height: 10),
              Text(
                gematria,
                style: ArcanumText.body(14, color: ArcanumColors.goldMuted),
              ),
            ],
            if (limit != null) ...[
              const SizedBox(height: 10),
              Text(
                limit,
                style: ArcanumText.body(
                  13,
                  italic: true,
                  color: ArcanumColors.ivoryMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              bridge.footnote,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ),
      ),
    );
  }
}
