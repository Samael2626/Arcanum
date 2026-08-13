import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../name_threshold/application/reading_identity_controller.dart';
import '../onboarding/application/onboarding_controller.dart';

abstract interface class AccountDeletionService {
  Future<void> deleteAccount();
}

class DefaultAccountDeletionService implements AccountDeletionService {
  DefaultAccountDeletionService(this._ref);

  final Ref _ref;

  @override
  Future<void> deleteAccount() async {
    await _ref.read(authProvider.notifier).deleteAccount();
    try {
      await Future.wait([
        _ref.read(readingIdentityRepositoryProvider).delete(),
        _ref.read(grimoireCryptoProvider).clearLocalKey(),
        clearOnboardingLocalData(),
      ]);
      _ref.invalidate(readingIdentityProvider);
      _ref.invalidate(onboardingProvider);
      _ref.invalidate(onboardingCompletedProvider);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'arcanum account deletion',
          context: ErrorDescription('clearing local user data'),
        ),
      );
    }
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  DefaultAccountDeletionService.new,
);
