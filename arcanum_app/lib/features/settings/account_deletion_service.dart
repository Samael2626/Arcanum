import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../onboarding/application/onboarding_controller.dart';

abstract interface class AccountDeletionService {
  Future<void> deleteAccount();
}

class DefaultAccountDeletionService implements AccountDeletionService {
  DefaultAccountDeletionService(this._ref);

  final Ref _ref;

  @override
  Future<void> deleteAccount() async {
    // Logout de RevenueCat antes de borrar la cuenta para orfanar la identidad RC.
    try {
      await Purchases.logOut();
    } catch (_) {
      // Best-effort: si falla, el backend borrará el customer vía API.
    }

    await _ref.read(authProvider.notifier).deleteAccount();
    try {
      await Future.wait([
        _ref.read(grimoireCryptoProvider).clearLocalKey(),
        clearOnboardingLocalData(),
      ]);
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
