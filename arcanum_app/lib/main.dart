import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/auth/auth_controller.dart';
import 'core/monetization/monetization_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';
import 'features/onboarding/application/onboarding_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics: capturar errores no atrapados
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  const adsEnabled = bool.fromEnvironment('ADS_ENABLED');
  if (adsEnabled) {
    // TODO(compliance): Implementar UMP antes de activar ADS_ENABLED. Ver el
    // bloque "Gap abierto: consentimiento de ads (UMP)" en
    // .agents/skills/arcanum-legal/references/ia-y-datos.md.
    await MobileAds.instance.initialize();
  }
  await MonetizationService.initialize('PLACEHOLDER_RC_API_KEY');

  // En desarrollo, log a consola en vez de Crashlytics
  if (kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  runZonedGuarded(() {
    runApp(const ProviderScope(child: ArcanumApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
