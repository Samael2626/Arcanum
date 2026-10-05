// Radiales del lienzo del taller:
//  - SelectionRadial: acciones de la letra o capa tocada, en circulo alrededor
//    del punto tocado (o del centro del elemento). El centro queda libre: el
//    elemento se sigue viendo y arrastrando entre los botones.
//  - AddRadial: el boton + abre un cuarto de circulo con los anadidos rapidos.
// Todo lo tocable mide 48 px.
import 'dart:math' as math;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

const double _kBtn = 48;

class RadialAction {
  final IconData? icon;
  final Widget? child;
  final String label;
  final VoidCallback onTap;
  const RadialAction({this.icon, this.child, required this.label, required this.onTap});
}

Widget _roundButton(RadialAction a, {Color? fill}) => Semantics(
      button: true,
      label: a.label,
      child: Tooltip(
        message: a.label,
        child: Material(
          color: fill ?? ArcanumColors.surface.withValues(alpha: .95),
          shape: const CircleBorder(side: BorderSide(color: ArcanumColors.gold)),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: a.onTap,
            child: SizedBox.square(
              dimension: _kBtn,
              child: Center(child: a.child ?? Icon(a.icon, size: 22, color: ArcanumColors.goldLight)),
            ),
          ),
        ),
      ),
    );

/// Acciones del elemento elegido. [side] es el lado del lienzo en pixeles.
class SelectionRadial extends StatelessWidget {
  final CanvasController ctl;
  final double side;
  final VoidCallback onEdited;
  const SelectionRadial({super.key, required this.ctl, required this.side, required this.onEdited});

