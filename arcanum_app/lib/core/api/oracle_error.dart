import 'package:dio/dio.dart';

/// Mensaje para un 422 que el cliente no sabe interpretar. El caso tipico es
/// un cliente desactualizado contra un backend que exige campos o cabeceras
/// nuevas: pedir actualizar es la accion util, no reintentar.
const String validationFallbackMessage =
    'No se pudo validar la consulta. Actualiza la app e inténtalo de nuevo.';

String oracleErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final rawDetail = data is Map ? data['detail'] : null;
    final detail = rawDetail is String
        ? rawDetail
        : rawDetail is Map && rawDetail['message'] is String
            ? rawDetail['message'] as String
            : null;
    switch (status) {
      case 400:
        return detail ?? 'Falta pregunta o tirada.';
      case 401:
        return 'Sesión expirada, inicia de nuevo.';
      case 402:
        return detail ?? 'Saldo insuficiente. Compra créditos para continuar.';
      case 404:
        return detail ?? 'Tirada no encontrada.';
      case 422:
        // Dos 422 muy distintos comparten codigo: el de dominio (falta la carta
        // natal) trae `detail` como texto, y el de validacion de FastAPI lo trae
        // como lista de errores por campo. Mostrar el canonico ante una lista
        // mandaba al usuario a recalcular su carta natal por una cabecera
        // ausente. Solo se reconoce el de dominio; el resto cae en el neutral.
        // El texto del backend no se muestra crudo: incluye rutas de la API.
        if (detail != null && detail.toLowerCase().contains('carta natal')) {
          return 'Falta tu carta natal. Calcúlala antes de consultar al oráculo.';
        }
        return validationFallbackMessage;
      case 429:
        return detail ?? 'El oráculo está saturado. Intenta de nuevo en unos minutos.';
      case 500:
        // Fallo del servidor: el detail puede traer trazas o texto tecnico.
        return 'El oráculo tuvo un problema temporal. Intenta de nuevo más tarde.';
      case 503:
        return detail ?? 'El oráculo no está disponible. Intenta de nuevo más tarde.';
    }
    if (status != null && status >= 500) {
      return 'El oráculo tuvo un problema temporal. Intenta de nuevo más tarde.';
    }
  }
  // Nunca interpolar el error: filtraria DioException, URL, status o stack.
  return 'La IA ritual no respondió. Intenta de nuevo.';
}

String assistantReply(Map<String, dynamic> conversation) {
  final messages = (conversation['messages'] as List?)?.cast<Map<String, dynamic>>();
  if (messages == null) return '';
  final assistant = messages.lastWhere(
    (message) => message['role'] == 'assistant',
    orElse: () => const <String, dynamic>{},
  );
  return (assistant['content'] as String?) ?? '';
}