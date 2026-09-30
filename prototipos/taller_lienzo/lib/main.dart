// Prueba en movil del lienzo del taller de sigilos. No es la pantalla final:
// sirve para medir tacto y rendimiento (FrameTiming) con el mismo motor y el
// mismo lienzo que usara la app. Cada 2 s escribe en el log una linea
// «LIENZO ...» con los tiempos del motor.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: TallerLienzo()));

const _styles = ['oro', 'pergamino', 'flash-mars', 'metal', 'plata'];
const _stacks = ['anillo + estrella', 'sin capas', 'hebreo + inscripción + símbolo'];
const _modes = ['normal', 'remate', 'ocultar', 'colocar'];
const _terms = ['pattee', 'none', 'star'];

class TallerLienzo extends StatefulWidget {
  const TallerLienzo({super.key});
  @override
  State<TallerLienzo> createState() => _TallerLienzoState();
}

class _TallerLienzoState extends State<TallerLienzo> with SingleTickerProviderStateMixin {
  late SigilDoc doc;
  late CanvasController ctl;
  int styleI = 0, stackI = 0, modeI = 0, termI = 0;
  GridMode grid = GridMode.none;
  final _frames = <FrameTiming>[];
  String perf = 'midiendo…';
  Timer? _perfTimer;
  Ticker? _auto;
  // el arrastre automatico repinta solo el lienzo, como un dedo real
  final _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _build();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _perfTimer = Timer.periodic(const Duration(seconds: 2), (_) => _report());
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _perfTimer?.cancel();
    _auto?.dispose();
    super.dispose();
  }

  void _build() {
    doc = SigilDoc(style: presetStyle(_styles[styleI]), terminals: _terms[termI]);
    ctl = CanvasController(doc);
    switch (stackI) {
      case 0:
        ctl.addLayer(LayerType.ringLatin, (l) => l
          ..symbol = 'jupiter'
          ..sep = 'cross');
        ctl.addLayer(LayerType.star, (l) => l.points = 7);
      case 2:
        ctl.addLayer(LayerType.ringHebrew);
        ctl.addLayer(LayerType.inscription, (l) => l.text = 'VOLUNTAS');
        ctl.addLayer(LayerType.symbol, (l) => l
          ..sym = '♃'
          ..x = 400
          ..y = 150);
    }
    ctl.layerSel = null;
    doc.generate('Mi práctica mantiene enfoque sereno');
    _applyMode();
  }

  void _applyMode() {
    ctl
      ..termPick = _modes[modeI] == 'remate'
      ..hideMode = _modes[modeI] == 'ocultar'
      ..stampMode = _modes[modeI] == 'colocar'
      ..termBrush = 'pattee'
      ..stampSym = '♃';
  }

  void _onTimings(List<FrameTiming> t) {
    _frames.addAll(t);
    if (_frames.length > 600) _frames.removeRange(0, _frames.length - 600);
  }

  double _pct(List<double> v, double p) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[math.min(s.length - 1, (p * s.length).floor())];
  }

  bool _testing = false;

  void _report() {
    if (_frames.isEmpty || _testing) return;
    final build = [for (final f in _frames) f.buildDuration.inMicroseconds / 1000];
    final raster = [for (final f in _frames) f.rasterDuration.inMicroseconds / 1000];
    // presupuesto de un frame a la frecuencia real de la pantalla; build y
    // raster van en hilos distintos: se pierde el frame si uno de los dos se pasa
    final hz = View.of(context).display.refreshRate, budget = 1000 / hz;
    final late = [for (var i = 0; i < build.length; i++) if (build[i] > budget || raster[i] > budget) i].length;
    final line = 'LIENZO ${hz.round()}Hz frames=${_frames.length} build p50=${_pct(build, .5).toStringAsFixed(1)} p90=${_pct(build, .9).toStringAsFixed(1)} max=${_pct(build, 1).toStringAsFixed(1)} '
        'raster p50=${_pct(raster, .5).toStringAsFixed(1)} p90=${_pct(raster, .9).toStringAsFixed(1)} max=${_pct(raster, 1).toStringAsFixed(1)} '
        'fuera_de_presupuesto(${budget.toStringAsFixed(1)}ms)=${(late / build.length * 100).toStringAsFixed(1)}% estilo=${_styles[styleI]} capas=${_stacks[stackI]}';

    debugPrint(line);
    setState(() => perf = line.replaceFirst('LIENZO ', ''));
    _frames.clear();
  }

  // Matriz: todos los estilos por todas las pilas, 4 s de arrastre cada uno.
  // Un solo toque; cada caso escribe su linea LIENZO en el log.
  Future<void> _matrix() async {
    for (var c = 0; c < _stacks.length; c++) {
      for (var st = 0; st < _styles.length; st++) {
        setState(() {
          stackI = c;
          styleI = st;
          _build();
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final done = Completer<void>();
        _autoDrag(seconds: 4, onDone: done.complete);
        await done.future;
      }
    }
    debugPrint('LIENZO_MATRIZ_FIN');
  }

  // Arrastre automatico: mide todo menos el tacto
  void _autoDrag({double seconds = 5, VoidCallback? onDone}) {
    final sg = doc.sigil;
    final p = sg.prims.firstWhere((q) => q.units.length == 1 && q is LinePrim) as LinePrim;
    final a = sg.view!.toCanvas(p.a), b = sg.view!.toCanvas(p.b);
    final start = Pt((a.x + b.x) / 2, (a.y + b.y) / 2);
    _frames.clear();
    _testing = true;
    ctl.pointerDown(start, pxScale: 2);
    _auto?.dispose();
    _auto = createTicker((el) {
      final t = el.inMicroseconds / 1e6;
      if (t > seconds) {
        _auto!.stop();
        ctl.pointerUp();
        setState(() {});
        // el ultimo frame llega por FrameTiming un poco despues
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _testing = false;
          debugPrint('LIENZO_PRUEBA');
          _report();
          onDone?.call();
        });
        return;
      }
      ctl.pointerMove(Pt(start.x + math.cos(t * 3) * 60 - 60, start.y + math.sin(t * 3) * 60), pxScale: 2);
      _repaint.value++;
    })
      ..start();
  }

  Widget _btn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(3),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: const Color(0xFFE6B422), side: const BorderSide(color: Color(0xFF2A2433))),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sel = ctl.sel != null ? 'letra ${ctl.sel}' : ctl.layerSel != null ? 'capa ${doc.layers.firstWhere((l) => l.id == ctl.layerSel).name}' : 'nada';
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B0F),
      body: SafeArea(
        child: Column(children: [
          Wrap(children: [
            _btn('Estilo: ${_styles[styleI]}', () => setState(() { styleI = (styleI + 1) % _styles.length; doc.style = presetStyle(_styles[styleI]); })),
            _btn('Capas: ${_stacks[stackI]}', () => setState(() { stackI = (stackI + 1) % _stacks.length; _build(); })),
            _btn('Rejilla: ${grid.name}', () => setState(() => grid = GridMode.values[(grid.index + 1) % 3])),
            _btn('Modo: ${_modes[modeI]}', () => setState(() { modeI = (modeI + 1) % _modes.length; _applyMode(); })),
            _btn('Remate: ${_terms[termI]}', () => setState(() { termI = (termI + 1) % _terms.length; doc.terminals = _terms[termI]; })),
            _btn('Imán: ${ctl.magnet ? 'sí' : 'no'}', () => setState(() => ctl.magnet = !ctl.magnet)),
            _btn('Prueba 5 s', _autoDrag),
            _btn('Matriz', _matrix),
          ]),
          // el lienzo cabe en el espacio libre, en vertical y en horizontal
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final side = math.min(box.maxWidth, box.maxHeight);
              return Center(child: SizedBox.square(dimension: side, child: SigilCanvas(controller: ctl, grid: grid, repaint: _repaint, onChanged: () => setState(() {}))));
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Elegido: $sel · guías: ${ctl.guides.map((g) => g.kind.name).join(', ')}\n$perf',
                style: const TextStyle(color: Color(0xFFD4C9B8), fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
