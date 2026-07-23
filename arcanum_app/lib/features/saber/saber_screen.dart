import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../arte/arte_screen.dart';
import '../lecturas/presentation/lecturas_screen.dart';

/// "Saber": el conocimiento de la tradición, en dos caras de una misma cosa.
///
/// Plantas (Materia Arcana) sale de los Libros (Lecturas): cuando una materia
/// dice que la ruda es del Sol, es Culpeper quien lo escribió. Antes eran dos
/// pestañas separadas y esa relación no se veía. Juntas bajo un toggle, el
/// puente Materia↔Culpeper vive en su casa natural.
class SaberScreen extends StatefulWidget {
  const SaberScreen({super.key});

  @override
  State<SaberScreen> createState() => _SaberScreenState();
}

class _SaberScreenState extends State<SaberScreen> {
  // 0 = Plantas (Materia), 1 = Libros (Lecturas).
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        _Toggle(index: _tab, onChanged: (i) => setState(() => _tab = i)),
        const SizedBox(height: 6),
        // IndexedStack conserva el estado y el scroll de cada cara al alternar:
        // vuelves a Plantas y sigue donde lo dejaste, sin recargar el catálogo.
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [ArteScreen(), LecturasScreen()],
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Toggle({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _pill('Plantas', 0),
              const SizedBox(width: 10),
              _pill('Libros', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, int value) {
    final selected = value == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected
                  ? ArcanumColors.gold.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? ArcanumColors.gold
                    : ArcanumColors.goldMuted.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              label,
              style: ArcanumText.body(
                16,
                color: selected ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
