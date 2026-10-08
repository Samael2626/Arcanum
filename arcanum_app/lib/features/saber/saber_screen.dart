import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/flow_navigation.dart';
import '../sendero/application/sendero_guide_controller.dart';
import '../../shared/widgets/arcanum_toggle.dart';
import '../arte/arte_screen.dart';
import '../lecturas/presentation/lecturas_screen.dart';
import 'sellos/sellos_screen.dart';

/// "Saber": el conocimiento de la tradición, en dos caras de una misma cosa.
///
/// Plantas (Materia Arcana) sale de los Libros (Lecturas): cuando una materia
/// dice que la ruda es del Sol, es Culpeper quien lo escribió. Antes eran dos
/// pestañas separadas y esa relación no se veía. Juntas bajo un toggle, el
/// puente Materia↔Culpeper vive en su casa natural.
///
/// Sellos es la tercera cara: consulta de los sellos históricos de Agrippa y de
/// la Goetia (obra de dominio público, con su procedencia a la vista).
class SaberScreen extends ConsumerStatefulWidget {
  const SaberScreen({super.key});

  @override
  ConsumerState<SaberScreen> createState() => _SaberScreenState();
}

class _SaberScreenState extends ConsumerState<SaberScreen> {
  // 0 = Plantas (Materia), 1 = Biblioteca (obras que se leen), 2 = Sellos.
  int _tab = 0;

  // Sellos carga ~2,9 MB de catálogo: no se construye hasta que se pide, y
  // una vez abierto conserva su estado como las otras caras.
  bool _sellosVisto = false;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(senderoGuideProvider);
    if (_tab == 1 && guide?.current.target == 'saber_toggle') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(senderoGuideProvider.notifier).onAction('saber_toggle');
        }
      });
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        KeyedSubtree(
          key: ref.read(senderoGuideTargetsProvider).keyFor('saber_toggle'),
          child: _Toggle(
            index: _tab,
            onChanged: (i) {
              setState(() {
                _tab = i;
                if (i == 2) _sellosVisto = true;
              });
              if (i == 1) {
                ref
                    .read(senderoGuideProvider.notifier)
                    .onAction('saber_toggle');
              }
            },
          ),
        ),
        const SizedBox(height: 6),
        // IndexedStack conserva el estado y el scroll de cada cara al alternar:
        // vuelves a Plantas y sigue donde lo dejaste, sin recargar el catálogo.
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              const ArteScreen(),
              const LecturasScreen(),
              if (_sellosVisto)
                SellosScreen(
                  onAnnotate: (p) =>
                      goGrimoireCompose(ref, context, title: p.title),
                  onPlanetHour: (_) =>
                      goCielo(ref, context, cara: cieloCaraAhora),
                )
              else
                const SizedBox.shrink(),
            ],
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
      ArcanumToggleOption(label: 'Sellos'),
    ],
  );
}
