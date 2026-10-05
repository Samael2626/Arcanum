/// La mesa dibujada: camara, paño, abanico, montones, cartas y radial.
///
/// No decide nada: lee `TableDirector.pieces()` y le pasa los toques. Pide
/// frames solo cuando algo espera al reloj o se mueve (`needsTicks`, la camara
/// o una animacion de pieza); con la mesa quieta no se dibuja nada.
///
/// Quien la monta la reconstruye cuando cambia la mesa del controlador
/// (`ref.watch(tableControllerProvider)`, como hace `TarotTableScreen`): el
/// director avisa de sus gestos, no de cada cambio del estado guardado.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../domain/table_state.dart';
import 'radial_logic.dart';
import '../../oraculo/widgets/tarot_card.dart';
import '../reading/lectura_revelada.dart';
import 'table_director.dart';
import 'table_fx.dart';
import 'table_geometry.dart';
import 'table_icons.dart';
import 'table_motion.dart';
import 'table_painters.dart';
import 'gesture_grammar.dart';
import 'table_pieces.dart';
import 'table_quality.dart';
import 'table_moon.dart';
import 'table_smoke.dart';

class TarotTableView extends StatefulWidget {
  const TarotTableView({
    super.key,
    required this.director,
    this.clock,
    this.quality,
    this.moonIllumination,
  });

  final TableDirector director;

  /// Reloj de los gestos (mantener, doble toque). Inyectable para los tests.
  final Duration Function()? clock;

  /// Calidad adaptativa. Inyectable para los tests; si no, la mesa usa la suya.
  final TableQuality? quality;

  /// Luz de la Luna sobre la mesa (0 nueva, 1 llena), o null sin dato.
  final double? moonIllumination;

  @override
  State<TarotTableView> createState() => _TarotTableViewState();
}

