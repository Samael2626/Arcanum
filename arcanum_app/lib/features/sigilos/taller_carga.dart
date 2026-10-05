// Carga del sigilo (gnosis de bajo riesgo): contemplarlo con la respiracion
// (4 s inhala, 4 sosten, 4 exhala, 4 sosten) durante 30, 60 o 120 s. Al
// terminar se decide: guardarlo o olvidarlo (intencion -> ... -> carga -> olvido).
import 'dart:async';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

enum CargaFin { guardar, olvidar }

class TallerCarga extends StatefulWidget {
  final SigilDoc doc;
  const TallerCarga({super.key, required this.doc});
  @override
  State<TallerCarga> createState() => _TallerCargaState();
}

class _TallerCargaState extends State<TallerCarga> with SingleTickerProviderStateMixin {
  int seconds = 30;
  Timer? _timer;
  int left = 30;
  bool running = false, done = false;
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  static const _fases = ['Inhala', 'Sostén', 'Exhala', 'Sostén'];

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      running = true;
      left = seconds;
    });
    _breath.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => left--);
      if (left <= 0) {
        t.cancel();
        _breath.stop();
        setState(() {
          running = false;
          done = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.doc.scene();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted), onPressed: () => Navigator.pop(context)),
          ),
          Text('CARGA DEL SIGILO', style: ArcanumText.label().copyWith(color: ArcanumColors.gold, letterSpacing: 4)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Fija la mirada en el sigilo y respira sin forzar. Cuando el tiempo termine, cierra los ojos y decide si lo guardas o lo olvidas.',
                textAlign: TextAlign.center, style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final side = box.biggest.shortestSide;
              return Center(
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(size: Size.square(side), painter: SigilScenePainter(bg: s.bg, fg: s.fg)),
                  AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) {
                      final t = _breath.value * 4, fase = t.floor() % 4, f = t - t.floor();
                      final k = fase == 0 ? .65 + .35 * f : fase == 1 ? 1.0 : fase == 2 ? 1 - .35 * f : .65;
                      return Opacity(
                        opacity: running ? .35 + .65 * (k - .65) / .35 : 0,
                        child: Container(
                          width: side * .3 * k,
                          height: side * .3 * k,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ArcanumColors.gold.withValues(alpha: .6))),
                          child: Center(child: Text(_fases[fase].toUpperCase(), style: ArcanumText.label().copyWith(color: ArcanumColors.gold))),
                        ),
                      );
                    },
                  ),
                ]),
              );
            }),
          ),
          Text('${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}', style: ArcanumText.heading(30).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          Padding(
            padding: const EdgeInsets.all(16),
            child: done
                ? Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, CargaFin.olvidar), style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.ivory), child: const Text('Olvidar'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, CargaFin.guardar), style: FilledButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: ArcanumColors.gold, foregroundColor: ArcanumColors.background), child: const Text('Guardar'))),
                  ])
                : Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final n in const [30, 60, 120])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('$n s'),
                          selected: seconds == n,
                          showCheckmark: false,
                          selectedColor: ArcanumColors.gold,
                          labelStyle: TextStyle(color: seconds == n ? ArcanumColors.background : ArcanumColors.ivory),
                          backgroundColor: ArcanumColors.surfaceHigh,
                          onSelected: running ? null : (_) => setState(() => left = seconds = n),
                        ),
                      ),
                    FilledButton(onPressed: running ? null : _start, style: FilledButton.styleFrom(minimumSize: const Size(96, 48), backgroundColor: ArcanumColors.gold, foregroundColor: ArcanumColors.background), child: const Text('Empezar')),
                  ]),
          ),
        ]),
      ),
    );
  }
}
