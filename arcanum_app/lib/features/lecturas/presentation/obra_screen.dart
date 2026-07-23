import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';

/// Índice de una obra: sus capítulos, agrupados por tipo.
///
/// Culpeper mezcla 317 entradas de planta con epístolas, catálogos y un
/// tratado de recetas. Sin agrupar serían 423 líneas indistinguibles.
class ObraScreen extends ConsumerStatefulWidget {
  final String workSlug;
  const ObraScreen({super.key, required this.workSlug});

  @override
  ConsumerState<ObraScreen> createState() => _ObraScreenState();
}

class _ObraScreenState extends ConsumerState<ObraScreen> {
  late final Future<LibraryWork> _future = ref
      .read(libraryRepositoryProvider)
      .work(widget.workSlug);

  final _search = TextEditingController();
  ChapterKind _kind = ChapterKind.herb;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ArcanumColors.ivoryMuted),
      ),
      body: FutureBuilder<LibraryWork>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
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
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  'No se pudo abrir la obra.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
                ),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(LibraryWork work) {
    // Solo se ofrecen las secciones que la obra realmente tiene.
    final kinds = [
      for (final kind in ChapterKind.values)
        if (work.byKind(kind).isNotEmpty) kind,
    ];
    if (!kinds.contains(_kind) && kinds.isNotEmpty) _kind = kinds.first;

    final query = _search.text.trim().toLowerCase();
    final chapters = work
        .byKind(_kind)
        .where((c) => query.isEmpty || c.title.toLowerCase().contains(query))
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Text(
              work.title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(30, color: ArcanumColors.gold),
            ),
            const SizedBox(height: 6),
            Text(
              '${work.author}${work.year != null ? ' · ${work.year}' : ''}',
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 18),

            // La procedencia forma parte del contenido, no es letra pequeña:
            // en una app que cita fuentes, decir de dónde sale el texto es
            // parte de lo que se ofrece.
            ArcanumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROCEDENCIA', style: ArcanumText.label()),
                  const SizedBox(height: 8),
                  Text(
                    work.licenseNote,
                    style: ArcanumText.body(
                      13,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: ArcanumText.body(15),
              decoration: InputDecoration(
                hintText: 'Buscar en la obra…',
                hintStyle: ArcanumText.body(
                  15,
                  color: ArcanumColors.ivoryMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: ArcanumColors.goldMuted,
                ),
                filled: true,
                fillColor: ArcanumColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
            const SizedBox(height: 14),

            if (kinds.length > 1)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final kind in kinds)
                    _KindChip(
                      label: kind.label,
                      count: work.byKind(kind).length,
                      selected: kind == _kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                ],
              ),
            const SizedBox(height: 14),

            if (chapters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  query.isEmpty
                      ? 'Esta sección está vacía.'
                      : 'Nada coincide con «${_search.text.trim()}».',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                ),
              )
            else
              ...chapters.map(
                (chapter) => _ChapterRow(
                  chapter: chapter,
                  onTap: () =>
                      context.push('/saber/${work.slug}/${chapter.slug}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _KindChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: selected
            ? ArcanumColors.gold.withValues(alpha: 0.16)
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? ArcanumColors.gold
              : ArcanumColors.goldMuted.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '$label · $count',
        style: ArcanumText.body(
          13,
          color: selected ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
        ),
      ),
    ),
  );
}

class _ChapterRow extends StatelessWidget {
  final LibraryChapterSummary chapter;
  final VoidCallback onTap;
  const _ChapterRow({required this.chapter, required this.onTap});

  static const _glyphs = {
    'sun': '☉',
    'moon': '☽',
    'mercury': '☿',
    'venus': '♀',
    'mars': '♂',
    'jupiter': '♃',
    'saturn': '♄',
  };

  @override
  Widget build(BuildContext context) {
    final planet = chapter.rulingPlanet;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                planet == null ? '' : (_glyphs[planet] ?? '✶'),
                style: const TextStyle(
                  fontSize: 16,
                  color: ArcanumColors.goldMuted,
                ),
              ),
            ),
            Expanded(child: Text(chapter.title, style: ArcanumText.body(16))),
            Text(
              '${chapter.paragraphCount}',
              style: ArcanumText.body(12, color: ArcanumColors.goldMuted),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: ArcanumColors.goldMuted,
            ),
          ],
        ),
      ),
    );
  }
}
