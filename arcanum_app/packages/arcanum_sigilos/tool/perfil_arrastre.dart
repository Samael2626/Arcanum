// Perfil de un frame de arrastre de letra, por etapas (Dart puro, en el PC).
// Uso: dart run tool/perfil_arrastre.dart
import 'dart:math' as math;

import 'package:arcanum_sigilos/engine/geometry.dart';
import 'package:arcanum_sigilos/engine/interaction.dart';
import 'package:arcanum_sigilos/engine/layers.dart';
import 'package:arcanum_sigilos/engine/scene.dart';
import 'package:arcanum_sigilos/engine/sigil_doc.dart';
import 'package:arcanum_sigilos/engine/style.dart';
import 'package:arcanum_sigilos/engine/terminals.dart';

void main() {
  for (final pila in ['anillo+estrella', 'hebreo+inscripcion+simbolo']) {
    final doc = SigilDoc(style: presetStyle('metal', today: DateTime(2026, 9, 30)), terminals: 'pattee');
    final ctl = CanvasController(doc);
    if (pila.startsWith('anillo')) {
      ctl.addLayer(LayerType.ringLatin, (l) => l..symbol = 'jupiter'..sep = 'cross');
      ctl.addLayer(LayerType.star, (l) => l.points = 7);
    } else {
      ctl.addLayer(LayerType.ringHebrew);
      ctl.addLayer(LayerType.inscription, (l) => l.text = 'VOLUNTAS');
      ctl.addLayer(LayerType.symbol, (l) => l..sym = '♃'..x = 400..y = 150);
    }
    doc.generate('Mi práctica mantiene enfoque sereno');
    final p = doc.sigil.prims.firstWhere((q) => q.units.length == 1 && q is LinePrim) as LinePrim;
    final a = doc.sigil.view!.toCanvas(p.a), b = doc.sigil.view!.toCanvas(p.b);
    final start = Pt((a.x + b.x) / 2, (a.y + b.y) / 2);
    ctl.pointerDown(start, pxScale: 2);
    final sw = {'snap': Stopwatch(), 'rebuild': Stopwatch(), 'scene': Stopwatch(), 'emitir(svg-like)': Stopwatch()};
    const n = 600;
    for (var i = 0; i < n; i++) {
      final t = i / 60, q = Pt(start.x + math.cos(t * 3) * 60 - 60, start.y + math.sin(t * 3) * 60);
      // mismas etapas que pointerMove, cronometradas por separado
      sw['snap']!.start();
      snapPoint(doc, q, 'letter:${doc.sigil.letters.first.ch}', pxScale: 2);
      sw['snap']!.stop();
      sw['rebuild']!.start();
      ctl.pointerMove(q, pxScale: 2);
      sw['rebuild']!.stop();
      sw['scene']!.start();
      final s = doc.scene();
      sw['scene']!.stop();
      sw['emitir(svg-like)']!.start();
      sceneSVG(s.fg);
      sw['emitir(svg-like)']!.stop();
    }
    ctl.pointerUp();
    final tv = doc.sigil.visible;
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      freeEnds(tv);
    }
    // ignore: avoid_print
    print('$pila · trazos=${doc.sigil.prims.length} · ms por frame: '
        '${sw.entries.map((e) => '${e.key}=${(e.value.elapsedMicroseconds / n / 1000).toStringAsFixed(2)}').join(' ')} '
        '(pointerMove incluye otro snap) · freeEnds=${(sw2.elapsedMicroseconds / n / 1000).toStringAsFixed(2)}');
  }
}
