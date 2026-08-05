import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/catat/catat_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kamu/kamu_screen.dart';
import '../../features/rekap/rekap_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _RootScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/catat', builder: (_, _) => const CatatScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/rekap', builder: (_, _) => const RekapScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/kamu', builder: (_, _) => const KamuScreen())],
        ),
      ],
    ),
  ],
);

class _RootScaffold extends StatelessWidget {
  const _RootScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Catat'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Rekap'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Kamu'),
        ],
      ),
    );
  }
}
