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

/// La portada de una obra: dónde se decide entrar a leerla.
///
/// No es el índice. El índice es una herramienta para buscar algo concreto y
/// vive un toque más adentro; lo primero que uno ve de un libro es su portada,
/// de dónde salió y por dónde iba.
class ObraScreen extends ConsumerStatefulWidget {
  final String workSlug;
  const ObraScreen({super.key, required this.workSlug});

  @override
  ConsumerState<ObraScreen> createState() => _ObraScreenState();
}

class _ObraScreenState extends ConsumerState<ObraScreen> {
  late Future<LibraryWork> _future = ref
      .read(libraryRepositoryProvider)
      .work(widget.workSlug);

  // ── Descarga ──────────────────────────────────────────────────────────────
  //
  // Nunca automática: hay muchas obras y Culpeper solo son 423 capítulos. Bajar
  // un libro entero es una decisión del usuario y de sus datos.
  bool _downloading = false;
  bool _cancelRequested = false;
  int _done = 0;
  int _total = 0;
  Set<String> _cached = const {};

  @override
  void initState() {
    super.initState();
    _refreshCached();
  }

  Future<void> _refreshCached() async {
    final cached = await ref
        .read(libraryCacheProvider)
        .cachedChapters(widget.workSlug);
    if (mounted) setState(() => _cached = cached);
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _cancelRequested = false;
      _done = 0;
      _total = 0;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .downloadWork(
            widget.workSlug,
            cancelled: () => _cancelRequested,
            onProgress: (done, total) {
              if (mounted) {
                setState(() {
                  _done = done;
                  _total = total;
                });
              }
            },
          );
    } finally {
      if (mounted) setState(() => _downloading = false);
      await _refreshCached();
    }
  }

  Future<void> _deleteDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArcanumColors.surface,
        title: Text(
          'Borrar la descarga',
          style: ArcanumText.heading(20, color: ArcanumColors.gold),
        ),
        content: Text(
          'La obra dejará de estar disponible sin conexión. Tu progreso, tus '
          'marcadores y tus pasajes guardados no se tocan.',
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Borrar',
              style: ArcanumText.body(14, color: ArcanumColors.burgundyLight),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryCacheProvider).clearWork(widget.workSlug);
    await _refreshCached();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(workProgressProvider(widget.workSlug));

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
            logLibraryFailure('obra', snapshot.error);
            return _Unavailable(
              onRetry: () => setState(
                () => _future = ref
                    .read(libraryRepositoryProvider)
                    .work(widget.workSlug, forceRefresh: true),
              ),
            );
          }
          return _content(snapshot.data!, progress.value);
        },
      ),
    );
  }

  Widget _content(LibraryWork work, ReadingProgress? progress) {
    final downloaded = _cached.length;
    final chapters = work.chapters.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            Center(
              child: WorkCover(
                title: work.title,
                author: work.author,
                year: work.year,
                height: 210,
                width: 150,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              work.title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(28, color: ArcanumColors.gold),
            ),
            const SizedBox(height: 6),
            Text(
              '${work.author}${work.year != null ? ' · ${work.year}' : ''}',
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 26),

            // Comenzar o Reanudar: la decisión principal, sola y sin competencia.
            _PrimaryAction(
              label: progress == null
                  ? 'Comenzar lectura'
                  : 'Reanudar lectura',
              sub: progress?.where.chapterTitle,
              onTap: () => _open(work, progress),
            ),
            const SizedBox(height: 12),
            _SecondaryAction(
              icon: Icons.list_alt_outlined,
              label: 'Índice',
              detail: '$chapters capítulos',
              onTap: () => context.push('/saber/${work.slug}/indice'),
            ),
            _DownloadAction(
              downloading: _downloading,
              done: _done,
              total: _total,
              downloaded: downloaded,
              chapters: chapters,
              onDownload: _download,
              onCancel: () => setState(() => _cancelRequested = true),
              onDelete: _deleteDownload,
            ),

            const SizedBox(height: 26),
            if (work.advisory != null) ...[
              _Note(title: 'AVISO', body: work.advisory!, warn: true),
              const SizedBox(height: 14),
            ],
            // La procedencia forma parte del contenido, no es letra pequeña: en
            // una app que cita fuentes, decir de dónde sale el texto es parte
            // de lo que se ofrece.
            _Note(title: 'PROCEDENCIA', body: work.licenseNote, warn: false),
          ],
        ),
      ),
    );
  }

  /// Abre por donde iba, o por el primer capítulo si es la primera vez.
  void _open(LibraryWork work, ReadingProgress? progress) {
    if (progress != null) {
      final p = progress.position;
      context.push(
        '/saber/${work.slug}/${p.chapterSlug}'
        '?anchor=${Uri.encodeComponent(p.paragraphAnchor)}'
        '&fragment=${p.fragmentIndex}',
      );
      return;
    }
    final ordered = [...work.chapters]
      ..sort((a, b) => a.position.compareTo(b.position));
    if (ordered.isEmpty) return;
    context.push('/saber/${work.slug}/${ordered.first.slug}');
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final String? sub;
  final VoidCallback onTap;

  const _PrimaryAction({required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: sub == null ? label : '$label. $sub',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ArcanumColors.gold.withValues(alpha: 0.12),
          border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.65)),
        ),
        child: Column(
          children: [
            Text(label, style: ArcanumText.body(16.5, color: ArcanumColors.gold)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SecondaryAction({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ArcanumColors.goldMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: ArcanumText.body(15))),
          if (detail != null)
            Text(
              detail!,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// Descargar, ver el avance, cancelar y borrar. Nunca automática.
class _DownloadAction extends StatelessWidget {
  final bool downloading;
  final int done;
  final int total;
  final int downloaded;
  final int chapters;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _DownloadAction({
    required this.downloading,
    required this.done,
    required this.total,
    required this.downloaded,
    required this.chapters,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (downloading) {
      final value = total == 0 ? null : done / total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecondaryAction(
            icon: Icons.downloading_outlined,
            label: total == 0
                ? 'Preparando la descarga…'
                : 'Descargando  ${((value ?? 0) * 100).round()}%',
            detail: total == 0 ? null : '$done de $total',
            onTap: onCancel,
            trailing: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                'Cancelar',
                style: ArcanumText.body(13, color: ArcanumColors.burgundyLight),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: ArcanumColors.goldMuted.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(ArcanumColors.gold),
            ),
          ),
        ],
      );
    }

    final complete = chapters > 0 && downloaded >= chapters;
    if (complete) {
      return _SecondaryAction(
        icon: Icons.offline_pin_outlined,
        label: 'Disponible sin conexión',
        detail: 'Borrar',
        onTap: onDelete,
      );
    }

    return _SecondaryAction(
      icon: Icons.download_outlined,
      label: downloaded == 0
          ? 'Descargar para leer sin conexión'
          : 'Completar la descarga',
      detail: downloaded == 0 ? null : '$downloaded de $chapters',
      onTap: onDownload,
    );
  }
}

class _Note extends StatelessWidget {
  final String title;
  final String body;
  final bool warn;

  const _Note({required this.title, required this.body, required this.warn});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: warn ? ArcanumColors.burgundyLight : ArcanumColors.goldMuted,
          width: 2,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ArcanumText.label()),
        const SizedBox(height: 7),
        Text(body, style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
      ],
    ),
  );
}

class _Unavailable extends StatelessWidget {
  final VoidCallback onRetry;
  const _Unavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            workUnavailableMessage,
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 16),
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
