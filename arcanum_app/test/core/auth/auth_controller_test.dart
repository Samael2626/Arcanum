import 'dart:async';

import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/auth/auth_repository.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage({this.token, this.cachedProfile});

  String? token;
  Map<String, dynamic>? cachedProfile;
  var clearCalls = 0;

  @override
  Future<String?> get access async => token;

  @override
  Future<String?> get refresh async => 'refresh-token';

  @override
  Future<Map<String, dynamic>?> get profile async => cachedProfile;

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    cachedProfile = Map<String, dynamic>.from(profile);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    token = null;
    cachedProfile = null;
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.storage) : super(Dio(), storage);

  final _MemoryTokenStorage storage;
  final meCompleter = Completer<Map<String, dynamic>>();
  var deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> me() => meCompleter.future;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    await storage.clear();
  }

  @override
  Future<void> logout() => storage.clear();
}

ProviderContainer _container(
  _MemoryTokenStorage storage,
  _FakeAuthRepository repository,
) {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('abre con perfil seguro y lo actualiza en segundo plano', () async {
    final storage = _MemoryTokenStorage(
      token: 'access-token',
      cachedProfile: {'id': 'user-a', 'display_name': 'Cache'},
    );
    final repository = _FakeAuthRepository(storage);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    expect(container.read(authProvider).status, AuthStatus.unknown);
    await _flush();
    expect(container.read(authProvider).status, AuthStatus.authenticated);
    expect(container.read(authProvider).user?['display_name'], 'Cache');

    repository.meCompleter.complete({
      'id': 'user-a',
      'display_name': 'Servidor',
    });
    await _flush();
    await _flush();

    expect(container.read(authProvider).user?['display_name'], 'Servidor');
    expect(storage.cachedProfile?['display_name'], 'Servidor');
  });

  test('conserva la sesión cacheada cuando Railway no responde', () async {
    final storage = _MemoryTokenStorage(
      token: 'access-token',
      cachedProfile: {'id': 'user-a'},
    );
    final repository = _FakeAuthRepository(storage);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    container.read(authProvider);
    repository.meCompleter.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        type: DioExceptionType.connectionError,
      ),
    );
    await _flush();
    await _flush();

    expect(container.read(authProvider).status, AuthStatus.authenticated);
    expect(storage.clearCalls, 0);
  });

  test('un 401 invalida tokens y perfil cacheado', () async {
    final storage = _MemoryTokenStorage(
      token: 'access-token',
      cachedProfile: {'id': 'user-a'},
    );
    final repository = _FakeAuthRepository(storage);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    container.read(authProvider);
    repository.meCompleter.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me'),
          statusCode: 401,
        ),
      ),
    );
    await _flush();
    await _flush();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(storage.clearCalls, 1);
    expect(storage.cachedProfile, isNull);
  });

  test('una validación tardía no revive la sesión tras logout', () async {
    final storage = _MemoryTokenStorage(
      token: 'access-token',
      cachedProfile: {'id': 'user-a'},
    );
    final repository = _FakeAuthRepository(storage);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    container.read(authProvider);
    await _flush();
    expect(container.read(authProvider).status, AuthStatus.authenticated);

    await container.read(authProvider.notifier).logout();
    repository.meCompleter.complete({'id': 'user-a'});
    await _flush();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('eliminar cuenta limpia la sesión local', () async {
    final storage = _MemoryTokenStorage(
      token: 'access-token',
      cachedProfile: {'id': 'user-a'},
    );
    final repository = _FakeAuthRepository(storage);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    container.read(authProvider);
    await _flush();
    await container.read(authProvider.notifier).deleteAccount();

    expect(repository.deleteCalls, 1);
    expect(storage.token, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });
}
