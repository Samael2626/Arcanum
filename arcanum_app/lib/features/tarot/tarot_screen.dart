/// Pantalla de la mesa de tarot: carga catalogos, monta el director y atiende
/// lo que la mesa pide (avisos, paneles, tienda, errores).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import 'application/table_controller.dart';
import 'domain/table_models.dart';
import 'domain/table_state.dart';
import 'table/table_director.dart';
import 'table/table_overlays.dart';
import 'table/table_panel.dart';
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
  const TarotTableScreen({super.key});

  @override
  ConsumerState<TarotTableScreen> createState() => _TarotTableScreenState();
}

class _TarotTableScreenState extends ConsumerState<TarotTableScreen>
    with WidgetsBindingObserver
    implements TableEffects {
  TableDirector? _director;

  /// Panel anclado abierto (D7): como mucho uno.
  ({Rect anchor, String title, WidgetBuilder body})? _panel;

  void _openPanel(Rect anchor, String title, WidgetBuilder body) =>
      setState(() => _panel = (anchor: anchor, title: title, body: body));

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _director?.dispose();
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
  ) => _director ??= TableDirector(
    ops: _ops,
    effects: this,
    decks: c.decks,
    spreads: c.spreads,
  );

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(tableControllerProvider);
    final catalog = ref.watch(tarotCatalogProvider);
    final body = switch ((table, catalog)) {
      (AsyncData(), AsyncData(:final value)) => TarotTableView(
        director: _directorFor(value),
      ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => _Failure(
        message: _describe(error),
        onRetry: () {
          ref.invalidate(tarotCatalogProvider);
          ref.invalidate(tableControllerProvider);
        },
      ),
      _ => const Center(
        child: CircularProgressIndicator(color: ArcanumColors.gold),
      ),
    };
    final panel = _panel;
    return PopScope(
      // atras cierra el panel antes que la mesa
      canPop: panel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePanel();
      },
      child: Scaffold(
        backgroundColor: ArcanumColors.background,
        body: SafeArea(
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
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  tooltip: 'Volver',
                  icon: const Icon(
                    Icons.arrow_back,
                    color: ArcanumColors.goldLight,
                  ),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/hoy'),
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
  @override
  void toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 2600),
        ),
      );
  }

  @override
  void error(Object error) => toast(_describe(error));

  static String _describe(Object error) {
    if (error is DioException) {
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      if (error.response == null) {
        return 'No hay conexión con el servidor. Inténtalo de nuevo.';
      }
    }
    return 'No se pudo completar. Inténtalo de nuevo.';
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
  void toggleSound() => toast('El sonido de la mesa llega más adelante.');

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
            f.nameEs ?? f.name ?? 'Carta',
            style: const TextStyle(
              fontSize: 22,
              height: 1.1,
              color: ArcanumColors.ivory,
            ),
          ),
          Text(card.reversed ? 'Invertida' : 'Al derecho', style: _muted),
          const SizedBox(height: 8),
          if (inSpread)
            Text(sp.slots[slot].meaning, style: _body)
          else if (card.host == null)
            Text(
              'No cuenta para la lectura: arrástrala a un hueco.',
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
        onSeal: (q) {
          _ops.arrange((s) => s.copyWith(seal: () => Seal(text: q)));
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
    // la clave vive lo que vive el panel: reintentar no cobra dos veces
    final key = IdempotencyKey.create();
    final seal = dir.table.seal;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArcanumColors.surface,
      builder: (context) => _InterpretationSheet(
        question: seal?.text,
        interpret: () => _ops.interpret(idempotencyKey: key),
        close: () async {
          await _ops.closeCircle();
          toast('Círculo cerrado. La lectura quedó guardada en Lecturas.');
        },
        onError: (e) {
          if (isCreditsRequired(e)) {
            Navigator.pop(context);
            creditsRequired();
          } else {
            error(e);
          }
        },
      ),
    );
  }

  @override
  void openHistory() {
    final readings = ref.read(arcanumApiProvider).tarotReadings();
    _openPanel(
      _menuAnchor,
      'Lecturas guardadas',
      (context) => FutureBuilder(
        future: readings,
        builder: (context, snap) {
          final rows = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (snap.hasError) Text(_describe(snap.error!), style: _muted),
              if (rows == null && !snap.hasError)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold),
                  ),
                ),
              if (rows != null && rows.isEmpty)
                Text('Todavía no has cerrado ningún círculo.', style: _muted),
              for (final r in rows ?? const <Map<String, dynamic>>[])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _spreadName(r['spread_type'] as String),
                    style: _body,
                  ),
                  subtitle: Text(
                    [
                      _date(r['created_at'] as String?),
                      if (r['question'] != null) '«${r['question']}»',
                    ].join(' · '),
                    style: _muted,
                  ),
                  // solo las lecturas de la mesa guardaron la mesa: las demas no se recolocan
                  trailing: r['table_snapshot'] == null
                      ? null
                      : TextButton(
                          onPressed: () => _continue(r),
                          child: const Text('Continuar'),
                        ),
                ),
            ],
          );
        },
      ),
    );
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
      toast('La lectura vuelve a la mesa.');
    } on Object catch (e) {
      error(e);
    }
  }

  String _spreadName(String slug) {
    if (slug == 'free') return 'Lectura libre';
    for (final s in _director?.spreads ?? const <SpreadDef>[]) {
      if (s.slug == slug) return s.name;
    }
    return 'Tirada';
  }

  static String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
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
  final ValueChanged<String> onSeal;

  @override
  State<_SealForm> createState() => _SealFormState();
}

