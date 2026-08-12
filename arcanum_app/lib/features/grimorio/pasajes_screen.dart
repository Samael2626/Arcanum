import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../lecturas/data/reading_repository.dart';
import '../lecturas/domain/reading_models.dart';
import '../lecturas/presentation/reader_widgets.dart';

/// Grimorio → Pasajes guardados.
///
/// Lo que el usuario subrayó mientras leía, en orden cronológico. La nota llega
/// cifrada del servidor y se descifra aquí con la clave del dispositivo: es una
/// entrada privada como cualquier otra del grimorio.
///
/// Tocar un pasaje abre el lector exactamente donde estaba — para eso se guardó
/// la posición estable y no un número de página.
class PasajesScreen extends ConsumerWidget {
  const PasajesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passages = ref.watch(savedPassagesProvider);

    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ArcanumColors.ivoryMuted),
        title: Text('Pasajes guardados', style: ArcanumText.body(16)),
      ),
      body: passages.when(
        loading: () => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: ArcanumColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, _) => _Empty(
          glyph: '✶',
          title: 'No se pudieron cargar tus pasajes',
          body:
              'Necesitas conexión para verlos. Los que guardaste siguen a '
              'salvo en tu cuenta.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _Empty(
              glyph: '❦',
              title: 'Aún no has guardado ningún pasaje',
              body:
                  'Mientras lees, mantén pulsado un párrafo para guardarlo '
                  'aquí con tu propia nota.',
            );
          }
          return RefreshIndicator(
            color: ArcanumColors.gold,
            backgroundColor: ArcanumColors.surface,
            onRefresh: () async => ref.invalidate(savedPassagesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: items.length,
              itemBuilder: (context, i) => _PassageCard(passage: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PassageCard extends ConsumerWidget {
  final SavedPassage passage;
  const _PassageCard({required this.passage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final where = passage.where;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        button: true,
        label:
            'Pasaje de ${where.workTitle}, ${where.chapterTitle}. '
            'Abrir en el lector.',
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: ArcanumColors.goldMuted, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${where.workTitle} · ${where.chapterTitle}'
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArcanumText.label(),
                      ),
                    ),
                    _Menu(passage: passage),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  passage.quote,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(15).copyWith(height: 1.5),
                ),
                if (passage.hasNote) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.edit_note,
                        size: 15,
                        color: ArcanumColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passage.note!,
                          style: ArcanumText.body(
                            14,
                            color: ArcanumColors.ivory,
                            italic: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (passage.noteUnreadable) ...[
                  const SizedBox(height: 12),
                  // Se dice en vez de fingir que no hay nota: la nota existe,
                  // pero fue escrita con la clave de otro dispositivo.
                  Text(
                    'Tu nota se escribió en otro dispositivo y no puede '
                    'descifrarse aquí.',
                    style: ArcanumText.body(
                      12.5,
                      color: ArcanumColors.burgundyLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Abre el lector en la posición exacta del pasaje.
  void _open(BuildContext context) {
    final p = passage.position;
    context.push(
      '/saber/${p.workSlug}/${p.chapterSlug}'
      '?anchor=${Uri.encodeComponent(p.paragraphAnchor)}'
      '&fragment=${p.fragmentIndex}',
    );
  }
}

class _Menu extends ConsumerWidget {
  final SavedPassage passage;
  const _Menu({required this.passage});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    icon: const Icon(
      Icons.more_horiz,
      size: 18,
      color: ArcanumColors.ivoryMuted,
    ),
    color: ArcanumColors.surface,
    onSelected: (value) async {
      final repo = ref.read(readingRepositoryProvider);
      if (value == 'note') {
        final note = await showPassageNoteDialog(
          context,
          quote: passage.quote,
          initial: passage.note ?? '',
        );
        if (note == null) return;
        // Una nota vacía borra la nota, no guarda una cadena en blanco.
        await repo.updateNote(passage.id, note.isEmpty ? null : note);
      } else if (value == 'delete') {
        await repo.removePassage(passage.id);
      }
      ref.invalidate(savedPassagesProvider);
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'note',
        child: Text(
          passage.hasNote ? 'Editar nota' : 'Añadir nota',
          style: ArcanumText.body(14),
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          'Eliminar pasaje',
          style: ArcanumText.body(14, color: ArcanumColors.burgundyLight),
        ),
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  final String glyph;
  final String title;
  final String body;

  const _Empty({
    required this.glyph,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            glyph,
            style: const TextStyle(fontSize: 44, color: ArcanumColors.goldMuted),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: ArcanumText.heading(22)),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: ArcanumText.body(14.5, color: ArcanumColors.ivoryMuted),
          ),
        ],
      ),
    ),
  );
}
