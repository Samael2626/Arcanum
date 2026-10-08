import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Un enlace hacia otra seccion: rotulo, icono y que hacer al tocarlo.
class PracticeLink {
  const PracticeLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Fila de enlaces al pie de una lectura o una ficha: lo que se lee lleva a
/// donde se hace. Discreta (texto dorado, sin relleno) para no competir con el
/// contenido, y con 48 dp de alto en cada enlace para el dedo.
///
/// Sin enlaces no ocupa sitio.
class PracticeLinks extends StatelessWidget {
  const PracticeLinks({super.key, required this.links});

  final List<PracticeLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      children: [
        for (final l in links)
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: ArcanumColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: l.onTap,
            icon: Icon(l.icon, size: 18, color: ArcanumColors.gold),
            label: Text(
              l.label,
              style: ArcanumText.body(15, color: ArcanumColors.gold),
            ),
          ),
      ],
    );
  }
}
