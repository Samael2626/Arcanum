import 'package:flutter/material.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../sigilos/sigil_store.dart';
import '../sigilos/taller_carga.dart';
import '../sigilos/taller_screen.dart';
import 'grimorio_atmosphere.dart';

class GrimorioDetail extends ConsumerStatefulWidget {
  final String id;

  /// Atmósfera del regente del día (heredada de la hoja de la lista para que la
  /// transición no parpadee de color). Si es null, se resuelve al cargar.
  final ArcanumMood? mood;
  const GrimorioDetail({super.key, required this.id, this.mood});
  @override
  ConsumerState<GrimorioDetail> createState() => _GrimorioDetailState();
}

class GrimoireFetchFailure implements Exception {
  const GrimoireFetchFailure(this.cause);
  final Object cause;
}

class GrimoireDecryptFailure implements Exception {
  const GrimoireDecryptFailure(this.cause);
  final Object cause;
}

class _GrimorioDetailState extends ConsumerState<GrimorioDetail> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<(Map<String, dynamic>, String)> _future = _load();
  bool _deleting = false;

  Future<(Map<String, dynamic>, String)> _load() async {
    late final Map<String, dynamic> entry;
    try {
      entry = await _api.grimoireGet(widget.id);
    } catch (error) {
      throw GrimoireFetchFailure(error);
    }
    late final String content;
    try {
      content = await ref
          .read(grimoireCryptoProvider)
          .decryptText(
            entry['encrypted_content'] as String,
            entry['content_iv'] as String,
          );
    } catch (error) {
      throw GrimoireDecryptFailure(error);
    }
    return (entry, content);
  }

  // llaves: una flecha devolveria el Future a setState, y eso lanza
  void _retry() => setState(() {
        _future = _load();
      });

  // el sigilo se decodifica una vez por contenido, no en cada build
  String? _sigilContent;
  SigilDecoded? _sigil;
  SigilDecoded? _decodeSigil(String content) {
    if (content != _sigilContent) {
      _sigilContent = content;
      _sigil = decodeSigilEntry(content);
    }
    return _sigil;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _continueSigil(SigilEntry entry) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => TallerScreen(entryId: widget.id, initial: entry)),
    );
    if (mounted && saved == true) _retry();
  }

  /// Cargar desde el Grimorio: la carga se anota en la entrada; soltar borra
  /// la intencion y deja el dibujo con la fecha.
  Future<void> _chargeSigil(SigilEntry entry) async {
    final r = await Navigator.of(context, rootNavigator: true).push<ChargeResult>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => TallerCarga(doc: entry.doc, keepLabel: 'Anotar')),
    );
    if (!mounted || r == null) return;
    final release = r.end == ChargeEnd.release;
    if (release && (!await confirmRelease(context, saved: true) || !mounted)) return;
    final store = SigilStore(_api, ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider), preview: ref.read(sigilPreviewProvider));
    try {
      final charged = SigilEntry(entry.doc, charges: [...entry.charges, await store.chargeNow(r.seconds)]);
      await store.save(release ? releasedCopy(charged, DateTime.now()) : charged, entryId: widget.id);
    } catch (error) {
      debugPrint('ARCANUM grimorio: fallo al anotar la carga ($error).');
      _snack(release
          ? 'No se pudo soltar: la intención sigue guardada. Inténtalo de nuevo.'
          : 'No se pudo anotar la carga. Revisa la conexión e inténtalo de nuevo.');
      return;
    }
    _snack(release ? 'Soltado. No lo busques.' : 'Carga anotada en el sigilo.');
    _retry();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArcanumColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Deshacer el sello?', style: ArcanumText.heading(22)),
        content: Text(
          'Esta entrada se borrará para siempre. No hay forma de recuperarla.',
          style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Conservar',
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Borrar',
              style: ArcanumText.body(15, color: ArcanumColors.burgundyLight),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _deleting = true);
      try {
        await _api.grimoireDelete(widget.id);
        if (mounted) Navigator.pop(context, true);
      } catch (error) {
        // El usuario ve un mensaje amable, pero la causa real no se pierde:
        // sin esto, un borrado que falla siempre sería indistinguible de uno
        // que falla por red.
        debugPrint('ARCANUM grimorio: fallo al borrar la entrada ($error).');
        if (!mounted) return;
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo borrar la entrada. Inténtalo de nuevo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>, String)>(
      future: _future,
      builder: (context, snap) {
        final entry = snap.data?.$1;
        final day = GrimoireDay.from(
          entry?['entry_date'] as String?,
          entry?['day_planet'] as String?,
        );
        final mood = widget.mood ?? day.mood;
        final accent = mood.accent;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: ArcanumColors.ivoryMuted,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: ArcanumColors.burgundyLight,
                ),
                onPressed: snap.hasData && !_deleting ? _confirmDelete : null,
              ),
            ],
          ),
          body: Stack(
            children: [
              // La página revive la atmósfera del momento en que fue sellada;
              // intensidad baja → tinta sobre pergamino teñido, no wash de color.
              Positioned.fill(child: GrimoireSky(mood: mood, intensity: 0.26)),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _body(snap, mood, accent, day),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    AsyncSnapshot<(Map<String, dynamic>, String)> snap,
    ArcanumMood mood,
    Color accent,
    GrimoireDay day,
  ) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(
          color: ArcanumColors.gold,
          strokeWidth: 2,
        ),
      );
    }
    if (snap.hasError) {
      final decryptionFailed = snap.error is GrimoireDecryptFailure;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '⛧',
                style: TextStyle(
                  fontSize: 40,
                  color: accent.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                decryptionFailed
                    ? 'El sello resiste'
                    : 'No se pudo abrir la entrada',
                style: ArcanumText.heading(22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                decryptionFailed
                    ? 'La clave de este dispositivo no pudo descifrar la entrada.'
                    : 'Tus palabras siguen selladas. Revisa tu conexión e inténtalo de nuevo.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
              if (!decryptionFailed) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final entry = snap.data!.$1;
    final content = snap.data!.$2;
    final type = entry['entry_type'] as String?;
    final title = (entry['title'] as String?)?.trim();
    final titleText = (title == null || title.isEmpty) ? 'Sin título' : title;
    final moon = entry['moon_phase'] as String?;
    final ph = entry['planetary_hour'] as String?;
    final dp = entry['day_planet'] as String? ?? day.planet;

    final ctx = <String>[
      if (ph != null) '${planetGlyph[ph] ?? ''} hora de ${planetEs[ph] ?? ph}',
      if (moon != null && moon.isNotEmpty) '☽ $moon',
      'día de ${planetEs[dp] ?? dp}',
    ].join('    ·    ');

    final colophon = moon != null && moon.isNotEmpty
        ? 'Sellado bajo la Luna en $moon'
        : 'Sellado bajo el cielo de ${day.weekdayEs}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 40),
      children: [
        Cascade(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entryTypeGlyph[type] ?? '❦',
                    style: TextStyle(fontSize: 14, color: accent),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    (entryTypeEs[type] ?? 'Nota').toUpperCase(),
                    style: ArcanumText.label().copyWith(
                      color: accent.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titleText,
                style: ArcanumText.heading(32).copyWith(height: 1.05),
              ),
              const SizedBox(height: 10),
              Text(
                ctx,
                style: ArcanumText.body(13, color: ArcanumColors.goldMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _OrnamentRule(accent: accent),
        const SizedBox(height: 22),
        Cascade(
          delayMs: 120,
          // un sigilo del taller se dibuja (y se puede seguir editando); una
          // entrada «Sigilo» escrita a mano antes del taller sigue siendo texto
          child: switch (type == 'sigil' ? _decodeSigil(content) : null) {
            SigilReadable(:final entry) => _SigilBody(
                entry: entry,
                onEdit: () => _continueSigil(entry),
                onCharge: () => _chargeSigil(entry),
                accent: accent,
              ),
            SigilUnreadable(:final newerVersion) => Text(
                newerVersion
                    ? 'Este sigilo se guardó con una versión más nueva de ARCANUM. Actualiza la app para verlo.'
                    : 'Este sigilo no se puede dibujar: sus datos están dañados.',
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted, italic: true),
              ),
            null => _ManuscriptBody(content: content, accent: accent),
          },
        ),
        const SizedBox(height: 34),
        Cascade(
          delayMs: 220,
          child: ClosingColophon(note: colophon, accent: accent),
        ),
      ],
    );
  }
}

// ── Cuerpo del manuscrito: capitular iluminada + jerarquía de página ─────────

class _ManuscriptBody extends StatelessWidget {
  final String content;
  final Color accent;
  const _ManuscriptBody({required this.content, required this.accent});

  @override
  Widget build(BuildContext context) {
    final body = ArcanumText.body(
      17.5,
      color: ArcanumColors.ivory,
    ).copyWith(height: 1.72);

    // Párrafos separados por línea en blanco o salto simple.
    final paras = content
        .trim()
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paras.isEmpty) {
      return Text('(sin contenido)', style: body);
    }

    // Primer párrafo con inicial iluminada; el resto, cuerpo normal.
    final first = paras.first;
    final initial = first.characters.first.toString();
    final rest = first.characters.skip(1).toString();

    final children = <Widget>[
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: initial,
              style: ArcanumText.heading(54, color: ArcanumColors.gold)
                  .copyWith(
                    height: 0.9,
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
            ),
            TextSpan(text: rest, style: body),
          ],
        ),
      ),
    ];
    for (final p in paras.skip(1)) {
      children.add(const SizedBox(height: 14));
      children.add(Text(p, style: body));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _OrnamentRule extends StatelessWidget {
  final Color accent;
  const _OrnamentRule({required this.accent});
  @override
  Widget build(BuildContext context) {
    Widget rule() => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              ArcanumColors.goldMuted.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        rule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('✧', style: TextStyle(color: accent, fontSize: 16)),
        ),
        rule(),
      ],
    );
  }
}

