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
import '../../features/grimorio/pasajes_screen.dart';
import '../../features/lecturas/presentation/indice_screen.dart';
import '../../features/saber/saber_screen.dart';
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
              routes: [
                GoRoute(
                  path: 'pasajes',
                  builder: (c, s) => const PasajesScreen(),
                ),
              ],
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
                    // 'indice' se declara ANTES de ':chapter': si no, casaria
                    // como si fuera el slug de un capitulo y el indice no se
                    // abriria nunca. Ningun capitulo puede llamarse asi.
                    GoRoute(
                      path: 'indice',
                      builder: (c, s) =>
                          IndiceScreen(workSlug: s.pathParameters['work']!),
                    ),
                    GoRoute(
                      path: ':chapter',
                      // anchor/fragment son opcionales: sin ellos el capitulo
                      // se abre por el principio, que es lo que hace el enlace
                      // profundo de siempre. Con ellos, cae en la posicion
                      // exacta que pidio "Reanudar" o un pasaje guardado.
                      builder: (c, s) => LectorScreen(
                        workSlug: s.pathParameters['work']!,
                        chapterSlug: s.pathParameters['chapter']!,
                        anchor: s.uri.queryParameters['anchor'],
                        fragmentIndex:
                            int.tryParse(
                              s.uri.queryParameters['fragment'] ?? '',
                            ) ??
                            0,
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
