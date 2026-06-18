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
  Future<List<Map<String, dynamic>>> materiaList({String? itemType, String? q}) async {
    final res = await _dio.get('/materia', queryParameters: {
      if (itemType != null) 'item_type': itemType,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Detalle completo de un ítem de Materia Arcana.
  Future<Map<String, dynamic>> materiaDetail(String slug) async {
    final res = await _dio.get('/materia/$slug');
    return res.data as Map<String, dynamic>;
  }
}

final arcanumApiProvider =
    Provider((ref) => ArcanumApi(ref.read(dioProvider)));
