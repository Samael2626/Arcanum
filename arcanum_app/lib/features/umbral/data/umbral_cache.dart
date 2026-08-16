import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/crypto/grimoire_crypto.dart';

/// Caché cifrado de la última lectura recibida.
///
/// Va cifrado porque la lectura lleva dentro signos y casas natales: es un
/// derivado de la fecha, hora y lugar de nacimiento, y guardarlo en claro
/// convertiría el caché en la copia sin candado de lo que el Grimorio sí
/// protege.
abstract interface class UmbralCache {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> contract);
  Future<void> clear();
}

class EncryptedUmbralCache implements UmbralCache {
  static const ciphertextKey = 'arcanum_umbral_reading_ciphertext_v1';
  static const nonceKey = 'arcanum_umbral_reading_nonce_v1';

  final FlutterSecureStorage _storage;
  final GrimoireCrypto _crypto;

  EncryptedUmbralCache({FlutterSecureStorage? storage, GrimoireCrypto? crypto})
    : _storage = storage ?? const FlutterSecureStorage(),
      _crypto = crypto ?? GrimoireCrypto();

  @override
  Future<Map<String, dynamic>?> load() async {
    final values = await Future.wait([
      _storage.read(key: ciphertextKey),
      _storage.read(key: nonceKey),
    ]);
    final ciphertext = values[0];
    final nonce = values[1];
    if (ciphertext == null || nonce == null) return null;
    try {
      final decoded = jsonDecode(await _crypto.decryptText(ciphertext, nonce));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      // Un caché ilegible no es motivo para dejar la pantalla rota: se olvida.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> contract) async {
    final sealed = await _crypto.encryptText(jsonEncode(contract));
    await _storage.write(key: ciphertextKey, value: sealed.ciphertext);
    await _storage.write(key: nonceKey, value: sealed.iv);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: ciphertextKey),
      _storage.delete(key: nonceKey),
    ]);
  }
}

final umbralCacheProvider = Provider<UmbralCache>(
  (ref) => EncryptedUmbralCache(),
);