class _TarotTableViewState extends State<TarotTableView>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastTick = Duration.zero;
  ui.Image? _back;

  // ---------- movimiento ----------
  /// Piezas del fotograma anterior: lo que falta ahora se ha ido; lo que
  /// sobra, acaba de nacer.
  Map<String, PieceView> _last = {};
  final Map<String, Birth?> _births = {};
  final Map<String, ({PieceView view, TablePose to, Duration duration})>
  _ghosts = {};

  /// El abanico se despliega al abrirse y se pliega al recogerse.
  late final AnimationController _fanCtl;
  String? _fanPid;
  bool _fanJustOpened = false;
  ({FanLayout fan, int count})? _closingFan;
  ({FanLayout fan, int count})? _lastFan;

  /// El bordado «Interpretar» despierta cuando la tirada esta lista.
  late final AnimationController _embroideryCtl;
  bool _wasReady = false;

  /// Huellas de las cartas que se acaban de desvelar.
  final Map<String, Imprint> _imprints = {};
  int _imprintSeq = 0;

  /// El barajado en escena.
  late final AnimationController _shuffleCtl;
  ({String pid, String style, int epoch})? _shuffle;
  int _seenShuffle = 0;

  /// Calidad adaptativa y medidor de fotogramas (especificacion §6).
  late final TableQuality _quality = widget.quality ?? TableQuality();
  late final FrameMeter _meter = FrameMeter(quality: _quality, scene: _scene);

  TableDirector get _dir => widget.director;

  /// Lo que se esta viendo, para la linea del medidor en el log.
  String _scene() {
    if (_shuffle != null) return 'barajar';
    if (_fanCtl.isAnimating || _dir.fanDragging) return 'abanico';
    final drag = _dir.dragKind;
    if (drag == DragKind.orbit) return 'camara';
    if (drag != null) return 'arrastre';
    final sp = _dir.spread?.slug ?? 'libre';
    return 'mesa:$sp:${_dir.table.cards.length}cartas';
  }

  Duration get _now => widget.clock?.call() ?? _clock.elapsed;

  @override
  void initState() {
    super.initState();
    _fanCtl = AnimationController(vsync: this);
    _shuffleCtl = AnimationController(vsync: this);
    _embroideryCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _dir.addListener(_changed);
    _quality.addListener(_qualityChanged);
    _meter.start();
  }

  void _qualityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final old = _back;
    _back = recordCardBack(pixelRatio: dpr.clamp(1.0, 3.0) * .75);
    old?.dispose();
  }

  @override
  void didUpdateWidget(TarotTableView old) {
    super.didUpdateWidget(old);
    if (old.director != widget.director) {
      old.director.removeListener(_changed);
      widget.director.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _dir.removeListener(_changed);
    _meter.stop();
    _quality.removeListener(_qualityChanged);
    if (widget.quality == null) _quality.dispose();
    _fanCtl.dispose();
    _shuffleCtl.dispose();
    _embroideryCtl.dispose();
    _ticker.dispose();
    _back?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
    _wake();
  }

  void _wake() {
    if (!_ticker.isActive) {
      _lastTick = _now;
      _ticker.start();
    }
  }

  void _onTick(Duration _) {
    final now = _now;
    final moving = _dir.tick(now, now - _lastTick);
    _lastTick = now;
    _meter.note();
    if (moving || _dir.needsTicks) {
      setState(() {});
    } else {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final back = _back;
    _dir.reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        _dir.setViewport(box.biggest);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _dir.pointerDown(e.pointer, e.localPosition, _now);
            _wake();
          },
          onPointerMove: (e) =>
              _dir.pointerMove(e.pointer, e.localPosition, _now),
          onPointerUp: (e) => _dir.pointerUp(e.pointer, e.localPosition, _now),
          onPointerCancel: (e) => _dir.pointerCancel(e.pointer),
          child: TableQualityScope(
            quality: _quality,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (back != null)
                  Transform(
                    transform: _dir.camera.matrix(),
                    child: SizedBox(
                      width: TableGeometry.width,
                      height: TableGeometry.height,
                      child: _table(back),
                    ),
                  ),
                if (widget.moonIllumination case final f?)
                  Positioned.fill(child: MoonlightLayer(illumination: f)),
                if (back != null)
                  Transform(
                    transform: _dir.camera.matrix(),
                    child: SizedBox(
                      width: TableGeometry.width,
                      height: TableGeometry.height,
                      child: CircleMarkLayer(emitter: _dir.circleMark),
                    ),
                  ),
                Positioned.fill(
                  child: SealFlightLayer(emitter: _dir.sealFlight),
                ),
                // el humo sube por la pantalla, encima de la mesa y bajo el radial
                Positioned.fill(child: SmokeLayer(emitter: _dir.smoke)),
                if (_dir.radial != null) _RadialOverlay(director: _dir),
                if (_dir.busy)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: ArcanumColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Despues del fotograma: arrancar animaciones desde `build` avisaria a sus
  /// oyentes en plena construccion.
  void _afterFrame(VoidCallback start) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) start();
      });

  /// Compara con el fotograma anterior: anota quien nace (y de donde) y deja
  /// un fantasma volando por cada pieza que se fue a algun sitio.
  void _trackMotion(List<PieceView> pieces) {
    final now = {for (final p in pieces) p.id: p};
    final still = MediaQuery.disableAnimationsOf(context);
    for (final e in now.entries) {
      final was = _last[e.key];
      if (was == null) {
        _births[e.key] = _dir.takeBirth(e.key);
        continue;
      }
      // se acaba de desvelar: deja su huella cuando termine de voltearse
      final card = e.value.card;
      if (!still &&
          _quality.imprints &&
          card != null &&
          card.faceUp &&
          was.card != null &&
          !was.card!.faceUp) {
        final face = tarotFaceOf(card.face);
        _imprints['${card.slug}#${_imprintSeq++}'] = Imprint.of(
          face,
          e.value.pose,
          delay: TarotFlipTiming.of(face).flip,
        );
      }
    }
    for (final e in _last.entries) {
      if (now.containsKey(e.key)) continue;
      _births.remove(e.key);
      final to = _dir.takeExit(e.key);
      // con «reducir movimiento» lo que se va desaparece, sin vuelo
      if (to != null && !still) {
        _ghosts[e.key] = (
          view: e.value,
          to: to,
          duration: _dir.takeExitDuration(e.key),
        );
      }
    }
    _last = now;
  }

  void _trackFan(int count) {
    final f = _dir.fan;
    final still = MediaQuery.disableAnimationsOf(context);
    if (f != null) {
      _lastFan = (fan: f, count: count);
      if (_dir.fanDragging) {
        _fanPid = f.pid;
        _fanJustOpened = false;
        if (_fanCtl.value != 1) _afterFrame(() => _fanCtl.value = 1);
      } else if (f.pid != _fanPid) {
        _fanPid = f.pid;
        _closingFan = null;
        _fanJustOpened = !still;
        _afterFrame(() {
          _fanJustOpened = false;
          // «reducir movimiento»: el abanico esta abierto, sin desplegarse
          if (still) {
            _fanCtl.value = 1;
            return;
          }
          _fanCtl
            ..duration = const Duration(milliseconds: 780)
            ..forward(from: 0);
        });
      }
    } else if (_fanPid != null) {
      _fanPid = null;
      if (still) {
        _closingFan = null;
        _afterFrame(() => _fanCtl.value = 0);
        return;
      }
      _closingFan = _lastFan;
      _afterFrame(() {
        _fanCtl.duration = const Duration(milliseconds: 460);
        _fanCtl.reverse(from: 1).whenComplete(() {
          if (mounted) setState(() => _closingFan = null);
        });
      });
    }
  }

  /// Enciende el bordado al quedar lista la tirada; lo apaga si deja de estarlo.
  void _trackEmbroidery() {
    final ready = _dir.readyToInterpret;
    if (ready == _wasReady) return;
    _wasReady = ready;
    final still = MediaQuery.disableAnimationsOf(context);
    _afterFrame(() {
      if (!ready) {
        _embroideryCtl.value = 0;
      } else if (still) {
        _embroideryCtl.value = 1;
      } else {
        _embroideryCtl.forward(from: 0);
      }
    });
  }

  void _trackShuffle() {
    final sh = _dir.shuffling;
    if (sh == null || sh.epoch == _seenShuffle) return;
    _seenShuffle = sh.epoch;
    // «reducir movimiento»: el barajado no se representa; lo dice el aviso
    if (MediaQuery.disableAnimationsOf(context)) return;
    _shuffle = sh;
    _afterFrame(() {
      _shuffleCtl
        ..duration = shuffleDuration(shuffleStyleOf(sh.style))
        ..forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _shuffle = null);
        });
    });
  }

  Widget _fanLayer(ui.Image back, List<PieceView> pieces) {
    final open = [
      for (final p in pieces)
        if (p.kind == PieceKind.fanCard) p.pose,
    ];
    final f = _dir.fan ?? _closingFan?.fan;
    if (f == null) return const SizedBox.shrink();
    final count = open.isNotEmpty ? open.length : (_closingFan?.count ?? 0);
    if (count == 0) return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _fanCtl,
        builder: (context, _) {
          final t = _fanJustOpened
              ? 0.0
              : Curves.easeOutCubic.transform(_fanCtl.value);
          final poses = t >= 1 && open.isNotEmpty
              ? open
              : fanPoses(f.start, Offset.lerp(f.start, f.end, t)!, count);
          return CustomPaint(
            size: const Size(TableGeometry.width, TableGeometry.height),
            painter: FanPainter(poses, back, soft: _quality.glow),
          );
        },
      ),
    );
  }

  Widget _shuffleLayer(ui.Image back) {
    final sh = _shuffle;
    final pile = sh == null ? null : _last['pile:${sh.pid}'];
    if (sh == null || pile == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _shuffleCtl,
        builder: (context, _) => CustomPaint(
          size: const Size(TableGeometry.width, TableGeometry.height),
          painter: ShuffleTheaterPainter(
            pile: pile.pose,
            style: shuffleStyleOf(sh.style),
            t: _quality.halfRate
                ? halfRate(
                    _shuffleCtl.value,
                    shuffleDuration(shuffleStyleOf(sh.style)),
                  )
                : _shuffleCtl.value,
            back: back,
            count: pile.count,
            seed: sh.epoch,
            soft: _quality.glow,
          ),
        ),
      ),
    );
  }

  Widget _ghost(
    String id,
    PieceView view,
    TablePose to,
    Duration duration,
    ui.Image back,
  ) => DepartingPiece(
    key: ValueKey('ghost:$id'),
    from: view.pose,
    to: to,
    duration: duration,
    onDone: () {
      if (mounted) setState(() => _ghosts.remove(id));
    },
    child: view.kind == PieceKind.pile
        ? CustomPaint(
            size: const Size(TableGeometry.cardW, TableGeometry.cardH),
            painter: PilePainter(count: view.count, back: back),
          )
        : RawImage(
            image: back,
            width: TableGeometry.cardW,
            height: TableGeometry.cardH,
            fit: BoxFit.fill,
          ),
  );

  Widget _table(ui.Image back) {
    final pieces = _dir.pieces();
    _trackMotion(pieces);
    _trackFan(pieces.where((p) => p.kind == PieceKind.fanCard).length);
    _trackShuffle();
    _trackEmbroidery();
    final table = _dir.table;
    final sp = _dir.spread;
    // el mazo recien abierto y sin tocar brilla: es por donde se empieza
    final fresh =
        table.piles.length == 1 &&
        table.cards.isEmpty &&
        table.fan == null &&
        (table.server?.label.startsWith('sin') ?? false);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(TableGeometry.width, TableGeometry.height),
            painter: FeltPainter(spread: sp, hotSlot: _dir.hotSlot),
          ),
        ),
        for (final p in pieces)
          if (p.kind == PieceKind.shelfDeck || p.kind == PieceKind.pile)
            PilePiece(
              key: ValueKey(p.id),
              view: p,
              back: back,
              glow: fresh && p.kind == PieceKind.pile && _quality.glow,
              birth: _births[p.id],
              // mientras se baraja, la caja muestra pocas: el resto esta en el aire
              shownCount:
                  _shuffle?.pid == p.id.substring(5) && p.id.startsWith('pile:')
                  ? (p.count * .25).round().clamp(2, p.count)
                  : null,
            ),
        _fanLayer(back, pieces),
        _shuffleLayer(back),
        // el bordado encendido y el sello van SOBRE el abanico y los montones:
        // en la zona cercana se pisan (abanico en y 782, sello en 712, bordado
        // en 716) y en el GN2200 el abanico los dejaba tapados y sin toque.
        // Las cartas en juego si pueden taparlos.
        IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _embroideryCtl,
              builder: (context, _) => CustomPaint(
                size: const Size(TableGeometry.width, TableGeometry.height),
                painter: EmbroideryPainter(
                  _quality.halfRate
                      ? halfRate(
                          _embroideryCtl.value,
                          const Duration(milliseconds: 1400),
                        )
                      : _embroideryCtl.value,
                  glow: _quality.glow,
                ),
              ),
            ),
          ),
        ),
        if (table.seal case final seal?)
          SealPiece(at: TableDirector.sealAt, open: seal.open),
        for (final e in _ghosts.entries)
          if (e.value.view.kind == PieceKind.pile)
            _ghost(e.key, e.value.view, e.value.to, e.value.duration, back),
        // la huella va bajo la carta: sale de sus bordes
        for (final e in _imprints.entries)
          ImprintPiece(
            key: ValueKey('imprint:${e.key}'),
            imprint: e.value,
            onDone: () {
              if (mounted) setState(() => _imprints.remove(e.key));
            },
          ),
        for (final p in pieces)
          if (p.kind == PieceKind.pendingCard)
            PendingCardPiece(
              key: ValueKey(p.id),
              view: p,
              back: back,
              birth: _births[p.id],
            ),
        for (final p in pieces)
          if (p.kind == PieceKind.card)
            TableCardPiece(
              key: ValueKey(p.id),
              view: p,
              back: back,
              positionLabel: _positionLabel(p),
              birth: _births[p.id],
            ),
        for (final e in _ghosts.entries)
          if (e.value.view.kind == PieceKind.card)
            _ghost(e.key, e.value.view, e.value.to, e.value.duration, back),
      ],
    );
  }

  String? _positionLabel(PieceView p) {
    final c = p.card!;
    final sp = _dir.spread;
    if (c.slot != null && sp != null && c.slot! < sp.cardCount) {
      return 'Posición ${c.slot! + 1}, ${sp.slots[c.slot!].name}';
    }
    if (c.host != null) return 'Aclaratoria';
    if (c.aside) return 'Apartada';
    return null;
  }
}

