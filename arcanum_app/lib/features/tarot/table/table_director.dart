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

import 'dart:async';
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
import 'table_haptics.dart';

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

  /// Se silencio o se volvio a oir la mesa desde el radial del paño.
  void muteChanged(bool muted) {}
  void creditsRequired() {}
  void error(Object error) {}
}

enum PieceKind {
  shelfDeck,
  pile,
  fanCard,

  /// Carta ya pedida al servidor que todavia no ha contestado: se ve volar a
  /// su sitio en el acto (boca abajo, como sale siempre) y no se puede tocar.
  pendingCard,
  card,
}

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

/// Una carta del abanico pedida al servidor y todavia sin respuesta.
class _PendingTake {
  _PendingTake({
    required this.fanId,
    required this.pid,
    required this.position,
    required this.from,
    required this.to,
    required this.slot,
  });

  final String fanId;
  final String pid;
  final int position;

  /// Donde estaba en el abanico y adonde va (hueco o sitio libre).
  final TablePose from;
  TablePose to;

  /// Hueco reservado: dos toques seguidos no van al mismo.
  final int? slot;
  final Stopwatch watch = Stopwatch()..start();

  /// Se saco arrastrando y el dedo ya se levanto: al llegar la carta se suelta.
  bool released = false;
  bool cancelled = false;

