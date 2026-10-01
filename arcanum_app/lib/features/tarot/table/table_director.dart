/// Director de la mesa: convierte gestos en acciones, sin saber como se dibuja.
///
/// Recibe toques de pantalla, pregunta que hay debajo (hit-test en unidades de
/// mesa), los pasa por la gramatica y ejecuta lo que salga contra `TableOps`.
/// Lleva el estado EFIMERO que no se guarda: lo que se esta arrastrando, el
/// radial abierto, la esquina a medio voltear, el peso de cada carta.
///
/// El dibujo (widgets o pintor, lo decide la prueba de rendimiento) solo lee
/// `pieces()` y escucha los avisos. Las reglas son las del prototipo v2.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/api/arcanum_api.dart';
import '../application/table_controller.dart';
import '../domain/table_models.dart';
import '../domain/table_state.dart';
import 'card_physics.dart';
import 'gesture_grammar.dart';
import 'radial_logic.dart';
import 'table_camera.dart';
import 'table_geometry.dart';

/// Lo que la mesa necesita de la pantalla: paneles, avisos y errores.
abstract class TableEffects {
  void toast(String message) {}
  void flipped(TableCard card) {}
  void shuffled(String pile, String style) {}
  void openReading(TableCard card) {}
  void openInterpretation() {}
  void openSeal() {}

  /// Se toco el sello: sellado no enseña la pregunta; roto, si.
  void openSealInfo(Seal seal) {}
  void openHistory() {}
  void toggleSound() {}
  void creditsRequired() {}
  void error(Object error) {}
}

enum PieceKind { shelfDeck, pile, fanCard, card }

/// Una pieza lista para dibujar, en unidades de mesa.
class PieceView {
  const PieceView({
    required this.id,
    required this.kind,
    required this.pose,
    this.lift = 0,
    this.tiltX = 0,
    this.tiltY = 0,
    this.count = 0,
    this.card,
    this.fanPosition,
    this.peelAngle = 0,
    this.peelHingeX = 0,
    this.label,
    this.dragging = false,
  });

  final String id;
  final PieceKind kind;
  final TablePose pose;

  /// Altura sobre el paño (arrastrando se levanta).
  final double lift;

  /// Inclinacion por el peso al arrastrar, en grados.
  final double tiltX, tiltY;

  /// Cartas del monton (grosor de la caja).
  final int count;
  final TableCard? card;

  /// Posicion en el monton de una carta del abanico.
  final int? fanPosition;

  /// Volteo por la esquina en curso: angulo (grados) y bisagra (x local).
  final double peelAngle, peelHingeX;
  final String? label;

  /// Va pegada al dedo: se dibuja sin animar el cambio de sitio.
  final bool dragging;

  double get width =>
      (kind == PieceKind.card || kind == PieceKind.fanCard ? 1 : 1) *
      TableGeometry.cardW;
  double get height => TableGeometry.cardH;
}

class _Drag {
  _Drag(this.kind, this.id, this.offset);
  final DragKind kind;
  String id;
  Offset offset;
  TablePose? origin;
  int? originSlot;
  String? cutSource;
  Offset? last;
  bool ready = true;

  /// El arrastre es un gesto deshacible que se abrio al empezar y se cierra al soltar.
  bool gesture = false;
}

class _Radial {
  _Radial(this.layout, this.title, this.onPick);
  final RadialLayout layout;
  final String title;
  final Future<void> Function(String id) onPick;
  int? hot;
}

class TableDirector extends ChangeNotifier {
  TableDirector({
    required this.ops,
    required this.effects,
    this.decks = const [],
    this.spreads = const [],
    math.Random? random,
    TableCamera? camera,
  }) : camera = camera ?? TableCamera(from: ops.table.camera),
       _random = random ?? math.Random();

  final TableOps ops;
  final TableEffects effects;
  final TableCamera camera;
  final GestureGrammar grammar = GestureGrammar();
  List<DeckInfo> decks;
  List<SpreadDef> spreads;
  final math.Random _random;

  _Drag? _drag;
  final Map<String, TablePose> _overrides = {};
  final Map<String, double> _lift = {};
  final Map<String, Wobble> _wobble = {};
  (String, Peel)? _peel;
  FanLayout? _fanDraft;
  _Radial? _radial;
  List<String>? _union;
  bool _busy = false;
  int? hotSlot;
  (String, Duration)? _pendingCardTap;
  Duration _now = Duration.zero;

  static const looseDoubleTap = Duration(milliseconds: 280);

  // ---------- movimiento: de donde nace y a donde va cada pieza ----------
  //
  // El estado de la mesa salta de golpe (una carta esta o no esta). Para que se
  // VEA viajar, el director anota de donde sale lo que aparece y a donde va lo
  // que se marcha, y la vista lo anima. Se consume al leerlo.
  final Map<String, ({TablePose from, Duration delay})> _births = {};
  final Map<String, TablePose> _exits = {};

  /// Barajado en curso, para que la vista lo represente. `epoch` cambia en
  /// cada barajado, aunque sea del mismo monton y con el mismo estilo.
  ({String pid, String style, int epoch})? shuffling;
  int _shuffleEpoch = 0;

  ({TablePose from, Duration delay})? takeBirth(String id) =>
      _births.remove(id);
  TablePose? takeExit(String id) => _exits.remove(id);

  void _born(String id, TablePose from, [Duration delay = Duration.zero]) =>
      _births[id] = (from: from, delay: delay);

  TablePose _pilePose(PileLayout p) =>
      TablePose(p.x, p.y, rot: p.rot, scale: TableGeometry.deckScale);

  /// Todo lo que hay fuera del mazo vuelve volando al monton `pid`.
  void _allExitTo(String pid) {
    final target = _pile(pid);
    if (target == null) return;
    for (final c in table.cards) {
      _exits['card:${c.slug}'] = _pilePose(target);
    }
  }

