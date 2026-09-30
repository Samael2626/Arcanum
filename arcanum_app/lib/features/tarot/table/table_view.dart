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
import 'radial_logic.dart';
import 'table_director.dart';
import 'table_geometry.dart';
import 'table_icons.dart';
import 'table_painters.dart';
import 'table_pieces.dart';

class TarotTableView extends StatefulWidget {
  const TarotTableView({super.key, required this.director, this.clock});

  final TableDirector director;

  /// Reloj de los gestos (mantener, doble toque). Inyectable para los tests.
  final Duration Function()? clock;

  @override
  State<TarotTableView> createState() => _TarotTableViewState();
}

class _TarotTableViewState extends State<TarotTableView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastTick = Duration.zero;
  ui.Image? _back;

  TableDirector get _dir => widget.director;
  Duration get _now => widget.clock?.call() ?? _clock.elapsed;

  @override
  void initState() {
    super.initState();
    _dir.addListener(_changed);
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
    if (moving || _dir.needsTicks) {
      setState(() {});
    } else {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final back = _back;
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
        );
      },
    );
  }

  Widget _table(ui.Image back) {
    final pieces = _dir.pieces();
    final fan = [
      for (final p in pieces)
        if (p.kind == PieceKind.fanCard) p.pose,
    ];
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
            painter: FeltPainter(
              spread: sp,
              hotSlot: _dir.hotSlot,
              ready: _dir.readyToInterpret,
            ),
          ),
        ),
        // el sello va sobre el paño y bajo las piezas: las cartas pueden taparlo
        if (table.seal case final seal?)
          SealPiece(at: TableDirector.sealAt, open: seal.open),
        for (final p in pieces)
          if (p.kind == PieceKind.shelfDeck || p.kind == PieceKind.pile)
            PilePiece(
              key: ValueKey(p.id),
              view: p,
              back: back,
              glow: fresh && p.kind == PieceKind.pile,
            ),
        if (fan.isNotEmpty)
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(TableGeometry.width, TableGeometry.height),
              painter: FanPainter(fan, back),
            ),
          ),
        for (final p in pieces)
          if (p.kind == PieceKind.card)
            TableCardPiece(
              key: ValueKey(p.id),
              view: p,
              back: back,
              positionLabel: _positionLabel(p),
            ),
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
          left: l.center.dx - 18,
          top: l.center.dy - 18,
          child: Semantics(
            label: director.ops.canUndo ? 'Deshacer' : 'Cerrar',
            button: true,
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
        for (var i = 0; i < l.items.length; i++)
          Positioned(
            left: l.positions[i].dx - 45,
            top: l.positions[i].dy - s / 2,
            width: 90,
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
              duration: const Duration(milliseconds: 120),
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
