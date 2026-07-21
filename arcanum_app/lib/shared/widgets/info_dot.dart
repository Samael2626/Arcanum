import 'package:flutter/material.dart';

import '../../core/content/glossary.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Busca una entrada del glosario fallando RUIDOSO si la clave no existe.
///
/// Una clave mal escrita hacía desaparecer el "?" sin decir nada. En debug
/// revienta; en release degrada a null y lo reporta.
GlossaryEntry? _lookup(String entryKey) {
  final entry = glossary[entryKey];
  if (entry == null) {
    assert(false, 'Glosario: clave inexistente "$entryKey"');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('Glosario: clave inexistente "$entryKey"'),
        library: 'arcanum glossary',
        context: ErrorDescription('resolviendo una entrada del glosario'),
      ),
    );
  }
  return entry;
}

/// Abre la hoja explicativa de un concepto desde cualquier gesto, no solo
/// desde el "?" (una palabra técnica, un número de casa, un aspecto…).
void showGlossarySheet(BuildContext context, String entryKey) {
  final entry = _lookup(entryKey);
  if (entry == null) return;
  _show(context, entry);
}

/// Pequeño círculo "?" (o "!") que abre una explicación del concepto.
class InfoDot extends StatelessWidget {
  final String entryKey;
  final String symbol;
  final double size;
  const InfoDot(this.entryKey, {super.key, this.symbol = '?', this.size = 18});

  @override
  Widget build(BuildContext context) {
    final entry = _lookup(entryKey);
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
          border: Border.all(
            color: ArcanumColors.goldMuted.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          symbol,
          style: TextStyle(
            color: ArcanumColors.gold,
            fontSize: size * 0.62,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

void _show(BuildContext context, GlossaryEntry entry) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ArcanumColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => ConstrainedBox(
      // Las entradas largas (casas, natal vs. tránsito) desbordaban una
      // Column fija: se limita a 80% de pantalla y se hace scrollable.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ArcanumColors.goldMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              entry.title,
              style: ArcanumText.heading(26, color: ArcanumColors.gold),
            ),
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
    ),
  );
}
