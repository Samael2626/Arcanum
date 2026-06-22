import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionPlanetViewer extends StatefulWidget {
  const ThermionPlanetViewer({Key? key}) : super(key: key);

  @override
  State<ThermionPlanetViewer> createState() => _ThermionPlanetViewerState();
}

class _ThermionPlanetViewerState extends State<ThermionPlanetViewer> {
  late ThermionViewerState _thermionViewerState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saturno 3D')),
      body: ThermionViewer(
        onViewerCreated: (controller) async {
          _thermionViewerState = controller;
          // Cargar asset comprimido
          await controller.loadGlb('assets/models/saturn.opt.glb');
          // Rotación automática
          controller.autoRotate = true;
          controller.autoRotateSpeed = 3.0;
        },
      ),
    );
  }
}
