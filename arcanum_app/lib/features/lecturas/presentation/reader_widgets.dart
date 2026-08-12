import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/api/oracle_error.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../arte/materia_lore.dart';
import '../data/reader_settings.dart';
import '../domain/library_models.dart';
import '../library_messages.dart';

/// Los dos fondos de lectura.
///
/// Sepia no es un adorno: a media luz el papel viejo cansa menos que el negro
/// puro, y de noche al revés. Son los mismos dorados apagados en ambos, para
/// que la sección no cambie de identidad al cambiar de fondo.
class ReaderColors {
  ReaderColors._();

  static const sepiaBackground = Color(0xFF1A160F);
  static const sepiaInk = Color(0xFFE8DCC4);
  static const sepiaGold = Color(0xFFC9A84C);
  static const sepiaMuted = Color(0xFFA1937A);
}

/// Cabecera mínima: dónde estás y en qué idioma. Nada más.
class ReaderHeader extends StatelessWidget {
  final String chapterTitle;
  final int page;
  final int total;
  final bool spanish;
  final bool onSepia;
  final ValueChanged<bool> onLanguageChanged;
  final VoidCallback onSettings;
  final VoidCallback onClose;

  const ReaderHeader({
    super.key,
    required this.chapterTitle,
    required this.page,
    required this.total,
    required this.spanish,
    required this.onSepia,
    required this.onLanguageChanged,
    required this.onSettings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final muted = onSepia ? ReaderColors.sepiaMuted : ArcanumColors.ivoryMuted;
    final gold = onSepia ? ReaderColors.sepiaGold : ArcanumColors.gold;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.arrow_back, size: 20, color: muted),
                tooltip: 'Volver',
              ),
              Expanded(
                child: Text(
                  chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(13, color: muted),
                ),
              ),
              _LanguageToggle(
                spanish: spanish,
                gold: gold,
                muted: muted,
                onChanged: onLanguageChanged,
              ),
              IconButton(
                onPressed: onSettings,
                icon: Icon(Icons.text_fields, size: 20, color: muted),
                tooltip: 'Ajustes de lectura',
              ),
            ],
          ),
          // Una línea finísima de avance. Un porcentaje grande convertiría la
          // lectura en una tarea con barra de progreso.
          _ProgressLine(value: total == 0 ? 0 : page / total, gold: gold),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final double value;
  final Color gold;
  const _ProgressLine({required this.value, required this.gold});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 2,
        backgroundColor: gold.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation(gold.withValues(alpha: 0.55)),
      ),
    ),
  );
}

class _LanguageToggle extends StatelessWidget {
  final bool spanish;
  final Color gold;
  final Color muted;
  final ValueChanged<bool> onChanged;

  const _LanguageToggle({
    required this.spanish,
    required this.gold,
    required this.muted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _option('ES', spanish),
      Text('·', style: ArcanumText.body(12, color: muted)),
      _option('EN', !spanish),
    ],
  );

  Widget _option(String label, bool active) => Semantics(
    button: true,
    selected: active,
    label: label == 'ES' ? 'Leer en español' : 'Leer en el idioma original',
    child: InkWell(
      onTap: () => onChanged(label == 'ES'),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        // 44 de alto: objetivo táctil accesible aunque el texto sea pequeño.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Text(
          label,
          style: ArcanumText.body(12.5, color: active ? gold : muted),
        ),
      ),
    ),
  );
}

/// Barra fija: Anterior · Índice · Siguiente, más el marcador.
class ReaderBottomBar extends StatelessWidget {
  final bool onSepia;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onIndex;
  final VoidCallback onBookmark;

