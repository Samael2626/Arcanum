import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cifrado del grimorio (AES-256-CBC). El contenido se cifra en el dispositivo;
/// el servidor solo guarda el ciphertext + IV.
///
/// MVP: la DEK (clave de cifrado de datos) se genera una vez y se guarda en
/// `flutter_secure_storage` (ligada al dispositivo). Endurecimiento pendiente
/// (reto #2): envolver la DEK con una KEK derivada de la contraseña (PBKDF2)
/// para sobrevivir cambios de dispositivo/contraseña.
class GrimoireCrypto {
  static const _dekKey = 'arcanum_grimoire_dek';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<enc.Encrypter> _encrypter() async {
    var b64 = await _storage.read(key: _dekKey);
    if (b64 == null) {
      b64 = enc.Key.fromSecureRandom(32).base64;
      await _storage.write(key: _dekKey, value: b64);
    }
    return enc.Encrypter(enc.AES(enc.Key.fromBase64(b64), mode: enc.AESMode.cbc));
  }

  Future<({String ciphertext, String iv})> encryptText(String plaintext) async {
    final encrypter = await _encrypter();
    final iv = enc.IV.fromSecureRandom(16);
    final ct = encrypter.encrypt(plaintext, iv: iv);
    return (ciphertext: ct.base64, iv: iv.base64);
  }

  Future<String> decryptText(String ciphertextB64, String ivB64) async {
    final encrypter = await _encrypter();
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(ciphertextB64),
      iv: enc.IV.fromBase64(ivB64),
    );
  }
}

final grimoireCryptoProvider = Provider((ref) => GrimoireCrypto());
