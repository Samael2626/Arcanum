// Prueba de rendimiento de la mesa de tarot (fase 4 del plan, paso 1).
//
// Pregunta que responde: con Impeller en el movil real, ¿78 cartas en abanico
// mas una Cruz Celta llegan a 60 fps como widgets con Transform, o hace falta
// pintarlas con CustomPainter? Cada escena corre 8 s en cada tecnica y se mide
// con FrameTiming (lo que de verdad tarda el motor), no con un contador propio.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ProbeApp());
}

const double tableW = 600, tableH = 900;
const double cardW = 76, cardH = cardW * 1.6;
const Duration warmup = Duration(seconds: 1);
const Duration measure = Duration(seconds: 8);

// Cruz Celta como en el prototipo: fraccion x, y del area de tirada y giro
const celtic = [
  (.36, .5, 0.0),
  (.36, .5, 90.0),
  (.36, .8, 0.0),
  (.14, .5, 0.0),
  (.36, .2, 0.0),
  (.58, .5, 0.0),
  (.84, .86, 0.0),
  (.84, .62, 0.0),
  (.84, .38, 0.0),
  (.84, .14, 0.0),
];
const spreadArea = Rect.fromLTWH(30, 60, 540, 520);
const spreadScale = .9;

enum Technique { widgets, painter }

enum Scene { fan, flip, drag, camera, all }

const sceneNames = {
  Scene.fan: 'Abanico abriéndose',
  Scene.flip: 'Diez cartas volteándose',
  Scene.drag: 'Carta arrastrada',
  Scene.camera: 'Cámara girando',
  Scene.all: 'Todo a la vez',
};
const techniqueNames = {
  Technique.widgets: 'Widgets',
  Technique.painter: 'Pintor',
};

class Result {
  Result(
    this.technique,
    this.scene,
    this.frames,
    this.seconds,
    this.build,
    this.raster,
    this.jank,
  );
  final Technique technique;
  final Scene scene;
  final int frames;
  final double seconds;
  final List<double> build;
  final List<double> raster;
  final int jank;

  double get fps => frames / seconds;
  static double p90(List<double> v) => v.isEmpty
      ? 0
      : (v.toList()..sort())[(v.length * .9).floor().clamp(0, v.length - 1)];
  double get buildP90 => p90(build);
  double get rasterP90 => p90(raster);
  double get jankPct => frames == 0 ? 0 : 100 * jank / frames;
  bool get passes => fps >= 57 && rasterP90 < 14 && buildP90 < 8;
}

/// Estado de la escena en el instante t (segundos). Igual para las dos tecnicas.
class Pose {
  Pose(this.scene, this.t);
  final Scene scene;
  final double t;

  bool on(Scene s) => scene == s || scene == Scene.all;

  double get fanOpen => on(Scene.fan) ? .55 + .45 * math.sin(t * 2.2) : 1;
  double get yaw => on(Scene.camera) ? 30 * math.sin(t * .8) : 0;
  double get theta => on(Scene.camera) ? 36 + 16 * math.sin(t * .55) : 30;

  /// Giro sobre el eje Y de la carta i del spread: 0 = boca arriba, pi = boca abajo.
  double flip(int i) => on(Scene.flip)
      ? math.pi * (.5 - .5 * math.cos(2 * math.pi * (t * .45 + i * .1)))
      : 0;

  Offset get dragPos => on(Scene.drag)
      ? Offset(300 + 200 * math.sin(t * 1.3), 420 + 260 * math.sin(t * 2.1))
      : const Offset(480, 700);

  /// Inclinacion de peso: sigue a la velocidad, como el muelle del prototipo.
  double get dragTilt => on(Scene.drag) ? .2 * math.cos(t * 1.3) : 0;

  List<(Offset, double)> fanCards() {
    const pivot = Offset(300, 1180), radius = 440.0;
    final range = 62 * fanOpen * math.pi / 180;
    return List.generate(78, (i) {
      final a = -range / 2 + range * i / 77;
      return (pivot + Offset(math.sin(a), -math.cos(a)) * radius, a);
    });
  }

