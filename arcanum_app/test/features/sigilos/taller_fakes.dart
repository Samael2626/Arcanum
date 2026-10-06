// Piezas de mentira compartidas por los tests del taller: API, cifrado
// (base64) y la app envuelta con sus proveedores.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/astro/user_place.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'user-a'});
}

class FakeApi extends ArcanumApi {
  FakeApi() : super(Dio());
  final created = <Map<String, dynamic>>[], updated = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> detail = const {};

  /// Si no es null, el alta espera a que se complete (envio en curso).
  Completer<void>? hold;

  @override
  Future<Map<String, dynamic>> grimoireCreate(Map<String, dynamic> body) async {
    created.add(body);
    if (hold != null) await hold!.future;
    return {'id': 'sigilo-1'};
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
class FakeCrypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async => (ciphertext: base64Encode(utf8.encode(plaintext)), iv: 'iv');
  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async => utf8.decode(base64Decode(ciphertextB64));
}

Widget tallerApp(Widget child, FakeApi api) => ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(FakeAuth.new),
        grimoireCryptoProvider.overrideWithValue(FakeCrypto()),
        userPlaceProvider.overrideWithValue(null),
        // miniatura fija: rasterizar no termina con el reloj falso
        sigilPreviewProvider.overrideWithValue((_) async => Uint8List.fromList(const [137, 80, 78, 71])),
      ],
      child: MaterialApp(home: child),
    );

void phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

