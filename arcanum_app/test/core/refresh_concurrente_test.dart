/// Que pasa cuando caducan el token y salen varias peticiones a la vez.
///
/// El backend ROTA el refresh: `rotate_refresh_token` BORRA el viejo al emitir
/// el nuevo. Asi que un refresco con un token ya gastado devuelve None, y el
/// cliente responde limpiando la sesion. La pregunta es si eso puede pasar con
/// varias peticiones en vuelo — que es justo lo que ocurre al abrir la app
/// despues de 15 minutos.
///
/// Este test NO da por buena ninguna hipotesis: reproduce el escenario y mira.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';
import 'package:arcanum_app/core/network/dio_client.dart';

/// Servidor de mentira que se comporta como el real: rota el refresh y rechaza
/// el que ya se gasto.
class _Servidor implements HttpClientAdapter {
  _Servidor();

  String refreshValido = 'R1';
  int contador = 1;
  int refrescos = 0;
  int rechazos = 0;
  final List<String> accesosVistos = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _,
      Future<void>? cancelar) async {
    if (options.path.contains('/auth/refresh')) {
      refrescos++;
      final enviado = (options.data as Map)['refresh_token'] as String;
      if (enviado != refreshValido) {
        // Token ya rotado: el backend real devuelve 401 aqui.
        rechazos++;
        return ResponseBody.fromString('{"detail":"invalido"}', 401,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
      }
      contador++;
      refreshValido = 'R$contador';
      return ResponseBody.fromString(
        '{"access_token":"A$contador","refresh_token":"R$contador"}', 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }

    final auth = options.headers['Authorization'] as String? ?? '';
    accesosVistos.add(auth);
    // Solo el acceso mas reciente vale. El viejo (A1) esta caducado.
    if (auth == 'Bearer A1' || auth.isEmpty) {
      return ResponseBody.fromString('{"detail":"caducado"}', 401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return ResponseBody.fromString('{"ok":true}', 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

/// Almacen en memoria: el plugin de almacenamiento seguro no existe en un test
/// de Dart puro, y depender de el solo anadiria una fuente de fallo ajena a lo
/// que aqui se quiere medir.
class _Memoria extends TokenStorage {
  String? _a = "A1";
  String? _r = "R1";
  bool limpiada = false;

  @override
  Future<String?> get access async => _a;
  @override
  Future<String?> get refresh async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }
  @override
  Future<void> setAccess(String access) async => _a = access;
  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
    limpiada = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tres peticiones a la vez con el token caducado', () async {
    final storage = _Memoria();
    final servidor = _Servidor();
    // El mismo adaptador para las dos: el Dio normal y el desnudo del refresco.
    final desnudo = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = servidor;
    final dio = buildDio(storage, refreshDio: desnudo);
    dio.httpClientAdapter = servidor;

    final resultados = await Future.wait([
      dio.get('/uno').then((r) => r.statusCode).catchError((Object e) {
        // ignore: avoid_print
        print('uno fallo: $e');
        return -1;
      }),
      dio.get('/dos').then((r) => r.statusCode).catchError((Object e) {
        // ignore: avoid_print
        print('dos fallo: $e');
        return -1;
      }),
      dio.get('/tres').then((r) => r.statusCode).catchError((Object e) {
        // ignore: avoid_print
        print('tres fallo: $e');
        return -1;
      }),
    ]);

    // Lo que de verdad importa: la sesion NO puede quedar cerrada.
    final quedaSesion = !storage.limpiada && (await storage.access) != null;

    // ignore: avoid_print
    print('resultados=$resultados refrescos=${servidor.refrescos} '
        'rechazos=${servidor.rechazos} sesion=$quedaSesion');

    expect(resultados.every((c) => c == 200), isTrue,
        reason: 'alguna peticion fallo: $resultados');
    expect(quedaSesion, isTrue, reason: 'la sesion se cerro sola');
  });

  test('un refresh ya invalido cierra la sesion limpiamente', () async {
    final storage = _Memoria().._r = 'CADUCADO';
    final servidor = _Servidor();
    final desnudo = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = servidor;
    final dio = buildDio(storage, refreshDio: desnudo);
    dio.httpClientAdapter = servidor;

    await expectLater(dio.get('/uno'), throwsA(isA<DioException>()));

    // Lo correcto cuando el refresh de verdad ya no vale: limpiar y propagar,
    // no reintentar en bucle ni dejar la sesion a medias.
    expect(servidor.rechazos, 1);
    expect(storage.limpiada, isTrue);
    expect(await storage.access, isNull);
  });

  test('sin refresh guardado ni siquiera lo intenta', () async {
    final storage = _Memoria()
      .._r = null
      .._a = 'A1';
    final servidor = _Servidor();
    final desnudo = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = servidor;
    final dio = buildDio(storage, refreshDio: desnudo);
    dio.httpClientAdapter = servidor;

    await expectLater(dio.get('/uno'), throwsA(isA<DioException>()));
    expect(servidor.refrescos, 0);
  });

  test('una sola peticion refresca una sola vez', () async {
    final storage = _Memoria();
    final servidor = _Servidor();
    final desnudo = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = servidor;
    final dio = buildDio(storage, refreshDio: desnudo);
    dio.httpClientAdapter = servidor;

    final r = await dio.get('/uno');
    expect(r.statusCode, 200);
    expect(servidor.refrescos, 1);
    // Y no reintenta en bucle: el guardia `retried` existe para esto.
    expect(servidor.accesosVistos.length, 2);
  });
}
