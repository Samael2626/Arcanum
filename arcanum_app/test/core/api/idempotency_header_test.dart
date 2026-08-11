import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que no sale a la red: guarda la peticion y responde 200.
class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'id': 'x', 'cards_drawn': {'cards': []}, 'resolved': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late ArcanumApi api;

  setUp(() {
    adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    api = ArcanumApi(dio);
  });

  String? headerOf(int i) =>
      adapter.requests[i].headers['Idempotency-Key'] as String?;

  test('las cuatro rutas de pago mandan Idempotency-Key', () async {
    await api.oracleIa(question: 'hola');
    await api.tarotDraw('three_card');
    await api.tarotDrawOne(question: 'hola');
    await api.tarotSpread(spreadType: 'three_card', question: 'hola');

    expect(adapter.requests.map((r) => r.path), [
      '/oracle/ia',
      '/oracle/tarot/draw',
      '/tarot/draw-one',
      '/tarot/spread',
    ]);
    for (var i = 0; i < 4; i++) {
      final key = headerOf(i);
      expect(key, isNotNull, reason: 'ruta ${adapter.requests[i].path} sin cabecera');
      expect(key, isNotEmpty);
    }
  });

  test('sin clave explicita el cliente genera una distinta por llamada', () async {
    await api.tarotDrawOne();
    await api.tarotDrawOne();
    expect(headerOf(0), isNot(headerOf(1)));
  });

  test('la clave que pasa la pantalla es la que viaja', () async {
    const key = 'clave-de-la-pantalla';
    await api.oracleIa(question: 'hola', idempotencyKey: key);
    await api.tarotSpread(spreadType: 'three_card', idempotencyKey: key);
    expect(headerOf(0), key);
    expect(headerOf(1), key);
  });

  test('IdempotencyKey.create genera UUIDv4 unicos', () {
    final keys = List.generate(50, (_) => IdempotencyKey.create());
    expect(keys.toSet(), hasLength(50));
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(keys.first),
      isTrue,
      reason: keys.first,
    );
  });
}
