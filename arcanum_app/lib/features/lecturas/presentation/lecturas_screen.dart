import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';

/// Lecturas: la biblioteca de obras en dominio público.
///
/// Es la sección que da fuente a lo que el resto de la app afirma. Cuando una
/// materia dice que la artemisa es de Marte, aquí está el párrafo de Culpeper
/// donde lo dice.
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async => setState(() => _future = _load(refresh: true)),
          child: FutureBuilder<List<LibraryWorkSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }
              final works = snapshot.data ?? const <LibraryWorkSummary>[];
              if (snapshot.hasError && works.isEmpty) {
                return _Message(
                  glyph: '✶',
                  title: 'La biblioteca no responde',
                  body:
                      'Desliza hacia abajo para reintentar. Lo que ya hayas '
                      'leído sigue disponible sin conexión.',
                  detail: '${snapshot.error}',
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
              return _list(works);
            },
          ),
        ),
      ),
    );
  }

  Widget _list(List<LibraryWorkSummary> works) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
    children: [
      const ArcanumHeader(subtitle: 'Lecturas'),
      const SizedBox(height: 8),
      Text(
        'Las fuentes de las que sale todo lo demás.',
        textAlign: TextAlign.center,
        style: ArcanumText.body(
          14,
          color: ArcanumColors.ivoryMuted,
          italic: true,
        ),
      ),
      const SizedBox(height: 24),
      ...works.map(
        (work) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _WorkCard(
            work: work,
            onTap: () => context.push('/lecturas/${work.slug}'),
          ),
        ),
      ),
    ],
  );
}

class _WorkCard extends StatelessWidget {
  final LibraryWorkSummary work;
  final VoidCallback onTap;
  const _WorkCard({required this.work, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ArcanumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              work.title,
              style: ArcanumText.heading(22, color: ArcanumColors.gold),
            ),
            const SizedBox(height: 4),
            Text(
              '${work.author}${work.year != null ? ' · ${work.year}' : ''}',
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${work.chapterCount} capítulos',
                  style: ArcanumText.body(13, color: ArcanumColors.goldMuted),
                ),
                const Spacer(),
                // Se avisa del avance en vez de dejar que el usuario descubra
                // por su cuenta que hay capítulos sin traducir.
                if (!work.fullyTranslated)
                  Text(
                    'Traducción al '
                    '${(work.translationProgress * 100).round()}%',
                    style: ArcanumText.body(
                      12,
                      color: ArcanumColors.ivoryMuted,
                      italic: true,
                    ),
                  ),
              ],
            ),
          ],
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
  final String? detail;

  const _Message({
    required this.glyph,
    required this.title,
    required this.body,
    this.detail,
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
      if (detail != null) ...[
        const SizedBox(height: 10),
        // El error crudo se muestra: un fallo desconocido debe verse.
        Text(
          detail!,
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            11,
            color: ArcanumColors.ivoryMuted.withValues(alpha: 0.6),
          ),
        ),
      ],
    ],
  );
}