  TableState get table => ops.table;
  bool get busy => _busy;
  RadialLayout? get radial => _radial?.layout;
  String? get radialTitle => _radial?.title;
  int? get radialHot => _radial?.hot;
  List<String>? get unionOrder => _union;

  SpreadDef? get spread {
    final slug = table.spread;
    for (final s in spreads) {
      if (s.slug == slug) return s;
    }
    return null;
  }

  FanLayout? get fan => _fanDraft ?? table.fan;

  /// El abanico sigue al dedo: se dibuja sin animar el despliegue.
  bool get fanDragging => _fanDraft != null;

  void setViewport(Size size) => camera.fit(size);

  // ---------- lo que se dibuja ----------

  /// Todas las piezas, de abajo arriba (orden de pintado).
  List<PieceView> pieces() {
    final out = <PieceView>[];
    final server = table.server;
    final open = server?.deck;
    final shelf = decks.where((d) => d.slug != open).toList();
    for (var i = 0; i < shelf.length; i++) {
      final id = 'shelf:${shelf[i].slug}';
      out.add(
        PieceView(
          id: id,
          kind: PieceKind.shelfDeck,
          pose:
              _overrides[id] ??
              shelfPose(decks.indexOf(shelf[i]), decks.length),
          lift: _lift[id] ?? 0,
          dragging: _overrides.containsKey(id),
          count: shelf[i].cardCount,
          label: shelf[i].name,
        ),
      );
    }
    final f = fan;
    for (final p in table.piles) {
      final id = 'pile:${p.pid}';
      final count = server?.piles[p.pid]?.count ?? 0;
      out.add(
        _withWobble(
          PieceView(
            id: id,
            kind: PieceKind.pile,
            pose:
                _overrides[id] ??
                TablePose(p.x, p.y, rot: p.rot, scale: TableGeometry.deckScale),
            lift: _lift[id] ?? 0,
            dragging: _overrides.containsKey(id),
            // con el abanico abierto, sus cartas estan en la mesa y la caja queda vacia
            count: f?.pid == p.pid ? 0 : count,
            label: p.pid == table.activePid ? _deckName(open) : 'Montón',
          ),
        ),
      );
    }
    if (f != null) {
      final positions = server?.piles[f.pid]?.positions ?? const <int>[];
      final poses = fanPoses(f.start, f.end, positions.length);
      for (var i = 0; i < positions.length; i++) {
        out.add(
          PieceView(
            id: 'fan:${f.pid}:${positions[i]}',
            kind: PieceKind.fanCard,
            pose: poses[i],
            fanPosition: positions[i],
          ),
        );
      }
    }
    final dragged = _drag?.id;
    final cards = [...table.cards]
      ..sort(
        (a, b) => (a.slug == dragged ? 1 : 0) - (b.slug == dragged ? 1 : 0),
      );
    for (final c in cards) {
      final id = 'card:${c.slug}';
      final peel = _peel != null && _peel!.$1 == c.slug ? _peel!.$2 : null;
      out.add(
        _withWobble(
          PieceView(
            id: id,
            kind: PieceKind.card,
            pose:
                _overrides[id] ??
                TablePose(c.x, c.y, rot: c.rot, scale: c.scale),
            lift: (_lift[id] ?? 0) + (peel?.lift ?? 0),
            dragging: _overrides.containsKey(id),
            card: c,
            peelAngle: peel?.angle ?? 0,
            peelHingeX: peel?.hingeX ?? 0,
          ),
        ),
      );
    }
    return out;
  }

  PieceView _withWobble(PieceView v) {
    final w = _wobble[v.id];
    if (w == null) return v;
    return PieceView(
      id: v.id,
      kind: v.kind,
      pose: v.pose,
      lift: v.lift,
      tiltX: w.tx,
      tiltY: w.ty,
      count: v.count,
      card: v.card,
      fanPosition: v.fanPosition,
      peelAngle: v.peelAngle,
      peelHingeX: v.peelHingeX,
      label: v.label,
      dragging: v.dragging,
    );
  }

  String _deckName(String? slug) {
    for (final d in decks) {
      if (d.slug == slug) return d.name;
    }
    return 'Mazo';
  }

  /// El bordado «Interpretar» se puede tocar: tirada completa y desvelada.
  bool get readyToInterpret {
    final s = spread;
    return s != null && !_busy && table.readyToInterpret(s);
  }

  static const Offset embroideryAt = Offset(300, 716);

  /// El sello de la pregunta, abajo a la izquierda del paño (como el prototipo).
  static const Offset sealAt = Offset(88, 712);
  static const double sealRadius = 42;

  // ---------- que hay bajo el dedo ----------
  Hit hitAt(Offset tablePoint) {
    final list = pieces();
    for (final v in list.reversed) {
      final pad = 24.0;
      final w = TableGeometry.cardW, h = TableGeometry.cardH;
      final local = localNormalized(
        v.pose,
        tablePoint,
        w: w + pad * 2 / v.pose.scale,
        h: h + pad * 2 / v.pose.scale,
      );
      if (local.dx.abs() > 1 || local.dy.abs() > 1) continue;
      final exact = localNormalized(v.pose, tablePoint);
      switch (v.kind) {
        case PieceKind.shelfDeck:
          return HitDeck(
            pid: v.id.substring(6),
            local: exact,
            count: v.count,
            inPlay: false,
          );
        case PieceKind.pile:
          return HitDeck(pid: v.id.substring(5), local: exact, count: v.count);
        case PieceKind.fanCard:
          return HitCard(slug: v.id, local: exact, faceUp: false, inFan: true);
        case PieceKind.card:
          return HitCard(
            slug: v.card!.slug,
            local: exact,
            faceUp: v.card!.faceUp,
          );
      }
    }
    // el sello esta encima del paño pero debajo de las cartas: se mira despues
    if (table.seal != null &&
        (tablePoint - sealAt).distance <= sealRadius + 8) {
      return const HitSeal();
    }
    if (readyToInterpret &&
        (tablePoint - embroideryAt).dx.abs() < 90 &&
        (tablePoint - embroideryAt).dy.abs() < 28) {
      return const HitEmbroidery();
    }
    final inside =
        tablePoint.dx >= 0 &&
        tablePoint.dx <= TableGeometry.width &&
        tablePoint.dy >= 0 &&
        tablePoint.dy <= TableGeometry.height;
    return inside ? const HitSurface() : const HitNothing();
  }

