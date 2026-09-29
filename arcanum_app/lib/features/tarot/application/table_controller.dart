import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/auth/auth_controller.dart';
import '../data/table_store.dart';
import '../domain/table_models.dart';
import '../domain/table_state.dart';

/// Cuanto dura la oferta de deshacer, como en el prototipo.
const undoWindow = Duration(seconds: 5);

/// Estado de la mesa: la API manda sobre el mazo, lo local sobre la disposicion.
///
/// Las operaciones sobre el mazo van en fila (una detras de otra): dos toques
/// seguidos no pueden aplicar vistas del servidor fuera de orden. Los errores
/// de red NO se tragan: los recibe la pantalla, que tiene que decirlo.
class TableController extends AsyncNotifier<TableState> {
  Future<void> _queue = Future.value();
  Timer? _saveTimer;
  TableState? _undo;
  DateTime? _undoUntil;

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
    final raw = await _api.tarotTableOp(_sessionId(), op, body);
    return ServerView.fromJson(raw);
  }

  // ---------- mazo (servidor) ----------
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

  Future<void> shuffle(String pile, {String style = 'cascada'}) =>
      _serial(() async {
        final view = await _op('shuffle', {'pile': pile, 'style': style});
        _set(_current.withServer(view));
      });

  /// Corta las `n` de arriba a un monton nuevo y devuelve su id.
  Future<String> cut(String pile, int n) => _serial(() async {
    final raw = await _api.tarotTableOp(_sessionId(), 'cut', {
      'pile': pile,
      'n': n,
    });
    _set(
      _current.withServer(
        ServerView.fromJson(raw['table'] as Map<String, dynamic>),
      ),
    );
    return raw['pile'] as String;
  });

  Future<void> merge(List<String> topFirst, String into) => _serial(() async {
    final view = await _op('merge', {'piles': topFirst, 'into': into});
    _set(_current.withServer(view));
  });

  /// Saca la carta de `position` y la deja boca abajo junto al monton.
  Future<TableCard> take(String pile, int position) => _serial(() async {
    final raw = await _api.tarotTableOp(_sessionId(), 'take', {
      'pile': pile,
      'position': position,
    });
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

  Future<void> giveBack(String slug, String pile) => _serial(() async {
    final view = await _op('return', {'slug': slug, 'pile': pile});
    _set(_current.withServer(view));
  });

  Future<void> gather(String pile) => _serial(() async {
    final view = await _op('gather', {'pile': pile});
    _set(_current.withServer(view).copyWith(spread: () => null));
  });

  // ---------- disposicion local ----------

  /// Cambia la disposicion (mover, voltear, elegir tirada...). Con
  /// `undoable`, la mesa de antes queda ofrecida para deshacer.
  void arrange(
    TableState Function(TableState) change, {
    bool undoable = false,
  }) {
    final before = _current;
    final next = change(before);
    if (identical(next, before)) return;
    if (undoable) {
      _undo = before;
      _undoUntil = now().add(undoWindow);
    }
    _set(next);
  }

  bool get canUndo =>
      _undo != null && _undoUntil != null && now().isBefore(_undoUntil!);

  /// Vuelve a la disposicion de antes del ultimo gesto.
  ///
  /// Deshace lo LOCAL. El mazo del servidor no retrocede: la foto se reconcilia
  /// con la vista actual, asi que una carta que ya volvio al mazo no reaparece.
  bool undo() {
    if (!canUndo) return false;
    final snap = _undo!;
    _forgetUndo();
    final server = _current.server;
    _set(server == null ? snap : snap.withServer(server));
    return true;
  }

  void _forgetUndo() {
    _undo = null;
    _undoUntil = null;
  }

  // ---------- interpretar y cerrar ----------

  /// Pide la lectura de Tradicion. Gasta cupo: un 402 llega tal cual a la
  /// pantalla, que abre el paywall.
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
  Future<Map<String, dynamic>> closeCircle() => _serial(() async {
    final s = _current;
    final reading = await _api.tarotCloseTable(_sessionId(), table: s.toJson());
    _forgetUndo();
    final userId = _userId;
    if (userId != null) await _store.clear(userId);
    _saveTimer?.cancel();
    state = AsyncData(TableState(camera: s.camera));
    return reading;
  });
}

final tableControllerProvider =
    AsyncNotifierProvider<TableController, TableState>(TableController.new);
