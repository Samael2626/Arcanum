import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/auth/auth_repository.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';
import 'package:arcanum_app/features/settings/account_deletion_service.dart';
import 'package:arcanum_app/features/settings/sensitive_data_consent_settings_card.dart';
import 'package:arcanum_app/features/settings/settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'display_name': 'Samuel',
    'email': 'samuel@example.com',
  });
}

class _FakeDeletionService implements AccountDeletionService {
  var calls = 0;

  @override
  Future<void> deleteAccount() async {
    calls++;
  }
}

class _SettingsApi extends ArcanumApi {
  _SettingsApi() : super(Dio());

  final recorded = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> userConsents() async => [
    {
      'kind': 'datos_sensibles',
      'policy_version': 'datos-sensibles-v1',
      'granted': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> recordConsent({
    required String kind,
    required String policyVersion,
    required bool granted,
  }) async {
    final value = {
      'kind': kind,
      'policy_version': policyVersion,
      'granted': granted,
    };
    recorded.add(value);
    return value;
  }
}

class _SettingsAuthRepository extends AuthRepository {
  _SettingsAuthRepository() : super(Dio(), TokenStorage());

  Map<String, dynamic>? updated;

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    updated = data;
    return data;
  }

  @override
  Future<Map<String, dynamic>> me() async => {
    'id': 'user-a',
    'display_name': 'Samuel',
    'email': 'samuel@example.com',
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el borrado exige confirmación escrita y ejecuta una vez', (
    tester,
  ) async {
    final service = _FakeDeletionService();
    final api = _SettingsApi();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/hoy',
          builder: (_, _) => const Scaffold(body: Text('HOY')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          arcanumApiProvider.overrideWithValue(api),
          accountDeletionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final deleteButton = find.text('Eliminar cuenta y datos');
    await tester.scrollUntilVisible(
      deleteButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Borrar todo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ELIMINAR');
    await tester.pump();
    await tester.tap(find.text('Borrar todo'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('HOY'), findsOneWidget);
  });

  testWidgets('revocar autorizacion borra datos sensibles', (tester) async {
    final api = _SettingsApi();
    final authRepository = _SettingsAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          arcanumApiProvider.overrideWithValue(api),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SensitiveDataConsentSettingsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revocar y borrar datos sensibles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.recorded.single['granted'], isFalse);
    expect(authRepository.updated, isNotNull);
    expect(authRepository.updated?['birth_date'], isNull);
    expect(authRepository.updated?['preferred_tradition'], isNull);
    expect(
      find.text('Autorización revocada y datos sensibles borrados.'),
      findsOneWidget,
    );
  });
}
