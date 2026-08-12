import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Clave de idempotencia para las rutas que cobran.
///
/// La genera el cliente, no el servidor: solo el cliente sabe que un reintento
/// tras un timeout es el MISMO intento y no una consulta nueva. Un UUIDv4 con
/// `Random.secure()` para que dos usuarios no colisionen jamás.
class IdempotencyKey {
  static final Random _random = Random.secure();

  static String create() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
        '-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// El backend responde 402 cuando se agotan cuota y créditos: es la señal para
/// abrir el paywall, no un error que mostrar tal cual.
bool isCreditsRequired(Object error) =>
    error is DioException && error.response?.statusCode == 402;

/// Cliente del backend Arcanum sobre Dio (auth vía interceptor).
class ArcanumApi {
  ArcanumApi(this._dio);
  final Dio _dio;

  /// Cabecera obligatoria en las cuatro rutas que cobran. Si la pantalla no
  /// pasa clave se genera una nueva: nunca se manda la petición sin ella.
  Options _idempotentOptions(String? key) =>
      Options(headers: {'Idempotency-Key': key ?? IdempotencyKey.create()});

  Future<Map<String, dynamic>> today({
    double lat = 4.71,
    double lon = -74.07,
  }) async {
    final res = await _dio.get(
      '/astral/today',
      queryParameters: {'lat': lat, 'lon': lon},
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Lecturas (obras en dominio público) ─────────────────────────────────
  //
  // Contenido público, como Materia Arcana: no requiere auth. Se piden por
  // separado índice y texto porque Culpeper son 423 capítulos y ~1,7 MB:
  // mandar el libro entero por una lista que el usuario solo ojea sería
  // gastar los datos de alguien para nada.

  /// Índice de obras, sin texto.
  Future<List<Map<String, dynamic>>> libraryWorks() async {
    final res = await _dio.get(
      '/library',
      options: Options(extra: const {'noAuth': true}),
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Una obra con su índice de capítulos, sin texto.
  /// [kind] filtra el índice: herb | appendix | catalogue | front.
  Future<Map<String, dynamic>> libraryWork(String slug, {String? kind}) async {
    final res = await _dio.get(
      '/library/$slug',
      queryParameters: {'kind': ?kind},
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Un capítulo con su texto. Es la unidad que se cachea para leer offline.
  Future<Map<String, dynamic>> libraryChapter(
    String workSlug,
    String chapterSlug,
  ) async {
    final res = await _dio.get(
      '/library/$workSlug/$chapterSlug',
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Calcula (o recalcula) y cachea la carta natal del usuario. Requiere auth.
  Future<Map<String, dynamic>> natalChart() async {
    final res = await _dio.post('/astral/natal-chart');
    return res.data as Map<String, dynamic>;
  }

  /// Tránsitos del cielo actual sobre la carta natal. Requiere auth.
  Future<Map<String, dynamic>> transits() async {
    final res = await _dio.get('/astral/transits');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> celestialOverview() async {
    final res = await _dio.get('/astral/overview');
    return res.data as Map<String, dynamic>;
  }

  /// Materia Arcana: catálogo (resumen). Filtros opcionales.
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async {
    final res = await _dio.get(
      '/materia',
      options: Options(extra: const {'noAuth': true}),
      queryParameters: {
        'item_type': ?itemType,
        'planet': ?planet,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Detalle completo de un ítem de Materia Arcana.
  Future<Map<String, dynamic>> materiaDetail(String slug) async {
    final res = await _dio.get(
      '/materia/$slug',
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  /// El puente Materia → Lecturas: qué capítulo de Culpeper trata esta planta.
  /// 404 cuando no hay capítulo enlazado (planta sin puente) — el llamador lo
  /// trata como ausencia esperada y no muestra la tarjeta, no como error.
  Future<Map<String, dynamic>> materiaBridge(String slug) async {
    final res = await _dio.get(
      '/library/by-materia/$slug',
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Grimorio (requiere auth; contenido cifrado en cliente) ──────────────────
  Future<List<Map<String, dynamic>>> grimoireList() async {
    final res = await _dio.get('/grimoire');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> grimoireGet(String id) async {
    final res = await _dio.get('/grimoire/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    final res = await _dio.post('/grimoire', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<void> grimoireDelete(String id) async {
    await _dio.delete('/grimoire/$id');
  }

  /// Tira de tarot. spread: 'three_card' | 'celtic_cross'. Requiere auth.
  /// Devuelve la sesión guardada (cartas en data['cards_drawn']['cards']).
  Future<Map<String, dynamic>> tarotDraw(String spread, {String? idempotencyKey}) async {
    final res = await _dio.post(
      '/oracle/tarot/draw',
      queryParameters: {'spread_type': spread},
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Consulta ritual con IA Claude. Requiere auth. El contexto astral lo
  /// construye el servidor desde la carta natal cacheada. Dos modos:
  /// - `question` + `divinationSessionId` → lectura anclada a la tirada, responde la pregunta.
  /// - solo `divinationSessionId` (question null/vacío) → lectura de la tirada sin pregunta.
  /// Devuelve OracleConversation (messages = lista de {role, content, timestamp}).
  Future<Map<String, dynamic>> oracleIa({
    String? question,
    String? divinationSessionId,
    String? idempotencyKey,
  }) async {
    final q = question?.trim();
    final res = await _dio.post(
      '/oracle/ia',
      data: {
        if (q != null && q.isNotEmpty) 'question': q,
        'divination_session_id': ?divinationSessionId,
      },
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Tarot (catálogo + sorteos) ──────────────────────────────────────────

  /// Catálogo de cartas del Tarot. Filtros opcionales.
  Future<List<Map<String, dynamic>>> tarotList({
    String? arcana,
    String? suit,
  }) async {
    final res = await _dio.get(
      '/tarot/cards',
      queryParameters: {'arcana': ?arcana, 'suit': ?suit},
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Detalle de una carta por slug.
  Future<Map<String, dynamic>> tarotCard(String slug) async {
    final res = await _dio.get('/tarot/cards/$slug');
    return res.data as Map<String, dynamic>;
  }

  /// Sorteo de una carta. Requiere auth.
  /// La pregunta se envía en texto plano (Pydantic del lado servidor la trunca a 1000 chars).
  Future<Map<String, dynamic>> tarotDrawOne({
    String? question,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/tarot/draw-one',
      data: {'question': ?question},
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Tirada completa (one_card | three_card | celtic_cross). Requiere auth.
  Future<Map<String, dynamic>> tarotSpread({
    required String spreadType,
    String? question,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/tarot/spread',
      data: {'spread_type': spreadType, 'question': ?question},
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Saldo de créditos del usuario. Solo lectura: la app lo consulta al abrir
  /// el paywall y después de un 402.
  Future<Map<String, dynamic>> creditsBalance() async {
    final res = await _dio.get('/credits/balance');
    return res.data as Map<String, dynamic>;
  }

  // ── Geocoding (onboarding: lugar de nacimiento real) ─────────────────────

  /// Resuelve país+ciudad a lat/lon/timezone reales (Nominatim + timezonefinder,
  /// calculado en el servidor). Requiere auth. El cliente DEBE mostrar
  /// `display_name` al usuario para que confirme antes de persistirlo — nunca
  /// guardar automáticamente sin confirmación. Si el backend no resuelve el
  /// lugar, propaga un DioException con `response.data['detail']` legible
  /// (422); el llamador debe fallar visible, nunca caer a un default.
  Future<Map<String, dynamic>> geoResolve({
    required String country,
    required String city,
  }) async {
    final res = await _dio.post(
      '/geo/resolve',
      data: {'country': country, 'city': city},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Biblioteca personal (/reading) ───────────────────────────────────────
  //
  // Al reves que /library, todo esto es privado y va autenticado. La posicion
  // que se manda es siempre la estable (obra, capitulo, ancla, fragmento):
  // NUNCA un numero de pagina, que cambia con la letra y la pantalla.
  //
  // Las notas de los pasajes viajan cifradas con la clave del Grimorio. Este
  // cliente no las cifra: recibe y devuelve opacos, y de la criptografia se
  // encarga ReadingRepository. Aqui no hay ningun campo de nota en claro.

  /// Guarda donde se quedo el usuario. Idempotente por obra: repetirlo deja el
  /// mismo estado, que es justo lo que hace falta cuando el lector guarda al
  /// pasar pagina y al salir casi a la vez.
  Future<Map<String, dynamic>> saveProgress({
    required Map<String, dynamic> position,
    required String language,
  }) async {
    final res = await _dio.put(
      '/reading/progress',
      data: {'position': position, 'language': language},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Progreso de una obra. Lanza 404 cuando no hay lectura empezada: es la
  /// senal de "Comenzar lectura", no un error.
  Future<Map<String, dynamic>> progressForWork(String workSlug) async {
    final res = await _dio.get('/reading/progress/$workSlug');
    return res.data as Map<String, dynamic>;
  }

  /// Todas las obras empezadas, la mas reciente primero.
  Future<List<Map<String, dynamic>>> allProgress() async {
    final res = await _dio.get('/reading/progress');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createBookmark({
    required Map<String, dynamic> position,
    String? label,
  }) async {
    final res = await _dio.post(
      '/reading/bookmarks',
      data: {'position': position, 'label': ?label},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> bookmarks({String? workSlug}) async {
    final res = await _dio.get(
      '/reading/bookmarks',
      queryParameters: {'work_slug': ?workSlug},
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteBookmark(String id) =>
      _dio.delete('/reading/bookmarks/$id');

  /// Guarda un pasaje. [encryptedNote] e [iv] ya vienen cifrados del llamador.
  Future<Map<String, dynamic>> createPassage({
    required Map<String, dynamic> position,
    required String quote,
    required String language,
    String? encryptedNote,
    String? iv,
  }) async {
    final res = await _dio.post(
      '/reading/passages',
      data: {
        'position': position,
        'quote_text': quote,
        'quote_language': language,
        'encrypted_note': encryptedNote,
        'note_iv': iv,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> passages({String? workSlug}) async {
    final res = await _dio.get(
      '/reading/passages',
      queryParameters: {'work_slug': ?workSlug},
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Sustituye la nota cifrada. Ambos en null la borra sin tocar el pasaje.
  Future<Map<String, dynamic>> updatePassageNote({
    required String id,
    String? encryptedNote,
    String? iv,
  }) async {
    final res = await _dio.patch(
      '/reading/passages/$id',
      data: {'encrypted_note': encryptedNote, 'note_iv': iv},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> deletePassage(String id) => _dio.delete('/reading/passages/$id');
}

final arcanumApiProvider = Provider((ref) => ArcanumApi(ref.read(dioProvider)));
