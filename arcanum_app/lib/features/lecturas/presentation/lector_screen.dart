import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/oracle_error.dart';
import '../../../core/api/arcanum_api.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../arte/materia_lore.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';

/// El lector: un capítulo de una obra, en español o en su original.
///
/// Tres capas de profundidad sobre el mismo texto, igual que en la carta natal:
/// se lee traducido, se puede ver el original a un toque, y se le puede pedir
/// al oráculo que explique un pasaje concreto.
class LectorScreen extends ConsumerStatefulWidget {
  final String workSlug;
  final String chapterSlug;

  const LectorScreen({
    super.key,
    required this.workSlug,
    required this.chapterSlug,
  });

  @override
  ConsumerState<LectorScreen> createState() => _LectorScreenState();
}

class _LectorScreenState extends ConsumerState<LectorScreen> {
  late Future<LibraryChapter> _future = _load();

  /// Idioma de lectura. Se mantiene mientras dure la sesión de lectura: quien
  /// lee en el original no quiere reactivarlo capítulo a capítulo.
  bool _spanish = true;

  /// Ancla del párrafo seleccionado. Solo uno a la vez: dos pasajes abiertos
  /// convertirían la lectura en un tablero.
  String? _selected;

  Future<LibraryChapter> _load() => ref
      .read(libraryRepositoryProvider)
      .chapter(widget.workSlug, widget.chapterSlug);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ArcanumColors.ivoryMuted),
        actions: [
          _LanguageToggle(
            spanish: _spanish,
            onChanged: (value) => setState(() => _spanish = value),
          ),
        ],
      ),
      body: FutureBuilder<LibraryChapter>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _Loading();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              error: '${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(LibraryChapter chapter) {
    // Si la obra aún no está traducida, se lee el original en vez de mostrar
    // un hueco: por eso se puede publicar con la traducción a medias.
    final untranslated = _spanish && !chapter.hasTranslation;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
          children: [
            Text(
              chapter.workTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: ArcanumText.label(),
            ),
            const SizedBox(height: 10),
            Text(
              chapter.title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(30, color: ArcanumColors.gold),
            ),
            if (chapter.rulingPlanet != null) ...[
              const SizedBox(height: 10),
              _RulingPlanet(planet: chapter.rulingPlanet!),
            ],
            const SizedBox(height: 22),

            // Puente inverso: si esta entrada es una hierba mapeada, se ofrece
            // volver a su ficha de Materia Arcana antes de leer el texto.
            if (chapter.materiaSlug != null) ...[
              _MateriaLink(slug: chapter.materiaSlug!, herbName: chapter.title),
              const SizedBox(height: 18),
            ],

            if (chapter.advisory != null) ...[
              _Advisory(text: chapter.advisory!),
              const SizedBox(height: 18),
            ],
            if (untranslated) ...[
              const _UntranslatedNotice(),
              const SizedBox(height: 18),
            ],

            ...chapter.paragraphs.map(
              (paragraph) => _Passage(
                paragraph: paragraph,
                spanish: _spanish,
                selected: _selected == paragraph.anchor,
                onTap: () => setState(
                  () => _selected = _selected == paragraph.anchor
                      ? null
                      : paragraph.anchor,
                ),
                chapterTitle: chapter.title,
                workTitle: chapter.workTitle,
              ),
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                '${chapter.workTitle} · dominio público',
                style: ArcanumText.body(
                  12,
                  color: ArcanumColors.ivoryMuted,
                  italic: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alterna español y original. El original nunca desaparece: es lo que permite
/// verificar una traducción automática y citar el pasaje tal cual se escribió.
class _LanguageToggle extends StatelessWidget {
  final bool spanish;
  final ValueChanged<bool> onChanged;
  const _LanguageToggle({required this.spanish, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option('ES', spanish),
          Text(
            ' · ',
            style: ArcanumText.body(13, color: ArcanumColors.goldMuted),
          ),
          _option('EN', !spanish),
        ],
      ),
    );
  }

  Widget _option(String label, bool active) => InkWell(
    onTap: () => onChanged(label == 'ES'),
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        label,
        style: ArcanumText.body(
          13,
          color: active ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
        ),
      ),
    ),
  );
}

