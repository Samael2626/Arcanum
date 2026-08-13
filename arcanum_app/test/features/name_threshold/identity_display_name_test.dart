import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/name_threshold/application/reading_identity_controller.dart';
import 'package:arcanum_app/features/name_threshold/data/reading_identity_repository.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:arcanum_app/features/name_threshold/presentation/identity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'display_name': 'Nombre Social Canario',
  });
}

class _EmptyStorage implements ReadingIdentityStorage {
  @override
  Future<void> delete() async {}
  @override
  Future<ReadingIdentityProfile?> load() async => null;
  @override
  Future<void> save(ReadingIdentityProfile profile) async {}
}

void main() {
  testWidgets('display_name se muestra pero no rellena perfil de lectura', (
    tester,
  ) async {
    final repository = ReadingIdentityRepository(_EmptyStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          readingIdentityRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: IdentityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nombre Social Canario'), findsOneWidget);
    expect(find.text('Perfil privado vacío'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IdentityScreen)),
    );
    expect(container.read(readingIdentityProvider).value, isNull);
  });
}
