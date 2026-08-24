import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConsentAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.method == 'GET' ? '[]' : jsonEncode(options.data);
    return ResponseBody.fromString(
      body,
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
  test('GET y POST usan el contrato probatorio de consentimientos', () async {
    final adapter = _ConsentAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    final api = ArcanumApi(dio);

    await api.userConsents();
    await api.recordConsent(
      kind: 'datos_sensibles',
      policyVersion: 'datos-sensibles-v1',
      granted: true,
    );

    expect(adapter.requests.map((request) => request.path), [
      '/consents',
      '/consents',
    ]);
    expect(adapter.requests.last.data, {
      'kind': 'datos_sensibles',
      'policy_version': 'datos-sensibles-v1',
      'granted': true,
    });
  });
}