  const ReaderBottomBar({
    super.key,
    required this.onSepia,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onIndex,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = onSepia ? ReaderColors.sepiaMuted : ArcanumColors.ivoryMuted;
    final gold = onSepia ? ReaderColors.sepiaGold : ArcanumColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: gold.withValues(alpha: 0.14))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _action(
            'Anterior',
            Icons.chevron_left,
            canGoBack ? onPrevious : null,
            gold,
            muted,
          ),
          _action('Índice', Icons.list_alt_outlined, onIndex, gold, muted),
          _action(
            'Marcar',
            Icons.bookmark_border,
            onBookmark,
            gold,
            muted,
          ),
          _action(
            'Siguiente',
            Icons.chevron_right,
            canGoForward ? onNext : null,
            gold,
            muted,
          ),
        ],
      ),
    );
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback? onTap,
    Color gold,
    Color muted,
  ) {
    final color = onTap == null ? muted.withValues(alpha: 0.35) : gold;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            // 48 de alto mínimo: pulgar, no puntero.
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(11, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La página de pausa al acabar un capítulo.
///
/// No es un botón muerto al final de un scroll: es un descanso con una salida
/// clara. Cuando la obra se acaba, se cierra en vez de ofrecer un "siguiente"
/// que no lleva a ninguna parte.
class ChapterClosing extends StatelessWidget {
  final LibraryChapter chapter;
  final LibraryChapterSummary? next;
  final VoidCallback? onContinue;
  final bool onSepia;

  const ChapterClosing({
    super.key,
    required this.chapter,
    required this.next,
    required this.onContinue,
    required this.onSepia,
  });

  @override
  Widget build(BuildContext context) {
    final muted = onSepia ? ReaderColors.sepiaMuted : ArcanumColors.ivoryMuted;
    final gold = onSepia ? ReaderColors.sepiaGold : ArcanumColors.gold;
    final ink = onSepia ? ReaderColors.sepiaInk : ArcanumColors.ivory;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❦', style: TextStyle(fontSize: 30, color: gold)),
            const SizedBox(height: 22),
            Text(
              next == null ? 'Has terminado la obra' : 'Fin del capítulo',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(24, color: ink),
            ),
            const SizedBox(height: 10),
            Text(
              next == null
                  ? '${chapter.workTitle} queda leída. Lo que subrayaste sigue '
                        'en tu grimorio.'
                  : chapter.title,
              textAlign: TextAlign.center,
              style: ArcanumText.body(14, color: muted, italic: true),
            ),
            const SizedBox(height: 30),
            if (next != null && onContinue != null)
              _ClosingButton(
                label: 'Continuar al siguiente capítulo',
                sub: next!.title,
                gold: gold,
                ink: ink,
                muted: muted,
                onTap: onContinue!,
              )
            else
              _ClosingButton(
                label: 'Volver a la obra',
                sub: null,
                gold: gold,
                ink: ink,
                muted: muted,
                onTap: () => context.pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClosingButton extends StatelessWidget {
  final String label;
  final String? sub;
  final Color gold;
  final Color ink;
  final Color muted;
  final VoidCallback onTap;

  const _ClosingButton({
    required this.label,
    required this.sub,
    required this.gold,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withValues(alpha: 0.5)),
          color: gold.withValues(alpha: 0.07),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ArcanumText.body(15, color: gold)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub!, style: ArcanumText.body(12.5, color: muted)),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Capítulo que no se pudo abrir: sin red y sin descarga.
class ChapterUnavailable extends StatelessWidget {
  final String workSlug;
  final VoidCallback onRetry;

  const ChapterUnavailable({
    super.key,
    required this.workSlug,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '✶',
            style: TextStyle(fontSize: 44, color: ArcanumColors.goldMuted),
          ),
          const SizedBox(height: 18),
          Text(
            'No se pudo abrir este pasaje',
            textAlign: TextAlign.center,
            style: ArcanumText.heading(22),
          ),
          const SizedBox(height: 10),
          Text(
            'Este capítulo no está descargado y ahora mismo no hay conexión. '
            'Puedes descargar la obra entera desde su portada para leerla sin red.',
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 8),
          Text(
            chapterUnavailableMessage,
            textAlign: TextAlign.center,
            style: ArcanumText.body(
              13,
              color: ArcanumColors.ivoryMuted.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Reintentar',
                  style: ArcanumText.body(15, color: ArcanumColors.gold),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/saber/$workSlug'),
                child: Text(
                  'Ir a la portada',
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Hojas y diálogos ────────────────────────────────────────────────────────

/// Ajustes de lectura: cuerpo, ancho y fondo. Se aplican en vivo.
void showReaderSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: ArcanumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(readerSettingsProvider);
        final controller = ref.read(readerSettingsProvider.notifier);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AJUSTES DE LECTURA', style: ArcanumText.label()),
              const SizedBox(height: 18),
              _SliderRow(
                label: 'Tamaño de letra',
                value: settings.fontSize,
                min: ReaderSettings.minFontSize,
                max: ReaderSettings.maxFontSize,
                display: settings.fontSize.round().toString(),
                onChanged: controller.setFontSize,
              ),
              _SliderRow(
                label: 'Ancho de lectura',
                value: settings.maxWidth,
                min: ReaderSettings.minWidth,
                max: ReaderSettings.maxWidthLimit,
                display: settings.maxWidth.round().toString(),
                onChanged: controller.setMaxWidth,
              ),
              const SizedBox(height: 10),
              Text('Fondo', style: ArcanumText.body(14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final palette in ReaderPalette.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _PaletteChip(
                        palette: palette,
                        selected: settings.palette == palette,
                        onTap: () => controller.setPalette(palette),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: ArcanumText.body(14)),
          const Spacer(),
          Text(display, style: ArcanumText.body(13, color: ArcanumColors.gold)),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        activeColor: ArcanumColors.gold,
        inactiveColor: ArcanumColors.goldMuted.withValues(alpha: 0.3),
        label: display,
        onChanged: onChanged,
      ),
    ],
  );
}

class _PaletteChip extends StatelessWidget {
  final ReaderPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Fondo ${palette.label}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: palette == ReaderPalette.sepia
              ? ReaderColors.sepiaBackground
              : ArcanumColors.background,
          border: Border.all(
            color: selected
                ? ArcanumColors.gold
                : ArcanumColors.goldMuted.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          palette.label,
          style: ArcanumText.body(
            14,
            color: palette == ReaderPalette.sepia
                ? ReaderColors.sepiaInk
                : ArcanumColors.ivory,
          ),
        ),
      ),
    ),
  );
}

/// Pide la nota opcional al guardar un pasaje.
///
/// Devuelve la nota (posiblemente vacía) o null si se canceló. La nota se
/// cifra después, en el repositorio: aquí solo se recoge.
Future<String?> showPassageNoteDialog(
  BuildContext context, {
  required String quote,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: ArcanumColors.surface,
      title: Text(
        initial == null ? 'Guardar pasaje' : 'Editar nota',
        style: ArcanumText.heading(20, color: ArcanumColors.gold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: ArcanumColors.goldMuted, width: 2),
              ),
            ),
            child: Text(
              quote.length > 180 ? '${quote.substring(0, 180)}…' : quote,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: ArcanumText.body(
                13,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            maxLines: 3,
            style: ArcanumText.body(15),
            decoration: InputDecoration(
              hintText: 'Tu nota (opcional)',
              hintStyle: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              filled: true,
              fillColor: ArcanumColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 13, color: ArcanumColors.goldMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tu nota se cifra en este dispositivo. Nadie más puede leerla.',
                  style: ArcanumText.body(11.5, color: ArcanumColors.ivoryMuted),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(
            'Guardar',
            style: ArcanumText.body(14, color: ArcanumColors.gold),
          ),
        ),
      ],
    ),
  );
}

/// El encabezado de la primera página: regencia, aviso y puente a Materia.
///
/// Va en la página uno y no flotando sobre el texto: es contexto de entrada a
/// la lectura, no cromo permanente.
class ChapterOpening extends ConsumerWidget {
  final LibraryChapter chapter;
  final bool onSepia;

  const ChapterOpening({
    super.key,
    required this.chapter,
    required this.onSepia,
  });

  static const _planetGlyphs = {
    'sun': '☉',
    'moon': '☽',
    'mercury': '☿',
    'venus': '♀',
    'mars': '♂',
    'jupiter': '♃',
    'saturn': '♄',
  };
  static const _planetNames = {
    'sun': 'Sol',
    'moon': 'Luna',
    'mercury': 'Mercurio',
    'venus': 'Venus',
    'mars': 'Marte',
    'jupiter': 'Júpiter',
    'saturn': 'Saturno',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = onSepia ? ReaderColors.sepiaMuted : ArcanumColors.ivoryMuted;
    final gold = onSepia ? ReaderColors.sepiaGold : ArcanumColors.gold;
    final planet = chapter.rulingPlanet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (planet != null) ...[
          Text(
            '${_planetGlyphs[planet] ?? '✶'}  ${_planetNames[planet] ?? planet}',
            style: ArcanumText.body(14, color: muted),
          ),
          const SizedBox(height: 10),
        ],
        if (chapter.advisory != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: gold.withValues(alpha: 0.5), width: 2),
              ),
            ),
            child: Text(
              chapter.advisory!,
              style: ArcanumText.body(12.5, color: muted),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (chapter.materiaSlug != null) ...[
          _MateriaLink(
            slug: chapter.materiaSlug!,
            herbName: chapter.title,
            gold: gold,
            muted: muted,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// De vuelta a la ficha de la planta en Materia Arcana.
class _MateriaLink extends ConsumerStatefulWidget {
  final String slug;
  final String herbName;
  final Color gold;
  final Color muted;

  const _MateriaLink({
    required this.slug,
    required this.herbName,
    required this.gold,
    required this.muted,
  });

  @override
  ConsumerState<_MateriaLink> createState() => _MateriaLinkState();
}

class _MateriaLinkState extends ConsumerState<_MateriaLink> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final detail = await ref
          .read(arcanumApiProvider)
          .materiaDetail(widget.slug);
      if (!mounted) return;
      showMateriaLoreSheet(
        context,
        future: Future.value(detail),
        slug: widget.slug,
        name: detail['name'] as String? ?? widget.herbName,
        itemType: detail['item_type'] as String? ?? 'herb',
        planet: detail['planet'] as String?,
        element: detail['element'] as String?,
        zodiac: detail['zodiac'] as String?,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la ficha de la planta.')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ver ${widget.herbName} en Materia Arcana',
    child: InkWell(
      onTap: _opening ? null : _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text('❦', style: TextStyle(fontSize: 15, color: widget.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ver esta planta en Materia Arcana',
                style: ArcanumText.body(13.5, color: widget.gold),
              ),
            ),
            if (_opening)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  color: widget.gold,
                  strokeWidth: 1.6,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Acciones sobre un pasaje: guardarlo, copiarlo o pedir que lo expliquen.
Future<void> showPassageActionsSheet(
  BuildContext context, {
  required String text,
  required String chapterTitle,
  required String workTitle,
  required VoidCallback onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ArcanumColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _PassageActions(
      text: text,
      chapterTitle: chapterTitle,
      workTitle: workTitle,
      onSave: onSave,
    ),
  );
}

class _PassageActions extends ConsumerStatefulWidget {
  final String text;
  final String chapterTitle;
  final String workTitle;
  final VoidCallback onSave;

  const _PassageActions({
    required this.text,
    required this.chapterTitle,
    required this.workTitle,
    required this.onSave,
  });

  @override
  ConsumerState<_PassageActions> createState() => _PassageActionsState();
}

class _PassageActionsState extends ConsumerState<_PassageActions> {
  bool _asking = false;
  String? _reply;
  String? _error;
  String? _idempotencyKey;

  Future<void> _explain() async {
    final key = _idempotencyKey ??= IdempotencyKey.create();
    setState(() {
      _asking = true;
      _error = null;
      _reply = null;
    });
    try {
      final response = await ref
          .read(arcanumApiProvider)
          .oracleIa(
            question:
                'Explícame este pasaje de "${widget.workTitle}", de la entrada '
                '"${widget.chapterTitle}":\n\n"${widget.text}"\n\nDime qué '
                'significa en su contexto histórico y qué utilidad tiene hoy.',
            idempotencyKey: key,
          );
      if (!mounted) return;
      _idempotencyKey = null;
      setState(() => _reply = assistantReply(response));
    } catch (error) {
      final needsCredits = isCreditsRequired(error);
      if (!mounted) return;
      setState(
        () => _error = needsCredits
            ? 'Saldo insuficiente. Puedes comprar créditos.'
            : oracleErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESTE PASAJE', style: ArcanumText.label()),
            const SizedBox(height: 10),
            Text(
              widget.text.length > 220
                  ? '${widget.text.substring(0, 220)}…'
                  : widget.text,
              style: ArcanumText.body(
                14,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
            const SizedBox(height: 18),
            _row(Icons.bookmark_add_outlined, 'Guardar en el grimorio', () {
              Navigator.pop(context);
              widget.onSave();
            }),
            _row(Icons.copy_all_outlined, 'Copiar', () async {
              await Clipboard.setData(ClipboardData(text: widget.text));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pasaje copiado')),
                );
              }
            }),
            _row(
              Icons.auto_awesome_outlined,
              _asking ? 'Consultando…' : 'Explícame esto',
              _asking ? null : _explain,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: ArcanumText.body(
                    13,
                    color: ArcanumColors.burgundyLight,
                  ),
                ),
              ),
            if (_reply != null)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: ArcanumColors.gold, width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EL ORÁCULO', style: ArcanumText.label()),
                    const SizedBox(height: 8),
                    Text(
                      _reply!.isEmpty
                          ? 'El oráculo guardó silencio.'
                          : _reply!,
                      style: ArcanumText.body(14.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null
        ? ArcanumColors.ivoryMuted
        : ArcanumColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label, style: ArcanumText.body(15, color: color)),
          ],
        ),
      ),
    );
  }
}
