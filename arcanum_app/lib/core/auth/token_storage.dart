import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda access/refresh tokens en almacenamiento seguro
/// (Keychain iOS / Keystore Android; en web usa cripto del navegador).
class TokenStorage {
  static const _kAccess = 'arcanum_access';
  static const _kRefresh = 'arcanum_refresh';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<String?> get access => _storage.read(key: _kAccess);
  Future<String?> get refresh => _storage.read(key: _kRefresh);

  Future<void> setAccess(String access) => _storage.write(key: _kAccess, value: access);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
