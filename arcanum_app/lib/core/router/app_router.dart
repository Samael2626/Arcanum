import 'package:go_router/go_router.dart';

import '../../features/arte/arte_screen.dart';
import '../../features/cielos/cielos_screen.dart';
import '../../features/grimorio/grimorio_screen.dart';
import '../../features/hoy/hoy_screen.dart';
import '../../features/oraculo/oraculo_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/hoy',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/hoy', builder: (c, s) => const HoyScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cielos', builder: (c, s) => const CielosScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/grimorio', builder: (c, s) => const GrimorioScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/arte', builder: (c, s) => const ArteScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/oraculo', builder: (c, s) => const OraculoScreen()),
        ]),
      ],
    ),
  ],
);