  List<(Offset, double)> spreadCards() => [
    for (final (fx, fy, rot) in celtic)
      (
        Offset(
          spreadArea.left + fx * spreadArea.width,
          spreadArea.top + fy * spreadArea.height,
        ),
        rot * math.pi / 180,
      ),
  ];
}

Matrix4 cameraMatrix(Size screen, double yawDeg, double thetaDeg) {
  final s = math.min(screen.width / tableW, screen.height / tableH) * .92;
  // la perspectiva se multiplica como matriz propia: poner la entrada (3, 2)
  // sobre una matriz ya trasladada deja el punto de fuga en la esquina
  final perspective = Matrix4.identity()..setEntry(3, 2, -1 / 1000);
  return Matrix4.identity()
    ..translateByDouble(screen.width / 2, screen.height / 2, 0, 1)
    ..multiply(perspective)
    ..rotateX(thetaDeg * math.pi / 180)
    ..rotateZ(yawDeg * math.pi / 180)
    ..scaleByDouble(s, s, s, 1)
    ..translateByDouble(-tableW / 2, -tableH / 2, 0, 1);
}

Matrix4 cardFlip(double angle) => Matrix4.identity()
  ..setEntry(3, 2, -1 / 600)
  ..rotateY(angle);

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const ProbeScreen(),
  );
}

