import 'package:flutter/material.dart';

import '../../shared/widgets/arcanum_toggle.dart';
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
  // 0 = Plantas (Materia), 1 = Biblioteca (obras que se leen).
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
  Widget build(BuildContext context) => ArcanumToggle(
    index: index,
    onChanged: onChanged,
    options: const [
      ArcanumToggleOption(label: 'Plantas'),
      ArcanumToggleOption(label: 'Biblioteca'),
    ],
  );
}
