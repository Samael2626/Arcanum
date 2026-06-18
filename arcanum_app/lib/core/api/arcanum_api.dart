import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente del backend Arcanum (FastAPI en localhost:8000).
/// Más adelante se migrará a Dio con interceptores JWT (Semana 4+).
class ArcanumApi {
  static const String baseUrl = 'http://localhost:8000';

  Future<Map<String, dynamic>> today({
    double lat = 4.71,
    double lon = -74.07,
  }) async {
    return _getJson('/astral/today?lat=$lat&lon=$lon');
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('El oráculo respondió ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
