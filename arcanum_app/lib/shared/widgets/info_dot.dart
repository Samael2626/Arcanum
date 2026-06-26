import 'package:flutter/material.dart';

import '../../core/content/glossary.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Pequeño círculo "?" (o "!") que abre una explicación del concepto.
class InfoDot extends StatelessWidget {
  final String entryKey;
  final String symbol;
  final double size;
  const InfoDot(this.entryKey, {super.key, this.symbol = '?', this.size = 18});

  @override
  Widget build(BuildContext context) {
    final entry = glossary[entryKey];
    if (entry == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _show(context, entry),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ArcanumColors.goldMuted.withValues(alpha: 0.7)),
        ),
        child: Text(symbol,
            style: TextStyle(
                color: ArcanumColors.gold, fontSize: size * 0.62, height: 1, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _show(BuildContext context, GlossaryEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcanumColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: ArcanumColors.goldMuted, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(entry.title, style: ArcanumText.heading(26, color: ArcanumColors.gold)),
            const SizedBox(height: 16),
            Text('QUÉ ES', style: ArcanumText.label()),
            const SizedBox(height: 6),
            Text(entry.what, style: ArcanumText.body(16)),
            const SizedBox(height: 18),
            Text('CÓMO USARLO', style: ArcanumText.label()),
            const SizedBox(height: 6),
            Text(entry.howTo, style: ArcanumText.body(16)),
          ],
        ),
      ),
    );
  }
}