/// Aviso histórico. Va con el capítulo, no solo en la portada: si se entra
/// directo a una entrada que afirma curar la peste, el encuadre debe estar.
class _Advisory extends StatelessWidget {
  final String text;
  const _Advisory({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: ArcanumColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border(
        left: BorderSide(color: ArcanumColors.burgundyLight, width: 2),
      ),
    ),
    child: Text(
      text,
      style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
    ),
  );
}

class _UntranslatedNotice extends StatelessWidget {
  const _UntranslatedNotice();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.translate, size: 15, color: ArcanumColors.goldMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Este pasaje aún no está traducido. Se muestra en su idioma original.',
          style: ArcanumText.body(
            13,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
      ),
    ],
  );
}

/// El planeta regente que la obra declara. Sale del texto ORIGINAL, extraído
/// en la ingesta: la correspondencia con Materia Arcana no depende de la
/// calidad de la traducción.
class _RulingPlanet extends StatelessWidget {
  final String planet;
  const _RulingPlanet({required this.planet});

  static const _glyphs = {
    'sun': '☉',
    'moon': '☽',
    'mercury': '☿',
    'venus': '♀',
    'mars': '♂',
    'jupiter': '♃',
    'saturn': '♄',
  };
  static const _names = {
    'sun': 'Sol',
    'moon': 'Luna',
    'mercury': 'Mercurio',
    'venus': 'Venus',
    'mars': 'Marte',
    'jupiter': 'Júpiter',
    'saturn': 'Saturno',
  };

  @override
  Widget build(BuildContext context) => Text(
    '${_glyphs[planet] ?? '✶'}  ${_names[planet] ?? planet}',
    textAlign: TextAlign.center,
    style: ArcanumText.body(15, color: ArcanumColors.goldMuted),
  );
}

/// El puente inverso: de vuelta a la ficha de la planta en Materia Arcana.
///
/// Aparece arriba del capítulo, antes del texto: quien llega a "Rosemary" en
/// Culpeper puede saltar a la correspondencia de la planta sin buscarla. Al
/// tocar, pide el detalle y abre la MISMA hoja que en Saber, sin puente de
/// vuelta (sería circular): ya se está en el capítulo que enlazaría.
class _MateriaLink extends ConsumerStatefulWidget {
  final String slug;
  final String herbName;
  const _MateriaLink({required this.slug, required this.herbName});

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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver ${widget.herbName} en Materia Arcana',
      child: InkWell(
        onTap: _opening ? null : _open,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ArcanumColors.gold.withValues(alpha: 0.06),
            border: Border.all(
              color: ArcanumColors.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Text(
                '❦',
                style: TextStyle(
                  color: ArcanumColors.gold.withValues(alpha: 0.85),
                  fontSize: 18,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EN MATERIA ARCANA', style: ArcanumText.label()),
                    const SizedBox(height: 2),
                    Text(
                      'Ver la correspondencia de esta planta',
                      style: ArcanumText.body(14.5, color: ArcanumColors.ivory),
                    ),
                  ],
                ),
              ),
              if (_opening)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: ArcanumColors.gold,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: ArcanumColors.gold,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un párrafo. Al tocarlo se abren sus acciones: copiar, y pedir al oráculo
/// que lo explique.
class _Passage extends ConsumerStatefulWidget {
  final LibraryParagraph paragraph;
  final bool spanish;
  final bool selected;
  final VoidCallback onTap;
  final String chapterTitle;
  final String workTitle;

  const _Passage({
    required this.paragraph,
    required this.spanish,
    required this.selected,
    required this.onTap,
    required this.chapterTitle,
    required this.workTitle,
  });

  @override
  ConsumerState<_Passage> createState() => _PassageState();
}

class _PassageState extends ConsumerState<_Passage> {
  bool _asking = false;
  String? _reply;
  String? _error;

  Future<void> _explain() async {
    setState(() {
      _asking = true;
      _error = null;
      _reply = null;
    });
    try {
      // Se manda SIEMPRE el original, no la traducción: es el texto que el
      // autor escribió, y pedir sobre una traducción automática sería explicar
      // el eco en vez de la voz.
      final response = await ref
          .read(arcanumApiProvider)
          .oracleIa(
            question:
                'Explícame este pasaje de "${widget.workTitle}", de la entrada '
                '"${widget.chapterTitle}":\n\n'
                '"${widget.paragraph.textOriginal}"\n\n'
                'Dime qué significa en su contexto histórico y qué utilidad '
                'tiene hoy en la práctica.',
          );
      if (!mounted) return;
      setState(() => _reply = assistantReply(response));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = oracleErrorMessage(error));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paragraph = widget.paragraph;
    final text = paragraph.textFor(spanish: widget.spanish);
    final showingTranslation = widget.spanish && paragraph.hasTranslation;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.selected
                    ? ArcanumColors.gold.withValues(alpha: 0.07)
                    : Colors.transparent,
              ),
              child: Text(
                text,
                textAlign: TextAlign.justify,
                // Cormorant Garamond a 17: es un libro, no una ficha.
                style: ArcanumText.body(17).copyWith(height: 1.62),
              ),
            ),
          ),