class ProbeScreen extends StatefulWidget {
  const ProbeScreen({super.key});

  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen>
    with SingleTickerProviderStateMixin {
  final time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  List<String> slugs = [];
  Map<String, ui.Image> faces = {};
  Technique technique = Technique.widgets;
  Scene scene = Scene.fan;
  bool running = false;
  bool recording = false;
  final List<FrameTiming> _timings = [];
  final List<Result> results = [];
  double liveFps = 0;
  int _liveFrames = 0;
  Duration _liveStart = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      time.value = elapsed.inMicroseconds / 1e6;
      _liveFrames++;
      if (elapsed - _liveStart > const Duration(milliseconds: 500)) {
        setState(
          () => liveFps =
              _liveFrames / ((elapsed - _liveStart).inMicroseconds / 1e6),
        );
        _liveFrames = 0;
        _liveStart = elapsed;
      }
    });
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _load();
  }

  Future<void> _load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final all =
        manifest
            .listAssets()
            .where((a) => a.startsWith('assets/tarot/'))
            .toList()
          ..sort();
    final loaded = <String, ui.Image>{};
    for (final a in all.take(celtic.length + 1)) {
      final data = await rootBundle.load(a);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 220,
      );
      loaded[a] = (await codec.getNextFrame()).image;
    }
    setState(() {
      slugs = all;
      faces = loaded;
    });
  }

  void _onTimings(List<FrameTiming> t) {
    if (recording) _timings.addAll(t);
  }

  Future<void> _runAll() async {
    setState(() {
      running = true;
      results.clear();
    });
    for (final tech in Technique.values) {
      for (final sc in Scene.values) {
        setState(() {
          technique = tech;
          scene = sc;
        });
        _liveStart = Duration.zero;
        _ticker.start();
        await Future<void>.delayed(warmup);
        _timings.clear();
        recording = true;
        final sw = Stopwatch()..start();
        await Future<void>.delayed(measure);
        recording = false;
        sw.stop();
        _ticker.stop();
        double ms(Duration d) => d.inMicroseconds / 1000;
        final budget = 1000 / 60;
        results.add(
          Result(
            tech,
            sc,
            _timings.length,
            sw.elapsedMicroseconds / 1e6,
            [for (final f in _timings) ms(f.buildDuration)],
            [for (final f in _timings) ms(f.rasterDuration)],
            _timings.where((f) => ms(f.totalSpan) > budget).length,
          ),
        );
        debugPrint(
          'MESA ${tech.name} ${sc.name}: ${results.last.fps.toStringAsFixed(1)} fps, '
          'build p90 ${results.last.buildP90.toStringAsFixed(1)} ms, raster p90 ${results.last.rasterP90.toStringAsFixed(1)} ms',
        );
      }
    }
    setState(() => running = false);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = slugs.length == 78 && faces.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready && (running || results.isEmpty))
            LayoutBuilder(
              builder: (context, box) => ValueListenableBuilder<double>(
                valueListenable: time,
                builder: (context, t, _) {
                  final pose = Pose(scene, t);
                  return Transform(
                    transform: cameraMatrix(box.biggest, pose.yaw, pose.theta),
                    child: SizedBox(
                      width: tableW,
                      height: tableH,
                      child: technique == Technique.widgets
                          ? WidgetTable(pose: pose, slugs: slugs)
                          : RepaintBoundary(
                              child: CustomPaint(
                                painter: TablePainter(
                                  pose,
                                  faces.values.toList(),
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(child: _hud(ready)),
        ],
      ),
    );
  }

  Widget _hud(bool ready) {
    final refresh = View.of(context).display.refreshRate;
    if (!running && results.isNotEmpty) {
      return ResultsView(results: results, refresh: refresh, onRepeat: _runAll);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: running
            ? Text(
                '${techniqueNames[technique]} · ${sceneNames[scene]}\n'
                '${liveFps.toStringAsFixed(0)} fps · pantalla a ${refresh.toStringAsFixed(0)} Hz\n'
                'Prueba ${results.length + 1} de ${Technique.values.length * Scene.values.length}. No toques la pantalla.',
                textAlign: TextAlign.center,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Prueba de la mesa de tarot',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dura ~${(Technique.values.length * Scene.values.length * (warmup + measure).inSeconds)} s. '
                    'Deja el móvil quieto, con brillo normal y sin ahorro de batería.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: ready ? _runAll : null,
                    child: Text(ready ? 'Empezar' : 'Cargando cartas…'),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------- tecnica A: un widget por carta ----------------
class WidgetTable extends StatelessWidget {
  const WidgetTable({super.key, required this.pose, required this.slugs});
  final Pose pose;
  final List<String> slugs;

  static Widget _at(
    Offset c,
    double rot,
    double scale,
    Widget child, {
    Matrix4? extra,
  }) {
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(rot)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-cardW / 2, -cardH / 2, 0, 1);
    if (extra != null) {
      m
        ..translateByDouble(cardW / 2, 0, 0, 1)
        ..multiply(extra)
        ..translateByDouble(-cardW / 2, 0, 0, 1);
    }
    return Positioned(
      left: 0,
      top: 0,
      child: Transform(transform: m, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spread = pose.spreadCards();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: Felt()),
        for (final (c, a) in pose.fanCards()) _at(c, a, 1, const CardBack()),
        for (var i = 0; i < spread.length; i++)
          _at(
            spread[i].$1,
            spread[i].$2,
            spreadScale,
            pose.flip(i) < math.pi / 2
                ? CardFace(slugs[i])
                : const CardBack(shadow: true),
            extra: cardFlip(pose.flip(i)),
          ),
        _at(
          pose.dragPos,
          pose.dragTilt,
          1.08,
          CardFace(slugs[celtic.length]),
          extra: Matrix4.identity()..rotateX(pose.dragTilt * .6),
        ),
      ],
    );
  }
}

class Felt extends StatelessWidget {
  const Felt({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [Color(0xFF3A1420), Color(0xFF1A0910)],
        radius: .9,
      ),
      borderRadius: BorderRadius.all(Radius.circular(28)),
      border: Border.fromBorderSide(
        BorderSide(color: Color(0xFF6E5A36), width: 3),
      ),
    ),
  );
}

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.shadow = false});
  final bool shadow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: cardW,
    height: cardH,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2340), Color(0xFF0E1226)],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFB39A5C), width: 1.2),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0x88B39A5C), width: .8),
            ),
          ),
        ),
      ),
    ),
  );
}

class CardFace extends StatelessWidget {
  const CardFace(this.asset, {super.key});
  final String asset;

  @override
  Widget build(BuildContext context) => Container(
    width: cardW,
    height: cardH,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: const Color(0xFFB39A5C), width: 1.2),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        cacheWidth: 220,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}

// ---------------- tecnica B: todo en un CustomPainter ----------------
class TablePainter extends CustomPainter {
  TablePainter(this.pose, this.faces);
  final Pose pose;
  final List<ui.Image> faces;