  List<RadialAction> _actions() {
    void act(VoidCallback f) {
      f();
      onEdited();
    }

    if (ctl.sel != null) {
      return [
        RadialAction(icon: Icons.rotate_left, label: 'Girar −15°', onTap: () => act(() => ctl.rotateLetter(-15))),
        RadialAction(icon: Icons.rotate_right, label: 'Girar +15°', onTap: () => act(() => ctl.rotateLetter(15))),
        RadialAction(icon: Icons.flip, label: 'Reflejo horizontal', onTap: () => act(ctl.flipLetterH)),
        RadialAction(child: const RotatedBox(quarterTurns: 1, child: Icon(Icons.flip, size: 22, color: ArcanumColors.goldLight)), label: 'Reflejo vertical', onTap: () => act(ctl.flipLetterV)),
        RadialAction(icon: Icons.remove, label: 'Reducir', onTap: () => act(() => ctl.scaleLetter(false))),
        RadialAction(icon: Icons.add, label: 'Ampliar', onTap: () => act(() => ctl.scaleLetter(true))),
        RadialAction(icon: Icons.restart_alt, label: 'Restaurar la letra', onTap: () => act(ctl.resetLetter)),
      ];
    }
    return [
      if (ctl.selectedLayerScales) ...[
        RadialAction(icon: Icons.remove, label: 'Reducir', onTap: () => act(() => ctl.scaleLayer(false))),
        RadialAction(icon: Icons.add, label: 'Ampliar', onTap: () => act(() => ctl.scaleLayer(true))),
      ],
      RadialAction(icon: Icons.rotate_left, label: 'Girar −15°', onTap: () => act(() => ctl.rotateLayer(-15))),
      RadialAction(icon: Icons.rotate_right, label: 'Girar +15°', onTap: () => act(() => ctl.rotateLayer(15))),
      RadialAction(icon: Icons.delete_outline, label: 'Quitar', onTap: () => act(ctl.deleteSelectedLayer)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final a = ctl.anchor();
    if (a == null) return const SizedBox.shrink();
    final acts = _actions(), n = acts.length;
    final r = n >= 6 ? 68.0 : 58.0, d = 2 * r + _kBtn + 8, k = side / kSize;
    // centro: donde se toco, si fue este elemento; si no, el del elemento
    final c = ctl.tap != null && ctl.tapFor == a.key ? ctl.tap! : Pt(a.x, a.cy);
    final cx = (c.x * k).clamp(d / 2 + 2, side - d / 2 - 2), cy = (c.y * k).clamp(d / 2 + 2, side - d / 2 - 2);
    final name = a.isLetter ? a.letter! : (a.layer!.type == LayerType.symbol ? (stampName(a.layer!.sym) ?? a.layer!.sym) : a.layer!.name);
    return Positioned(
      left: cx - d / 2,
      top: cy - d / 2,
      width: d,
      height: d,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < n; i++)
          Positioned(
            left: d / 2 + math.cos((-90 + i * 360 / n) * math.pi / 180) * r - _kBtn / 2,
            top: d / 2 + math.sin((-90 + i * 360 / n) * math.pi / 180) * r - _kBtn / 2,
            child: _roundButton(acts[i]),
          ),
        // nombre del elemento, bajo el anillo
        Positioned(
          left: 0,
          right: 0,
          bottom: -22,
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: ArcanumColors.surface.withValues(alpha: .92), borderRadius: BorderRadius.circular(12)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Text(name, style: const TextStyle(color: ArcanumColors.gold, fontSize: 12))),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Boton + del lienzo con su cuarto de circulo de anadidos rapidos.
class AddRadial extends StatelessWidget {
  final bool open;
  final ValueChanged<bool> onToggle;
  final void Function(LayerType type) onAdd;
  final VoidCallback onSymbol;
  const AddRadial({super.key, required this.open, required this.onToggle, required this.onAdd, required this.onSymbol});

  @override
  Widget build(BuildContext context) {
    final items = <RadialAction>[
      RadialAction(icon: Icons.circle_outlined, label: 'Círculo', onTap: () => onAdd(LayerType.circle)),
      RadialAction(icon: Icons.crop_square, label: 'Cuadrado', onTap: () => onAdd(LayerType.square)),
      RadialAction(icon: Icons.radio_button_unchecked, label: 'Anillo', onTap: () => onAdd(LayerType.ringLatin)),
      RadialAction(icon: Icons.star_border, label: 'Estrella', onTap: () => onAdd(LayerType.star)),
      RadialAction(icon: Icons.title, label: 'Inscripción', onTap: () => onAdd(LayerType.inscription)),
      RadialAction(child: const GlyphIcon('♃', size: 22, color: ArcanumColors.goldLight), label: 'Símbolo', onTap: onSymbol),
    ];
    const r = 190.0;
    return Stack(clipBehavior: Clip.none, children: [
      if (open)
        for (var i = 0; i < items.length; i++) ...() {
          // cuarto de circulo desde el boton hacia arriba y a la izquierda;
          // distancias medidas desde la esquina (derecha, abajo) al centro del +
          final a = (180 + i * 90 / (items.length - 1)) * math.pi / 180;
          const c = 8 + _kBtn / 2;
          final bx = c - math.cos(a) * r, by = c - math.sin(a) * r;
          // la etiqueta va por fuera del arco: no tapa a ningun boton vecino
          final lx = c - math.cos(a) * (r + 44), ly = c - math.sin(a) * (r + 44);
          return [
            Positioned(
              right: bx - _kBtn / 2,
              bottom: by - _kBtn / 2,
              child: _roundButton(RadialAction(icon: items[i].icon, child: items[i].child, label: items[i].label, onTap: () {
                onToggle(false);
                items[i].onTap();
              })),
            ),
            Positioned(
              right: lx - 45,
              bottom: ly - 9,
              width: 90,
              height: 18,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: ArcanumColors.surface.withValues(alpha: .92), borderRadius: BorderRadius.circular(8)),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(items[i].label, style: const TextStyle(color: ArcanumColors.ivory, fontSize: 11))),
                  ),
                ),
              ),
            ),
          ];
        }(),
      Positioned(
        right: 8,
        bottom: 8,
        child: _roundButton(
          RadialAction(child: AnimatedRotation(turns: open ? .125 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.add, color: ArcanumColors.background, size: 26)), label: open ? 'Cerrar' : 'Añadir', onTap: () => onToggle(!open)),
          fill: ArcanumColors.gold,
        ),
      ),
    ]);
  }
}