class _SealFormState extends State<_SealForm> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _seal() {
    final q = _text.text.trim();
    if (q.isEmpty) return widget.onCancel();
    widget.onSeal(q);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
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

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              letterSpacing: 1,
              color: ArcanumColors.goldLight,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _InterpretationSheet extends StatefulWidget {
  const _InterpretationSheet({
    required this.question,
    required this.interpret,
    required this.close,
    required this.onError,
  });

  final String? question;
  final Future<Interpretation> Function() interpret;
  final Future<void> Function() close;
  final void Function(Object error) onError;

  @override
  State<_InterpretationSheet> createState() => _InterpretationSheetState();
}

class _InterpretationSheetState extends State<_InterpretationSheet> {
  Interpretation? _reading;
  bool _working = false;

  Future<void> _go(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on Object catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    return _SheetFrame(
      title: r?.spreadName ?? 'Interpretación',
      children: [
        if (widget.question != null) ...[
          const _Label('Tu pregunta'),
          Text('«${widget.question}»', style: _body),
          const SizedBox(height: 14),
        ],
        if (r == null) ...[
          Text(
            'Interpretar gasta una lectura de tu cupo diario de tarot.',
            style: _muted,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _working
                ? null
                : () => _go(() async {
                    final reading = await widget.interpret();
                    if (mounted) setState(() => _reading = reading);
                  }),
            child: Text(_working ? 'Interpretando…' : 'Interpretar'),
          ),
        ] else ...[
          if (r.skyLine case final sky?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(sky, style: _muted),
            ),
          for (final c in r.cards) ...[
            _Label(c.position),
            Text(
              '${c.face.nameEs ?? c.face.name ?? c.face.slug}${c.face.reversed ? ' · invertida' : ''}',
              style: const TextStyle(
                fontSize: 16,
                color: ArcanumColors.goldLight,
              ),
            ),
            if (c.positionMeaning != null)
              Text(c.positionMeaning!, style: _muted),
            const SizedBox(height: 4),
            Text(c.meaning, style: _body),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _working
                ? null
                : () => _go(() async {
                    await widget.close();
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: const Text('Cerrar el círculo'),
          ),
        ],
      ],
    );
  }
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
