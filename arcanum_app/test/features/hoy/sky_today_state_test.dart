import 'package:arcanum_app/features/hoy/sky_today_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(int status, {Object? detail}) => DioException(
  requestOptions: RequestOptions(path: '/astral/horoscope'),
  response: Response(
    requestOptions: RequestOptions(path: '/astral/horoscope'),
    statusCode: status,
    data: detail == null ? null : {'detail': detail},
  ),
);

void main() {
  group('cada fallo se dice por lo que es', () {
    test('sin carta natal se ofrece calcularla, no revisar la conexión', () {
      final failure = classifySkyFailure(_dio(404));

      expect(failure, SkyTodayFailure.sinCartaNatal);
      expect(skyFailureMessage(failure), contains('carta natal'));
      expect(skyFailureRoute(failure), '/cielos');
      expect(skyFailureMessage(failure), isNot(contains('conexión')));
    });

    test('faltan datos de nacimiento y se manda al perfil', () {
      final failure = classifySkyFailure(
        _dio(422, detail: 'Faltan datos de nacimiento: birth_lat'),
      );

      expect(failure, SkyTodayFailure.sinDatosDeNacimiento);
      expect(skyFailureRoute(failure), '/perfil');
    });

    test('un 422 de validación NO manda a completar el perfil', () {
      // FastAPI devuelve una lista de errores por campo. Tratarlo como el 422
      // de dominio mandaria a la persona a arreglar datos que ya estan bien.
      final failure = classifySkyFailure(
        _dio(
          422,
          detail: [
            {
              'loc': ['header', 'x'],
              'msg': 'field required',
            },
          ],
        ),
      );

      expect(failure, SkyTodayFailure.cieloNoLegible);
      expect(skyFailureRoute(failure), isNull);
    });

    test('la sesión expirada no se disfraza de fallo de red', () {
      final failure = classifySkyFailure(_dio(401));

      expect(failure, SkyTodayFailure.sesionExpirada);
      expect(skyFailureRoute(failure), '/login');
    });

    test('un 503 es el cielo ilegible, no una sesión ni una carta ausente', () {
      expect(classifySkyFailure(_dio(503)), SkyTodayFailure.cieloNoLegible);
    });

    test('cualquier 5xx cae en cielo ilegible', () {
      expect(classifySkyFailure(_dio(500)), SkyTodayFailure.cieloNoLegible);
      expect(classifySkyFailure(_dio(502)), SkyTodayFailure.cieloNoLegible);
    });

    test('un error que no es de red ni de HTTP no inventa una causa', () {
      expect(classifySkyFailure(Exception('boom')), SkyTodayFailure.sinRed);
    });
  });

  group('cuándo la lectura local es una respuesta y no un relleno', () {
    test('sin red y sin modelo los tránsitos siguen valiendo', () {
      expect(allowsLocalReading(SkyTodayFailure.sinRed), isTrue);
      expect(allowsLocalReading(SkyTodayFailure.cieloNoLegible), isTrue);
    });

    test('sin carta, sin datos o sin sesión no hay tránsito que leer', () {
      // Ofrecer una lectura aqui seria inventarsela: no hay carta natal contra
      // la que calcular nada.
      expect(allowsLocalReading(SkyTodayFailure.sinCartaNatal), isFalse);
      expect(allowsLocalReading(SkyTodayFailure.sinDatosDeNacimiento), isFalse);
      expect(allowsLocalReading(SkyTodayFailure.sesionExpirada), isFalse);
    });
  });

  group('el mensaje no filtra nada ni deja huecos', () {
    test('cada causa tiene su propio mensaje', () {
      final mensajes = SkyTodayFailure.values.map(skyFailureMessage).toSet();

      expect(
        mensajes.length,
        SkyTodayFailure.values.length,
        reason: 'dos causas con el mismo texto son un catch unico disfrazado',
      );
      for (final m in mensajes) {
        expect(m.trim(), isNotEmpty);
        expect(m, isNot(contains('DioException')));
        expect(m, isNot(contains('/astral')));
      }
    });
  });
}
