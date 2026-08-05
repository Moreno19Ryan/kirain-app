import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/catat/catat_screen.dart';
import '../../features/categories/presentation/manage_categories_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kamu/kamu_screen.dart';
import '../../features/rekap/rekap_screen.dart';
import 'go_router_refresh_stream.dart';

const _authRoutes = {'/sign-in', '/verify-otp'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authRepository.onAuthStateChange),
    redirect: (context, state) {
      final isSignedIn = authRepository.currentUser != null;
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);

      if (!isSignedIn && !isAuthRoute) return '/sign-in';
      if (isSignedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => OtpVerifyScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/kelola-kategori',
        builder: (_, _) => const ManageCategoriesScreen(),
      ),
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
});

class _RootScaffold extends StatelessWidget {
  const _RootScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
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
