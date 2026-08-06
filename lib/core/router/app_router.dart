import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/budget/presentation/budget_cycle_settings_screen.dart';
import '../../features/budget/presentation/gajian_reminder_prompt.dart';
import '../../features/catat/catat_screen.dart';
import '../../features/categories/presentation/manage_categories_screen.dart';
import '../../features/goals/presentation/manage_goals_screen.dart';
import '../../features/help/presentation/faq_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kamu/kamu_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/legal/presentation/terms_of_service_screen.dart';
import '../../features/recurring/presentation/manage_recurring_screen.dart';
import '../../features/recurring/presentation/recurring_due_prompt.dart';
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
      GoRoute(
        path: '/target-nabung',
        builder: (_, _) => const ManageGoalsScreen(),
      ),
      GoRoute(
        path: '/transaksi-berulang',
        builder: (_, _) => const ManageRecurringScreen(),
      ),
      GoRoute(
        path: '/siklus-budget',
        builder: (_, _) => const BudgetCycleSettingsScreen(),
      ),
      GoRoute(path: '/bantuan', builder: (_, _) => const FaqScreen()),
      GoRoute(
        path: '/kebijakan-privasi',
        builder: (_, _) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/syarat-ketentuan',
        builder: (_, _) => const TermsOfServiceScreen(),
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

/// Stateful (rather than HomeScreen) so the due-recurring check runs once
/// per app session without coupling HomeScreen's tests to recurring-feature
/// state — this shell wraps the whole bottom-nav, so it only ever mounts
/// once regardless of which tab is active first.
class _RootScaffold extends ConsumerStatefulWidget {
  const _RootScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<_RootScaffold> {
  static const _quickActions = QuickActions();
  static const _catatBranchIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Sequential, not parallel — both can show a dialog, and running them
      // one after another avoids two showDialog calls racing on the same
      // frame.
      await checkAndPromptDueRecurring(context, ref);
      if (!mounted) return;
      await checkAndPromptGajianReminder(context, ref);
    });
    _setUpQuickActions();
  }

  /// Long-press the launcher icon -> straight to Catat, per CLAUDE.md's
  /// "App shortcuts". Only reachable once signed in, since this widget only
  /// mounts inside the authenticated shell — a cold start while signed out
  /// just falls through to the normal sign-in redirect instead.
  void _setUpQuickActions() {
    _quickActions.initialize((type) {
      if (type == 'catat') widget.navigationShell.goBranch(_catatBranchIndex);
    });
    _quickActions.setShortcutItems(const [
      ShortcutItem(type: 'catat', localizedTitle: 'Catat Transaksi'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;

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
          NavigationDestination(icon: _CatatNavIcon(selected: false), selectedIcon: _CatatNavIcon(selected: true), label: 'Catat'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Rekap'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Kamu'),
        ],
      ),
    );
  }
}

/// "Catat" is the most-used action in the app, so it gets a filled circular
/// badge to stand out from the other, plain outline nav icons — per
/// CLAUDE.md's "tombol Catat idealnya jadi elemen paling menonjol".
class _CatatNavIcon extends StatelessWidget {
  const _CatatNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.add,
        size: 26,
        color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
      ),
    );
  }
}
