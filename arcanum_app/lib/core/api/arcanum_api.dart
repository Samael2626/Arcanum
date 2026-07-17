import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Cliente del backend Arcanum sobre Dio (auth vía interceptor).
class ArcanumApi {
  ArcanumApi(this._dio);
  final Dio _dio;

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
  Future<Map<String, dynamic>> tarotDraw(String spread) async {
    final res = await _dio.post(
      '/oracle/tarot/draw',
      queryParameters: {'spread_type': spread},
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
  }) async {
    final q = question?.trim();
    final res = await _dio.post(
      '/oracle/ia',
      data: {
        if (q != null && q.isNotEmpty) 'question': q,
        'divination_session_id': ?divinationSessionId,
      },
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
  Future<Map<String, dynamic>> tarotDrawOne({String? question}) async {
    final res = await _dio.post(
      '/tarot/draw-one',
      data: {'question': ?question},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Tirada completa (one_card | three_card | celtic_cross). Requiere auth.
  Future<Map<String, dynamic>> tarotSpread({
    required String spreadType,
    String? question,
  }) async {
    final res = await _dio.post(
      '/tarot/spread',
      data: {'spread_type': spreadType, 'question': ?question},
    );
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
}

final arcanumApiProvider = Provider((ref) => ArcanumApi(ref.read(dioProvider)));
