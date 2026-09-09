import 'package:arcanum_app/features/grimorio/grimorio_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _conCodigo(int codigo) => DioException(
  requestOptions: RequestOptions(path: '/grimoire'),
  response: Response(
    requestOptions: RequestOptions(path: '/grimoire'),
    statusCode: codigo,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('por qué no se pudo sellar', () {
    test('sin red se dice que es la red', () {
      final sinRed = DioException(
        requestOptions: RequestOptions(path: '/grimoire'),
        type: DioExceptionType.connectionError,
      );
      expect(esFalloDeRed(sinRed), isTrue);
      expect(mensajeAlSellar(sinRed), contains('conexión'));
    });

    test('un rechazo del servidor NO se disfraza de fallo de red', () {
      // El bug: con conexión perfecta, un 422 decía «revisa tu conexión» y
      // mandaba al usuario a mirar donde no estaba el problema.
      for (final codigo in [400, 409, 422]) {
        final mensaje = mensajeAlSellar(_conCodigo(codigo));
        expect(mensaje, contains('rechazó'));
        expect(mensaje, isNot(contains('conexión')));
      }
    });

    test('la sesión caída se nombra, no se confunde con la red', () {
      expect(esSesionCaida(_conCodigo(401)), isTrue);
      expect(mensajeAlSellar(_conCodigo(401)), contains('Sesión expirada'));
    });

    test('un 5xx invita a esperar, no a revisar el wifi', () {
      final mensaje = mensajeAlSellar(_conCodigo(503));
      expect(mensaje, contains('servidor'));
      expect(mensaje, isNot(contains('conexión')));
    });

    test('lo que no viene del servidor tampoco culpa a la red', () {
      // Cifrado, almacenamiento, un nulo inesperado.
      final mensaje = mensajeAlSellar(StateError('clave no derivada'));
      expect(mensaje, isNot(contains('conexión')));
      expect(mensaje, contains('Vuelve a intentarlo'));
    });

    test('el mensaje nunca enseña detalles del servidor', () {
      final conRuta = DioException(
        requestOptions: RequestOptions(path: '/grimoire'),
        response: Response(
          requestOptions: RequestOptions(path: '/grimoire'),
          statusCode: 422,
          data: {'detail': 'body -> encrypted_content: field required'},
        ),
        type: DioExceptionType.badResponse,
      );
      final mensaje = mensajeAlSellar(conRuta);
      expect(mensaje, isNot(contains('encrypted_content')));
      expect(mensaje, isNot(contains('body')));
    });
  });
}
