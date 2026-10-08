// Entrada, guardado y restauracion del sello personal en un telefono 390x844.
import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/sigilos/personal_screen.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_app/shared/widgets/gold_button.dart';
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
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async { created.add(body); return {'id': 'personal-1'}; }
  @override
  Future<Map<String, dynamic>> moon() async => {'phase_name': 'Creciente'};
  @override
  Future<Map<String, dynamic>> grimoireGet(String id) async => detail;
}

class _Crypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async => (ciphertext: base64Encode(utf8.encode(plaintext)), iv: 'iv');
  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async => utf8.decode(base64Decode(ciphertextB64));
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
  testWidgets('editar el nombre exige volver a trazar antes de guardar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const PersonalScreen(), _Api()));
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await tester.tap(find.text('Trazar figura'));
    await tester.pump();
    final save = find.widgetWithText(GoldButton, 'Guardar en el Grimorio');
    expect(tester.widget<GoldButton>(save).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).first, 'Gabriel');
    await tester.pump();
    expect(tester.widget<GoldButton>(save).onPressed, isNull);
    expect(find.textContaining('Vuelve a trazar'), findsOneWidget);
    await tester.tap(find.text('Trazar figura'));
    await tester.pump();
    expect(tester.widget<GoldButton>(save).onPressed, isNotNull);
  });
  testWidgets('el editor ofrece el sello y la pantalla cabe en 390x844', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const GrimorioEditor(), _Api()));
    await tester.tap(find.text('Sigilo'));
    await tester.pump();
    await tester.ensureVisible(find.text('Crear sello personal'));
    await tester.tap(find.text('Crear sello personal'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Samuel: fuente y planeta cambian; la kamea impone su tabla', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const PersonalScreen(), _Api()));
    final state = tester.state<PersonalScreenState>(find.byType(PersonalScreen));
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await tester.tap(find.text('Trazar figura'));
    await tester.pump();
    expect(state.debugDoc.ready, isTrue);
    expect(state.debugDoc.buildSVG(), contains('No es un sello histórico'));
    await _show(tester, find.text('Rosa-Cruz'));
    await tester.tap(find.text('Rosa-Cruz'));
    await tester.pump();
    expect(state.debugDoc.rosa.hebrew, 'שמואל');
    await tester.tap(find.text('Kamea'));
    await tester.pump();
    await _show(tester, find.text('Marte'));
    await tester.tap(find.text('Marte'));
    await tester.pump();
    expect(state.debugDoc.planet, 'mars');
    expect(state.debugDoc.buildSVG(), contains('metal: hierro'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar cifra el documento y no pone Samuel en el titulo', (tester) async {
    _phone(tester);
    final api = _Api();
    await tester.pumpWidget(_app(const PersonalScreen(), api));
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await tester.tap(find.text('Trazar figura'));
    await tester.pump();
    await _show(tester, find.text('Guardar en el Grimorio'));
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final body = api.created.single;
    expect(body['entry_type'], 'sigil');
    expect(body['title'] as String, startsWith('Sello personal, '));
    expect(body['title'] as String, isNot(contains('Samuel')));
    final plain = utf8.decode(base64Decode(body['encrypted_content'] as String));
    expect(decodePersonalEntry(plain)!.displayedName, 'Samuel');
    expect(decodeSigilEntry(plain), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle restaura y deja seguir editando el sello', (tester) async {
    _phone(tester);
    final doc = PersonalDoc();
    doc.letters.sigil.method = ReductionMethod.unique;
    doc.letters.generate('Samuel');
    doc.name = 'Samuel';
    final enc = await _Crypto().encryptText(encodePersonalEntry(doc));
    final api = _Api()..detail = {'id': 'personal-1', 'entry_type': 'sigil', 'title': 'Sello personal, 5 de octubre',
      'encrypted_content': enc.ciphertext, 'content_iv': enc.iv, 'moon_phase': 'Creciente', 'entry_date': '2026-10-05T10:00:00Z'};
    await tester.pumpWidget(_app(const GrimorioDetail(id: 'personal-1'), api));
    for (var i = 0; i < 4; i++) { await tester.pump(const Duration(milliseconds: 300)); }
    expect(find.text('Seguir el sello personal'), findsOneWidget);
    expect(find.textContaining('Samuel'), findsNothing);
    await tester.ensureVisible(find.text('Seguir el sello personal'));
    await tester.tap(find.text('Seguir el sello personal'));
    await tester.pumpAndSettle();
    final state = tester.state<PersonalScreenState>(find.byType(PersonalScreen));
    expect(state.debugDoc.displayedName, 'Samuel');
  });
}
