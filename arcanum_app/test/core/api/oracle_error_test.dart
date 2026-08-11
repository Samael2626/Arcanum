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
        'El oráculo está saturado. Intenta de nuevo en unos minutos.',
      );
      expect(oracleErrorMessage(_http(400)), 'Falta pregunta o tirada.');
      expect(oracleErrorMessage(_http(404)), 'Tirada no encontrada.');
      expect(oracleErrorMessage(_http(422)), validationFallbackMessage);
    });

    test('el 422 de dominio nombra la carta natal, sin rutas de la API', () {
      final msg = oracleErrorMessage(_http(422, data: {
        'detail': 'Calcula primero tu carta natal con POST /astral/natal-chart.',
      }));
      expect(msg, 'Falta tu carta natal. Calcúlala antes de consultar al oráculo.');
      expect(msg, isNot(contains('/astral')));
      expect(msg, isNot(contains('POST')));
    });

    test('el 422 de validacion con detail lista no habla de carta natal', () {
      // Lo que devuelve FastAPI cuando falta la cabecera Idempotency-Key.
      final msg = oracleErrorMessage(_http(422, data: {
        'detail': [
          {
            'type': 'missing',
            'loc': ['header', 'Idempotency-Key'],
            'msg': 'Field required',
            'input': null,
            'url': 'https://errors.pydantic.dev/2.10/v/missing',
          }
        ],
      }));
      expect(msg, validationFallbackMessage);
      expect(msg.toLowerCase(), isNot(contains('carta natal')));
      expect(msg, isNot(contains('Idempotency-Key')));
      expect(msg, isNot(contains('header')));
      expect(msg, isNot(contains('missing')));
      expect(msg, isNot(contains('pydantic')));
      expect(msg, isNot(contains('DioException')));
      expect(msg, isNot(contains('422')));
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

    test('el 500 da mensaje humano y no filtra nada tecnico', () {
      final msg = oracleErrorMessage(
        _http(500, data: {'detail': "TypeError: build_oracle_context() missing 1 required positional argument: 'db'"}),
      );
      expect(
        msg,
        'El oráculo tuvo un problema temporal. Intenta de nuevo más tarde.',
      );
      expect(msg, isNot(contains('DioException')));
      expect(msg, isNot(contains('500')));
      expect(msg, isNot(contains('RequestOptions')));
      expect(msg, isNot(contains('TypeError')));
      expect(msg, isNot(contains('/oracle/ia')));
    });

    test('cualquier 5xx sin caso propio cae al mensaje temporal', () {
      for (final status in [501, 502, 504, 599]) {
        final msg = oracleErrorMessage(_http(status));
        expect(
          msg,
          'El oráculo tuvo un problema temporal. Intenta de nuevo más tarde.',
        );
        expect(msg, isNot(contains('$status')));
      }
    });

    test('un fallo desconocido no expone el objeto de error', () {
      final msg = oracleErrorMessage(StateError('socket cerrado en /oracle/ia'));
      expect(msg, 'La IA ritual no respondió. Intenta de nuevo.');
      expect(msg, isNot(contains('socket cerrado')));
      expect(msg, isNot(contains('StateError')));
    });

    test('un DioException sin response tampoco filtra detalles', () {
      final msg = oracleErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/oracle/ia'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(msg, 'La IA ritual no respondió. Intenta de nuevo.');
      expect(msg, isNot(contains('DioException')));
      expect(msg, isNot(contains('RequestOptions')));
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

  test('el 402 lee detail objeto', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/oracle/ia'),
      response: Response(
        requestOptions: RequestOptions(path: '/oracle/ia'),
        statusCode: 402,
        data: {'detail': {'message': 'Compra créditos para continuar.'}},
      ),
    );
    expect(oracleErrorMessage(error), 'Compra créditos para continuar.');
  });
}