          if (widget.selected) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                if (showingTranslation)
                  _Action(
                    label: paragraph.translationStatus?.label ?? 'Traducción',
                    icon: Icons.translate,
                    // Informativo: declara que la tradujo una máquina.
                    onTap: null,
                  ),
                _Action(
                  label: 'Copiar',
                  icon: Icons.copy_all_outlined,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pasaje copiado')),
                      );
                    }
                  },
                ),
                _Action(
                  label: _asking ? 'Consultando…' : 'Explícame esto',
                  icon: null,
                  glyph: '✦',
                  onTap: _asking ? null : _explain,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Text(
                  _error!,
                  style: ArcanumText.body(
                    13,
                    color: ArcanumColors.burgundyLight,
                  ),
                ),
              ),
            if (_reply != null) _OracleReply(text: _reply!),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? glyph;
  final VoidCallback? onTap;

  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? ArcanumColors.ivoryMuted : ArcanumColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null)
              Text(glyph!, style: TextStyle(fontSize: 12, color: color))
            else if (icon != null)
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: ArcanumText.body(13, color: color)),
          ],
        ),
      ),
    );
  }
}

class _OracleReply extends StatelessWidget {
  final String text;
  const _OracleReply({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: ArcanumColors.surfaceHigh.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      border: const Border(
        left: BorderSide(color: ArcanumColors.gold, width: 2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EL ORÁCULO', style: ArcanumText.label()),
        const SizedBox(height: 8),
        Text(
          text.isEmpty ? 'El oráculo guardó silencio.' : text,
          style: ArcanumText.body(15),
        ),
      ],
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        color: ArcanumColors.gold,
        strokeWidth: 2,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '✶',
            style: TextStyle(fontSize: 48, color: ArcanumColors.goldMuted),
          ),
          const SizedBox(height: 18),
          Text(
            'No se pudo abrir este pasaje',
            textAlign: TextAlign.center,
            style: ArcanumText.heading(22),
          ),
          const SizedBox(height: 10),
          Text(
            'Si ya lo habías leído antes, estaría disponible sin conexión. '
            'Este todavía no se ha descargado.',
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 8),
          // El error crudo se muestra: un fallo desconocido debe verse.
          Text(
            error,
            textAlign: TextAlign.center,
            style: ArcanumText.body(
              11,
              color: ArcanumColors.ivoryMuted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Reintentar',
              style: ArcanumText.body(15, color: ArcanumColors.gold),
            ),
          ),
        ],
      ),
    ),
  );
}
