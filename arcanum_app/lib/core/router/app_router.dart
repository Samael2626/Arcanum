import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/cielos/cielos_screen.dart';
import '../../features/grimorio/grimorio_screen.dart';
import '../../features/hoy/hoy_screen.dart';
import '../../features/lecturas/presentation/lector_screen.dart';
import '../../features/lecturas/presentation/obra_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/oraculo/oraculo_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/perfil/perfil_screen.dart';
import '../../features/saber/saber_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tarot/tarot_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/hoy',
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/privacy', builder: (c, s) => const PrivacyScreen()),
    GoRoute(path: '/perfil', builder: (c, s) => const PerfilScreen()),
    GoRoute(path: '/paywall', builder: (c, s) => const PaywallScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/hoy', builder: (c, s) => const HoyScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/cielos', builder: (c, s) => const CielosScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/grimorio',
              builder: (c, s) => const GrimorioScreen(),
            ),
          ],
        ),
        // Saber = Plantas (Materia) + Libros (Lecturas). El lector de obras
        // cuelga aquí: volver desde un pasaje lleva al índice de su obra, y de
        // ahí a Saber — el recorrido natural de quien lee.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saber',
              builder: (c, s) => const SaberScreen(),
              routes: [
                GoRoute(
                  path: ':work',
                  builder: (c, s) =>
                      ObraScreen(workSlug: s.pathParameters['work']!),
                  routes: [
                    GoRoute(
                      path: ':chapter',
                      builder: (c, s) => LectorScreen(
                        workSlug: s.pathParameters['work']!,
                        chapterSlug: s.pathParameters['chapter']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/oraculo',
              builder: (c, s) => const OraculoScreen(),
              routes: [
                GoRoute(path: 'tarot', builder: (c, s) => const TarotScreen()),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
