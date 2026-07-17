import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/settings/account_deletion_service.dart';
import 'package:arcanum_app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

void main() {
  testWidgets('el borrado exige confirmación escrita y ejecuta una vez', (
    tester,
  ) async {
    final service = _FakeDeletionService();
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
          accountDeletionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final deleteButton = find.text('Eliminar cuenta y datos');
    await tester.ensureVisible(deleteButton);
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
}
