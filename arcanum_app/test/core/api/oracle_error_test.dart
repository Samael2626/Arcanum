import 'package:arcanum_app/core/api/oracle_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _http(int status, {Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/oracle/ia'),
  response: Response(
    requestOptions: RequestOptions(path: '/oracle/ia'),
    statusCode: status,
    data: data,
  ),
);

void main() {
  group('mensaje de error del oráculo', () {
    test('prefiere el detail del backend, que ya viene redactado', () {
      final msg = oracleErrorMessage(
        _http(
          429,
          data: {
            'detail': 'Has alcanzado tu cupo diario de consultas (5/día).',
          },
        ),
      );
      expect(msg, 'Has alcanzado tu cupo diario de consultas (5/día).');
    });

    test('cae al mensaje canónico si no hay detail', () {
      expect(
        oracleErrorMessage(_http(429)),
        'Cupo diario del oráculo alcanzado.',
      );
      expect(oracleErrorMessage(_http(400)), 'Falta pregunta o tirada.');
      expect(oracleErrorMessage(_http(404)), 'Tirada no encontrada.');
      expect(
        oracleErrorMessage(_http(422)),
        'Falta tu carta natal o la tirada no es válida.',
      );
    });

    test('el 401 ignora el detail: el usuario debe reautenticarse', () {
      expect(
        oracleErrorMessage(_http(401, data: {'detail': 'token expired'})),
        'Sesión expirada, inicia de nuevo.',
      );
    });

    test('un detail no textual no revienta', () {
      expect(
        oracleErrorMessage(_http(400, data: {'detail': 42})),
        'Falta pregunta o tirada.',
      );
      expect(
        oracleErrorMessage(_http(400, data: 'respuesta en texto plano')),
        'Falta pregunta o tirada.',
      );
    });

    test('un fallo desconocido se muestra, no se esconde', () {
      final msg = oracleErrorMessage(StateError('socket cerrado'));
      expect(msg, startsWith('La IA ritual no respondió.'));
      expect(msg, contains('socket cerrado'));
    });
  });

  group('respuesta del asistente', () {
    test('toma el último mensaje del asistente', () {
      final reply = assistantReply({
        'messages': [
          {'role': 'user', 'content': 'primera pregunta'},
          {'role': 'assistant', 'content': 'primera respuesta'},
          {'role': 'user', 'content': 'segunda pregunta'},
          {'role': 'assistant', 'content': 'segunda respuesta'},
        ],
      });
      expect(reply, 'segunda respuesta');
    });

    test('devuelve vacío si no hay mensajes del asistente', () {
      expect(assistantReply({'messages': []}), '');
      expect(
        assistantReply({
          'messages': [
            {'role': 'user', 'content': 'hola'},
          ],
        }),
        '',
      );
    });

    test('tolera una conversación sin campo messages', () {
      expect(assistantReply(const {}), '');
    });
  });
}
