import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Placeholder elegante para pantallas aún sin lógica (skeleton de Semana 3).
class ComingSoon extends StatelessWidget {
  final String glyph;
  final String title;
  final String description;
  const ComingSoon({
    super.key,
    required this.glyph,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph,
                style: const TextStyle(fontSize: 64, color: ArcanumColors.goldMuted)),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center, style: ArcanumText.heading(30)),
            const SizedBox(height: 12),
            Text(description,
                textAlign: TextAlign.center,
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.4)),
              ),
              child: Text('Próximamente',
                  style: ArcanumText.body(13, color: ArcanumColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}
