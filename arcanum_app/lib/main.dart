import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/auth/auth_controller.dart';
import 'core/config/release_config.dart';
import 'core/licencias/registro_licencias.dart';
import 'core/firebase/firebase_startup.dart';
import 'core/monetization/monetization_service.dart';
import 'core/places/city_catalog.dart';
import 'core/places/city_index_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';
import 'features/onboarding/application/onboarding_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La OFL obliga a distribuir su texto; esto lo hace visible en la app.
  registrarLicencias();
  // No usar Firebase.initializeApp directamente: en Android el provider nativo
  // ya creo [DEFAULT] y el segundo intento mata el arranque.
  await ensureFirebaseInitialized();

  // Crashlytics: capturar errores no atrapados
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  if (ReleaseConfig.adsEnabled) {
    // TODO(compliance): Implementar UMP antes de activar ADS_ENABLED. Ver el
    // bloque "Gap abierto: consentimiento de ads (UMP)" en
    // .agents/skills/arcanum-legal/references/ia-y-datos.md.
    await MobileAds.instance.initialize();
  }
  ReleaseConfig.validateForStartup();
  if (ReleaseConfig.revenueCatEnabled) {
    await MonetizationService.initialize(ReleaseConfig.revenueCatApiKey);
  }

  // En desarrollo, log a consola en vez de Crashlytics
  if (kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  // Catalogo de ciudades: se carga una vez, aqui, porque el selector de lugar
  // lo pide de forma sincrona. Si falla, la app arranca igual y el selector
  // ensena su estado de "catalogo no disponible" con el rescate por servidor:
  // mejor eso que no arrancar por una lista de ciudades.
  CityCatalog? cityCatalog;
  try {
    cityCatalog = await CityCatalog.load();
  } catch (error, stack) {
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
  }

  runZonedGuarded(() {
    runApp(
      ProviderScope(
        overrides: [
          if (cityCatalog != null)
            cityIndexProvider.overrideWithValue(cityCatalog),
        ],
        child: const ArcanumApp(),
      ),
    );
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
      // Sin esto, los widgets de Material caen a INGLÉS: los selectores de
      // fecha y hora del onboarding decían "Select date", "Sat, Jan 1" y
      // "Cancel / OK" en una app escrita entera en español, y eso lo veía cada
      // persona nueva en dos pantallas seguidas.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Solo español. Declarar más idiomas sin traducir NUESTROS textos daría
      // una app medio traducida: el calendario en francés y el horóscopo en
      // español. Cuando haya traducción de verdad, se amplía aquí.
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      routerConfig: ref.watch(arcanumRouterProvider),
    );
  }
}
