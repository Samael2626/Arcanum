import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Tarjeta base con borde dorado tenue.
class ArcanumCard extends StatelessWidget {
  final Widget child;
  const ArcanumCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: ArcanumColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.28)),
      ),
      child: child,
    );
  }
}

/// Etiqueta dorada en versalitas (ej. "HORA PLANETARIA").
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: ArcanumText.label());
}

/// Divisor ornamental con estrella central.
class Ornament extends StatelessWidget {
  const Ornament({super.key});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Container(
                  height: 1,
                  color: ArcanumColors.goldMuted.withValues(alpha: 0.5))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child:
                Text('✧', style: TextStyle(color: ArcanumColors.gold, fontSize: 16)),
          ),
          Expanded(
              child: Container(
                  height: 1,
                  color: ArcanumColors.goldMuted.withValues(alpha: 0.5))),
        ],
      );
}

/// Cabecera de pantalla: wordmark ARCANUM + subtítulo + ornamento.
class ArcanumHeader extends StatelessWidget {
  final String subtitle;
  const ArcanumHeader({super.key, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('ARCANUM',
              textAlign: TextAlign.center, style: ArcanumText.wordmark()),
          const SizedBox(height: 6),
          Text(subtitle,
              style: ArcanumText.body(17,
                  italic: true, color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 16),
          const Ornament(),
        ],
      );
}
