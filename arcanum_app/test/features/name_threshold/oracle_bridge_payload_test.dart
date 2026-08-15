import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/name_threshold/domain/name_resonance.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que no sale a la red: guarda la peticion y responde 200.
class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'messages': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ReadingIdentityProfile _profile({
  required String givenName,
  String? surname,
}) {
  final now = DateTime.utc(2026, 8, 15);
  return ReadingIdentityProfile(
    parts: [
      ReadingNamePart(
        id: 'given',
        type: NamePartType.givenName,
        originalText: givenName,
        dialect: ReadingDialect.latinAmerica,
        createdAt: now,
      ),
      if (surname != null)
        ReadingNamePart(
          id: 'surname',
          type: NamePartType.surname,
          originalText: surname,
          dialect: ReadingDialect.latinAmerica,
          createdAt: now,
        ),
    ],
    createdAt: now,
    updatedAt: now,
  );
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

  Map<String, dynamic> bodyOf(int index) =>
      adapter.requests[index].data as Map<String, dynamic>;

  test('con el puente apagado la pregunta viaja literal', () async {
    await api.oracleIa(
      question: NameResonance.composeOracleQuestion('¿Qué suelto?', null),
      divinationSessionId: 'sesion-1',
    );
    expect(bodyOf(0)['question'], '¿Qué suelto?');
  });

  test('el cuerpo real solo lleva la frase del catalogo', () async {
    final resonance = NameResonance.fromProfile(
      _profile(givenName: 'Adán', surname: 'ApellidoCanario'),
    );
    await api.oracleIa(
      question: NameResonance.composeOracleQuestion('¿Qué suelto?', resonance),
      divinationSessionId: 'sesion-1',
    );

    final body = bodyOf(0);
    // Ni un campo nuevo: el puente cabalga la pregunta que ya existia.
    expect(body.keys.toSet(), {'question', 'divination_session_id'});

    final question = body['question'] as String;
    expect(question, startsWith('¿Qué suelto?'));
    expect(question, contains('Humano, hombre.'));

    // Lo que jamas cruza.
    expect(question, isNot(contains('Adán')));
    expect(question, isNot(contains('Adan')));
    expect(question, isNot(contains('ApellidoCanario')));
    expect(question, isNot(contains('אדם')));
    expect(question, isNot(contains('45')));
    expect(question, isNot(contains('latinAmerica')));

    // Y el texto entero es exactamente el previsto, sin margen.
    expect(
      question,
      '¿Qué suelto?\n\n'
      'Resonancia simbolica elegida por quien consulta: Humano, hombre. '
      'Acompana la lectura como eco; no afirma rasgos, destino ni caracter.',
    );
  });

  test('un nombre sin ficha no publica nada', () async {
    final resonance = NameResonance.fromProfile(
      _profile(givenName: 'NombreCanarioSinFicha'),
    );
    expect(resonance, isNotNull);
    expect(resonance!.oracleClause, isNull);

    await api.oracleIa(
      question: NameResonance.composeOracleQuestion('¿Qué suelto?', resonance),
      divinationSessionId: 'sesion-1',
    );
    final question = bodyOf(0)['question'] as String;
    expect(question, '¿Qué suelto?');
    expect(question, isNot(contains('NombreCanarioSinFicha')));
  });

  test('sin pregunta la resonancia no viaja sola', () async {
    final resonance = NameResonance.fromProfile(_profile(givenName: 'Adán'));
    final composed = NameResonance.composeOracleQuestion('', resonance);
    expect(composed, isEmpty);

    await api.oracleIa(
      question: composed.isEmpty ? null : composed,
      divinationSessionId: 'sesion-1',
    );
    expect(bodyOf(0).keys.toSet(), {'divination_session_id'});
  });
}
