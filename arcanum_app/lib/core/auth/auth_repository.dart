import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Datos de registro (incluye natales para poder calcular la carta).
class RegisterData {
  final String email;
  final String password;
  final String? displayName;
  final String? birthDate; // ISO: 2000-06-15T00:00:00
  final String? birthTime; // ISO: 2000-06-15T14:30:00
  final String? birthLat;
  final String? birthLon;
  final String? birthTimezone;

  const RegisterData({
    required this.email,
    required this.password,
    this.displayName,
    this.birthDate,
    this.birthTime,
    this.birthLat,
    this.birthLon,
    this.birthTimezone,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
        if (birthDate != null) 'birth_date': birthDate,
        if (birthTime != null) 'birth_time': birthTime,
        if (birthLat != null) 'birth_lat': birthLat,
        if (birthLon != null) 'birth_lon': birthLon,
        if (birthTimezone != null) 'birth_timezone': birthTimezone,
      };
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final TokenStorage _storage;

  Future<void> register(RegisterData data) async {
    try {
      await _dio.post('/auth/register',
          data: data.toJson(), options: Options(extra: {'noAuth': true}));
    } on DioException catch (e) {
      throw AuthException(_detail(e) ?? 'No se pudo registrar');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          extra: {'noAuth': true},
        ),
      );
      await _storage.save(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
    } on DioException catch (e) {
      throw AuthException(_detail(e) ?? 'Credenciales inválidas');
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/users/me');
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final refresh = await _storage.refresh;
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh});
      } on DioException {
        // expira solo; igual limpiamos local
      }
    }
    await _storage.clear();
  }

  String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return null;
  }
}
