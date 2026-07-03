import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';
import '../../../shared/widgets/arcanum_mood.dart';
import '../../../shared/widgets/arcanum_surface.dart';
import '../sign_lore.dart';

/// Galería de los 12 signos como cartas ilustradas, cada una vestida con la
/// atmósfera viva de su elemento. Toca una carta para abrir su lore completo.
/// Resalta el signo solar y el ascendente del usuario si se conocen.
class SignGallery extends StatelessWidget {
  final String? sunSign;
  final String? ascSign;
  const SignGallery({super.key, this.sunSign, this.ascSign});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.42,
      ),
      itemCount: zodiacOrder.length,
      itemBuilder: (context, i) {
        final key = zodiacOrder[i];
        return _SignCard(
          signKey: key,
          isSun: key == sunSign,
          isAsc: key == ascSign,
        );
      },
    );
  }
}

class _SignCard extends StatelessWidget {
  final String signKey;
  final bool isSun;
  final bool isAsc;
  const _SignCard({required this.signKey, this.isSun = false, this.isAsc = false});

  @override
  Widget build(BuildContext context) {
    final lore = signLore[signKey]!;
    final mood = ArcanumMood.forElement(lore.elemento);
    final glyph = signGlyph[signKey] ?? '✶';
    final name = signEs[signKey] ?? signKey;
    final br = BorderRadius.circular(14);
    final highlighted = isSun || isAsc;

    return GestureDetector(
      onTap: () => showSignLoreSheet(context, signKey),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(
            color: mood.accent.withValues(alpha: highlighted ? 0.75 : 0.34),
            width: highlighted ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? mood.glow.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.30),
              blurRadius: highlighted ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: br,
          child: ArcanumSurface(
            mood: mood,
            intensity: highlighted ? 0.5 : 0.4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(glyph,
                          style: TextStyle(fontSize: 34, color: mood.accent)),
                      const Spacer(),
                      if (isSun) _tag('☉ Sol', mood.accent),
                      if (isAsc) _tag('AC', mood.accent),
                    ],
                  ),
                  const Spacer(),
                  Text(name,
                      style: ArcanumText.heading(22, color: ArcanumColors.ivory)),
                  const SizedBox(height: 2),
                  Text('${lore.elemento} · ${lore.regente}',
                      style: ArcanumText.body(13,
                          color: ArcanumColors.ivoryMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String txt, Color accent) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: ArcanumColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.6)),
        ),
        child: Text(txt,
            style: ArcanumText.body(11, color: ArcanumColors.gold)
                .copyWith(fontWeight: FontWeight.w600)),
      );
}