/// El radial, en coordenadas de pantalla: circulos sueltos de 52 dp con su
/// nombre debajo. Los toques los decide el director; esto solo se dibuja.
class _RadialOverlay extends StatelessWidget {
  const _RadialOverlay({required this.director});

  final TableDirector director;

  @override
  Widget build(BuildContext context) {
    final l = director.radial!;
    final hot = director.radialHot;
    // «reducir movimiento»: los circulos estan en su sitio, sin salir del centro
    final still = MediaQuery.disableAnimationsOf(context);
    const s = RadialLayout.buttonSize;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: .35)),
        ),
        Positioned(
          left: l.titlePosition.dx - 120,
          top: l.titlePosition.dy - 12,
          width: 240,
          child: Text(
            director.radialTitle ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              letterSpacing: 1.2,
              color: ArcanumColors.goldLight,
            ),
          ),
        ),
        Positioned(
          left: l.center.dx - 24,
          top: l.center.dy - 24,
          child: Semantics(
            label: director.ops.canUndo ? 'Deshacer' : 'Cerrar',
            button: true,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ArcanumColors.goldMuted),
                  ),
                  child: Center(
                    child: TableIcon(
                      director.ops.canUndo ? 'undo' : 'x',
                      color: ArcanumColors.goldMuted,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < l.items.length; i++)
          // cada circulo sale del centro, uno detras de otro, como en el prototipo
          TweenAnimationBuilder<double>(
            key: ValueKey((identityHashCode(l), i)),
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: still
                ? Duration.zero
                : Duration(milliseconds: 170 + 28 * i),
            curve: Interval(
              i * .08 / (1 + i * .08),
              1,
              curve: Curves.easeOutBack,
            ),
            builder: (context, t, child) {
              final at = Offset.lerp(l.center, l.positions[i], t)!;
              return Positioned(
                left: at.dx - 45,
                top: at.dy - s / 2,
                width: 90,
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              );
            },
            child: _RadialButton(item: l.items[i], hot: i == hot),
          ),
      ],
    );
  }
}

class _RadialButton extends StatelessWidget {
  const _RadialButton({required this.item, required this.hot});

  final RadialItem item;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    const s = RadialLayout.buttonSize;
    return Opacity(
      opacity: item.enabled ? 1 : .28,
      child: Semantics(
        label: item.label,
        button: true,
        enabled: item.enabled,
        selected: item.current,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: hot ? 1.18 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: Container(
                width: s,
                height: s,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hot
                      ? ArcanumColors.gold
                      : ArcanumColors.surfaceHigh.withValues(alpha: .95),
                  border: Border.all(
                    color: item.current
                        ? ArcanumColors.goldLight
                        : ArcanumColors.gold.withValues(alpha: .7),
                    width: item.current ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TableIcon(
                  item.id,
                  color: hot
                      ? ArcanumColors.background
                      : ArcanumColors.goldLight,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.1,
                color: hot ? ArcanumColors.goldLight : ArcanumColors.ivoryMuted,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
