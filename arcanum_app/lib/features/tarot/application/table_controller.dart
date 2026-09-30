import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/auth/auth_controller.dart';
import '../data/table_store.dart';
import '../domain/table_models.dart';
import '../domain/table_state.dart';

/// Cuanto dura la oferta de deshacer, como en el prototipo.
const undoWindow = Duration(seconds: 5);

/// Lo que la mesa (el director de gestos) necesita del estado. Lo implementa
/// `TableController`; los tests lo pueden falsear sin red ni Riverpod.
abstract interface class TableOps {
  TableState get table;
  Future<void> openDeck(String deck);
  Future<void> shuffle(String pile, {String style});
  Future<String> cut(String pile, int n);
  Future<void> merge(List<String> topFirst, String into);
  Future<TableCard> take(String pile, int position);
  Future<void> giveBack(String slug, String pile);
  Future<void> gather(String pile);
  void arrange(TableState Function(TableState) change, {bool undoable});

  /// Empieza un gesto que se podra deshacer entero, aunque haga varias
  /// operaciones en el servidor (unir y recoger, cortar y colocar...).
  void beginUndoable();

  /// Termina el gesto: desde aqui se ofrece deshacerlo.
  void commitUndoable();
  bool get canUndo;

  /// Hasta cuando se ofrece deshacer, o null si no hay nada que deshacer.
  DateTime? get undoUntil;
  Future<bool> undo();
  Future<Interpretation> interpret({String? idempotencyKey});
  Future<Map<String, dynamic>> closeCircle();

  /// Continua una lectura guardada: mesa nueva con sus cartas colocadas.
  Future<void> continueReading(Map<String, dynamic> reading);
}

/// Estado de la mesa: la API manda sobre el mazo, lo local sobre la disposicion.
///
/// Las operaciones sobre el mazo van en fila (una detras de otra): dos toques
/// seguidos no pueden aplicar vistas del servidor fuera de orden. Los errores
/// de red NO se tragan: los recibe la pantalla, que tiene que decirlo.
class TableController extends AsyncNotifier<TableState> implements TableOps {
  Future<void> _queue = Future.value();
  Timer? _saveTimer;
  TableState? _undo;
  DateTime? _undoUntil;

  /// El deshacer ofrecido toco el mazo del servidor: deshacerlo le pide volver.
  bool _undoServer = false;

  /// Gesto en curso: la mesa de antes, si ya marco punto en el servidor y si
  /// llego a tocarlo.
  TableState? _gesture;
  bool _checkpointPending = false;
  bool _gestureServer = false;

  ArcanumApi get _api => ref.read(arcanumApiProvider);
  TableStore get _store => ref.read(tableStoreProvider);
  String? get _userId => ref.read(authProvider).user?['id']?.toString();

  /// Reloj inyectable para los tests de deshacer.
  DateTime Function() now = DateTime.now;

  @override
  Future<TableState> build() async {
    final userId = ref.watch(
      authProvider.select((s) => s.user?['id']?.toString()),
    );
    ref.onDispose(() => _saveTimer?.cancel());
    if (userId == null) return TableState.empty;
    final local = await _store.load(userId);
    final ServerView? view;
    try {
      final raw = await _api.tarotCurrentTable();
      view = raw == null ? null : ServerView.fromJson(raw);
    } on Object {
      // Sin red se ve la mesa guardada; la primera operacion dira si sigue viva
      return local ?? TableState.empty;
    }
    final camera = local?.camera ?? const TableCameraState();
    if (view == null) {
      if (local?.hasTable ?? false) await _store.clear(userId);
      return TableState(camera: camera);
    }
    // La mesa guardada solo vale si es la misma que sigue abierta en el servidor
    final base = local != null && local.sessionId == view.id
        ? local
        : TableState(camera: camera, activePid: view.piles.keys.firstOrNull);
    return base.withServer(view);
  }

  TableState get _current => state.value ?? TableState.empty;

  @override
  TableState get table => _current;

  void _set(TableState next) {
    state = AsyncData(next);
    _saveSoon();
  }

  void _saveSoon() {
    final userId = _userId;
    if (userId == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(flush()),
    );
  }

