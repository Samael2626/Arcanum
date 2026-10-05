// Pantalla de la Rosa-Cruz: trazar un nombre sobre el Lamen, guardar cifrado
// sin el nombre en el titulo, y la entrada vista desde el Grimorio.
import 'dart:convert';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/rosa_screen.dart';
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
    return {'id': 'rosa-1'};
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

Future<RosaScreenState> _abrir(WidgetTester tester, _FakeApi api) async {
  _phone(tester);
  await tester.pumpWidget(_app(const RosaScreen(), api));
  return tester.state<RosaScreenState>(find.byType(RosaScreen));
}

/// Lleva el control a la zona visible de la lista del panel.
Future<void> _ver(WidgetTester t, Finder f, {double delta = 200}) async {
  await t.scrollUntilVisible(f, delta, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

Future<void> _trazar(WidgetTester tester, String nombre) async {
  await tester.enterText(find.byType(TextField).first, nombre);
  await _ver(tester, find.text('Trazar sobre el Lamen'));
  await tester.tap(find.text('Trazar sobre el Lamen'));
  await tester.pump();
}

void main() {
  testWidgets('sin nombre el Lamen queda sin trazo y se pide un nombre', (tester) async {
    await _abrir(tester, _FakeApi());
    expect(find.textContaining('Escribe un nombre y pulsa'), findsOneWidget);
  });

  testWidgets('un nombre se transcribe al hebreo y se traza igual que el motor', (tester) async {
    final st = await _abrir(tester, _FakeApi());
    await _trazar(tester, 'Metatron');
    expect(find.textContaining('Escribe un nombre y pulsa'), findsNothing);
    expect(st.debugDoc.hebrew, 'מטטרון');
    expect(st.debugDoc.buildSVG(), (RosaDoc()..setName('Metatron')).buildSVG());
  });

  testWidgets('la lectura da el recorrido, la gematria y las marcas de Metatron', (tester) async {
    await _abrir(tester, _FakeApi());
    await _trazar(tester, 'Metatron');
    await _ver(tester, find.textContaining('(estándar)'));
    expect(find.textContaining('964 (mayor'), findsOneWidget);
    expect(find.textContaining('מ Agua → ט Leo → ר Sol → ו Tauro → נ Escorpio'), findsOneWidget);
    expect(find.textContaining('quiebro en ט (Tet, 2 veces seguidas)'), findsOneWidget);
  });

  testWidgets('editar el hebreo retraza y los interruptores cambian el dibujo', (tester) async {
    final st = await _abrir(tester, _FakeApi());
    await _trazar(tester, 'Metatron');
    await _ver(tester, find.byType(TextField).at(1), delta: -200);
    await tester.enterText(find.byType(TextField).at(1), 'שדי');
    await tester.pump();
    expect(st.debugDoc.hebrew, 'שדי');
    expect(st.debugDoc.trace.length, 3);
    final base = st.debugDoc.buildSVG();
    await _ver(tester, find.text('Colores de las letras'));
    await tester.tap(find.text('Colores de las letras'));
    await tester.pump();
    expect(st.debugDoc.colors, isTrue);
    expect(st.debugDoc.buildSVG(), isNot(base));
    await _ver(tester, find.text('Ver el Lamen'), delta: -200);
    await tester.tap(find.text('Ver el Lamen'));
    await tester.pump();
    expect(st.debugDoc.diagram, isFalse);
    expect(st.debugDoc.buildSVG(), isNot(contains('rose-diagram')));
  });

  testWidgets('guardar cifra el documento y el titulo no lleva el nombre', (tester) async {
    final api = _FakeApi();
    final st = await _abrir(tester, api);
    await _trazar(tester, 'Metatron');
    await _ver(tester, find.text('Guardar en el Grimorio'));
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final body = api.created.single;
    expect(body['entry_type'], 'sigil');
    expect(body['title'] as String, startsWith('Rosa-Cruz, '));
    expect((body['title'] as String).toLowerCase(), isNot(contains('metatron')));
    final plain = utf8.decode(base64Decode(body['encrypted_content'] as String));
    expect(decodeSigilEntry(plain), isNull);
    expect(decodeKameaEntry(plain), isNull);
    final doc = decodeRosaEntry(plain)!;
    expect(doc.name, 'Metatron');
    expect(doc.buildSVG(), st.debugDoc.buildSVG());
    // guardar otra vez reescribe la misma entrada
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _ver(tester, find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(api.updated.single.$1, 'rosa-1');
    expect(api.created, hasLength(1));
  });

  testWidgets('con cambios sin guardar, cerrar pregunta antes de salir', (tester) async {
    await _abrir(tester, _FakeApi());
    await _trazar(tester, 'Samuel');
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(find.byType(RosaScreen), findsOneWidget);
  });

  testWidgets('en el editor del Grimorio, «Sigilo» ofrece abrir una Rosa-Cruz', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const GrimorioEditor(), _FakeApi()));
    await tester.tap(find.text('Sigilo'));
    await tester.pump();
    expect(find.text('Abrir una Rosa-Cruz'), findsOneWidget);
    await tester.ensureVisible(find.text('Abrir una Rosa-Cruz'));
    await tester.tap(find.text('Abrir una Rosa-Cruz'));
    await tester.pumpAndSettle();
    expect(find.byType(RosaScreen), findsOneWidget);
  });

  testWidgets('el detalle dibuja la Rosa-Cruz y deja seguir editandola', (tester) async {
    _phone(tester);
    final doc = RosaDoc()..setName('Metatron');
    final enc = await _FakeCrypto().encryptText(encodeRosaEntry(doc));
    final api = _FakeApi()
      ..detail = {'id': 'rosa-1', 'entry_type': 'sigil', 'title': 'Rosa-Cruz, 5 de octubre', 'encrypted_content': enc.ciphertext, 'content_iv': enc.iv, 'moon_phase': 'Creciente', 'entry_date': '2026-10-05T10:00:00Z'};
    await tester.pumpWidget(_app(const GrimorioDetail(id: 'rosa-1'), api));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Seguir en la Rosa-Cruz'), findsOneWidget);
    expect(find.text('Seguir en el taller'), findsNothing);
    expect(find.textContaining('Metatron'), findsNothing);
    await tester.ensureVisible(find.text('Seguir en la Rosa-Cruz'));
    await tester.tap(find.text('Seguir en la Rosa-Cruz'));
    await tester.pumpAndSettle();
    final st = tester.state<RosaScreenState>(find.byType(RosaScreen));
    expect(st.debugDoc.hebrew, 'מטטרון');
    expect(st.debugDoc.name, 'Metatron');
  });

  test('una Rosa-Cruz, una kamea y un sigilo de letras no se confunden al leerse', () {
    final r = encodeRosaEntry(RosaDoc()..setName('Samuel'));
    final k = encodeKameaEntry(KameaDoc(hebrew: 'אגיאל'));
    final s = encodeSigilEntry(SigilDoc()..generate('Quiero paz'));
    for (final other in [k, s]) {
      expect(decodeRosaEntry(other), isNull);
    }
    expect(decodeSigilEntry(r), isNull);
    expect(decodeKameaEntry(r), isNull);
    expect(decodeRosaEntry('Dibujé el Lamen a mano.'), isNull);
    expect(decodeRosaEntry('{"taller":"sigilo-rosa","doc":{"v":99}}'), isNull);
  });
}
