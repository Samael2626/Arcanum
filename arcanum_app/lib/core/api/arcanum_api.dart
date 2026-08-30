import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

class IdempotencyKey {
  static final Random _random = Random.secure();

  static String create() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

bool isCreditsRequired(Object error) =>
    error is DioException && error.response?.statusCode == 402;

class ArcanumApi {
  ArcanumApi(this._dio);
  final Dio _dio;

  Options _idempotentOptions(String? key) =>
      Options(headers: {'Idempotency-Key': key ?? IdempotencyKey.create()});

  Future<Map<String, dynamic>> today({
    double lat = 4.71,
    double lon = -74.07,
  }) async {
    final res = await _dio.get(
      '/astral/today',
      queryParameters: {'lat': lat, 'lon': lon},
      options: Options(extra: const {'noAuth': true}),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> libraryWorks() async => (await _dio.get(
    '/library',
    options: Options(extra: const {'noAuth': true}),
  )).data.cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> libraryWork(String slug, {String? kind}) async =>
      (await _dio.get(
            '/library/$slug',
            queryParameters: {'kind': ?kind},
            options: Options(extra: const {'noAuth': true}),
          )).data
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> libraryChapter(
    String workSlug,
    String chapterSlug,
  ) async =>
      (await _dio.get(
            '/library/$workSlug/$chapterSlug',
            options: Options(extra: const {'noAuth': true}),
          )).data
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> natalChart() async =>
      (await _dio.post('/astral/natal-chart')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> transits() async =>
      (await _dio.get('/astral/transits')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> celestialOverview() async =>
      (await _dio.get('/astral/overview')).data as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async => (await _dio.get(
    '/materia',
    options: Options(extra: const {'noAuth': true}),
    queryParameters: {
      'item_type': ?itemType,
      'planet': ?planet,
      if (q != null && q.isNotEmpty) 'q': q,
    },
  )).data.cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> materiaDetail(String slug) async =>
      (await _dio.get(
            '/materia/$slug',
            options: Options(extra: const {'noAuth': true}),
          )).data
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> materiaBridge(String slug) async =>
      (await _dio.get(
            '/library/by-materia/$slug',
            options: Options(extra: const {'noAuth': true}),
          )).data
          as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> grimoireList() async =>
      (await _dio.get('/grimoire')).data.cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> grimoireGet(String id) async =>
      (await _dio.get('/grimoire/$id')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> grimoireCreate(
    Map<String, dynamic> body,
  ) async =>
      (await _dio.post('/grimoire', data: body)).data as Map<String, dynamic>;
  Future<void> grimoireDelete(String id) async => _dio.delete('/grimoire/$id');

  Future<Map<String, dynamic>> tarotDraw(
    String spread, {
    String? idempotencyKey,
  }) async =>
      (await _dio.post(
            '/oracle/tarot/draw',
            queryParameters: {'spread_type': spread},
            options: _idempotentOptions(idempotencyKey),
          )).data
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> oracleIa({
    String? question,
    String? divinationSessionId,
    String? idempotencyKey,
  }) async {
    final q = question?.trim();
    final res = await _dio.post(
      '/oracle/ia',
      data: {
        if (q != null && q.isNotEmpty) 'question': q,
        'divination_session_id': ?divinationSessionId,
      },
      options: _idempotentOptions(idempotencyKey),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> tarotList({
    String? arcana,
    String? suit,
  }) async => (await _dio.get(
    '/tarot/cards',
    queryParameters: {'arcana': ?arcana, 'suit': ?suit},
  )).data.cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> tarotCard(String slug) async =>
      (await _dio.get('/tarot/cards/$slug')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> tarotDrawOne({
    String? question,
    String? idempotencyKey,
  }) async =>
      (await _dio.post(
            '/tarot/draw-one',
            data: {'question': ?question},
            options: _idempotentOptions(idempotencyKey),
          )).data
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> tarotSpread({
    required String spreadType,
    String? question,
    String? idempotencyKey,
  }) async =>
      (await _dio.post(
            '/tarot/spread',
            data: {'spread_type': spreadType, 'question': ?question},
            options: _idempotentOptions(idempotencyKey),
          )).data
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> creditsBalance() async =>
      (await _dio.get('/credits/balance')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> geoResolve({
    required String country,
    required String city,
  }) async =>
      (await _dio.post(
            '/geo/resolve',
            data: {'country': country, 'city': city},
          )).data
          as Map<String, dynamic>;

  Future<void> createContentReport({
    required String source,
    required String contentRef,
    required String reason,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    await _dio.post(
      '/reports',
      data: {
        'source': source,
        'content_ref': contentRef,
        'reason': reason,
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      },
    );
  }

  Future<List<Map<String, dynamic>>> userConsents() async =>
      (await _dio.get('/consents')).data.cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> recordConsent({
    required String kind,
    required String policyVersion,
    required bool granted,
  }) async =>
      (await _dio.post(
            '/consents',
            data: {
              'kind': kind,
              'policy_version': policyVersion,
              'granted': granted,
            },
          )).data
          as Map<String, dynamic>;
}

final arcanumApiProvider = Provider((ref) => ArcanumApi(ref.read(dioProvider)));