  String get id => 'pending:$fanId';
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
    this.haptics = const TableHaptics(),
  }) : camera = camera ?? TableCamera(from: ops.table.camera),
       _random = random ?? math.Random();

  final TableOps ops;
  final TableEffects effects;
  final TableCamera camera;
  final TableHaptics haptics;
  final GestureGrammar grammar = GestureGrammar();

  /// «Reducir movimiento» del sistema: la camara salta sin suavizado ni
  /// inercia. Lo pone la vista en cada construccion.
  bool reduceMotion = false;

  /// Mesa en silencio (radial del paño): sin vibracion, y sin sonido cuando
  /// llegue. Decidido por Samuel el 05-oct. Lo guarda la pantalla.
  bool muted = false;

  /// Vibra, salvo con la mesa en silencio. La pantalla lo usa para sellar,
  /// romper el sello y cerrar el circulo.
  void buzz(Buzz b) {
    if (!muted) unawaited(haptics.play(b));
  }

  void _buzz(Buzz b) => buzz(b);

  void _toggleMute() {
    muted = !muted;
    effects.muteChanged(muted);
    effects.toast(
      muted ? 'Mesa en silencio: ya no vibra.' : 'La mesa vuelve a vibrar.',
    );
  }

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
  final Map<String, _PendingTake> _pending = {};
  int? hotSlot;

  /// Cartas del abanico pedidas al servidor que aun no han llegado.
  Iterable<String> get pendingTakes => _pending.keys;

  /// Lo que tardo cada carta del abanico desde el toque hasta que el servidor
  /// la dio (las ultimas 50). La carta se ve en el acto; esto mide la red.
  final List<Duration> takeTimings = [];
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

  /// Donde se abrio el ultimo radial, en pantalla: ancla de lo que se elija en el.
  Offset? get menuAt => _menuAt;
  Offset? _menuAt;

  /// Rectangulo de pantalla que ocupa una carta, girada incluida: ancla de su panel.
  Rect screenRectOfCard(TableCard c) {
    final hw = TableGeometry.cardW * c.scale / 2,
        hh = TableGeometry.cardH * c.scale / 2;
    final a = c.rot * math.pi / 180, cos = math.cos(a), sin = math.sin(a);
    return _bounds([
      for (final (dx, dy) in [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)])
        camera.toScreen(
          Offset(c.x + dx * cos - dy * sin, c.y + dx * sin + dy * cos),
        ),
    ]);
  }

  /// Rectangulo de pantalla del sello: ancla del panel de la pregunta.
  Rect get sealScreenRect => _bounds([
    for (final (dx, dy) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
      camera.toScreen(sealAt + Offset(dx * sealRadius, dy * sealRadius)),
  ]);

  /// Rectangulo de pantalla del bordado «Interpretar»: ancla de su panel.
  Rect get embroideryScreenRect => _bounds([
    for (final (dx, dy) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
      camera.toScreen(embroideryAt + Offset(dx * 90.0, dy * 28.0)),
  ]);

  /// Lo que ocupa el sello en la mesa.
  static Rect get sealRect =>
      Rect.fromCircle(center: sealAt, radius: sealRadius);

  /// Lo que ocupa el bordado «Interpretar» en la mesa (y donde se toca).
  static Rect get embroideryRect =>
      Rect.fromCenter(center: embroideryAt, width: 180, height: 56);

  static Rect _bounds(List<Offset> p) => Rect.fromLTRB(
    p.map((o) => o.dx).reduce(math.min),
    p.map((o) => o.dy).reduce(math.min),
    p.map((o) => o.dx).reduce(math.max),
    p.map((o) => o.dy).reduce(math.max),
  );

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

  /// Que se esta arrastrando ahora, o null.
  DragKind? get dragKind => _drag?.kind;

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
      // las ya pedidas salen del abanico en el acto, sin esperar al servidor
      final positions = [
        for (final pos in server?.piles[f.pid]?.positions ?? const <int>[])
          if (!_pending.containsKey('fan:${f.pid}:$pos')) pos,
      ];
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
    for (final p in _pending.values) {
      out.add(
        PieceView(
          id: p.id,
          kind: PieceKind.pendingCard,
          pose: _overrides[p.id] ?? p.to,
          lift: _lift[p.id] ?? 0,
          dragging: _overrides.containsKey(p.id),
        ),
      );
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

  /// Lo que hay bajo un punto de la mesa (a ras del paño).
  Hit hitAt(Offset tablePoint) => hitAtScreen(camera.toScreen(tablePoint));

  /// Lo que hay bajo el dedo, en el mismo orden en que se dibuja.
  ///
  /// Cada pieza se busca en SU plano: una carta levantada (arrastrandose,
  /// volteandose) se dibuja mas cerca de la camara y se toca donde se ve, no
  /// en el paño de debajo. Primero se mira lo que hay justo bajo el dedo y,
  /// solo si no hay nada, la zona de toque ampliada: asi el margen de una
  /// carta no le roba el toque al sello o a la carta de al lado.
  Hit hitAtScreen(Offset screen) {
    final list = pieces();
    final ground = camera.toTable(screen);
    for (final padded in const [false, true]) {
      final hit = _hitPass(list, screen, ground, padded: padded);
      if (hit != null) return hit;
    }
    final inside =
        ground.dx >= 0 &&
        ground.dx <= TableGeometry.width &&
        ground.dy >= 0 &&
        ground.dy <= TableGeometry.height;
    return inside ? const HitSurface() : const HitNothing();
  }

  Hit? _hitPass(
    List<PieceView> list,
    Offset screen,
    Offset ground, {
    required bool padded,
  }) {
    Hit? piece(PieceView v) {
      final at = v.lift == 0 ? ground : camera.toTable(screen, z: v.lift);
      final pad = padded ? 24.0 / v.pose.scale : 0.0;
      final w = TableGeometry.cardW, h = TableGeometry.cardH;
      final exact = localNormalized(v.pose, at);
      final local = padded
          ? localNormalized(v.pose, at, w: w + pad * 2, h: h + pad * 2)
          : exact;
      if (local.dx.abs() > 1 || local.dy.abs() > 1) return null;
      return switch (v.kind) {
        PieceKind.shelfDeck => HitDeck(
          pid: v.id.substring(6),
          local: exact,
          count: v.count,
          inPlay: false,
        ),
        PieceKind.pile => HitDeck(
          pid: v.id.substring(5),
          local: exact,
          count: v.count,
        ),
        PieceKind.fanCard => HitCard(
          slug: v.id,
          local: exact,
          faceUp: false,
          inFan: true,
        ),
        PieceKind.card => HitCard(
          slug: v.card!.slug,
          local: exact,
          faceUp: v.card!.faceUp,
        ),
        PieceKind.pendingCard => null,
      };
    }

    // de arriba abajo, como se pinta: cartas en juego, bordado y sello (sobre
    // el abanico y los montones), abanico, montones y estante
    for (final v in list.reversed) {
      if (v.kind != PieceKind.card) continue;
      final h = piece(v);
      if (h != null) return h;
    }
    if (readyToInterpret && embroideryRect.contains(ground)) {
      return const HitEmbroidery();
    }
    if (table.seal != null &&
        (ground - sealAt).distance <= sealRadius + (padded ? 8 : 0)) {
      return const HitSeal();
    }
    for (final v in list.reversed) {
      if (v.kind == PieceKind.card || v.kind == PieceKind.pendingCard) continue;
      final h = piece(v);
      if (h != null) return h;
    }
    return null;
  }

  @visibleForTesting
  void debugLift(String id, double z) => _lift[id] = z;

  @visibleForTesting
  Future<void> debugCut(String pid) => _autoCut(pid);

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
    _apply(grammar.down(pointer, screen, time, hitAtScreen(screen)));
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
    var moving = reduceMotion ? camera.settleNow() : camera.step(dt);
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
          _saveCamera();
        case OpenRadialIntent(:final hit, :final position):
          _openRadialFor(hit, position);
        case RadialMoveIntent(:final position):
          final r = _radial;
          if (r != null) {
            final hot = r.layout.hotAt(position);
            if (hot != null && hot != r.hot) _buzz(Buzz.radialHover);
            r.hot = hot;
          }
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
          _saveCamera();
      }
    }
    if (intents.isNotEmpty) notifyListeners();
  }

  /// La camara viaja en la foto de la mesa: al volver se ve como se dejo.
  /// Antes no se guardaba nunca y la mesa volvia siempre a la vista inicial.
  void _saveCamera() {
    final s = camera.state;
    final was = table.camera;
    if (was.theta == s.theta &&
        was.yaw == s.yaw &&
        was.zoom == s.zoom &&
        was.panX == s.panX &&
        was.panY == s.panY) {
      return;
    }
    ops.arrange((t) => t.copyWith(camera: s));
  }

  void _report(Object e) {
    if (isCreditsRequired(e)) {
      effects.creditsRequired();
    } else {
      effects.error(e);
    }
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
    // sacar del abanico no espera a nada: cada toque es una carta
    if (hit case HitCard(inFan: true, :final slug)) {
      unawaited(_takeFromFan(slug));
      return;
    }
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
    _buzzReveal([c]);
    effects.flipped(table.card(c.slug)!);
  }

  /// Desvelar vibra una vez; si sale un Mayor, con su patron.
  void _buzzReveal(Iterable<TableCard> cards) {
    if (cards.isEmpty) return;
    _buzz(
      cards.any((c) => c.face.arcana == 'major')
          ? Buzz.revealMajor
          : Buzz.reveal,
    );
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

  /// Saca una carta del abanico.
  ///
  /// En el acto, sin esperar al servidor: la carta sale del abanico y vuela a
  /// su hueco (o a un sitio libre), y el hueco queda reservado. Asi un toque
  /// se ve siempre y el siguiente toque no se pierde. Cuando el servidor dice
  /// que carta era, la de verdad ocupa ese sitio; si falla, vuelve al abanico
  /// y se dice por que.
  ///
  /// Antes el toque esperaba la respuesta con la mesa bloqueada (`_busy`) y
  /// los toques de mientras se tiraban en silencio.
  Future<void> _takeFromFan(String fanId, {_Drag? drag}) async {
    if (_pending.containsKey(fanId)) return;
    final from = _poseOf(fanId);
    if (from == null) return;
    final parts = fanId.split(':');
    final sp = spread;
    final slot = drag != null || sp == null ? null : _firstEmptySlot(sp);
    final scale = sp?.cardScale ?? TableGeometry.freeScale;
    final to = drag != null
        ? TablePose(from.x, from.y, scale: scale)
        : slot != null
        ? slotPose(sp!, slot)
        : _looseSpot(from.offset, scale);
    final p = _PendingTake(
      fanId: fanId,
      pid: parts[1],
      position: int.parse(parts[2]),
      from: from,
      to: to,
      slot: slot,
    );
    _pending[fanId] = p;
    if (drag == null) _born(p.id, from);
    notifyListeners();
    final TableCard card;
    try {
      card = await ops.take(p.pid, p.position);
    } on Object catch (e) {
      _pending.remove(fanId);
      _overrides.remove(p.id);
      _lift.remove(p.id);
      if (drag != null) {
        if (identical(_drag, drag)) _drag = null;
        if (drag.gesture) ops.commitUndoable();
      }
      notifyListeners();
      _report(e);
      return;
    }
    _pending.remove(fanId);
    _timeTake(p);
    if (_count(p.pid) == 0) ops.arrange((s) => s.copyWith(fan: () => null));
    if (drag != null && !p.released && identical(_drag, drag)) {
      // el dedo sigue abajo: la carta de verdad sigue al dedo desde ahi
      _continueDrag(p, card, drag);
    } else if (drag != null) {
      _landReleased(p, card, drag);
    } else {
      _born('card:${card.slug}', _shownPending(p));
      _land(card.slug, p.slot, p.to);
    }
    notifyListeners();
  }

  /// Donde se esta viendo la carta pendiente: va de camino 420 ms.
  TablePose _shownPending(_PendingTake p) {
    const travel = 420;
    final t = (p.watch.elapsedMilliseconds / travel).clamp(0.0, 1.0);
    if (t >= 1) return p.to;
    final e = 1 - math.pow(1 - t, 3).toDouble();
    return TablePose(
      p.from.x + (p.to.x - p.from.x) * e,
      p.from.y + (p.to.y - p.from.y) * e,
      rot: p.from.rot + (p.to.rot - p.from.rot) * e,
      scale: p.from.scale + (p.to.scale - p.from.scale) * e,
    );
  }

  void _timeTake(_PendingTake p) {
    p.watch.stop();
    takeTimings.add(p.watch.elapsed);
    if (takeTimings.length > 50) takeTimings.removeAt(0);
    if (!kReleaseMode) {
      debugPrint(
        '[mesa] sacar carta: ${p.watch.elapsedMilliseconds} ms hasta la '
        'respuesta del servidor (la carta se ve al instante)',
      );
    }
  }

  /// Deja una carta recien sacada en su hueco (si sigue libre) o en `spot`.
  void _land(String slug, int? slot, TablePose spot) {
    final sp = spread;
    final free =
        sp != null &&
            slot != null &&
            slot < sp.cardCount &&
            table.cardInSlot(slot) == null
        ? slot
        : null;
    if (sp != null && free != null) return _place(slug, sp, free);
    ops.arrange(
      (s) => s.updateCard(
        slug,
        (k) => k.copyWith(
          x: spot.x,
          y: spot.y,
          scale: sp?.cardScale ?? TableGeometry.freeScale,
          rot: _random.nextDouble() * 10 - 5,
        ),
      ),
    );
  }

  /// La carta llego con el dedo todavia en ella: pasa a arrastrarse.
  void _continueDrag(_PendingTake p, TableCard card, _Drag d) {
    final id = 'card:${card.slug}';
    final pose = _overrides.remove(p.id) ?? p.to;
    _lift.remove(p.id);
    _wobble.remove(p.id);
    ops.arrange(
      (s) => s.updateCard(
        card.slug,
        (k) => k.copyWith(x: pose.x, y: pose.y, scale: pose.scale),
      ),
    );
    // venia del abanico: no hay sitio al que devolver una carta desplazada
    d
      ..id = id
      ..origin = null
      ..ready = true;
    _overrides[id] = pose;
    _lift[id] = 64;
  }

  /// El dedo se levanto antes de que llegara la carta: se suelta donde quedo.
  void _landReleased(_PendingTake p, TableCard card, _Drag d) {
    final pose = p.to;
    d
      ..id = 'card:${card.slug}'
      ..origin = null;
    try {
      ops.arrange(
        (s) => s.updateCard(
          card.slug,
          (k) => k.copyWith(x: pose.x, y: pose.y, scale: pose.scale),
        ),
      );
      _born(d.id, pose);
      if (p.cancelled) {
        _autoPlace(card.slug, pose.offset);
      } else {
        _dropCard(card.slug, pose, d);
      }
    } finally {
      if (d.gesture) ops.commitUndoable();
    }
  }

  /// Coloca una carta como si se hubiera tocado en el abanico: primer hueco
  /// libre o, sin hueco, un sitio libre.
  void _autoPlace(String slug, Offset near) {
    final sp = spread;
    final slot = sp == null ? null : _firstEmptySlot(sp);
    if (sp != null && slot != null) return _place(slug, sp, slot);
    final scale = sp?.cardScale ?? TableGeometry.freeScale;
    _land(slug, null, _looseSpot(near, scale, skip: slug));
  }

  /// Lo que no puede taparse al dejar algo en la mesa: huecos de la tirada,
  /// cartas, montones (con su nombre), el sello, el bordado y lo pendiente.
  List<Rect> _occupied({String? skip}) {
    final sp = spread;
    return [
      if (sp != null)
        for (var i = 0; i < sp.cardCount; i++) poseRect(slotPose(sp, i)),
      for (final c in table.cards)
        if (c.slug != skip && !c.aside)
          poseRect(TablePose(c.x, c.y, rot: c.rot, scale: c.scale)),
      for (final p in table.piles) _pileRect(TablePose(p.x, p.y, rot: p.rot)),
      for (final p in _pending.values) poseRect(p.to),
      sealRect,
      embroideryRect,
    ];
  }

  /// Un monton ocupa su caja y su nombre, que va debajo.
  static Rect _pileRect(TablePose p) {
    final r = poseRect(
      TablePose(p.x, p.y, rot: p.rot, scale: TableGeometry.deckScale),
    );
    return Rect.fromLTRB(r.left - 12, r.top, r.right + 12, r.bottom + 34);
  }

  /// Hasta donde se dejan las cartas sueltas: el paño por encima de la zona
  /// cercana (y 690 en la especificacion), que es la del mazo y el abanico.
  static const Rect _looseArea = Rect.fromLTRB(18, 172, 582, 690);

  /// Sitio libre para una carta suelta: ni encima de la tirada, ni del sello,
  /// ni del bordado, ni de otra carta, y lo mas cerca posible de `near`.
  TablePose _looseSpot(Offset near, double scale, {String? skip}) {
    final at = freeSpot(
      size: Size(TableGeometry.cardW * scale, TableGeometry.cardH * scale),
      taken: _occupied(skip: skip),
      area: _looseArea,
      near: near,
    );
    return TablePose(at.dx, at.dy, scale: scale);
  }

  /// Primer hueco sin carta y sin una carta de camino.
  int? _firstEmptySlot(SpreadDef sp) {
    for (var i = 0; i < sp.cardCount; i++) {
      if (_slotFree(i)) return i;
    }
    return null;
  }

  bool _slotFree(int i) =>
      table.cardInSlot(i) == null && !_pending.values.any((p) => p.slot == i);

  void _place(String slug, SpreadDef sp, int slot) {
    final pose = slotPose(sp, slot);
    _buzz(Buzz.snap);
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
        if (_slotFree(i)) i,
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

  /// Sitio para un monton nuevo (un corte): en la zona cercana si cabe sin
  /// tapar nada, y si no, en el paño donde menos tape. Antes se buscaba solo
  /// lejos de otros montones y podia caer sobre el bordado o el sello.
  Offset _freeSpot(PileLayout near) {
    final taken = _occupied();
    final f = fan;
    if (f != null) {
      final poses = fanPoses(f.start, f.end, 2);
      taken.add(
        poseRect(poses.first).expandToInclude(poseRect(poses.last)).inflate(30),
      );
    }
    final size = _pileRect(const TablePose(0, 0)).size;
    Offset pick(Rect area) => freeSpot(
      size: size,
      taken: taken,
      area: area,
      near: Offset(near.x, near.y),
    );
    bool clear(Offset at) {
      final r = Rect.fromCenter(
        center: at,
        width: size.width,
        height: size.height,
      );
      return taken.every((t) {
        final i = r.intersect(t);
        return i.width <= 0 || i.height <= 0;
      });
    }

    // el rectangulo del monton va con el nombre debajo: el centro de la caja
    // queda por encima del centro del rectangulo
    Offset box(Offset c) => c.translate(0, -17);
    final close = pick(const Rect.fromLTRB(18, 690, 582, 882));
    if (clear(close)) return box(close);
    return box(pick(TableGeometry.cloth));
  }

  int _cutSize(int n) =>
      (n * (.3 + _random.nextDouble() * .4)).round().clamp(1, n - 1);

  Future<void> _autoCut(String pid) async {
    final src = _pile(pid);
    if (src == null) return;
    final spot = _freeSpot(src);
    await _undoable(() async {
      final np = await ops.cut(pid, _cutSize(_count(pid)));
      _buzz(Buzz.cut);
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
    _buzz(Buzz.closeCircle);
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
    _buzzReveal(hidden);
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
    _menuAt = screen;
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
            soundOn: !muted,
          ),
          (id) async => switch (id) {
            'seal' => effects.openSeal(),
            'hist' => effects.openHistory(),
            'sound' => _toggleMute(),
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
      _buzz(Buzz.shuffle);
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
                _buzz(Buzz.cut);
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
          // sale del abanico al empezar a arrastrarla: se ve en el dedo en el
          // acto y la carta de verdad la sustituye al llegar del servidor
          ops.beginUndoable();
          d
            ..gesture = true
            ..id = 'pending:${hit.slug}';
          unawaited(_takeFromFan(hit.slug, drag: d));
          final p = _pending[hit.slug];
          if (p == null) {
            _drag = null;
            ops.commitUndoable();
            return;
          }
          _lift[d.id] = 64;
          _moveDragged(d, at);
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
    // el arrastre se mide a ras del paño, como el prototipo: lo que se suelta
    // cae donde esta el dedo (la carta levantada se ve un poco desplazada)
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
        hotSlot =
            (d.id.startsWith('card:') || d.id.startsWith('pending:')) &&
                sp != null
            ? nearestSlot(sp, _overrides[d.id]!.offset)
            : null;
    }
  }

  void _dragEnd(DragKind kind, Offset screen, bool cancelled) {
    final pending = _drag?.id.startsWith('pending:') ?? false;
    // una carta del abanico que aun no llego cierra su gesto al llegar
    final gesture = !pending && (_drag?.gesture ?? false);
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
        // con «reducir movimiento» la mesa se para donde la deja el dedo
        if (!cancelled && !reduceMotion) {
          camera.releaseOrbit(vyaw: d.offset.dx, vtheta: d.offset.dy);
        }
        _saveCamera();
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
          _buzzReveal([table.card(slug)!]);
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
        if (d.id.startsWith('pending:')) {
          // el servidor no ha contestado: se anota donde se solto
          final p = _pending[d.id.substring(8)];
          if (p != null) {
            p
              ..released = true
              ..cancelled = cancelled
              ..to = pose ?? p.to;
          }
          return;
        }
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

  /// Caja del abanico abierto, o null.
  Rect? get _fanBox {
    final f = fan;
    if (f == null) return null;
    final poses = fanPoses(f.start, f.end, 2);
    return poseRect(poses.first).expandToInclude(poseRect(poses.last));
  }

  void _dropCard(String slug, TablePose pose, _Drag d) {
    final sp = spread;
    final slot = sp == null ? null : nearestSlot(sp, pose.offset);
    // soltada encima del abanico (o casi sin moverla al sacarla): taparia las
    // demas, asi que se coloca como si se hubiera tocado
    final box = _fanBox;
    if (slot == null && box != null && box.contains(pose.offset)) {
      return _autoPlace(slug, pose.offset);
    }
    if (sp != null && slot != null) {
      final other = table.cardInSlot(slot);
      // la desplazada ocupa el hueco que se libera o el sitio de donde vino la
      // otra; si la otra no venia de ningun sitio (el abanico), uno libre
      final back = other == null || other.slug == slug
          ? null
          : d.originSlot != null
          ? slotPose(sp, d.originSlot!)
          : d.origin ??
                _looseSpot(
                  Offset(other.x, other.y),
                  sp.cardScale,
                  skip: other.slug,
                );
      _buzz(Buzz.snap);
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