  /// Guarda ya la mesa, sin esperar al diferido. Para cuando la app pasa a
  /// segundo plano y para los tests.
  Future<void> flush() async {
    _saveTimer?.cancel();
    final userId = _userId;
    final s = state.value;
    if (userId != null && s != null) await _store.save(userId, s);
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _queue.then((_) => task());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  String _sessionId() {
    final id = _current.sessionId;
    if (id == null) throw StateError('No hay ninguna mesa abierta.');
    return id;
  }

  Future<ServerView> _op(String op, Map<String, dynamic> body) async {
    final raw = await _api.tarotTableOp(_sessionId(), op, _checkpoint(body));
    return ServerView.fromJson(raw);
  }

  /// Decide si esta operacion marca punto de deshacer en el servidor.
  ///
  /// Dentro de un gesto, solo la primera: asi el servidor vuelve a antes del
  /// gesto entero. Fuera de un gesto el servidor avanza por su cuenta, y un
  /// deshacer ofrecido que dependia de el ya no seria el nuestro: se retira.
  Map<String, dynamic> _checkpoint(Map<String, dynamic> body) {
    final bool cp;
    if (_gesture != null) {
      cp = _checkpointPending;
      _checkpointPending = false;
      _gestureServer = true;
    } else {
      cp = true;
      if (_undoServer) _forgetUndo();
    }
    return {...body, 'checkpoint': cp};
  }

  // ---------- mazo (servidor) ----------
  @override
  Future<void> openDeck(String deck) => _serial(() async {
    final view = ServerView.fromJson(await _api.tarotOpenTable(deck));
    _forgetUndo();
    _set(
      TableState(
        camera: _current.camera,
        activePid: view.piles.keys.firstOrNull,
      ).withServer(view),
    );
  });

  @override
  Future<void> shuffle(String pile, {String style = 'cascada'}) =>
      _serial(() async {
        final view = await _op('shuffle', {'pile': pile, 'style': style});
        _set(_current.withServer(view));
      });

  /// Corta las `n` de arriba a un monton nuevo y devuelve su id.
  @override
  Future<String> cut(String pile, int n) => _serial(() async {
    final raw = await _api.tarotTableOp(
      _sessionId(),
      'cut',
      _checkpoint({'pile': pile, 'n': n}),
    );
    _set(
      _current.withServer(
        ServerView.fromJson(raw['table'] as Map<String, dynamic>),
      ),
    );
    return raw['pile'] as String;
  });

  @override
  Future<void> merge(List<String> topFirst, String into) => _serial(() async {
    final view = await _op('merge', {'piles': topFirst, 'into': into});
    _set(_current.withServer(view));
  });

  /// Saca la carta de `position` y la deja boca abajo junto al monton.
  @override
  Future<TableCard> take(String pile, int position) => _serial(() async {
    final raw = await _api.tarotTableOp(
      _sessionId(),
      'take',
      _checkpoint({'pile': pile, 'position': position}),
    );
    final face = CardFace.fromJson(raw['card'] as Map<String, dynamic>);
    final from = _current.piles.where((p) => p.pid == pile).firstOrNull;
    final card = TableCard(
      face: face,
      x: from?.x ?? 300,
      y: (from?.y ?? 720) - 160,
      rot: from?.rot ?? 0,
    );
    _set(
      _current
          .withServer(ServerView.fromJson(raw['table'] as Map<String, dynamic>))
          .addCard(card),
    );
    return card;
  });

  @override
  Future<void> giveBack(String slug, String pile) => _serial(() async {
    final view = await _op('return', {'slug': slug, 'pile': pile});
    _set(_current.withServer(view));
  });

  @override
  Future<void> gather(String pile) => _serial(() async {
    final view = await _op('gather', {'pile': pile});
    _set(_current.withServer(view).copyWith(spread: () => null));
  });

  // ---------- disposicion local ----------

  /// Cambia la disposicion (mover, voltear, elegir tirada...). Con
  /// `undoable`, la mesa de antes queda ofrecida para deshacer.
  @override
  void arrange(
    TableState Function(TableState) change, {
    bool undoable = false,
  }) {
    final before = _current;
    final next = change(before);
    if (identical(next, before)) return;
    // dentro de un gesto, la foto la guarda el gesto al empezar
    if (undoable && _gesture == null) {
      _undo = before;
      _undoServer = false;
      _undoUntil = now().add(undoWindow);
    }
    _set(next);
  }

  @override
  void beginUndoable() {
    _gesture = _current;
    _checkpointPending = true;
    _gestureServer = false;
  }

  /// Va a la fila: se cierra el gesto despues de sus operaciones pendientes.
  @override
  void commitUndoable() => unawaited(
    _serial(() async {
      final snap = _gesture;
      _gesture = null;
      if (snap == null || identical(snap, _current)) return;
      _undo = snap;
      _undoServer = _gestureServer;
      _undoUntil = now().add(undoWindow);
    }),
  );

  @override
  DateTime? get undoUntil => canUndo ? _undoUntil : null;

  @override
  bool get canUndo =>
      _undo != null && _undoUntil != null && now().isBefore(_undoUntil!);

  /// Vuelve a la mesa de antes del ultimo gesto.
  ///
  /// Si el gesto toco el mazo (cortar, unir, sacar, devolver...), el servidor
  /// vuelve tambien a su mazo de antes (decision del 30-sep). La foto local se
  /// reconcilia con lo que diga el servidor, que manda.
  @override
  Future<bool> undo() => _serial(() async {
    if (!canUndo) return false;
    final snap = _undo!;
    final server = _undoServer;
    _forgetUndo();
    if (server) {
      final view = ServerView.fromJson(await _api.tarotUndo(_sessionId()));
      _set(snap.withServer(view));
    } else {
      final view = _current.server;
      _set(view == null ? snap : snap.withServer(view));
    }
    return true;
  });

  void _forgetUndo() {
    _undo = null;
    _undoUntil = null;
    _undoServer = false;
  }

  // ---------- interpretar y cerrar ----------

  /// Pide la lectura de Tradicion. Gasta cupo: un 402 llega tal cual a la
  /// pantalla, que abre el paywall.
  @override
  Future<Interpretation> interpret({String? idempotencyKey}) =>
      _serial(() async {
        final s = _current;
        final spread = s.spread;
        if (spread == null) throw StateError('No hay tirada elegida.');
        final raw = await _api.tarotInterpret(
          _sessionId(),
          spread: spread,
          placements: s.placements(),
          question: s.seal?.text,
          idempotencyKey: idempotencyKey,
        );
        final current = await _api.tarotCurrentTable();
        if (current != null) {
          _set(
            _current
                .withServer(ServerView.fromJson(current))
                .copyWith(
                  seal: () => s.seal == null
                      ? null
                      : Seal(text: s.seal!.text, open: true),
                ),
          );
        }
        return Interpretation.fromJson(raw);
      });

  /// Cierra el circulo: el servidor guarda la lectura con la foto de la mesa
  /// y la mesa local queda vacia. Devuelve la lectura guardada.
  ///
  /// Sin interpretar tambien vale (decision del 30-sep), y no gasta cupo: se
  /// guarda lo que hay en la mesa. Sin tirada, las cartas sueltas que no estan
  /// apartadas son una lectura libre. El sello se abre al cerrar.
  @override
  Future<Map<String, dynamic>> closeCircle() => _serial(() async {
    final s = _current;
    final seal = s.seal;
    final snap = seal == null
        ? s
        : s.copyWith(seal: () => Seal(text: seal.text, open: true));
    final unread = s.server?.status == 'open';
    final reading = await _api.tarotCloseTable(
      _sessionId(),
      table: snap.toJson(),
      spread: unread ? s.spread : null,
      question: unread ? seal?.text : null,
      placements: !unread
          ? const []
          : s.spread != null
          ? s.placements()
          : [
              for (final c in s.cards)
                if (!c.aside && c.slot == null && c.host == null)
                  {'slug': c.slug, if (c.turned) 'turned': true},
            ],
    );
    _forgetUndo();
    final userId = _userId;
    if (userId != null) await _store.clear(userId);
    _saveTimer?.cancel();
    state = AsyncData(TableState(camera: s.camera));
    return reading;
  });

  /// Continua una lectura guardada (decision del 30-sep): el servidor abre una
  /// mesa con esas cartas ya fuera del mazo y aqui se recoloca la foto que se
  /// guardo al cerrar el circulo. El sentido viene del servidor, asi que un
  /// giro ya esta aplicado: las cartas llegan sin `turned`.
  @override
  Future<void> continueReading(Map<String, dynamic> reading) =>
      _serial(() async {
        final raw = reading['table_snapshot'];
        final snap = raw is Map<String, dynamic>
            ? TableState.fromJson(raw)
            : null;
        if (snap == null) {
          throw StateError('Esta lectura no guardó la mesa.');
        }
        final view = ServerView.fromJson(
          await _api.tarotOpenTable(
            snap.server?.deck ?? 'rws',
            fromReading: reading['id'] as String,
          ),
        );
        _forgetUndo();
        final sense = {for (final d in view.drawn) d.slug: d.reversed};
        _set(
          snap
              .copyWith(
                server: () => null,
                fan: () => null,
                camera: _current.camera,
                cards: [
                  for (final c in snap.cards)
                    TableCard(
                      face: CardFace(
                        slug: c.face.slug,
                        reversed: sense[c.slug] ?? c.face.reversed,
                        name: c.face.name,
                        nameEs: c.face.nameEs,
                        arcana: c.face.arcana,
                        suit: c.face.suit,
                        number: c.face.number,
                      ),
                      x: c.x,
                      y: c.y,
                      rot: c.rot,
                      scale: c.scale,
                      slot: c.slot,
                      aside: c.aside,
                      faceUp: c.faceUp,
                      dir: c.dir,
                      host: c.host,
                    ),
                ],
              )
              .withServer(view),
        );
      });
}

final tableControllerProvider =
    AsyncNotifierProvider<TableController, TableState>(TableController.new);
