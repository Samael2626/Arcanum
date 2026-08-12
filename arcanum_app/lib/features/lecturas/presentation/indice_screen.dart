import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';
import '../library_messages.dart';

/// El índice de una obra: herramienta secundaria para buscar algo concreto.
///
/// Vive un toque más adentro que la portada porque leer un libro no empieza por
/// su índice. Culpeper mezcla 317 entradas de planta con epístolas, catálogos y
/// un tratado de recetas: sin agrupar serían 423 líneas indistinguibles, así
/// que se separa por tipo y se puede buscar dentro.
class IndiceScreen extends ConsumerStatefulWidget {
  final String workSlug;
  const IndiceScreen({super.key, required this.workSlug});

  @override
  ConsumerState<IndiceScreen> createState() => _IndiceScreenState();
}

class _IndiceScreenState extends ConsumerState<IndiceScreen> {
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
        title: Text('Índice', style: ArcanumText.body(16)),
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
            logLibraryFailure('obra', snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  workUnavailableMessage,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: ArcanumText.body(15),
                decoration: InputDecoration(
                  hintText: 'Buscar en ${work.title}…',
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
            ),
            if (kinds.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final kind in kinds)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _KindChip(
                          label: kind.label,
                          count: work.byKind(kind).length,
                          selected: kind == _kind,
                          onTap: () => setState(() => _kind = kind),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: chapters.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          query.isEmpty
                              ? 'Esta sección está vacía.'
                              : 'Nada coincide con «${_search.text.trim()}».',
                          textAlign: TextAlign.center,
                          style: ArcanumText.body(
                            15,
                            color: ArcanumColors.ivoryMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
                      itemCount: chapters.length,
                      itemBuilder: (context, i) => _ChapterRow(
                        chapter: chapters[i],
                        // pushReplacement: llegar al lector desde el índice y
                        // luego volver debe devolver a la portada, no apilar
                        // índice sobre índice cada vez que se cambia de
                        // capítulo.
                        onTap: () => context.pushReplacement(
                          '/saber/${work.slug}/${chapters[i].slug}',
                        ),
                      ),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
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
