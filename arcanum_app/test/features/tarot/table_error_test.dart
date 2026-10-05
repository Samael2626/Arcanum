import 'package:arcanum_app/features/tarot/domain/table_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _http(int status, Object? data) {
  final req = RequestOptions(path: '/tarot/sessions');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  test('sesion caida: se pide volver a entrar, no el texto en ingles', () {
    final e = _http(401, {'detail': 'Not authenticated'});
    expect(isTableSessionLost(e), isTrue);
    expect(tableErrorMessage(e), 'Tu sesión caducó. Vuelve a entrar.');
  });

  test('el 403 sin token de FastAPI tambien es sesion caida', () {
    final e = _http(403, {'detail': 'Not authenticated'});
    expect(isTableSessionLost(e), isTrue);
  });

  test('los mensajes propios de la mesa se muestran tal cual', () {
    expect(
      tableErrorMessage(_http(409, {'detail': 'Ya no se puede deshacer.'})),
      'Ya no se puede deshacer.',
    );
    expect(
      tableErrorMessage(
        _http(404, {'detail': 'La mesa no existe o ya caducó.'}),
      ),
      'La mesa no existe o ya caducó.',
    );
  });

  test('los textos por defecto del framework no llegan al usuario', () {
    for (final raw in [
      'Not Found',
      'Method Not Allowed',
      'Internal Server Error',
    ]) {
      final msg = tableErrorMessage(_http(404, {'detail': raw}), debug: false);
      expect(msg, isNot(contains(raw)));
      expect(msg, 'No se pudo completar. Inténtalo de nuevo.');
    }
  });

  test('la validacion de FastAPI (lista) no se muestra cruda', () {
    final e = _http(422, {
      'detail': [
        {
          'loc': ['body', 'spread'],
          'msg': 'field required',
        },
      ],
    });
    expect(
      tableErrorMessage(e, debug: false),
      'No se pudo completar. Actualiza la app e inténtalo de nuevo.',
    );
  });

  test('sin respuesta es falta de conexion', () {
    final e = DioException(requestOptions: RequestOptions(path: '/x'));
    expect(
      tableErrorMessage(e),
      'No hay conexión con el servidor. Inténtalo de nuevo.',
    );
  });

  test(
    'fuera de la tienda se anota que fallo, sin mostrar el detalle crudo',
    () {
      final msg = tableErrorMessage(_http(500, 'boom'), debug: true);
      expect(msg, startsWith('No se pudo completar. Inténtalo de nuevo.'));
      expect(msg, contains('HTTP 500 /tarot/sessions'));
      expect(msg, isNot(contains('boom')));
    },
  );
}
