import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/auth/auth_controller.dart';
import 'core/monetization/monetization_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';
import 'features/onboarding/application/onboarding_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await MonetizationService.initialize('PLACEHOLDER_RC_API_KEY');
  runApp(const ProviderScope(child: ArcanumApp()));
}

class ArcanumApp extends ConsumerWidget {
  const ArcanumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        unawaited(
          tryFlushPendingProfile(ref.read(onboardingProvider.notifier)),
        );
        // Identificar usuario en RevenueCat tras login.
        final userId = next.user?['id'] as String?;
        if (userId != null) {
          ref.read(monetizationServiceProvider).identify(userId);
        }
      }
      if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        ref.read(monetizationServiceProvider).logout();
      }
    });

    return MaterialApp.router(
      title: 'ARCANUM',
      debugShowCheckedModeBanner: false,
      theme: buildArcanumTheme(),
      routerConfig: appRouter,
    );
  }
}
