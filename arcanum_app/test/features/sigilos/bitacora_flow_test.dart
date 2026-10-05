// El olvido deja una anotacion cifrada sin guardar el documento del sigilo.
import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/sigilos/bitacora_sheet.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ArcanumApi {
  _Api() : super(Dio());
  final created = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    created.add(body);
    return {'id': 'ritual-1'};
  }
  @override
  Future<Map<String, dynamic>> moon() async => {'phase_name': 'Creciente'};
}

class _Crypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async =>
    (ciphertext: base64Encode(utf8.encode(plaintext)), iv: 'iv');
}

Widget _app(_Api api) => ProviderScope(overrides: [
  arcanumApiProvider.overrideWithValue(api),
  grimoireCryptoProvider.overrideWithValue(_Crypto()),
  userPlaceProvider.overrideWithValue(null),
], child: const MaterialApp(home: Scaffold(body: TallerScreen())));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('crear, cargar, olvidar y anotar cifra solo la observacion', (tester) async {
    _phone(tester);
    final api = _Api();
    await tester.pumpWidget(_app(api));
    final state = tester.state<TallerScreenState>(find.byType(TallerScreen));
    await tester.enterText(find.byType(TextField).first, 'Mi intención secreta');
    await tester.tap(find.text('Forjar'));
    await tester.pump();
    expect(state.debugDoc.sigil.prims, isNotEmpty);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cargar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('respira a tu ritmo'), findsOneWidget);
    expect(find.text('SOSTÉN'), findsNothing);
    await tester.tap(find.text('Empezar'));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    await tester.tap(find.text('Olvidar'));
    await tester.pumpAndSettle();
    expect(find.byType(BitacoraSheet), findsOneWidget);
    expect(state.debugDoc.sigil.prims, isEmpty);
    expect(find.textContaining('Mi intención secreta'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'La respiración me ayudó a concentrarme.');
    await tester.tap(find.text('Guardar en la Bitácora'));
    await tester.pumpAndSettle();
    expect(api.created, hasLength(1));
    final body = api.created.single;
    expect(body['entry_type'], 'ritual');
    expect(body['title'] as String, startsWith('Práctica de sigilo, '));
    expect(body['title'] as String, isNot(contains('intención')));
    expect(utf8.decode(base64Decode(body['encrypted_content'] as String)), 'La respiración me ayudó a concentrarme.');
  });
}
