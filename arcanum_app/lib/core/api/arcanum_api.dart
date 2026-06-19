import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Cliente del backend Arcanum sobre Dio (auth vía interceptor).
class ArcanumApi {
  ArcanumApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> today({double lat = 4.71, double lon = -74.07}) async {
    final res = await _dio.get('/astral/today',
        queryParameters: {'lat': lat, 'lon': lon});
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

  /// Materia Arcana: catálogo (resumen). Filtros opcionales.
  Future<List<Map<String, dynamic>>> materiaList({String? itemType, String? planet, String? q}) async {
    final res = await _dio.get('/materia', queryParameters: {
      if (itemType != null) 'item_type': itemType,
      if (planet != null) 'planet': planet,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Detalle completo de un ítem de Materia Arcana.
  Future<Map<String, dynamic>> materiaDetail(String slug) async {
    final res = await _dio.get('/materia/$slug');
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
    final res = await _dio.post('/oracle/tarot/draw', queryParameters: {'spread_type': spread});
    return res.data as Map<String, dynamic>;
  }

  /// Consulta ritual con IA Claude. Requiere auth. Solo envía la pregunta;
  /// el contexto astral lo construye el servidor desde la carta natal cacheada.
  /// Devuelve OracleConversation (messages = lista de {role, content, timestamp}).
  Future<Map<String, dynamic>> oracleIa({required String question}) async {
    final res = await _dio.post('/oracle/ia', data: {'question': question});
    return res.data as Map<String, dynamic>;
  }
}

final arcanumApiProvider =
    Provider((ref) => ArcanumApi(ref.read(dioProvider)));
