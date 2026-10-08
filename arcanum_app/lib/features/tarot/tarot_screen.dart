/// Pantalla de la mesa de tarot: carga catalogos, monta el director y atiende
/// lo que la mesa pide (avisos, paneles, tienda, errores).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import 'application/table_controller.dart';
import 'domain/table_error.dart';
import 'domain/table_models.dart';
import 'domain/table_state.dart';
import 'reading/lectura_revelada.dart';
import 'reading/readings_history.dart';
import 'table/table_director.dart';
import 'table/table_moon.dart';
import 'table/table_notice.dart';
import 'table/table_overlays.dart';
import 'table/table_panel.dart';
import 'table/table_sound.dart';
import 'table/table_sound_player.dart';
import 'table/table_view.dart';

/// Mazos y tiradas del servidor: la app y el Oraculo leen la misma definicion.
final tarotCatalogProvider =
    FutureProvider<({List<DeckInfo> decks, List<SpreadDef> spreads})>((
      ref,
    ) async {
      final api = ref.read(arcanumApiProvider);
      final (decks, spreads) = await (
        api.tarotDecks(),
        api.tarotSpreads(),
      ).wait;
      return (
        decks: [for (final d in decks) DeckInfo.fromJson(d)],
        spreads: [for (final s in spreads) SpreadDef.fromJson(s)],
      );
    });

class TarotTableScreen extends ConsumerStatefulWidget {
  const TarotTableScreen({super.key, this.continueFrom});

  /// Lectura guardada que se abre en la mesa al llegar (desde `/lecturas`).
  final Map<String, dynamic>? continueFrom;

  /// Donde se recuerda el silencio de la mesa entre sesiones.
  static const mutedKey = 'tarot_mesa_silencio';

  @override
  ConsumerState<TarotTableScreen> createState() => _TarotTableScreenState();
}

