// Acceso, guardado y restauracion de Comparar en un telefono 390x844.
import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/compare_screen.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'user-a'});
}

class _Api extends ArcanumApi {
  _Api() : super(Dio());
  final created = <Map<String, dynamic>>[];
  Map<String, dynamic> detail = const {};
  @override
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    created.add(body);
    return {'id': 'compare-1'};
  }
  @override
  Future<Map<String, dynamic>> moon() async => {'phase_name': 'Creciente'};
  @override
  Future<Map<String, dynamic>> grimoireGet(String id) async => detail;
}

class _Crypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async =>
    (ciphertext: base64Encode(utf8.encode(plaintext)), iv: 'iv');
  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async =>
    utf8.decode(base64Decode(ciphertextB64));
}

Widget _app(Widget child, _Api api) => ProviderScope(overrides: [
  arcanumApiProvider.overrideWithValue(api), authProvider.overrideWith(_Auth.new),
  grimoireCryptoProvider.overrideWithValue(_Crypto()), userPlaceProvider.overrideWithValue(null),
], child: MaterialApp(home: child));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _show(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('el editor abre Comparar y cabe en 390x844', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const GrimorioEditor(), _Api()));
    await tester.tap(find.text('Sigilo'));
    await tester.pump();
    await tester.ensureVisible(find.text('Comparar tres sistemas'));
    await tester.tap(find.text('Comparar tres sistemas'));
    await tester.pumpAndSettle();
    expect(find.byType(CompareScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Samuel se guarda cifrado con titulo neutro', (tester) async {
    _phone(tester);
    final api = _Api();
    await tester.pumpWidget(_app(const CompareScreen(), api));
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await tester.tap(find.text('Comparar').first);
    await tester.pump();
    final state = tester.state<CompareScreenState>(find.byType(CompareScreen));
    expect(state.debugDoc.ready, isTrue);
    expect(state.debugDoc.rosa.hebrew, 'שמואל');
    await _show(tester, find.text('Guardar en el Grimorio'));
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final body = api.created.single;
    expect(body['entry_type'], 'sigil');
    expect(body['title'] as String, startsWith('Comparación de sigilos, '));
    expect(body['title'] as String, isNot(contains('Samuel')));
    final plain = utf8.decode(base64Decode(body['encrypted_content'] as String));
    expect(decodeCompareEntry(plain)!.name, 'Samuel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle restaura la lamina', (tester) async {
    _phone(tester);
    final doc = CompareDoc(day: 6)..generate('Samuel');
    final enc = await _Crypto().encryptText(encodeCompareEntry(doc));
    final api = _Api()..detail = {'id': 'compare-1', 'entry_type': 'sigil',
      'title': 'Comparación de sigilos, 5 de octubre', 'encrypted_content': enc.ciphertext,
      'content_iv': enc.iv, 'entry_date': '2026-10-05T10:00:00Z'};
    await tester.pumpWidget(_app(const GrimorioDetail(id: 'compare-1'), api));
    for (var i = 0; i < 4; i++) { await tester.pump(const Duration(milliseconds: 300)); }
    expect(find.text('Seguir la comparación'), findsOneWidget);
    await tester.ensureVisible(find.text('Seguir la comparación'));
    await tester.tap(find.text('Seguir la comparación'));
    await tester.pumpAndSettle();
    expect(tester.state<CompareScreenState>(find.byType(CompareScreen)).debugDoc.name, 'Samuel');
  });

  test('el detalle de Kamea oculta el rotulo del nombre y conserva el pie', () {
    final doc = KameaDoc(name: 'Samuel')..setName('Samuel');
    final source = doc.scene().fg.singleWhere((g) => g.layer == 'caption').prims!;
    final detail = kameaDetailScene(doc).fg.singleWhere((g) => g.layer == 'caption').prims!;
    expect((source.first as TextPrim).ch, 'Samuel');
    expect(detail.length, 1);
    expect((detail.single as TextPrim).ch, (source.last as TextPrim).ch);
  });
}
