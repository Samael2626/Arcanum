import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';
import 'features/onboarding/application/onboarding_controller.dart';

void main() => runApp(const ProviderScope(child: ArcanumApp()));

class ArcanumApp extends ConsumerWidget {
  const ArcanumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al pasar a autenticado, reintenta el perfil de onboarding que no se pudo
    // enviar por un fallo de red. Sin esto, la fecha, hora y lugar de
    // nacimiento se quedaban solo en el dispositivo y la carta natal era
    // imposible para siempre, sin que el usuario pudiera arreglarlo.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        unawaited(
          tryFlushPendingProfile(ref.read(onboardingProvider.notifier)),
        );
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
