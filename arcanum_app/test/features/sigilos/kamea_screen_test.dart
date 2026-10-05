// Pantalla de la Kamea: trazar un nombre, guardar cifrado sin el nombre en el
// titulo, y la entrada vista desde el Grimorio (editor y detalle).
import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/kamea_screen.dart';
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

class _FakeApi extends ArcanumApi {
  _FakeApi() : super(Dio());
  final created = <Map<String, dynamic>>[], updated = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> detail = const {};

  @override
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    created.add(body);
    return {'id': 'kamea-1'};
  }

  @override
  Future<Map<String, dynamic>> grimoireUpdate(String id, Map<String, dynamic> body) async {
    updated.add((id, body));
    return {'id': id};
  }

  @override
  Future<Map<String, dynamic>> grimoireGet(String id) async => detail;

  @override
  Future<Map<String, dynamic>> moon() async => {'phase_name': 'Creciente'};
}

/// Cifrado de mentira: base64 (el de verdad tiene sus propios tests).
class _FakeCrypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async => (ciphertext: base64Encode(utf8.encode(plaintext)), iv: 'iv');
  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async => utf8.decode(base64Decode(ciphertextB64));
}

Widget _app(Widget child, _FakeApi api) => ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_Auth.new),
        grimoireCryptoProvider.overrideWithValue(_FakeCrypto()),
        userPlaceProvider.overrideWithValue(null),
      ],
      child: MaterialApp(home: child),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<KameaScreenState> _abrir(WidgetTester tester, _FakeApi api) async {
  _phone(tester);
  await tester.pumpWidget(_app(const KameaScreen(), api));
  return tester.state<KameaScreenState>(find.byType(KameaScreen));
}

/// Lleva el control a la zona visible de la lista del panel.
Future<void> _ver(WidgetTester t, Finder f, {double delta = 200}) async {
  await t.scrollUntilVisible(f, delta, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('sin nombre la tabla queda vacia y se pide un nombre', (tester) async {
    await _abrir(tester, _FakeApi());
    expect(find.text('Escribe un nombre o elige uno de los de Agrippa.'), findsOneWidget);
  });

  testWidgets('un nombre de Agrippa traza igual que el motor (Agiel sobre Saturno)', (tester) async {
    final st = await _abrir(tester, _FakeApi());
    await _ver(tester, find.text('Inteligencia: Agiel'));
    await tester.tap(find.text('Inteligencia: Agiel'));
    await tester.pump();
    expect(find.text('Escribe un nombre o elige uno de los de Agrippa.'), findsNothing);
    expect(st.debugDoc.hebrew, 'אגיאל');
    final ref = KameaDoc(hebrew: 'אגיאל', name: 'Agiel');
    expect(st.debugDoc.buildSVG(), ref.buildSVG());
  });

  testWidgets('un nombre propio se transcribe al hebreo y cambiar de tabla cambia el trazo', (tester) async {
    final st = await _abrir(tester, _FakeApi());
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await _ver(tester, find.text('Trazar sobre la tabla'));
    await tester.tap(find.text('Trazar sobre la tabla'));
    await tester.pump();
    expect(st.debugDoc.hebrew, 'שמואל');
    final saturno = st.debugDoc.buildSVG();
    await _ver(tester, find.textContaining('Luna'), delta: -200);
    await tester.tap(find.textContaining('Luna').first);
    await tester.pump();
    expect(st.debugDoc.planet, 'moon');
    expect(st.debugDoc.buildSVG(), isNot(saturno));
  });

  testWidgets('guardar cifra el documento y el titulo nombra la tabla, no el nombre', (tester) async {
    final api = _FakeApi();
    final st = await _abrir(tester, api);
    await tester.enterText(find.byType(TextField).first, 'Samuel');
    await _ver(tester, find.text('Trazar sobre la tabla'));
    await tester.tap(find.text('Trazar sobre la tabla'));
    await tester.pump();
    await _ver(tester, find.text('Guardar en el Grimorio'));
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final body = api.created.single;
    expect(body['entry_type'], 'sigil');
    expect(body['title'] as String, startsWith('Kamea de Saturno, '));
    expect((body['title'] as String).toLowerCase(), isNot(contains('samuel')));
    expect(body['moon_phase'], 'Creciente');
    final plain = utf8.decode(base64Decode(body['encrypted_content'] as String));
    expect(decodeSigilEntry(plain), isNull);
    final doc = decodeKameaEntry(plain)!;
    expect(doc.name, 'Samuel');
    expect(doc.buildSVG(), st.debugDoc.buildSVG());
    // guardar otra vez reescribe la misma entrada
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _ver(tester, find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(api.updated.single.$1, 'kamea-1');
    expect(api.created, hasLength(1));
  });

  testWidgets('con cambios sin guardar, cerrar pregunta antes de salir', (tester) async {
    await _abrir(tester, _FakeApi());
    await _ver(tester, find.text('Inteligencia: Agiel'));
    await tester.tap(find.text('Inteligencia: Agiel'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(find.byType(KameaScreen), findsOneWidget);
  });

  testWidgets('en el editor del Grimorio, «Sigilo» ofrece abrir una kamea', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const GrimorioEditor(), _FakeApi()));
    await tester.tap(find.text('Sigilo'));
    await tester.pump();
    expect(find.text('Abrir una kamea'), findsOneWidget);
    await tester.tap(find.text('Abrir una kamea'));
    await tester.pumpAndSettle();
    expect(find.byType(KameaScreen), findsOneWidget);
  });

  testWidgets('el detalle dibuja la kamea y deja seguir editandola', (tester) async {
    _phone(tester);
    final doc = KameaDoc(planet: 'venus', hebrew: 'קדמאל', name: 'Kedemel');
    final enc = await _FakeCrypto().encryptText(encodeKameaEntry(doc));
    final api = _FakeApi()
      ..detail = {'id': 'kamea-1', 'entry_type': 'sigil', 'title': 'Kamea de Venus, 4 de octubre', 'encrypted_content': enc.ciphertext, 'content_iv': enc.iv, 'moon_phase': 'Creciente', 'entry_date': '2026-10-04T10:00:00Z'};
    await tester.pumpWidget(_app(const GrimorioDetail(id: 'kamea-1'), api));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Seguir en la kamea'), findsOneWidget);
    expect(find.text('Seguir en el taller'), findsNothing);
    await tester.ensureVisible(find.text('Seguir en la kamea'));
    await tester.tap(find.text('Seguir en la kamea'));
    await tester.pumpAndSettle();
    final st = tester.state<KameaScreenState>(find.byType(KameaScreen));
    expect(st.debugDoc.planet, 'venus');
    expect(st.debugDoc.hebrew, 'קדמאל');
  });

  test('una kamea y un sigilo de letras no se confunden al leerse', () {
    final k = encodeKameaEntry(KameaDoc(hebrew: 'אגיאל'));
    final s = encodeSigilEntry(SigilEntry(SigilDoc()..generate('Quiero paz')));
    expect(decodeSigilEntry(k), isNull);
    expect(decodeKameaEntry(s), isNull);
    expect(decodeKameaEntry('Dibujé una tabla a mano.'), isNull);
    expect(decodeKameaEntry('{"taller":"sigilo-kamea","doc":{"v":99}}'), isNull);
  });
}
