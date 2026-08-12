import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/lecturas/data/reading_repository.dart';
import 'package:arcanum_app/features/lecturas/domain/reading_position.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra lo que sale hacia el servidor. Lo que se comprueba aquí es
/// exactamente eso: qué cruza la frontera del dispositivo.
class _SpyApi extends ArcanumApi {
  _SpyApi() : super(Dio());

  Map<String, dynamic>? lastProgressPosition;
  String? lastProgressLanguage;
  Map<String, dynamic>? lastPassageBody;
  Map<String, dynamic>? lastNoteBody;

  Object? progressError;
  Object? bookmarkError;
  Object? passageError;
  List<Map<String, dynamic>> storedPassages = const [];

  static Map<String, dynamic> _echoPosition(Map<String, dynamic> position) => {
    ...position,
    'work_title': 'The Complete Herbal',
    'chapter_title': 'Amara Dulcis',
  };

  @override
  Future<Map<String, dynamic>> saveProgress({
    required Map<String, dynamic> position,
    required String language,
  }) async {
    lastProgressPosition = position;
    lastProgressLanguage = language;
    return {
      'id': 'progress-1',
      'position': _echoPosition(position),
      'language': language,
      'updated_at': '2026-08-12T10:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> progressForWork(String workSlug) async {
    if (progressError case final error?) throw error;
    return {
      'id': 'progress-1',
      'position': _echoPosition({
        'work_slug': workSlug,
        'chapter_slug': 'amara-dulcis',
        'paragraph_anchor': 'culpeper.amara-dulcis.3',
        'fragment_index': 2,
      }),
      'language': 'en',
      'updated_at': '2026-08-12T10:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> createBookmark({
    required Map<String, dynamic> position,
    String? label,
  }) async {
    if (bookmarkError case final error?) throw error;
    return {
      'id': 'bookmark-1',
      'position': _echoPosition(position),
      'label': label,
      'created_at': '2026-08-12T10:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> createPassage({
    required Map<String, dynamic> position,
    required String quote,
    required String language,
    String? encryptedNote,
    String? iv,
  }) async {
    if (passageError case final error?) throw error;
    lastPassageBody = {
      'position': position,
      'quote_text': quote,
      'quote_language': language,
      'encrypted_note': encryptedNote,
      'note_iv': iv,
    };
    return {
      'id': 'passage-1',
      'position': _echoPosition(position),
      'quote_text': quote,
      'quote_language': language,
      'encrypted_note': encryptedNote,
      'note_iv': iv,
      'created_at': '2026-08-12T10:00:00Z',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> passages({String? workSlug}) async =>
      storedPassages;

  @override
  Future<Map<String, dynamic>> updatePassageNote({
    required String id,
    String? encryptedNote,
    String? iv,
  }) async {
    lastNoteBody = {'encrypted_note': encryptedNote, 'note_iv': iv};
    return {
      'id': id,
      'position': _echoPosition({
        'work_slug': 'culpeper-complete-herbal',
        'chapter_slug': 'amara-dulcis',
        'paragraph_anchor': 'culpeper.amara-dulcis.1',
        'fragment_index': 0,
      }),
      'quote_text': 'cita',
      'quote_language': 'es',
      'encrypted_note': encryptedNote,
      'note_iv': iv,
      'created_at': '2026-08-12T10:00:00Z',
    };
  }
}

/// Cifrado de juguete, reversible y reconocible: si algo sale sin pasar por
/// aquí, el texto en claro aparecerá tal cual en el cuerpo de la petición.
class _FakeCrypto extends GrimoireCrypto {
  bool failDecrypt = false;

  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async =>
      (ciphertext: 'sellado(${plaintext.split('').reversed.join()})', iv: 'iv-fijo');

  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async {
    if (failDecrypt) throw StateError('clave distinta');
    final inner = ciphertextB64.substring(
      'sellado('.length,
      ciphertextB64.length - 1,
    );
    return inner.split('').reversed.join();
  }
}

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/reading'),
  response: Response(requestOptions: RequestOptions(path: '/reading'), statusCode: code),
);

const _position = ReadingPosition(
  workSlug: 'culpeper-complete-herbal',
  chapterSlug: 'amara-dulcis',
  paragraphAnchor: 'culpeper.amara-dulcis.3',
  fragmentIndex: 2,
);

const _secreto = 'lo que escribi para mi';

void main() {
  late _SpyApi api;
  late _FakeCrypto crypto;
  late ReadingRepository repo;

  setUp(() {
    api = _SpyApi();
    crypto = _FakeCrypto();
    repo = ReadingRepository(api, crypto);
  });

  group('progreso', () {
    test('se envia la posicion estable, nunca un numero de pagina', () async {
      await repo.saveProgress(_position, spanish: true);

      expect(api.lastProgressPosition, {
        'work_slug': 'culpeper-complete-herbal',
        'chapter_slug': 'amara-dulcis',
        'paragraph_anchor': 'culpeper.amara-dulcis.3',
        'fragment_index': 2,
      });
      // Nada que se parezca a una pagina: es lo que romperia al cambiar la
      // letra o la pantalla.
      expect(api.lastProgressPosition!.containsKey('page'), isFalse);
      expect(api.lastProgressPosition!.keys, hasLength(4));
    });

    test('el idioma viaja con la posicion', () async {
      await repo.saveProgress(_position, spanish: false);
      expect(api.lastProgressLanguage, 'en');
    });

    test('reanudar devuelve la posicion y el idioma exactos', () async {
      final progress = await repo.progressFor('culpeper-complete-herbal');

      expect(progress!.position, _position);
      expect(progress.spanish, isFalse);
      expect(progress.where.chapterTitle, 'Amara Dulcis');
    });

    test('sin lectura empezada devuelve null, no un error', () async {
      api.progressError = _status(404);
      expect(await repo.progressFor('culpeper-complete-herbal'), isNull);
    });

    test('un fallo del servidor no propaga al guardar', () async {
      // Perder el progreso de una pagina no puede tumbar la lectura.
      final roto = ReadingRepository(_BrokenApi(), crypto);
      expect(await roto.saveProgress(_position, spanish: true), isNull);
    });
  });

  group('marcadores', () {
    test('marcar dos veces el mismo punto devuelve null, no un error', () async {
      api.bookmarkError = _status(409);
      expect(await repo.addBookmark(_position), isNull);
    });

    test('un marcador nuevo conserva su posicion', () async {
      final bookmark = await repo.addBookmark(_position, label: 'Regencia');
      expect(bookmark!.position, _position);
      expect(bookmark.label, 'Regencia');
    });
  });

  group('pasajes guardados', () {
    test('la nota sale CIFRADA: el texto en claro nunca cruza', () async {
      await repo.savePassage(
        position: _position,
        quote: 'It is under the planet Mercury.',
        spanish: false,
        note: _secreto,
      );

      final body = api.lastPassageBody!;
      expect(body['encrypted_note'], isNot(contains(_secreto)));
      expect(body['note_iv'], 'iv-fijo');
      // Y en ningun otro campo del cuerpo se cuela la nota.
      expect(body.toString(), isNot(contains(_secreto)));
    });

    test('sin nota no se manda ciphertext vacio, se manda ausencia', () async {
      await repo.savePassage(
        position: _position,
        quote: 'cita',
        spanish: true,
        note: '   ',
      );
      expect(api.lastPassageBody!['encrypted_note'], isNull);
      expect(api.lastPassageBody!['note_iv'], isNull);
    });

    test('al leer, la nota vuelve descifrada', () async {
      final sealed = await crypto.encryptText(_secreto);
      api.storedPassages = [
        {
          'id': 'p1',
          'position': _SpyApi._echoPosition(_position.toJson()),
          'quote_text': 'cita',
          'quote_language': 'es',
          'encrypted_note': sealed.ciphertext,
          'note_iv': sealed.iv,
          'created_at': '2026-08-12T10:00:00Z',
        },
      ];

      final passages = await repo.passages();

      expect(passages.single.note, _secreto);
      expect(passages.single.hasNote, isTrue);
      expect(passages.single.noteUnreadable, isFalse);
    });

    test('una nota que esta clave no puede abrir se declara, no se oculta',
        () async {
      crypto.failDecrypt = true;
      api.storedPassages = [
        {
          'id': 'p1',
          'position': _SpyApi._echoPosition(_position.toJson()),
          'quote_text': 'cita',
          'quote_language': 'es',
          'encrypted_note': 'sellado(algo)',
          'note_iv': 'iv-fijo',
          'created_at': '2026-08-12T10:00:00Z',
        },
      ];

      final passage = (await repo.passages()).single;

      // Fingir que no hay nota seria mentirle a quien la escribio.
      expect(passage.note, isNull);
      expect(passage.noteUnreadable, isTrue);
    });

    test('editar la nota vuelve a cifrar', () async {
      await repo.updateNote('p1', 'nota nueva');
      expect(api.lastNoteBody!['encrypted_note'], isNot(contains('nota nueva')));
      expect(api.lastNoteBody!['note_iv'], 'iv-fijo');
    });

    test('borrar la nota manda ausencia en ambos campos', () async {
      await repo.updateNote('p1', null);
      expect(api.lastNoteBody, {'encrypted_note': null, 'note_iv': null});
    });

    test('guardar dos veces el mismo pasaje devuelve null', () async {
      api.passageError = _status(409);
      expect(
        await repo.savePassage(
          position: _position,
          quote: 'cita',
          spanish: true,
        ),
        isNull,
      );
    });
  });
}

class _BrokenApi extends ArcanumApi {
  _BrokenApi() : super(Dio());

  @override
  Future<Map<String, dynamic>> saveProgress({
    required Map<String, dynamic> position,
    required String language,
  }) async => throw _status(500);
}