  // ---------- entrada de toques (coordenadas de pantalla) ----------
  void pointerDown(int pointer, Offset screen, Duration time) {
    _now = time;
    final r = _radial;
    if (r != null && !grammar.active) {
      // radial abierto para tocar: tocar una opcion la elige, tocar fuera lo cierra
      final i = r.layout.tappedAt(screen);
      _radial = null;
      // el centro deshace el ultimo gesto si todavia se puede; si no, cierra
      if (i == null &&
          (screen - r.layout.center).distance < 24 &&
          ops.canUndo) {
        _run(() async {
          if (await ops.undo()) effects.toast('Deshecho');
        });
      }
      if (i != null) _run(() => r.onPick(r.layout.items[i].id));
      notifyListeners();
      return;
    }
    _apply(grammar.down(pointer, screen, time, hitAt(camera.toTable(screen))));
  }

  void pointerMove(int pointer, Offset screen, Duration time) {
    _now = time;
    _apply(grammar.move(pointer, screen, time));
  }

  void pointerUp(int pointer, Offset screen, Duration time) {
    _now = time;
    _apply(grammar.up(pointer, screen, time));
  }

  void pointerCancel(int pointer) => _apply(grammar.cancel(pointer));

  /// Hay algo esperando al reloj (mantener, doble toque) o en movimiento.
  /// Con la mesa quieta no se piden frames: la bateria lo agradece.
  bool get needsTicks =>
      grammar.deadline != null ||
      _pendingCardTap != null ||
      _wobble.isNotEmpty ||
      _drag != null;

  /// Un frame: temporizadores de la gramatica, camara y peso de las cartas.
  /// Devuelve true si hay que repintar.
  bool tick(Duration time, Duration dt) {
    _now = time;
    _apply(grammar.tick(time));
    final pending = _pendingCardTap;
    if (pending != null && time - pending.$2 >= looseDoubleTap) {
      _pendingCardTap = null;
      _returnToPile(pending.$1);
    }
    var moving = camera.step(dt);
    _wobble.removeWhere((_, w) => !w.step());
    moving |= _wobble.isNotEmpty;
    return moving;
  }

  // ---------- intenciones ----------
  void _apply(List<Intent> intents) {
    for (final i in intents) {
      switch (i) {
        case TapIntent(:final hit, :final position):
          _tap(hit, position);
        case ResetCameraIntent():
          camera.reset();
        case OpenRadialIntent(:final hit, :final position):
          _openRadialFor(hit, position);
        case RadialMoveIntent(:final position):
          final r = _radial;
          if (r != null) r.hot = r.layout.hotAt(position);
        case RadialReleaseIntent(:final position):
          final r = _radial;
          final hot = r?.layout.hotAt(position);
          if (r != null && hot != null) {
            _radial = null;
            _run(() => r.onPick(r.layout.items[hot].id));
          }
        // soltar en el centro deja el radial abierto para tocar
        case CloseCircleIntent():
          _run(_closeCircle);
        case DragStartIntent(
          :final kind,
          :final hit,
          :final start,
          :final position,
        ):
          _dragStart(kind, hit, start, position);
        case DragUpdateIntent(:final kind, :final position, :final delta):
          _dragUpdate(kind, position, delta);
        case DragEndIntent(:final kind, :final position, :final cancelled):
          _dragEnd(kind, position, cancelled);
        case PinchStartIntent(:final a, :final b):
          camera.startPinch(a, b);
        case PinchUpdateIntent(:final a, :final b):
          camera.updatePinch(a, b);
        case PinchEndIntent():
          break;
      }
    }
    if (intents.isNotEmpty) notifyListeners();
  }

