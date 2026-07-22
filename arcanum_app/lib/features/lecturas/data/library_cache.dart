import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/library_models.dart';

/// Caché en disco de Lecturas: lo que hace posible leer sin conexión.
///
/// Se guardan ficheros y no `SharedPreferences` porque un capítulo puede pesar
/// decenas de KB y una obra entera más de un mega: `SharedPreferences` carga
/// todo su contenido en memoria al arrancar, así que meter el libro ahí
/// penalizaría el arranque de la app entera.
///
/// En web no hay sistema de ficheros: allí la caché se desactiva y todo se
/// sirve de red. La PWA es el campo de pruebas, no el destino final.
class LibraryCache {
  static const _folder = 'lecturas';

  Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> _file(String name) async {
    final dir = await _dir();
    return dir == null ? null : File('${dir.path}/$name.json');
  }

  /// Nombre de fichero seguro: los slugs vienen del backend y no deben poder
  /// escapar del directorio de caché.
  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  // ── Lectura ─────────────────────────────────────────────────────────────

  Future<List<LibraryWorkSummary>?> readIndex() async => _read('index', (json) {
    final list = json['works'] as List;
    return list
        .map((w) => LibraryWorkSummary.fromJson(w as Map<String, dynamic>))
        .toList();
  });

  Future<LibraryWork?> readWork(String slug) async =>
      _read('work_${_safe(slug)}', LibraryWork.fromJson);

  Future<LibraryChapter?> readChapter(
    String workSlug,
    String chapterSlug,
  ) async => _read(
    'chapter_${_safe(workSlug)}_${_safe(chapterSlug)}',
    LibraryChapter.fromJson,
  );

  Future<T?> _read<T>(
    String name,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final file = await _file(name);
      if (file == null || !await file.exists()) return null;
      return parse(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (error) {
      // Una caché corrupta no puede tumbar la pantalla: se descarta y se
      // vuelve a red. Se deja rastro para no perder el aviso.
      debugPrint(
        'ARCANUM lecturas: caché ilegible "$name" ($error). Se descarta.',
      );
      unawaited(_delete(name));
      return null;
    }
  }

  // ── Escritura ───────────────────────────────────────────────────────────

  Future<void> writeIndex(List<LibraryWorkSummary> works) =>
      _write('index', {'works': works.map((w) => w.toJson()).toList()});

  Future<void> writeWork(LibraryWork work) =>
      _write('work_${_safe(work.slug)}', work.toJson());

  Future<void> writeChapter(LibraryChapter chapter) => _write(
    'chapter_${_safe(chapter.workSlug)}_${_safe(chapter.slug)}',
    chapter.toJson(),
  );

  Future<void> _write(String name, Map<String, dynamic> data) async {
    try {
      final file = await _file(name);
      if (file == null) return; // web: sin caché
      await file.writeAsString(jsonEncode(data));
    } catch (error) {
      // Quedarse sin espacio no debe impedir leer: se pierde el offline, no
      // la lectura en curso.
      debugPrint('ARCANUM lecturas: no se pudo cachear "$name" ($error).');
    }
  }

  Future<void> _delete(String name) async {
    final file = await _file(name);
    if (file != null && await file.exists()) await file.delete();
  }

  // ── Gestión ─────────────────────────────────────────────────────────────

  /// Capítulos cacheados de una obra: permite mostrar qué está disponible sin
  /// conexión en vez de dejar que el usuario lo descubra al quedarse sin red.
  Future<Set<String>> cachedChapters(String workSlug) async {
    final dir = await _dir();
    if (dir == null) return {};
    final prefix = 'chapter_${_safe(workSlug)}_';
    final out = <String>{};
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (name.startsWith(prefix) && name.endsWith('.json')) {
        out.add(name.substring(prefix.length, name.length - 5));
      }
    }
    return out;
  }

  /// Cuánto ocupa la biblioteca en el dispositivo.
  Future<int> sizeInBytes() async {
    final dir = await _dir();
    if (dir == null) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Libera el espacio. Lo pedirá el usuario desde Ajustes.
  Future<void> clear() async {
    final dir = await _dir();
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }
}
