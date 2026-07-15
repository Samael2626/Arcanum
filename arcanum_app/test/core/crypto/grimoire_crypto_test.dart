import 'dart:convert';
import 'dart:typed_data';

import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('v2 cifra y descifra con AES-GCM y nonce de 96 bits', () async {
    final crypto = GrimoireCrypto();

    final sealed = await crypto.encryptText('secreto del grimorio');

    expect(sealed.ciphertext, startsWith('v2:'));
    expect(base64Decode(sealed.iv), hasLength(12));
    expect(sealed.ciphertext, isNot(contains('secreto del grimorio')));
    expect(
      await crypto.decryptText(sealed.ciphertext, sealed.iv),
      'secreto del grimorio',
    );
  });

  test('v2 rechaza contenido alterado', () async {
    final crypto = GrimoireCrypto();
    final sealed = await crypto.encryptText('contenido autentico');
    final bytes = base64Decode(sealed.ciphertext.substring(3));
    bytes[0] ^= 1;
    final altered = 'v2:${base64Encode(bytes)}';

    expect(() => crypto.decryptText(altered, sealed.iv), throwsA(anything));
  });

  test('mantiene lectura de entradas legacy AES-CBC', () async {
    final keyBytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final key = enc.Key(keyBytes);
    const storage = FlutterSecureStorage();
    await storage.write(key: 'arcanum_grimoire_dek', value: key.base64);
    final iv = enc.IV(Uint8List.fromList(List<int>.generate(16, (i) => i + 1)));
    final legacy = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final ciphertext = legacy.encrypt('entrada anterior', iv: iv).base64;

    expect(
      await GrimoireCrypto().decryptText(ciphertext, iv.base64),
      'entrada anterior',
    );
  });
}
