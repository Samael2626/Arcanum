import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/crypto/grimoire_crypto.dart';
import '../domain/table_state.dart';

/// Autoguardado de la mesa en el dispositivo, CIFRADO como el Grimorio.
///
/// La foto lleva la pregunta sellada y las cartas de una lectura en curso:
/// es tan privada como una entrada del Grimorio, asi que usa su mismo cifrado
/// (AES-256-GCM con la clave del dispositivo). En `SharedPreferences` solo
/// queda texto cifrado.
///
/// Una por usuario: al cambiar de cuenta en el mismo movil no se ve la mesa
/// del otro.
class TableStore {
  TableStore(this._crypto);

  static const _prefix = 'tarot_table_v1_';

  final GrimoireCrypto _crypto;

  String _key(String userId) => '$_prefix$userId';

  Future<void> save(String userId, TableState state) async {
    final sealed = await _crypto.encryptText(jsonEncode(state.toJson()));
    await (await SharedPreferences.getInstance()).setString(
      _key(userId),
      jsonEncode({'ciphertext': sealed.ciphertext, 'iv': sealed.iv}),
    );
  }

  /// La mesa guardada, o null si no hay, es de otra version o no se puede
  /// descifrar (por ejemplo, tras borrar la clave del dispositivo).
  Future<TableState?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      final box = jsonDecode(raw) as Map<String, dynamic>;
      final plain = await _crypto.decryptText(
        box['ciphertext'] as String,
        box['iv'] as String,
      );
      return TableState.fromJson(jsonDecode(plain) as Map<String, dynamic>);
    } on Object {
      // Ilegible: se descarta para no tropezar con ella en cada arranque
      await prefs.remove(_key(userId));
      return null;
    }
  }

  Future<void> clear(String userId) async =>
      (await SharedPreferences.getInstance()).remove(_key(userId));
}

final tableStoreProvider = Provider(
  (ref) => TableStore(ref.read(grimoireCryptoProvider)),
);

/// Borra las mesas guardadas de todos los usuarios de este dispositivo.
Future<void> clearTarotLocalData() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().where(
    (k) => k.startsWith(TableStore._prefix),
  )) {
    await prefs.remove(key);
  }
}
