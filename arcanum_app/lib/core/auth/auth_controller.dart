import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'auth_repository.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  const AuthState(this.status, [this.user]);
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final dioProvider = Provider((ref) => buildDio(ref.read(tokenStorageProvider)));

final authRepositoryProvider = Provider(
  (ref) =>
      AuthRepository(ref.read(dioProvider), ref.read(tokenStorageProvider)),
);

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  int _revision = 0;

  @override
  AuthState build() {
    final revision = ++_revision;
    unawaited(_bootstrap(revision));
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _bootstrap(int revision) async {
    final stored = await Future.wait([_storage.access, _storage.profile]);
    if (revision != _revision) return;
    final token = stored[0] as String?;
    final cachedUser = stored[1] as Map<String, dynamic>?;
    if (token == null) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }

    if (cachedUser != null) {
      state = AuthState(AuthStatus.authenticated, cachedUser);
      unawaited(_refreshSession(revision, keepCachedOnNetworkError: true));
      return;
    }

    await _refreshSession(revision, keepCachedOnNetworkError: false);
  }

  Future<void> _refreshSession(
    int revision, {
    required bool keepCachedOnNetworkError,
  }) async {
    try {
      final user = await _repo.me();
      if (revision != _revision) return;
      await _storage.saveProfile(user);
      if (revision == _revision) {
        state = AuthState(AuthStatus.authenticated, user);
      }
    } on DioException catch (error) {
      if (revision != _revision) return;
      if (error.response?.statusCode == 401) {
        await _storage.clear();
        if (revision == _revision) {
          state = const AuthState(AuthStatus.unauthenticated);
        }
      } else if (!keepCachedOnNetworkError) {
        state = const AuthState(AuthStatus.unauthenticated);
      }
    } on Object {
      if (revision == _revision && !keepCachedOnNetworkError) {
        state = const AuthState(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final revision = ++_revision;
    await _repo.login(email, password);
    final user = await _repo.me();
    if (revision != _revision) return;
    await _storage.saveProfile(user);
    if (revision == _revision) {
      state = AuthState(AuthStatus.authenticated, user);
    }
  }

  Future<void> register(RegisterData data) async {
    await _repo.register(data);
    await login(data.email, data.password);
  }

  /// Recarga el perfil desde el servidor (p.ej. tras el onboarding).
  Future<void> refreshUser() async {
    if (state.isAuthenticated) {
      final revision = _revision;
      final user = await _repo.me();
      if (revision != _revision) return;
      await _storage.saveProfile(user);
      if (revision == _revision) {
        state = AuthState(AuthStatus.authenticated, user);
      }
    }
  }

  Future<void> deleteAccount() async {
    final revision = ++_revision;
    await _repo.deleteAccount();
    if (revision == _revision) {
      state = const AuthState(AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    final revision = ++_revision;
    await _repo.logout();
    if (revision == _revision) {
      state = const AuthState(AuthStatus.unauthenticated);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
