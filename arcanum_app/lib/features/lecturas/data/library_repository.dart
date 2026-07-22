import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../domain/library_models.dart';
import 'library_cache.dart';

/// Decide entre red y caché para Lecturas.
///
/// La política es **caché primero, red después**, al revés que en el resto de
/// la app. Un libro de 1653 no cambia: pedirlo cada vez gastaría datos para
/// recibir lo mismo. Y la promesa de la sección es leer sin conexión, así que
/// lo que ya está descargado tiene que abrirse al instante y sin red.
///
/// Cuando hay red, se refresca en segundo plano: así una corrección de
/// traducción llega sola, sin que el usuario tenga que vaciar nada.
class LibraryRepository {
  LibraryRepository(this._api, this._cache);

  final ArcanumApi _api;
  final LibraryCache _cache;

  /// Índice de obras. Devuelve la caché de inmediato si la hay.
  Future<List<LibraryWorkSummary>> works({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.readIndex();
      if (cached != null && cached.isNotEmpty) {
        unawaited(_refreshIndex());
        return cached;
      }
    }
    final fresh = (await _api.libraryWorks())
        .map(LibraryWorkSummary.fromJson)
        .toList();
    await _cache.writeIndex(fresh);
    return fresh;
  }

  Future<LibraryWork> work(String slug, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.readWork(slug);
      if (cached != null) {
        unawaited(_refreshWork(slug));
        return cached;
      }
    }
    final fresh = LibraryWork.fromJson(await _api.libraryWork(slug));
    await _cache.writeWork(fresh);
    return fresh;
  }

  /// Un capítulo con su texto.
  ///
  /// Si no hay caché y tampoco red, el error se propaga: es mejor decir que no
  /// se pudo abrir que mostrar una pantalla vacía sin explicación.
  Future<LibraryChapter> chapter(
    String workSlug,
    String chapterSlug, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _cache.readChapter(workSlug, chapterSlug);
      if (cached != null) {
        unawaited(_refreshChapter(workSlug, chapterSlug));
        return cached;
      }
    }
    final fresh = LibraryChapter.fromJson(
      await _api.libraryChapter(workSlug, chapterSlug),
    );
    await _cache.writeChapter(fresh);
    return fresh;
  }

  /// Descarga una obra entera para leerla sin conexión.
  ///
  /// Va de uno en uno y no en paralelo a propósito: 423 peticiones simultáneas
  /// contra el backend serían un ataque a tu propio servidor.
  /// [onProgress] recibe (hechos, total) para poder cancelar o mostrar avance.
  Future<int> downloadWork(
    String slug, {
    ChapterKind? only,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final work = await this.work(slug);
    final chapters = only == null
        ? work.chapters
        : work.byKind(only).toList(growable: false);

    var done = 0;
    for (final summary in chapters) {
      if (cancelled?.call() ?? false) break;
      try {
        await chapter(slug, summary.slug);
      } catch (error) {
        // Un capítulo que falla no aborta la descarga entera: se reintenta la
        // próxima vez que se abra.
        debugPrint('ARCANUM lecturas: falló "${summary.slug}" ($error).');
      }
      onProgress?.call(++done, chapters.length);
    }
    return done;
  }

  // ── Refresco en segundo plano ───────────────────────────────────────────
  //
  // No molestan al usuario: la caché ya sirvió y sin red no hay nada que
  // hacer. Pero dejan rastro — si el refresco fallara SIEMPRE, la biblioteca
  // se congelaría en una versión vieja sin que nadie se enterase.

  Future<void> _refreshIndex() async {
    try {
      await _cache.writeIndex(
        (await _api.libraryWorks()).map(LibraryWorkSummary.fromJson).toList(),
      );
    } catch (error) {
      debugPrint('ARCANUM lecturas: refresco en segundo plano falló ($error).');
    }
  }

  Future<void> _refreshWork(String slug) async {
    try {
      await _cache.writeWork(
        LibraryWork.fromJson(await _api.libraryWork(slug)),
      );
    } catch (error) {
      debugPrint('ARCANUM lecturas: refresco en segundo plano falló ($error).');
    }
  }

  Future<void> _refreshChapter(String workSlug, String chapterSlug) async {
    try {
      await _cache.writeChapter(
        LibraryChapter.fromJson(
          await _api.libraryChapter(workSlug, chapterSlug),
        ),
      );
    } catch (error) {
      debugPrint('ARCANUM lecturas: refresco en segundo plano falló ($error).');
    }
  }
}

final libraryCacheProvider = Provider((ref) => LibraryCache());

final libraryRepositoryProvider = Provider(
  (ref) => LibraryRepository(
    ref.read(arcanumApiProvider),
    ref.read(libraryCacheProvider),
  ),
);
