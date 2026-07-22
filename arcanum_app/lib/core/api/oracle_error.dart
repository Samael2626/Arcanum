import 'package:dio/dio.dart';

/// Mapea los errores documentados de `POST /oracle/ia` a un mensaje claro.
///
/// Prefiere el `detail` del backend cuando existe (ya viene redactado para el
/// usuario: el cupo diario, por ejemplo, dice cuántas consultas tienes). Si no,
/// cae al mensaje canónico por código de estado. El último recurso incluye la
/// excepción cruda a propósito: un fallo desconocido debe verse, no esconderse
/// tras un "algo salió mal".
String oracleErrorMessage(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = (data is Map && data['detail'] is String)
        ? data['detail'] as String
        : null;
    switch (status) {
      case 400:
        return detail ?? 'Falta pregunta o tirada.';
      case 401:
        return 'Sesión expirada, inicia de nuevo.';
      case 404:
        return detail ?? 'Tirada no encontrada.';
      // 422 lo emiten dos causas distintas (sin carta natal / la sesión no es
      // una tirada), así que el fallback cubre ambas. En la práctica el
      // backend siempre manda `detail` aquí.
      case 422:
        return detail ?? 'Falta tu carta natal o la tirada no es válida.';
      case 429:
        return detail ?? 'Cupo diario del oráculo alcanzado.';
    }
  }
  return 'La IA ritual no respondió. $e';
}

/// Extrae la última respuesta del oráculo de una `OracleConversationResponse`.
/// Devuelve cadena vacía si la conversación no trae mensaje del asistente.
String assistantReply(Map<String, dynamic> conversation) {
  final messages = (conversation['messages'] as List?)
      ?.cast<Map<String, dynamic>>();
  if (messages == null) return '';
  final assistant = messages.lastWhere(
    (m) => m['role'] == 'assistant',
    orElse: () => const <String, dynamic>{},
  );
  return (assistant['content'] as String?) ?? '';
}
