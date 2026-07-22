import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Carcasa con barra de navegación inferior persistente (5 pestañas).
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: navigationShell),
            Positioned(
              top: 4,
              right: 6,
              child: Semantics(
                label: 'Abrir ajustes',
                button: true,
                child: IconButton.filledTonal(
                  tooltip: 'Ajustes',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_twilight_outlined),
            selectedIcon: Icon(Icons.wb_twilight),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Cielos',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Grimorio',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Arte',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Oráculo',
          ),
          // Sexta pestaña. Material recomienda 3-5: con seis, las etiquetas se
          // aprietan en pantallas estrechas. Si llega a molestar, la salida
          // natural es fundir Arte y Lecturas bajo un mismo "Saber", ya que
          // Materia Arcana sale justamente de estas obras.
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: 'Lecturas',
          ),
        ],
      ),
    );
  }
}