// ── Cuerpo de un sigilo del taller ───────────────────────────────────────────

/// El sigilo dibujado por el mismo motor que lo creo. La intencion no se
/// muestra sola: en la practica del sigilo se suelta; queda a un toque. Un
/// sigilo soltado ya no la tiene, ni se edita ni se carga.
class _SigilBody extends StatefulWidget {
  final SigilEntry entry;
  final VoidCallback onEdit, onCharge;
  final Color accent;
  const _SigilBody({required this.entry, required this.onEdit, required this.onCharge, required this.accent});
  @override
  State<_SigilBody> createState() => _SigilBodyState();
}

class _SigilBodyState extends State<_SigilBody> {
  bool _showIntention = false;
  late LettersScene _scene = widget.entry.doc.scene();

  @override
  void didUpdateWidget(_SigilBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.entry, widget.entry)) _scene = widget.entry.doc.scene();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _chargeLine(SigilCharge c) => [
        '${dayMonthEs(c.at)}, ${_two(c.at.hour)}:${_two(c.at.minute)}',
        '${c.seconds} s',
        if (c.moon != null && c.moon!.isNotEmpty) '☽ ${c.moon}',
        if (c.hour != null) '${planetGlyph[c.hour] ?? ''} hora de ${planetEs[c.hour] ?? c.hour}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final e = widget.entry, accent = widget.accent;
    final muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted);
    final outlined = OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: accent);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(
        builder: (context, box) => Center(
          child: CustomPaint(size: Size.square(box.maxWidth), painter: SigilScenePainter(bg: _scene.bg, fg: _scene.fg)),
        ),
      ),
      const SizedBox(height: 16),
      if (e.isReleased)
        Text('Soltado el ${dayMonthEs(e.released!)}. La intención ya no está en ARCANUM.',
            textAlign: TextAlign.center, style: ArcanumText.body(16, color: ArcanumColors.goldMuted, italic: true))
      else ...[
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.onCharge, style: outlined, child: const Text('Cargar'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: widget.onEdit, style: outlined, child: const Text('Seguir en el taller'))),
        ]),
        TextButton(
          onPressed: () => setState(() => _showIntention = !_showIntention),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.ivoryMuted),
          child: Text(_showIntention ? 'Ocultar la intención' : 'Ver la intención'),
        ),
        if (_showIntention) Text('«${e.doc.sigil.intention}»', textAlign: TextAlign.center, style: ArcanumText.body(17, italic: true)),
      ],
      if (e.charges.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(e.charges.length == 1 ? 'Cargado 1 vez' : 'Cargado ${e.charges.length} veces',
            style: ArcanumText.label().copyWith(color: ArcanumColors.gold, letterSpacing: 2)),
        const SizedBox(height: 6),
        for (final c in e.charges) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(_chargeLine(c), style: muted)),
      ],
    ]);
  }
}
