import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/crypto/grimoire_crypto.dart';
import '../domain/reading_identity.dart';

abstract interface class ReadingIdentityStorage {
  Future<ReadingIdentityProfile?> load();
  Future<void> save(ReadingIdentityProfile profile);
  Future<void> delete();
}

class EncryptedReadingIdentityStorage implements ReadingIdentityStorage {
  static const ciphertextKey = 'arcanum_reading_identity_ciphertext_v1';
  static const nonceKey = 'arcanum_reading_identity_nonce_v1';

  final FlutterSecureStorage _storage;
  final GrimoireCrypto _crypto;

  EncryptedReadingIdentityStorage({
    FlutterSecureStorage? storage,
    GrimoireCrypto? crypto,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _crypto = crypto ?? GrimoireCrypto();

  @override
  Future<ReadingIdentityProfile?> load() async {
    final values = await Future.wait([
      _storage.read(key: ciphertextKey),
      _storage.read(key: nonceKey),
    ]);
    final ciphertext = values[0];
    final nonce = values[1];
    if (ciphertext == null && nonce == null) return null;
    if (ciphertext == null || nonce == null) {
      throw const FormatException('Perfil cifrado incompleto');
    }
    final plaintext = await _crypto.decryptText(ciphertext, nonce);
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Perfil cifrado invalido');
    }
    return ReadingIdentityProfile.fromJson(decoded);
  }

  @override
  Future<void> save(ReadingIdentityProfile profile) async {
    final sealed = await _crypto.encryptText(jsonEncode(profile.toJson()));
    await _storage.write(key: ciphertextKey, value: sealed.ciphertext);
    await _storage.write(key: nonceKey, value: sealed.iv);
  }

  @override
  Future<void> delete() async {
    await Future.wait([
      _storage.delete(key: ciphertextKey),
      _storage.delete(key: nonceKey),
    ]);
  }
}

class ReadingIdentityRepository {
  final ReadingIdentityStorage storage;

  const ReadingIdentityRepository(this.storage);

  Future<ReadingIdentityProfile?> load() => storage.load();
  Future<void> save(ReadingIdentityProfile profile) => storage.save(profile);
  Future<void> delete() => storage.delete();

  String exportLocal(ReadingIdentityProfile profile) =>
      const JsonEncoder.withIndent('  ').convert(profile.toJson());
}
