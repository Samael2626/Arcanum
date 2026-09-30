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
    return Scaffold(
      backgroundColor: ArcanumColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: body),
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
          ],
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
    _sheet(
      title: f.nameEs ?? f.name ?? 'Carta',
      children: [
        if (card.reversed) const _Note('Invertida'),
        if (sp != null && slot != null && slot < sp.cardCount) ...[
          _Label('${slot + 1} · ${sp.slots[slot].name}'),
          Text(sp.slots[slot].meaning, style: _body),
        ] else if (card.host != null)
          const _Note('Aclaratoria')
        else
          const _Note('Fuera de la tirada: no cuenta para la lectura'),
        const SizedBox(height: 12),
        Text(
          'El significado de la carta llega con la interpretación.',
          style: _muted,
        ),
      ],
    );
  }

  @override
  void openSeal() {
    final text = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArcanumColors.surfaceHigh,
        title: const Text('Sellar la pregunta'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Escríbela antes de tirar',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final q = text.text.trim();
              if (q.isNotEmpty) {
                _ops.arrange((s) => s.copyWith(seal: () => Seal(text: q)));
              }
              Navigator.pop(context);
            },
            child: const Text('Sellar'),
          ),
        ],
      ),
    ).whenComplete(text.dispose);
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
    final api = ref.read(arcanumApiProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArcanumColors.surface,
      builder: (context) => FutureBuilder(
        future: api.tarotReadings(),
        builder: (context, snap) {
          final rows = snap.data;
          return _SheetFrame(
            title: 'Lecturas',
            children: [
              if (snap.hasError) Text(_describe(snap.error!), style: _muted),
              if (rows == null && !snap.hasError)
                const Center(
                  child: CircularProgressIndicator(color: ArcanumColors.gold),
                ),
              if (rows != null && rows.isEmpty)
                Text('Todavía no has cerrado ningún círculo.', style: _muted),
              for (final r in rows ?? const <Map<String, dynamic>>[])
                ListTile(
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
                ),
            ],
          );
        },
      ),
    );
  }

  String _spreadName(String slug) {
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

  void _sheet({required String title, required List<Widget> children}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArcanumColors.surface,
      builder: (context) => _SheetFrame(title: title, children: children),
    );
  }
}

const _body = TextStyle(fontSize: 15, height: 1.45, color: ArcanumColors.ivory);
const _muted = TextStyle(
  fontSize: 13,
  height: 1.4,
  color: ArcanumColors.ivoryMuted,
);

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

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: ArcanumColors.goldLight,
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
          if (r.moonPhase != null || r.planetaryHour != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (r.moonPhase != null) r.moonPhase!,
                  if (r.planetaryHour != null) 'hora de ${r.planetaryHour}',
                ].join(' · '),
                style: _muted,
              ),
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