class _TarotTableScreenState extends ConsumerState<TarotTableScreen>
    with WidgetsBindingObserver
    implements TableEffects {
  TableDirector? _director;
  final GlobalKey _tableRootKey = GlobalKey();

  /// Panel anclado abierto (D7): como mucho uno.
  ({Rect anchor, String title, WidgetBuilder body})? _panel;

  void _openPanel(Rect anchor, String title, WidgetBuilder body) =>
      setState(() => _panel = (anchor: anchor, title: title, body: body));

  /// Lectura ya interpretada de esta mesa: reabrirla no vuelve a cobrar.
  Interpretation? _reading;

  /// La «Lectura revelada» esta a la vista (D7).
  bool _revealing = false;

  void _closePanel() {
    if (_panel != null) setState(() => _panel = null);
  }

  /// Ancla de lo elegido en un radial del paño: un punto donde se abrio.
  Rect get _menuAnchor {
    final at =
        _director?.menuAt ?? MediaQuery.sizeOf(context).center(Offset.zero);
    return Rect.fromCenter(center: at, width: 1, height: 1);
  }

  TableController get _ops => ref.read(tableControllerProvider.notifier);

  /// La lectura de `continueFrom` ya se pidio: no se repite en cada build.
  bool _continueAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMuted();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _director?.dispose();
    _notices.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // al irse a segundo plano la mesa se guarda YA: Android puede matar la app
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ops.flush();
    }
  }

  TableDirector _directorFor(
    ({List<DeckInfo> decks, List<SpreadDef> spreads}) c,
  ) {
    final existing = _director;
    if (existing != null) return existing;
    final dir = TableDirector(
      ops: _ops,
      effects: this,
      decks: c.decks,
      spreads: c.spreads,
      sound: TableSound(player: ref.read(tableSoundPlayerProvider)),
    )..muted = _silent;
    // el motor arranca y carga en segundo plano: la mesa no lo espera
    unawaited(dir.sound.prepare());
    return _director = dir;
  }

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(tableControllerProvider);
    final catalog = ref.watch(tarotCatalogProvider);
    final current = table.asData?.value;
    final fan = current?.fan;
    final fanPositions = fan == null
        ? null
        : current?.server?.piles[fan.pid]?.positions;
    // la Luna de la lectura si ya se interpreto; si no, la de ahora
    final moon = tableMoonFor(_reading, ref.watch(tableMoonNowProvider).value);
    final body = switch ((table, catalog)) {
      (AsyncData(), AsyncData(:final value)) => TarotTableView(
        director: _directorFor(value),
        moonIllumination: moon?.illumination,
      ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => _Failure(
        message: _failedToLoad(error),
        onRetry: () {
          ref.invalidate(tarotCatalogProvider);
          ref.invalidate(tableControllerProvider);
        },
      ),
      _ => const Center(
        child: CircularProgressIndicator(color: ArcanumColors.gold),
      ),
    };
    final pending = widget.continueFrom;
    if (pending != null && !_continueAsked && _director != null) {
      _continueAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _continue(pending);
      });
    }
    final panel = _panel;
    return PopScope(
      // atras cierra el panel antes que la mesa
      canPop: panel == null && !_revealing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (panel != null) {
          _closePanel();
        } else {
          setState(() => _revealing = false);
        }
      },
      child: Scaffold(
        backgroundColor: ArcanumColors.background,
        body: SafeArea(
          child: Stack(
            key: _tableRootKey,
            children: [
              // con la lectura encima, la mesa sale del lector de pantalla
              Positioned.fill(
                child: ExcludeSemantics(
                  excluding: _revealing && _reading != null,
                  child: Stack(
                    children: [
                      Positioned.fill(child: body),
                      // encima de la mesa y fuera de su Listener: sus toques no tocan el paño
                      if (_director != null) ...[
                        const Positioned.fill(child: TableHelp()),
                        Positioned.fill(
                          child: UndoDot(
                            until: _ops.undoUntil,
                            onUndo: () async {
                              try {
                                if (await _ops.undo()) toast('Deshecho');
                              } on Object catch (e) {
                                error(e);
                              }
                            },
                          ),
                        ),
                      ],
                      if (_director != null &&
                          fanPositions != null &&
                          fanPositions.isNotEmpty)
                        Positioned.fill(
                          child: FanPickerButton(
                            positions: fanPositions,
                            onChoose: _director!.takeFanPosition,
                          ),
                        ),
                      if (_director case final dir?)
                        Positioned.fill(
                          child: NoticeLayer(
                            board: _notices,
                            camera: dir.camera,
                            embroideryAt: TableDirector.embroideryAt,
                          ),
                        ),
                      // la fase, junto a la ayuda, como en el prototipo
                      if (moon != null && _director != null)
                        Positioned(
                          top: 4,
                          right: 52,
                          child: MoonBadge(moon: moon, onTap: toast),
                        ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: IconButton(
                          tooltip: 'Volver',
                          icon: const Icon(
                            Icons.arrow_back,
                            color: ArcanumColors.goldLight,
                          ),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/hoy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_revealing && _reading != null)
                Positioned.fill(
                  child: LecturaRevelada(
                    reading: _reading!,
                    spread: _director?.spread,
                    onBack: () => setState(() => _revealing = false),
                    onCloseCircle: _closeCircle,
                    onAskOracle: _askOracle,
                    entrance: _entranceOf(_reading!),
                  ),
                ),
              if (panel != null)
                Positioned.fill(
                  child: TablePanel(
                    anchor: panel.anchor,
                    title: panel.title,
                    onClose: _closePanel,
                    child: Builder(builder: panel.body),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- lo que pide la mesa ----------
  /// Los avisos ya no son un SnackBar blanco: salen en la mesa, segun lo que
  /// dicen (ver `table_notice.dart`).
  final NoticeBoard _notices = NoticeBoard();

  @override
  void toast(String message, {NoticeKind kind = NoticeKind.pill, Offset? at}) {
    if (!mounted) return;
    final piece = kind == NoticeKind.piece && at != null;
    _notices.show(
      TableNotice(
        message,
        kind: piece || kind == NoticeKind.embroidery ? kind : NoticeKind.pill,
        at: piece ? at : null,
      ),
    );
  }

  @override
  void error(Object error) {
    toast(tableErrorMessage(error));
    // sesion caida: se cierra de verdad y la guarda del router lleva al login
    if (isTableSessionLost(error)) ref.read(authProvider.notifier).logout();
  }

  /// La mesa no cargo. Con la sesion caida, «Reintentar» fallaria igual:
  /// se cierra despues del fotograma (no en pleno build) y el router lleva
  /// al login.
  String _failedToLoad(Object error) {
    if (isTableSessionLost(error)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(authProvider.notifier).logout();
      });
    }
    return tableErrorMessage(error);
  }

  @override
  void creditsRequired() {
    if (mounted) context.push('/paywall');
  }

  @override
  void flipped(TableCard card) {}

  @override
  void shuffled(String pile, String style) {}

  @override
  void muteChanged(bool muted) => _saveMuted(muted);

  bool _silent = false;

  Future<void> _loadMuted() async {
    try {
      final muted =
          (await SharedPreferences.getInstance()).getBool(
            TarotTableScreen.mutedKey,
          ) ??
          false;
      _silent = muted;
      _director?.muted = muted;
    } on Object {
      // sin preferencias se queda como esta: vibrando
    }
  }

  Future<void> _saveMuted(bool muted) async {
    _silent = muted;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        TarotTableScreen.mutedKey,
        muted,
      );
    } on Object {
      // si no se puede guardar, vale para esta sesion
    }
  }

  @override
  void openReading(TableCard card) {
    final dir = _director;
    if (dir == null) return;
    final sp = dir.spread;
    final slot = card.slot;
    final f = card.face;
    final inSpread = sp != null && slot != null && slot < sp.cardCount;
    _openPanel(
      dir.screenRectOfCard(card),
      inSpread
          ? '${slot + 1} · ${sp.slots[slot].name}'
          : card.host != null
          ? 'Aclaratoria'
          : 'Fuera de la tirada',
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            f.commonName,
            style: const TextStyle(
              fontSize: 22,
              height: 1.1,
              color: ArcanumColors.ivory,
            ),
          ),
          if (f.goldenDawnTitle case final gd?)
            Text(gd, style: _muted.copyWith(fontStyle: FontStyle.italic)),
          Text(card.reversed ? 'Invertida' : 'Al derecho', style: _muted),
          const SizedBox(height: 8),
          if (inSpread)
            Text(sp.slots[slot].meaning, style: _body)
          else if (card.host == null)
            Text(
              sp == null
                  ? TableDirector.spreadHint
                  : 'No cuenta para la lectura: arrástrala a un hueco.',
              style: _muted,
            ),
          const SizedBox(height: 8),
          Text(
            'El significado de la carta llega con la interpretación.',
            style: _muted,
          ),
        ],
      ),
    );
  }

  @override
  void openSeal() {
    final dir = _director;
    if (dir == null) return;
    _openPanel(
      dir.sealScreenRect,
      'Sellar la pregunta',
      (context) => _SealForm(
        onCancel: _closePanel,
        onSeal: (q, fieldRect) {
          final root = _tableRootKey.currentContext?.findRenderObject();
          if (root is RenderBox) {
            dir.sealFlight.fly(
              q,
              Rect.fromPoints(
                root.globalToLocal(fieldRect.topLeft),
                root.globalToLocal(fieldRect.bottomRight),
              ),
              dir.sealScreenRect,
            );
          }
          _ops.arrange((s) => s.copyWith(seal: () => Seal(text: q)));
          dir.sealed();
          _closePanel();
        },
      ),
    );
  }

  @override
  void openSealInfo(Seal seal) {
    final dir = _director;
    if (dir == null) return;
    _openPanel(
      dir.sealScreenRect,
      seal.open ? 'Pregunta abierta' : 'Pregunta sellada',
      // sellada no se enseña: para eso se sello
      (context) => seal.open
          ? Text('«${seal.text}»', style: _body)
          : Text('Se abre al interpretar.', style: _muted),
    );
  }

  @override
  void openInterpretation() {
    final dir = _director;
    if (dir == null) return;
    // la lectura de esta mesa: la que se acaba de ver o, si la pantalla se
    // monto de nuevo (al volver del Oraculo, 08-oct), la que la mesa tiene
    // guardada. Ya esta pagada: se abre sin aviso de cobro
    final shown = _reading ?? dir.table.server?.interpretation;
    if (shown != null && shown.describes(dir.table)) {
      return setState(() {
        _reading = shown;
        _revealing = true;
      });
    }
    // la de antes era de otras cartas: se interpreta la mesa de ahora
    _reading = null;
    // la clave vive lo que vive el panel: reintentar no cobra dos veces
    final key = IdempotencyKey.create();
    final seal = dir.table.seal;
    _openPanel(
      dir.embroideryScreenRect,
      'Interpretación',
      (context) => _InterpretPrompt(
        question: seal?.text,
        interpret: () => _ops.interpret(idempotencyKey: key),
        onReading: (r) {
          // el sello se rompe al interpretar
          if (seal != null && !seal.open) dir.sealBroken();
          setState(() {
            _panel = null;
            _reading = r;
            _revealing = true;
          });
        },
        onError: (e) {
          if (isCreditsRequired(e)) {
            _closePanel();
            creditsRequired();
          } else {
            error(e);
          }
        },
      ),
    );
  }

  /// Donde esta en la mesa cada carta de la lectura: de ahi vuelan al abrirla.
  List<Rect?> _entranceOf(Interpretation reading) {
    final dir = _director;
    if (dir == null) return const [];
    return [
      for (final c in reading.cards)
        if (dir.table.card(c.face.slug) case final card?)
          dir.screenRectOfCard(card)
        else
          null,
    ];
  }

  Future<void> _closeCircle() async {
    _director?.prepareCircleClose();
    try {
      await _ops.closeCircle();
      _director?.circleClosed();
      setState(() {
        _revealing = false;
        _reading = null;
      });
      toast(
        'Círculo cerrado. La lectura quedó guardada en Lecturas.',
        kind: NoticeKind.embroidery,
      );
    } on Object catch (e) {
      _director?.cancelCircleClose();
      error(e);
    }
  }

  @override
  void openHistory() {
    final readings = ref.read(arcanumApiProvider).tarotReadings();
    _openPanel(
      _menuAnchor,
      'Lecturas guardadas',
      (context) => TarotReadingsList(
        readings: readings,
        spreadName: (slug) =>
            tarotSpreadName(slug, _director?.spreads ?? const <SpreadDef>[]),
        onContinue: _continue,
      ),
    );
  }

  /// Del final de la lectura al Oraculo. `go` y no `push`: el Oraculo vive en
  /// el shell y apilarlo encima de la mesa duplica sus navegadores. No se
  /// pierde nada: la mesa queda guardada y el servidor devuelve la misma
  /// interpretacion sin volver a cobrarla.
  void _askOracle() {
    unawaited(_ops.flush());
    context.go('/oraculo');
  }

  /// Continuar: mesa nueva con las mismas cartas colocadas (decision del
  /// 30-sep). Abrir otra mesa recoge la actual, asi que si tiene cartas se pregunta.
  Future<void> _continue(Map<String, dynamic> reading) async {
    final busy = _director?.table.cards.isNotEmpty ?? false;
    if (busy) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ArcanumColors.surfaceHigh,
          title: const Text('Continuar esta lectura'),
          content: const Text(
            'La mesa que tienes ahora se recogerá sin guardar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _closePanel();
    try {
      await _ops.continueReading(reading);
      toast('La lectura vuelve a la mesa.', kind: NoticeKind.embroidery);
    } on Object catch (e) {
      error(e);
    }
  }
}

const _body = TextStyle(fontSize: 15, height: 1.45, color: ArcanumColors.ivory);
const _muted = TextStyle(
  fontSize: 13,
  height: 1.4,
  color: ArcanumColors.ivoryMuted,
);

/// Escribir y sellar la pregunta, dentro del panel anclado al sello.
class _SealForm extends StatefulWidget {
  const _SealForm({required this.onCancel, required this.onSeal});
  final VoidCallback onCancel;
  final void Function(String, Rect) onSeal;

  @override
  State<_SealForm> createState() => _SealFormState();
}

class _SealFormState extends State<_SealForm> {
  final _text = TextEditingController();
  final _fieldKey = GlobalKey();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _seal() {
    final q = _text.text.trim();
    if (q.isEmpty) return widget.onCancel();
    final field = _fieldKey.currentContext?.findRenderObject();
    if (field is! RenderBox) return;
    widget.onSeal(q, field.localToGlobal(Offset.zero) & field.size);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        key: _fieldKey,
        controller: _text,
        autofocus: true,
        maxLength: 300,
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _seal(),
        style: _body,
        decoration: const InputDecoration(
          hintText: '¿Qué quieres preguntar?',
          helperText:
              'Quedará sellada sobre el paño y se abrirá al interpretar.',
          helperMaxLines: 2,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
          const SizedBox(width: 6),
          FilledButton(onPressed: _seal, child: const Text('Sellar')),
        ],
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        letterSpacing: 1,
        color: ArcanumColors.gold,
      ),
    ),
  );
}

/// Antes de interpretar: la pregunta y lo que cuesta. Al interpretar se abre
/// la «Lectura revelada».
class _InterpretPrompt extends StatefulWidget {
  const _InterpretPrompt({
    required this.question,
    required this.interpret,
    required this.onReading,
    required this.onError,
  });

  final String? question;
  final Future<Interpretation> Function() interpret;
  final ValueChanged<Interpretation> onReading;
  final void Function(Object error) onError;

  @override
  State<_InterpretPrompt> createState() => _InterpretPromptState();
}

class _InterpretPromptState extends State<_InterpretPrompt> {
  bool _working = false;

  Future<void> _go() async {
    setState(() => _working = true);
    try {
      final reading = await widget.interpret();
      widget.onReading(reading);
    } on Object catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.question != null) ...[
        const _Label('Tu pregunta'),
        Text('«${widget.question}»', style: _body),
        const SizedBox(height: 10),
      ],
      Text(
        'Interpretar gasta una lectura de tu cupo diario de tarot.',
        style: _muted,
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: _working ? null : _go,
        child: Text(_working ? 'Interpretando…' : 'Interpretar'),
      ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: _body),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
