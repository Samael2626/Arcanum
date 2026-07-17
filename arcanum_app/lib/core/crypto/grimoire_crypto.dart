import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cifrado versionado del grimorio.
///
/// - v2: AES-256-GCM autenticado, para todas las escrituras nuevas.
/// - v1: AES-256-CBC legado, solo lectura para conservar entradas existentes.
///
/// La DEK permanece ligada al dispositivo en [FlutterSecureStorage]. El paso
/// siguiente será envolverla con una KEK derivada del PIN y desbloqueable con
/// biometría y Android Keystore.
class GrimoireCrypto {
  static const _dekKey = 'arcanum_grimoire_dek';
  static const _v2Prefix = 'v2:';
  static final Uint8List _v2AssociatedData = Uint8List.fromList(
    utf8.encode('arcanum-grimoire:v2'),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<enc.Key> _key() async {
    var b64 = await _storage.read(key: _dekKey);
    if (b64 == null) {
      b64 = enc.Key.fromSecureRandom(32).base64;
      await _storage.write(key: _dekKey, value: b64);
    }
    return enc.Key.fromBase64(b64);
  }

  Future<({String ciphertext, String iv})> encryptText(String plaintext) async {
    final encrypter = enc.Encrypter(
      enc.AES(await _key(), mode: enc.AESMode.gcm),
    );
    // 96 bits es el tamaño de nonce recomendado para GCM.
    final nonce = enc.IV.fromSecureRandom(12);
    final ciphertext = encrypter.encrypt(
      plaintext,
      iv: nonce,
      associatedData: _v2AssociatedData,
    );
    return (ciphertext: '$_v2Prefix${ciphertext.base64}', iv: nonce.base64);
  }

  Future<String> decryptText(String ciphertextB64, String ivB64) async {
    final key = await _key();
    if (ciphertextB64.startsWith(_v2Prefix)) {
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(
        enc.Encrypted.fromBase64(ciphertextB64.substring(_v2Prefix.length)),
        iv: enc.IV.fromBase64(ivB64),
        associatedData: _v2AssociatedData,
      );
    }

    final legacy = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return legacy.decrypt(
      enc.Encrypted.fromBase64(ciphertextB64),
      iv: enc.IV.fromBase64(ivB64),
    );
  }

  Future<void> clearLocalKey() => _storage.delete(key: _dekKey);
}

final grimoireCryptoProvider = Provider((ref) => GrimoireCrypto());
