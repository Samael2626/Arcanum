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
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
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

  /// Cuanto se espera a una ruta que llama al MODELO.
  ///
  /// El `receiveTimeout` global son 12 s, dimensionados para rutas de calculo
  /// que responden en decimas. Una interpretacion no es eso: medido contra
  /// produccion, una tirada de tres cartas tardo 4,5 s y 10,3 s en dos
  /// llamadas seguidas, y la Cruz Celta tiene un techo de tokens mayor
  /// (`_LARGE_SPREAD_MAX_TOKENS`), asi que tarda mas. Con 12 s el margen era
  /// de segundos y en red movil se agotaba.
  ///
  /// Un timeout que salta ANTES de que el servidor termine es el peor de los
  /// dos mundos: la persona ve "la IA no respondio" —el mensaje de error sin
  /// respuesta HTTP, no un 5xx— mientras el backend SI genera, cobra el cupo y
  /// guarda el resultado. La consulta se pago y no se leyo.
  ///
  /// No se sube el timeout global: en las rutas rapidas, esperar un minuto a
  /// algo que murio es peor que rendirse a los 12 s.
  static const Duration _esperaModelo = Duration(seconds: 90);

  /// Cabecera obligatoria en las cuatro rutas que cobran. Si la pantalla no
  /// pasa clave se genera una nueva: nunca se manda la petición sin ella.
  ///
  /// La espera larga viaja aqui porque toda ruta que llama al modelo pasa por
  /// esta cabecera: asi no hay forma de mandar una peticion de IA sin ella.
  /// Las dos que cobran sin llamar al modelo —los sorteos de carta, que son
  /// calculo puro y responden en poco mas de un segundo— tambien se la llevan.
  /// No molesta: el techo solo se toca cuando algo va mal, y en ese caso da
  /// margen de sobra en vez de cortar una respuesta que venia en camino.
  Options _idempotentOptions(String? key) => Options(
    headers: {'Idempotency-Key': key ?? IdempotencyKey.create()},
    receiveTimeout: _esperaModelo,
  );

  /// Cielo de hoy en un lugar concreto: hora planetaria + regente + luna.
  ///
  /// Sin valores por omision a proposito. La hora planetaria se deriva del orto
  /// y el ocaso del sitio, asi que un default convertiria el olvido de quien
  /// llame en la ciudad de otra persona, en silencio. Quien no tenga lugar
  /// confirmado pide [moon], que es global y siempre cierta.
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) async {
    final res = await _dio.get(
      '/astral/today',
      queryParameters: {'lat': lat, 'lon': lon},
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Fase lunar: la misma en todo el planeta, no depende del lugar ni de la
  /// sesion. Es lo unico del cielo de hoy que puede afirmarse sin coordenadas.
  Future<Map<String, dynamic>> moon() async {
    final res = await _dio.get(
      '/astral/moon',
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

  /// El cielo de hoy leído por la IA. Requiere auth y carta natal.
  ///
  /// El servidor lo genera una vez por día y sirve el mismo texto el resto de
  /// la jornada, así que llamar de más no cuesta ni cambia la lectura.
  /// El cielo de hoy SIN interpretar: que transito manda y a que separacion
  /// real. Gratis — no reserva cupo, no llama al modelo y no manda nada a un
  /// tercero, asi que tampoco necesita consentimiento.
  ///
  /// Es lo que pinta el sello antes de abrirse. Sin este endpoint, ENSENAR el
  /// sello costaria lo mismo que ABRIRLO, porque el unico sitio que sabia el
  /// transito del dia era el que genera el texto.
  Future<Map<String, dynamic>> skyToday() async {
    final res = await _dio.get('/astral/sky-today');
    return res.data as Map<String, dynamic>;
  }

  /// El horoscopo del dia, interpretado por el modelo.
  ///
  /// No lleva `Idempotency-Key`: la unicidad la pone el servidor con la fecha
  /// local de la persona. Pero llama al modelo igual que el Oraculo, asi que
  /// necesita la misma espera; sin esto quedaba con los 12 s globales.
  Future<Map<String, dynamic>> horoscope() async {
    final res = await _dio.get(
      '/astral/horoscope',
      options: Options(receiveTimeout: _esperaModelo),
    );
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

  /// Reporta una salida de IA como ofensiva o peligrosa.
  ///
  /// Google Play exige que se pueda reportar SIN salir de la app, asi que esto
  /// no puede ser un enlace de correo. Se manda un fragmento acotado y nunca
  /// el texto entero: un reporte no es excusa para volcar la lectura de
  /// alguien en un sitio que no esta pensado para guardarla.
  /// Denuncia de contenido de IA. Ruta unica: `POST /reports`.
  ///
  /// Antes iba a `/reports/content`, que solo dejaba una linea en el log de la
  /// aplicacion. Los logs rotan: eso servia para enterarse, no para llevar el
  /// historial que la politica AI-Generated Content de Play da por hecho. Ahora
  /// las dos vias de denuncia escriben en `content_reports`.
  ///
  /// No se manda el texto denunciado. El servidor guarda la referencia y la
  /// pantalla; un reporte no es excusa para persistir en claro la lectura de
  /// alguien.
  Future<void> reportContent({
    required String surface,
    required String reason,
    String? excerpt,
    String? note,
  }) => createContentReport(
        source: surface,
        contentRef: '',
        reason: reason,
        note: note,
      );

  /// Tira de tarot. spread: 'three_card' | 'celtic_cross'. Requiere auth.
  /// Devuelve la sesión guardada (cartas en data['cards_drawn']['cards']).
  Future<Map<String, dynamic>> tarotDraw(
    String spread, {
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/oracle/tarot/draw',
      queryParameters: {'spread_type': spread},
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Consulta ritual con IA. Requiere auth. El contexto astral lo
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

  // ── Denuncia de contenido generado por IA ───────────────────────────────
  //
  // Requisito literal de la politica AI-Generated Content de Play: poder
  // denunciar sin salir de la app.

  Future<void> createContentReport({
    required String source,
    required String contentRef,
    required String reason,
    String? note,
  }) async {
    await _dio.post(
      '/reports',
      data: {
        'source': source,
        'content_ref': contentRef,
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  // ── Consentimientos ─────────────────────────────────────────────────────
  //
  // Se persisten en el servidor, no solo en el dispositivo: en Colombia la
  // autorizacion hay que poder demostrarla. Ver core/privacy/consent_policy.dart.

  Future<List<Map<String, dynamic>>> userConsents() async =>
      (await _dio.get('/consents')).data.cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> recordConsent({
    required String kind,
    required String policyVersion,
    required bool granted,
  }) async =>
      (await _dio.post(
            '/consents',
            data: {
              'kind': kind,
              'policy_version': policyVersion,
              'granted': granted,
            },
          )).data
          as Map<String, dynamic>;
}

final arcanumApiProvider = Provider((ref) => ArcanumApi(ref.read(dioProvider)));