  static final _felt = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0xFF3A1420), Color(0xFF1A0910)],
      radius: .9,
    ).createShader(const Rect.fromLTWH(0, 0, tableW, tableH));
  static final _feltBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFF6E5A36);
  static final _back = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C2340), Color(0xFF0E1226)],
    ).createShader(const Rect.fromLTWH(0, 0, cardW, cardH));
  static final _gold = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0xFFB39A5C);
  static final _goldThin = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .8
    ..color = const Color(0x88B39A5C);
  static final _shadow = Paint()
    ..color = Colors.black54
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final _image = Paint()..filterQuality = FilterQuality.medium;
  static final _rrect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, cardW, cardH),
    const Radius.circular(5),
  );

  void _card(
    Canvas canvas,
    Offset c,
    double rot,
    double scale, {
    ui.Image? face,
    double flip = 0,
    bool shadow = false,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.scale(scale);
    if (flip != 0) canvas.transform(cardFlip(flip).storage);
    canvas.translate(-cardW / 2, -cardH / 2);
    if (shadow) canvas.drawRRect(_rrect.shift(const Offset(0, 3)), _shadow);
    final showFace = face != null && flip < math.pi / 2;
    if (showFace) {
      canvas.save();
      canvas.clipRRect(_rrect);
      canvas.drawImageRect(
        face,
        Rect.fromLTWH(0, 0, face.width.toDouble(), face.height.toDouble()),
        const Rect.fromLTWH(0, 0, cardW, cardH),
        _image,
      );
      canvas.restore();
    } else {
      canvas.drawRRect(_rrect, _back);
      canvas.drawRect(
        const Rect.fromLTWH(6, 6, cardW - 12, cardH - 12),
        _goldThin,
      );
    }
    canvas.drawRRect(_rrect, _gold);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final table = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, tableW, tableH),
      const Radius.circular(28),
    );
    canvas.drawRRect(table, _felt);
    canvas.drawRRect(table, _feltBorder);
    for (final (c, a) in pose.fanCards()) {
      _card(canvas, c, a, 1);
    }
    final spread = pose.spreadCards();
    for (var i = 0; i < spread.length; i++) {
      _card(
        canvas,
        spread[i].$1,
        spread[i].$2,
        spreadScale,
        face: faces[i],
        flip: pose.flip(i),
        shadow: true,
      );
    }
    _card(
      canvas,
      pose.dragPos,
      pose.dragTilt,
      1.08,
      face: faces[celtic.length],
      shadow: true,
    );
  }

  @override
  bool shouldRepaint(TablePainter old) =>
      old.pose.t != pose.t || old.pose.scene != pose.scene;
}

// ---------------- resultados ----------------
class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.results,
    required this.refresh,
    required this.onRepeat,
  });
  final List<Result> results;
  final double refresh;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    String verdict(Technique t) {
      final rs = results.where((r) => r.technique == t);
      final ok = rs.where((r) => r.passes).length;
      return '${techniqueNames[t]}: $ok de ${rs.length} escenas a 60 fps';
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('Resultado', style: TextStyle(fontSize: 20)),
        Text(
          'Pantalla a ${refresh.toStringAsFixed(0)} Hz. Pasa si da ≥ 57 fps, dibujo p90 < 14 ms y montaje p90 < 8 ms.',
        ),
        const SizedBox(height: 8),
        for (final t in Technique.values)
          Text(verdict(t), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(2.4)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Text('Escena', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('fps', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'montaje p90',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'dibujo p90',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('tirones', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            for (final r in results)
              TableRow(
                decoration: BoxDecoration(
                  color: r.passes
                      ? const Color(0x2233AA55)
                      : const Color(0x33CC3344),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${techniqueNames[r.technique]} · ${sceneNames[r.scene]}',
                    ),
                  ),
                  Text(r.fps.toStringAsFixed(0)),
                  Text('${r.buildP90.toStringAsFixed(1)} ms'),
                  Text('${r.rasterP90.toStringAsFixed(1)} ms'),
                  Text('${r.jankPct.toStringAsFixed(0)} %'),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Haz una captura de esta pantalla y mándamela.'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onRepeat,
            child: const Text('Repetir'),
          ),
        ),
      ],
    );
  }
}
