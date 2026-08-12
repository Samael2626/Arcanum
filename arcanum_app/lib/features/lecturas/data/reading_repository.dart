import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/crypto/grimoire_crypto.dart';
import '../domain/reading_models.dart';
import '../domain/reading_position.dart';

/// Progreso, marcadores y pasajes guardados.
///
/// Es la frontera del cifrado: por debajo solo circulan opacos, y por encima
/// las pantallas ven texto en claro. Ninguna nota sale de aquí sin cifrar, y la
/// clave es la misma DEK del Grimorio ligada al dispositivo — un pasaje
/// guardado es una entrada privada como cualquier otra.
class ReadingRepository {
  ReadingRepository(this._api, this._crypto);

  final ArcanumApi _api;
  final GrimoireCrypto _crypto;

  // ── Progreso ─────────────────────────────────────────────────────────────

  /// Guarda la posición. Devuelve null si falla: perder el progreso de una
  /// página no puede tumbar la lectura, así que el fallo se traga y se registra.
  Future<ReadingProgress?> saveProgress(
    ReadingPosition position, {
    required bool spanish,
  }) async {
    try {
      return ReadingProgress.fromJson(
        await _api.saveProgress(
          position: position.toJson(),
          language: spanish ? 'es' : 'en',
        ),
      );
    } catch (error) {
      debugPrint('ARCANUM lecturas: no se pudo guardar el progreso ($error).');
      return null;
    }
  }

  /// Progreso de una obra, o null si aún no se ha empezado.
  ///
  /// El 404 del backend se traduce a null aquí y no se propaga: "sin empezar"
  /// es un estado normal de la portada, no una avería que mostrar.
  Future<ReadingProgress?> progressFor(String workSlug) async {
    try {
      return ReadingProgress.fromJson(await _api.progressForWork(workSlug));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<ReadingProgress>> allProgress() async =>
      (await _api.allProgress()).map(ReadingProgress.fromJson).toList();

  // ── Marcadores ───────────────────────────────────────────────────────────

  Future<List<ReadingBookmark>> bookmarks({String? workSlug}) async =>
      (await _api.bookmarks(workSlug: workSlug))
          .map(ReadingBookmark.fromJson)
          .toList();

  /// Crea un marcador. Devuelve null si ya había uno en esa posición (409):
  /// marcar dos veces el mismo punto no es un error que enseñar en rojo.
  Future<ReadingBookmark?> addBookmark(
    ReadingPosition position, {
    String? label,
  }) async {
    try {
      return ReadingBookmark.fromJson(
        await _api.createBookmark(position: position.toJson(), label: label),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) return null;
      rethrow;
    }
  }

  Future<void> removeBookmark(String id) => _api.deleteBookmark(id);

  // ── Pasajes guardados ────────────────────────────────────────────────────

  Future<List<SavedPassage>> passages({String? workSlug}) async {
    final raw = await _api.passages(workSlug: workSlug);
    return Future.wait(raw.map(_decode));
  }

  /// Guarda un pasaje, cifrando la nota antes de que salga del dispositivo.
  Future<SavedPassage?> savePassage({
    required ReadingPosition position,
    required String quote,
    required bool spanish,
    String? note,
  }) async {
    final sealed = await _seal(note);
    try {
      return await _decode(
        await _api.createPassage(
          position: position.toJson(),
          quote: quote,
          language: spanish ? 'es' : 'en',
          encryptedNote: sealed?.ciphertext,
          iv: sealed?.iv,
        ),
      );
    } on DioException catch (error) {
      // 409: ya estaba guardado. No es un fallo desde la mano del usuario.
      if (error.response?.statusCode == 409) return null;
      rethrow;
    }
  }

  Future<SavedPassage> updateNote(String id, String? note) async {
    final sealed = await _seal(note);
    return _decode(
      await _api.updatePassageNote(
        id: id,
        encryptedNote: sealed?.ciphertext,
        iv: sealed?.iv,
      ),
    );
  }

  Future<void> removePassage(String id) => _api.deletePassage(id);

  // ── Cifrado ──────────────────────────────────────────────────────────────

  /// Cifra la nota. Una nota vacía es ausencia de nota, no una cadena cifrada
  /// vacía: así borrarla desde el editor la borra de verdad.
  Future<({String ciphertext, String iv})?> _seal(String? note) async {
    final clean = note?.trim();
    if (clean == null || clean.isEmpty) return null;
    return _crypto.encryptText(clean);
  }

  Future<SavedPassage> _decode(Map<String, dynamic> json) async {
    final ciphertext = json['encrypted_note'] as String?;
    final iv = json['note_iv'] as String?;

    String? note;
    var unreadable = false;
    if (ciphertext != null && iv != null) {
      try {
        note = await _crypto.decryptText(ciphertext, iv);
      } catch (error) {
        // Clave distinta: otra instalación, o la DEK se perdió. Se marca en
        // vez de fingir que el usuario nunca escribió nada — la nota existe,
        // simplemente este dispositivo no puede leerla.
        debugPrint('ARCANUM lecturas: nota ilegible con esta clave ($error).');
        unreadable = true;
      }
    }

    return SavedPassage(
      id: json['id'] as String,
      where: ResolvedPosition.fromJson(
        json['position'] as Map<String, dynamic>,
      ),
      quote: json['quote_text'] as String,
      quoteInSpanish: (json['quote_language'] as String? ?? 'es') == 'es',
      note: note,
      noteUnreadable: unreadable,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

final readingRepositoryProvider = Provider(
  (ref) => ReadingRepository(
    ref.read(arcanumApiProvider),
    ref.read(grimoireCryptoProvider),
  ),
);

/// Pasajes guardados del usuario, para "Grimorio → Pasajes guardados".
final savedPassagesProvider = FutureProvider.autoDispose(
  (ref) => ref.read(readingRepositoryProvider).passages(),
);

/// Progreso de una obra concreta, para decidir Comenzar vs Reanudar.
final workProgressProvider = FutureProvider.autoDispose
    .family<ReadingProgress?, String>(
      (ref, workSlug) =>
          ref.read(readingRepositoryProvider).progressFor(workSlug),
    );

/// Todo el progreso, para pintar el avance en la estantería.
final allProgressProvider = FutureProvider.autoDispose(
  (ref) => ref.read(readingRepositoryProvider).allProgress(),
);
