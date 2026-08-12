import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../data/library_repository.dart';
import '../data/reading_repository.dart';
import '../domain/library_models.dart';
import '../domain/reading_models.dart';
import '../library_messages.dart';
import 'work_cover.dart';

/// La Biblioteca: una estantería, no una lista técnica.
///
/// Es la sección que da fuente a lo que el resto de la app afirma. Cuando una
/// materia dice que la artemisa es de Marte, aquí está el párrafo de Culpeper
/// donde lo dice — pero eso no se ofrece como una tabla de datos: se ofrece
/// como libros que se pueden abrir.
class LecturasScreen extends ConsumerStatefulWidget {
  const LecturasScreen({super.key});

  @override
  ConsumerState<LecturasScreen> createState() => _LecturasScreenState();
}

class _LecturasScreenState extends ConsumerState<LecturasScreen> {
  late Future<List<LibraryWorkSummary>> _future = _load();

  Future<List<LibraryWorkSummary>> _load({bool refresh = false}) =>
      ref.read(libraryRepositoryProvider).works(forceRefresh: refresh);

  @override
  Widget build(BuildContext context) {
    // El progreso puede no estar (sin sesión, sin red): la estantería se pinta
    // igual, simplemente sin avance. Leer no exige haber iniciado sesión.
    final progress = ref.watch(allProgressProvider);
    final byWork = <String, ReadingProgress>{
      for (final p in progress.value ?? const <ReadingProgress>[])
        p.position.workSlug: p,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async {
            ref.invalidate(allProgressProvider);
            setState(() => _future = _load(refresh: true));
          },
          child: FutureBuilder<List<LibraryWorkSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }
              final works = snapshot.data ?? const <LibraryWorkSummary>[];
              if (snapshot.hasError && works.isEmpty) {
                logLibraryFailure('indice', snapshot.error);
                return const _Message(
                  glyph: '✶',
                  title: 'La biblioteca no responde',
                  body: libraryUnavailableMessage,
                );
              }
              if (works.isEmpty) {
                return const _Message(
                  glyph: '☰',
                  title: 'Todavía no hay obras',
                  body:
                      'Pronto encontrarás aquí los grimorios y herbarios que '
                      'sostienen lo que ARCANUM te cuenta.',
                );
              }
              return _shelf(works, byWork);
            },
          ),
        ),
      ),
    );
  }

  Widget _shelf(
    List<LibraryWorkSummary> works,
    Map<String, ReadingProgress> progress,
  ) {
    // Lo empezado primero: quien está leyendo algo quiere volver a ello, no
    // ojear el catálogo otra vez.
    final ordered = [...works]
      ..sort((a, b) {
        final pa = progress[a.slug];
        final pb = progress[b.slug];
        if ((pa != null) != (pb != null)) return pa != null ? -1 : 1;
        if (pa != null && pb != null) {
          return pb.updatedAt.compareTo(pa.updatedAt);
        }
        return a.title.compareTo(b.title);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
      children: [
        for (final work in ordered)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _ShelfEntry(
              work: work,
              progress: progress[work.slug],
              onTap: () => context.push('/saber/${work.slug}'),
            ),
          ),
      ],
    );
  }
}

/// Un libro en la estantería: portada, datos y por dónde ibas.
class _ShelfEntry extends StatelessWidget {
  final LibraryWorkSummary work;
  final ReadingProgress? progress;
  final VoidCallback onTap;

  const _ShelfEntry({
    required this.work,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final started = progress != null;

    return Semantics(
      button: true,
      label: started
          ? 'Reanudar ${work.title} en ${progress!.where.chapterTitle}'
          : 'Comenzar ${work.title}, de ${work.author}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkCover(
                title: work.title,
                author: work.author,
                year: work.year,
                height: 136,
                width: 96,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      work.title,
                      style: ArcanumText.heading(
                        20,
                        color: ArcanumColors.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${work.author}${work.year != null ? ' · ${work.year}' : ''}',
                      style: ArcanumText.body(
                        13.5,
                        color: ArcanumColors.ivoryMuted,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (started) ...[
                      Text(
                        'REANUDAR LECTURA',
                        style: ArcanumText.label(),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        progress!.where.chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArcanumText.body(
                          14,
                          color: ArcanumColors.ivory,
                        ),
                      ),
                    ] else
                      Text(
                        'Comenzar lectura',
                        style: ArcanumText.body(14, color: ArcanumColors.gold),
                      ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${work.chapterCount} capítulos',
                          style: ArcanumText.body(
                            12,
                            color: ArcanumColors.goldMuted,
                          ),
                        ),
                        // Se avisa del avance de traducción en vez de dejar que
                        // el usuario descubra por su cuenta que hay capítulos
                        // sin traducir.
                        if (!work.fullyTranslated) ...[
                          Text(
                            '  ·  ',
                            style: ArcanumText.body(
                              12,
                              color: ArcanumColors.goldMuted,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'traducida al '
                              '${(work.translationProgress * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ArcanumText.body(
                                12,
                                color: ArcanumColors.ivoryMuted,
                                italic: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      SizedBox(height: 200),
      Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: ArcanumColors.gold,
            strokeWidth: 2,
          ),
        ),
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  final String glyph;
  final String title;
  final String body;

  const _Message({
    required this.glyph,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    children: [
      const SizedBox(height: 150),
      Center(
        child: Text(
          glyph,
          style: const TextStyle(fontSize: 52, color: ArcanumColors.goldMuted),
        ),
      ),
      const SizedBox(height: 20),
      Text(title, textAlign: TextAlign.center, style: ArcanumText.heading(26)),
      const SizedBox(height: 12),
      Text(
        body,
        textAlign: TextAlign.center,
        style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
      ),
    ],
  );
}
