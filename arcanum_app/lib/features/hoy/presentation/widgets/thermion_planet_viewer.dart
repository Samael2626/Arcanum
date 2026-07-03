import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';

/// STUB — el visor 3D real dependía de `thermion_flutter`, que no está en el
/// pubspec (rompía `flutter analyze`/`build`/`widget_test` al bootear).
/// Se aísla con un placeholder autocontenido hasta reincorporar la dep.
/// Nada del árbol de la app lo importa hoy; existe solo para no romper el build.
class ThermionPlanetViewer extends StatelessWidget {
  const ThermionPlanetViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saturno 3D')),
      body: const Center(
        child: Text(
          'Visor 3D no disponible',
          style: TextStyle(color: ArcanumColors.ivoryMuted),
        ),
      ),
    );
  }
}
