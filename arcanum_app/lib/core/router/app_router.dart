import 'package:go_router/go_router.dart';

import '../../features/arte/arte_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/cielos/cielos_screen.dart';
import '../../features/grimorio/grimorio_screen.dart';
import '../../features/hoy/hoy_screen.dart';
import '../../features/lecturas/presentation/lector_screen.dart';
import '../../features/lecturas/presentation/lecturas_screen.dart';
import '../../features/lecturas/presentation/obra_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/oraculo/oraculo_screen.dart';
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
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/arte', builder: (c, s) => const ArteScreen()),
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/lecturas',
              builder: (c, s) => const LecturasScreen(),
              routes: [
                // Anidadas para que volver desde un pasaje lleve al índice de
                // su obra, y de ahí a la biblioteca — el recorrido natural de
                // quien está leyendo.
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
      ],
    ),
  ],
);