  /// Ejecuta una accion que habla con el servidor: una a la vez, y los errores
  /// se dicen (un 402 abre la tienda).
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on Object catch (e) {
      if (isCreditsRequired(e)) {
        effects.creditsRequired();
      } else {
        effects.error(e);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Un gesto que se deshace entero, aunque haga varias operaciones.
  Future<void> _undoable(Future<void> Function() gesture) async {
    ops.beginUndoable();
    try {
      await gesture();
    } finally {
      ops.commitUndoable();
    }
  }

  // ---------- tocar ----------
  void _tap(Hit hit, Offset screen) {
    if (_busy) return;
    switch (hit) {
      case HitSurface():
        if (_union != null) _union = null;
      case HitEmbroidery():
        if (readyToInterpret) effects.openInterpretation();
      case HitSeal():
        final seal = table.seal;
        if (seal != null) effects.openSealInfo(seal);
      case HitDeck(inPlay: false, :final pid):
        _run(() => _openDeck(pid, TableGeometry.homeSpot));
      case HitDeck(:final pid, :final count):
        if (_union != null) return _pickUnion(pid);
        if (count == 0 && fan?.pid != pid) {
          return effects.toast('Este montón está vacío');
        }
        _autoFan(pid);
      case HitCard(inFan: true, :final slug):
        _run(() => _takeFromFan(slug));
      case HitCard(:final slug):
        final c = table.card(slug);
        if (c == null) return;
        if (c.slot != null || c.host != null) return _revealOrRead(c);
        // suelta: un toque la devuelve a su monton; dos, la desvelan
        final pending = _pendingCardTap;
        if (pending != null && pending.$1 == slug) {
          _pendingCardTap = null;
          return _revealOrRead(c);
        }
        _pendingCardTap = (slug, _now);
      case HitNothing():
        break;
    }
  }

  void _revealOrRead(TableCard c) {
    if (c.faceUp) return effects.openReading(c);
    ops.arrange((s) => s.updateCard(c.slug, (k) => k.copyWith(faceUp: true)));
    effects.flipped(table.card(c.slug)!);
  }

  // ---------- mazos ----------
  bool get _tableBusy =>
      table.cards.isNotEmpty || table.fan != null || table.piles.length > 1;

  Future<void> _openDeck(String deck, Offset at) async {
    if (table.hasTable && _tableBusy) {
      return effects.toast(
        'Recoge las cartas y une los montones antes de cambiar de mazo',
      );
    }
    final shelf = decks.indexWhere((d) => d.slug == deck);
    await ops.openDeck(deck);
    final pid = table.activePid;
    if (pid != null && shelf >= 0) {
      _born('pile:$pid', shelfPose(shelf, decks.length));
    }
    if (pid != null) {
      ops.arrange(
        (s) => s.copyWith(
          piles: [
            for (final p in s.piles) p.pid == pid ? p.moved(at.dx, at.dy) : p,
          ],
        ),
      );
    }
    effects.toast(
      '${_deckName(deck)} en juego. Tócalo para extenderlo; mantenlo pulsado para lo demás.',
    );
  }

  PileLayout? _pile(String pid) {
    for (final p in table.piles) {
      if (p.pid == pid) return p;
    }
    return null;
  }

  int _count(String pid) => table.server?.piles[pid]?.count ?? 0;

  void _autoFan(String pid) {
    final p = _pile(pid);
    if (p == null || _count(pid) == 0) return;
    final y = p.y
        .clamp(TableGeometry.shelfY + 90, TableGeometry.fanY)
        .toDouble();
    final endX = p.x > TableGeometry.width / 2
        ? 58.0
        : TableGeometry.width - 58;
    ops.arrange(
      (s) => s.copyWith(
        fan: () =>
            FanLayout(pid: pid, start: Offset(p.x, y), end: Offset(endX, y)),
      ),
      undoable: true,
    );
  }

  Future<void> _takeFromFan(String fanId) async {
    final parts = fanId.split(':');
    final pid = parts[1], pos = int.parse(parts[2]);
    final from = _poseOf(fanId);
    final card = await ops.take(pid, pos);
    if (from != null) _born('card:${card.slug}', from);
    if (_count(pid) == 0) ops.arrange((s) => s.copyWith(fan: () => null));
    final sp = spread;
    final empty = sp == null ? null : _firstEmptySlot(sp);
    if (sp != null && empty != null) {
      _place(card.slug, sp, empty);
    } else {
      ops.arrange(
        (s) => s.updateCard(
          card.slug,
          (k) => k.copyWith(
            y: k.y - 150,
            scale: sp?.cardScale ?? TableGeometry.freeScale,
            rot: k.rot + _random.nextDouble() * 10 - 5,
          ),
        ),
      );
    }
  }

  int? _firstEmptySlot(SpreadDef sp) {
    for (var i = 0; i < sp.cardCount; i++) {
      if (table.cardInSlot(i) == null) return i;
    }
    return null;
  }

  void _place(String slug, SpreadDef sp, int slot) {
    final pose = slotPose(sp, slot);
    ops.arrange(
      (s) => s
          .putInSlot(slug, slot)
          .updateCard(
            slug,
            (k) => k.copyWith(
              x: pose.x,
              y: pose.y,
              rot: pose.rot,
              scale: pose.scale,
              aside: false,
            ),
          ),
    );
  }

  Future<void> _deal(String pid) async {
    final sp = spread;
    if (sp == null) return _openSpreadRadial(pid, then: () => _deal(pid));
    final empty = [
      for (var i = 0; i < sp.cardCount; i++)
        if (table.cardInSlot(i) == null) i,
    ];
    if (empty.isEmpty) return effects.toast('La tirada ya está completa');
    var dealt = 0;
    for (final slot in empty) {
      final positions = table.server?.piles[pid]?.positions ?? const [];
      if (positions.isEmpty) {
        return effects.toast('No quedan cartas en este montón');
      }
      final pile = _pile(pid);
      final card = await ops.take(pid, positions.first);
      if (pile != null) {
        _born(
          'card:${card.slug}',
          _pilePose(pile),
          Duration(milliseconds: 110 * dealt++),
        );
      }
      _place(card.slug, sp, slot);
    }
  }

  Offset _freeSpot(PileLayout near) {
    final w = TableGeometry.cardW * TableGeometry.deckScale * 1.9;
    for (final dx in [-w, w, -2 * w, 2 * w]) {
      final x = (near.x + dx).clamp(70.0, TableGeometry.width - 70);
      if (table.piles.every(
        (q) =>
            (Offset(q.x, q.y) - Offset(x, near.y)).distance >
            TableGeometry.cardW * TableGeometry.deckScale * 1.2,
      )) {
        return Offset(x, near.y);
      }
    }
    return Offset(
      near.x.clamp(70.0, TableGeometry.width - 70),
      (near.y - TableGeometry.cardH * TableGeometry.deckScale * 1.3).clamp(
        TableGeometry.shelfY + 70,
        TableGeometry.height - 70,
      ),
    );
  }

  int _cutSize(int n) =>
      (n * (.3 + _random.nextDouble() * .4)).round().clamp(1, n - 1);

  Future<void> _autoCut(String pid) async {
    final src = _pile(pid);
    if (src == null) return;
    final spot = _freeSpot(src);
    await _undoable(() async {
      final np = await ops.cut(pid, _cutSize(_count(pid)));
      _born('pile:$np', _pilePose(src));
      ops.arrange(
        (s) => s.copyWith(
          piles: [
            for (final p in s.piles)
              p.pid == np ? p.moved(spot.dx, spot.dy) : p,
          ],
        ),
      );
    });
    effects.toast(
      'Corte hecho. Mantén pulsado un montón para Unir, o arrástralo sobre otro.',
    );
  }

  /// Apila de abajo arriba: el servidor recibe de arriba abajo. El monton
  /// principal, si esta en la lista, es el que se queda.
  Future<void> _stack(List<String> bottomToTop) async {
    if (table.fan != null) ops.arrange((s) => s.copyWith(fan: () => null));
    final keeper = bottomToTop.contains(table.activePid)
        ? table.activePid!
        : bottomToTop.first;
    final base = _pile(bottomToTop.first)!;
    for (final pid in bottomToTop) {
      if (pid != keeper) _exits['pile:$pid'] = _pilePose(base);
    }
    await ops.merge(bottomToTop.reversed.toList(), keeper);
    ops.arrange(
      (s) => s.copyWith(
        piles: [
          for (final p in s.piles)
            p.pid == keeper ? p.moved(base.x, base.y, base.rot) : p,
        ],
      ),
    );
    _union = null;
  }

  void _pickUnion(String pid) {
    final u = _union!;
    if (u.contains(pid)) return;
    u.add(pid);
    if (u.length == table.piles.length) {
      _run(() async {
        await _undoable(() => _stack(List.of(u)));
        effects.toast('Unidos en el orden que elegiste');
      });
    }
  }

  Future<void> _autoUnion() async {
    final active = table.activePid!;
    // corte clasico: lo que quedo abajo pasa arriba
    final others = [
      for (final p in table.piles)
        if (p.pid != active) p.pid,
    ].reversed;
    await _undoable(() => _stack([...others, active]));
    effects.toast('Unidos: lo de abajo pasa arriba');
  }

  /// Recoger todo: une los montones y devuelve las cartas. Se deshace entero.
  Future<void> _collectAll() => _undoable(() async {
    if (table.fan != null) ops.arrange((s) => s.copyWith(fan: () => null));
    if (table.piles.length > 1) {
      final active = table.activePid!;
      await _stack([
        active,
        for (final p in table.piles)
          if (p.pid != active) p.pid,
      ]);
    }
    _allExitTo(table.activePid!);
    await ops.gather(table.activePid!);
    ops.arrange((s) => s.copyWith(spread: () => null, seal: () => null));
  });

  Future<void> _closeCircle() async {
    // sin interpretar tambien se guarda (decision del 30-sep): lo que haya en la mesa
    if (!table.cards.any((c) => !c.aside)) {
      return effects.toast('No hay cartas sobre el paño que guardar');
    }
    await ops.closeCircle();
    effects.toast('Círculo cerrado. La lectura quedó guardada en Lecturas.');
  }

  // ---------- cartas ----------
  void _returnToPile(String slug) {
    final c = table.card(slug);
    if (c == null || table.piles.isEmpty) return;
    final candidates = table.piles.where((p) => fan?.pid != p.pid).toList();
    final pool = candidates.isEmpty ? table.piles : candidates;
    final target = pool.reduce(
      (a, b) =>
          (Offset(a.x, a.y) - Offset(c.x, c.y)).distance <=
              (Offset(b.x, b.y) - Offset(c.x, c.y)).distance
          ? a
          : b,
    );
    _exits['card:$slug'] = _pilePose(target);
    _run(() => _undoable(() => ops.giveBack(slug, target.pid)));
  }

  void _setAside(String slug) {
    final aside = table.cards.where((k) => k.aside).length;
    final open = table.server?.deck;
    final other = decks.indexWhere((d) => d.slug != open);
    final home = other < 0
        ? const TablePose(420, 84)
        : shelfPose(other, decks.length);
    final x = home.x + (home.x + 125 < TableGeometry.width - 40 ? 125 : -125);
    ops.arrange(
      (s) => s.updateCard(
        slug,
        (k) => k.copyWith(
          slot: () => null,
          host: () => null,
          aside: true,
          x: x + aside * 3,
          y: home.y - aside * 2,
          rot: aside.isOdd ? 4 : -3,
          scale: TableGeometry.deckScale,
        ),
      ),
      undoable: true,
    );
    effects.toast('Apartada en el estante: no cuenta para la lectura');
  }

  void _turn(String slug) {
    ops.arrange(
      (s) => s.updateCard(slug, (k) => k.copyWith(turned: !k.turned)),
      undoable: true,
    );
    final c = table.card(slug)!;
    effects.toast(
      c.faceUp
          ? (c.reversed ? 'Ahora está invertida' : 'Ahora está al derecho')
          : 'Girada: se desvelará en el otro sentido',
    );
  }

  void _revealAll() {
    final hidden = table.cards.where((c) => !c.aside && !c.faceUp).toList()
      ..sort((a, b) => (a.slot ?? 99).compareTo(b.slot ?? 99));
    ops.arrange((s) {
      var t = s;
      for (final c in hidden) {
        t = t.updateCard(c.slug, (k) => k.copyWith(faceUp: true));
      }
      return t;
    });
    for (final c in hidden) {
      effects.flipped(table.card(c.slug)!);
    }
  }

  // ---------- radiales ----------
  void _openRadial(
    Offset screen,
    String title,
    List<RadialItem> items,
    Future<void> Function(String) onPick,
  ) {
    _radial = _Radial(
      RadialLayout.at(screen, camera.viewport, items),
      title,
      onPick,
    );
  }

  void closeRadial() {
    _radial = null;
    notifyListeners();
  }

  Offset _screenOf(TablePose p) => camera.toScreen(p.offset);

  void _openRadialFor(Hit hit, Offset screen) {
    switch (hit) {
      case HitSurface():
        final reading = table.cards.any((c) => c.slot != null && c.faceUp);
        _openRadial(
          screen,
          'Paño',
          RadialMenus.cloth(
            canSeal: table.seal == null && !table.cards.any((c) => c.faceUp),
            canGather:
                table.hasTable &&
                (table.cards.isNotEmpty ||
                    table.fan != null ||
                    table.piles.length > 1),
            hasReadings: true,
            soundOn: true,
          ),
          (id) async => switch (id) {
            'seal' => effects.openSeal(),
            'hist' => effects.openHistory(),
            'sound' => effects.toggleSound(),
            'all' when reading => _openRadial(
              screen,
              'Recoger todo',
              RadialMenus.gatherWithReading,
              (b) => b == 'close' ? _closeCircle() : _collectAll(),
            ),
            'all' => await _collectAll(),
            _ => null,
          },
        );
      case HitDeck(inPlay: true, :final pid):
        final count = _count(pid);
        _openRadial(
          screen,
          '${pid == table.activePid ? _deckName(table.server?.deck) : 'Montón'} · $count',
          RadialMenus.deck(
            count: count,
            cardsOut: table.cards.isNotEmpty,
            piles: table.piles.length,
          ),
          (id) async => switch (id) {
            'shuffle' => _openShuffleRadial(pid, screen),
            'cut' => await _autoCut(pid),
            'fan' => _autoFan(pid),
            'deal' => await _deal(pid),
            'collect' => await _collectAll(),
            'spread' => _openSpreadRadial(pid),
            'union' => _openRadial(
              screen,
              'Unir montones',
              RadialMenus.union,
              (b) async => b == 'order' ? _union = [] : await _autoUnion(),
            ),
            _ => null,
          },
        );
      case HitCard(inFan: true, :final slug):
        _openRadial(screen, 'Abanico', RadialMenus.fan, (id) async {
          final pid = slug.split(':')[1];
          switch (id) {
            case 'take':
              await _takeFromFan(slug);
            case 'gather':
              ops.arrange((s) => s.copyWith(fan: () => null));
            case 'shuffle':
              ops.arrange((s) => s.copyWith(fan: () => null));
              _openShuffleRadial(pid, screen);
          }
        });
      case HitCard(:final slug):
        final c = table.card(slug);
        if (c == null) return;
        final hidden = table.cards.where((k) => !k.aside && !k.faceUp).length;
        final sp = spread;
        final title = c.faceUp
            ? (c.face.nameEs ?? c.face.name ?? '')
            : c.slot != null && sp != null
            ? '${c.slot! + 1} · ${sp.slots[c.slot!].name}'
            : c.aside
            ? 'Apartada'
            : 'Fuera de la tirada';
        _openRadial(
          screen,
          title,
          RadialMenus.card(
            faceUp: c.faceUp,
            aside: c.aside,
            canRevealAll: sp != null && hidden > 1,
          ),
          (id) async => switch (id) {
            'read' => effects.openReading(c),
            'reveal' => _revealOrRead(c),
            'turn' => _turn(slug),
            'collect' => _returnToPile(slug),
            'aside' => _setAside(slug),
            'reveal-all' => _revealAll(),
            _ => null,
          },
        );
      case HitDeck() || HitEmbroidery() || HitSeal() || HitNothing():
        break;
    }
  }

  void _openShuffleRadial(String pid, Offset screen) {
    _openRadial(screen, 'Barajar', RadialMenus.shuffle, (style) async {
      shuffling = (pid: pid, style: style, epoch: ++_shuffleEpoch);
      notifyListeners();
      await ops.shuffle(pid, style: style);
      effects.shuffled(pid, style);
      effects.toast(
        table.piles.length > 1
            ? 'Montón barajado. Los demás no se tocan.'
            : 'Barajado. El servidor fija el orden; tú eliges qué posiciones sacar.',
      );
    });
    notifyListeners();
  }

  void _openSpreadRadial(String pid, {Future<void> Function()? then}) {
    final pile = _pile(pid);
    final at = pile == null
        ? camera.viewport.center(Offset.zero)
        : _screenOf(TablePose(pile.x, pile.y));
    _openRadial(
      at,
      'Tirada',
      [
        for (final s in spreads)
          RadialItem(s.slug, s.name, current: s.slug == table.spread),
      ],
      (slug) async {
        _applySpread(slug);
        if (then != null) await then();
      },
    );
    notifyListeners();
  }

  /// Cambiar de tirada: las cartas colocadas conservan su hueco si existe en
  /// la nueva y van a su sitio; las que sobran quedan libres.
  void _applySpread(String slug) {
    final sp = spreads.firstWhere((s) => s.slug == slug);
    ops.arrange(
      (s) => s.copyWith(
        spread: () => slug,
        cards: [
          for (final c in s.cards)
            if (c.slot == null)
              c
            else if (c.slot! >= sp.cardCount)
              c.copyWith(slot: () => null)
            else
              () {
                final p = slotPose(sp, c.slot!);
                return c.copyWith(x: p.x, y: p.y, rot: p.rot, scale: p.scale);
              }(),
        ],
      ),
      undoable: true,
    );
  }

  // ---------- arrastrar ----------
  String _pieceId(Hit hit) => switch (hit) {
    HitCard(inFan: true, :final slug) => slug,
    HitCard(:final slug) => 'card:$slug',
    HitDeck(inPlay: false, :final pid) => 'shelf:$pid',
    HitDeck(:final pid) => 'pile:$pid',
    _ => '',
  };

  TablePose? _poseOf(String id) {
    for (final v in pieces()) {
      if (v.id == id) return v.pose;
    }
    return null;
  }

  void _dragStart(DragKind kind, Hit hit, Offset start, Offset screen) {
    final at = camera.toTable(screen);
    switch (kind) {
      case DragKind.orbit:
        _drag = _Drag(kind, '', Offset.zero);
      case DragKind.peel:
        final c = table.card((hit as HitCard).slug)!;
        _peel = (c.slug, Peel(startLocal: hit.local, cardScale: c.scale));
        _drag = _Drag(kind, 'card:${c.slug}', Offset.zero);
      case DragKind.fan:
        final pid = (hit as HitDeck).pid;
        final p = _pile(pid)!;
        _fanDraft = FanLayout(pid: pid, start: Offset(p.x, p.y), end: at);
        _drag = _Drag(kind, 'pile:$pid', Offset.zero);
      case DragKind.cut:
        final pid = (hit as HitDeck).pid;
        final src = _pile(pid)!;
        final d = _Drag(kind, '', Offset(src.x, src.y) - camera.toTable(start))
          ..cutSource = pid
          ..ready = false;
        _drag = d;
        _busy = true;
        ops.beginUndoable();
        d.gesture = true;
        ops
            .cut(pid, _cutSize(hit.count))
            .then(
              (np) {
                d
                  ..id = 'pile:$np'
                  ..ready = true;
                _lift[d.id] = 40;
                _moveDragged(d, d.last ?? at);
                notifyListeners();
              },
              onError: (Object e) {
                _drag = null;
                ops.commitUndoable();
                effects.error(e);
              },
            )
            .whenComplete(() {
              _busy = false;
              notifyListeners();
            });
      case DragKind.move:
        final id = _pieceId(hit);
        final d = _Drag(kind, id, Offset.zero);
        _drag = d;
        if (hit is HitCard && hit.inFan) {
          // sale del abanico al empezar a arrastrarla
          d.ready = false;
          final parts = hit.slug.split(':');
          ops.beginUndoable();
          d.gesture = true;
          ops
              .take(parts[1], int.parse(parts[2]))
              .then(
                (card) {
                  if (_count(parts[1]) == 0) {
                    ops.arrange((s) => s.copyWith(fan: () => null));
                  }
                  d
                    ..id = 'card:${card.slug}'
                    ..origin = TablePose(
                      card.x,
                      card.y,
                      rot: card.rot,
                      scale: card.scale,
                    )
                    ..offset = Offset.zero
                    ..ready = true;
                  _lift[d.id] = 64;
                  _moveDragged(d, d.last ?? at);
                  notifyListeners();
                },
                onError: (Object e) {
                  _drag = null;
                  // cerrar dos veces no pasa nada: el segundo no encuentra gesto
                  ops.commitUndoable();
                  effects.error(e);
                },
              );
          return;
        }
        final pose = _poseOf(id);
        if (pose == null) {
          _drag = null;
          return;
        }
        d
          ..origin = pose
          ..offset = pose.offset - camera.toTable(start)
          ..originSlot = hit is HitCard ? table.card(hit.slug)?.slot : null;
        _lift[id] = 64;
        _moveDragged(d, at);
    }
  }

  void _moveDragged(_Drag d, Offset at) {
    final base = _overrides[d.id] ?? _poseOf(d.id);
    if (base == null) return;
    final p = at + d.offset;
    _overrides[d.id] = TablePose(p.dx, p.dy, rot: base.rot, scale: base.scale);
  }

  void _dragUpdate(DragKind kind, Offset screen, Offset delta) {
    final d = _drag;
    if (d == null) return;
    final at = camera.toTable(screen);
    final prev = d.last ?? at;
    d.last = at;
    switch (kind) {
      case DragKind.orbit:
        final v = camera.orbitBy(delta);
        d.offset = Offset(v.vyaw, v.vtheta);
      case DragKind.peel:
        final c = table.card(_peel!.$1)!;
        _peel!.$2.update(
          localNormalized(TablePose(c.x, c.y, rot: c.rot, scale: c.scale), at),
        );
      case DragKind.fan:
        _fanDraft = _fanDraft!.to(at);
      case DragKind.cut || DragKind.move:
        if (!d.ready) return;
        _moveDragged(d, at);
        (_wobble[d.id] ??= Wobble()).push(at - prev);
        final sp = spread;
        hotSlot = d.id.startsWith('card:') && sp != null
            ? nearestSlot(sp, _overrides[d.id]!.offset)
            : null;
    }
  }

  void _dragEnd(DragKind kind, Offset screen, bool cancelled) {
    final gesture = _drag?.gesture ?? false;
    try {
      _dropDragged(kind, cancelled);
    } finally {
      if (gesture) ops.commitUndoable();
    }
  }

  void _dropDragged(DragKind kind, bool cancelled) {
    final d = _drag;
    _drag = null;
    hotSlot = null;
    if (d == null) return;
    _wobble[d.id]?.release();
    _lift.remove(d.id);
    switch (kind) {
      case DragKind.orbit:
        if (!cancelled) {
          camera.releaseOrbit(vyaw: d.offset.dx, vtheta: d.offset.dy);
        }
      case DragKind.peel:
        final (slug, peel) = _peel!;
        _peel = null;
        if (!cancelled && peel.commits) {
          ops.arrange(
            (s) => s.updateCard(
              slug,
              (k) => k.copyWith(faceUp: true, dir: -peel.corner.toInt()),
            ),
          );
          effects.flipped(table.card(slug)!);
        }
      case DragKind.fan:
        final draft = _fanDraft!;
        _fanDraft = null;
        if (!cancelled && draft.length >= 90) {
          ops.arrange((s) => s.copyWith(fan: () => draft), undoable: true);
        }
      case DragKind.cut:
        final pose = _overrides.remove(d.id);
        if (!d.ready || pose == null) return;
        final np = d.id.substring(5), src = _pile(d.cutSource!)!;
        if (cancelled ||
            (pose.offset - Offset(src.x, src.y)).distance <
                TableGeometry.cardW * TableGeometry.deckScale * .9) {
          // soltado encima: el corte se deshace y el orden queda como estaba
          _run(() => ops.merge([np, src.pid], src.pid));
        } else {
          ops.arrange(
            (s) => s.copyWith(
              piles: [
                for (final p in s.piles)
                  p.pid == np ? p.moved(pose.x, pose.y) : p,
              ],
            ),
          );
        }
      case DragKind.move:
        final pose = _overrides.remove(d.id);
        if (!d.ready || pose == null) return;
        if (cancelled) return;
        if (d.id.startsWith('card:')) {
          _dropCard(d.id.substring(5), pose, d);
        } else if (d.id.startsWith('pile:')) {
          _dropPile(d.id.substring(5), pose);
        } else if (d.id.startsWith('shelf:') && pose.y > TableGeometry.shelfY) {
          _run(() => _openDeck(d.id.substring(6), pose.offset));
        }
    }
  }

  void _dropCard(String slug, TablePose pose, _Drag d) {
    final sp = spread;
    final slot = sp == null ? null : nearestSlot(sp, pose.offset);
    if (sp != null && slot != null) {
      final other = table.cardInSlot(slot);
      final origin = d.origin;
      ops.arrange((s) {
        var t = s.putInSlot(slug, slot);
        final target = slotPose(sp, slot);
        t = t.updateCard(
          slug,
          (k) => k.copyWith(
            x: target.x,
            y: target.y,
            rot: target.rot,
            scale: target.scale,
            aside: false,
          ),
        );
        if (other != null && other.slug != slug) {
          // la desplazada ocupa el hueco que se libera o el sitio de donde vino la otra
          final back = d.originSlot != null
              ? slotPose(sp, d.originSlot!)
              : origin;
          if (back != null) {
            t = t.updateCard(
              other.slug,
              (k) => k.copyWith(
                x: back.x,
                y: back.y,
                rot: back.rot,
                scale: sp.cardScale,
              ),
            );
          }
        }
        return t;
      }, undoable: true);
      return effects.toast('${slot + 1} · ${sp.slots[slot].name}');
    }
    // soltada junto a una carta de la tirada (sin caer en su hueco): aclaratoria
    if (sp != null && pose.y >= TableGeometry.shelfY) {
      for (final h in table.cards) {
        if (h.slug == slug || h.slot == null) continue;
        if ((Offset(h.x, h.y) - pose.offset).distance <
            TableGeometry.cardH * h.scale * 1.05) {
          final n = table
              .clarifiersOf(h.slug)
              .where((k) => k.slug != slug)
              .length;
          final at = clarifierPose(
            TablePose(h.x, h.y, rot: h.rot, scale: h.scale),
            n,
          );
          ops.arrange(
            (s) => s
                .clarify(slug, h.slug)
                .updateCard(
                  slug,
                  (k) => k.copyWith(
                    x: at.x,
                    y: at.y,
                    rot: at.rot,
                    scale: at.scale,
                  ),
                ),
            undoable: true,
          );
          return effects.toast(
            'Aclaratoria de ${h.slot! + 1} · ${sp.slots[h.slot!].name}',
          );
        }
      }
    }
    final aside = pose.y < TableGeometry.shelfY;
    ops.arrange(
      (s) => s.updateCard(
        slug,
        (k) => k.copyWith(
          slot: () => null,
          host: () => null,
          aside: aside,
          x: pose.x.clamp(40, TableGeometry.width - 40),
          y: pose.y.clamp(40, TableGeometry.height - 40),
          scale: aside
              ? TableGeometry.deckScale
              : (sp?.cardScale ?? TableGeometry.freeScale),
        ),
      ),
      undoable: true,
    );
    if (aside) {
      effects.toast('Apartada en el estante: no cuenta para la lectura');
    } else if (sp != null) {
      effects.toast('Fuera de la tirada: no cuenta para la lectura');
    }
  }

  void _dropPile(String pid, TablePose pose) {
    // soltarlo sobre otro monton los une: el soltado queda encima
    for (final q in table.piles) {
      if (q.pid == pid || q.pid == fan?.pid) continue;
      if ((Offset(q.x, q.y) - pose.offset).distance <
          TableGeometry.cardW * TableGeometry.deckScale * .8) {
        // se queda donde se solto y desde ahi vuela a unirse: sin volver atras
        ops.arrange(
          (st) => st.copyWith(
            piles: [
              for (final p in st.piles)
                p.pid == pid ? p.moved(pose.x, pose.y) : p,
            ],
          ),
        );
        _run(() async {
          await _undoable(() => _stack([q.pid, pid]));
          effects.toast(
            table.piles.length > 1 ? 'Montones unidos' : 'Mazo entero de nuevo',
          );
        });
        return;
      }
    }
    final x = pose.x.clamp(70.0, TableGeometry.width - 70);
    final y = pose.y.clamp(
      TableGeometry.shelfY + 70,
      TableGeometry.height - 70,
    );
    ops.arrange(
      (s) => s.copyWith(
        piles: [for (final p in s.piles) p.pid == pid ? p.moved(x, y) : p],
      ),
      undoable: true,
    );
  }
}
