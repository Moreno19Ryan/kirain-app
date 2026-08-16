import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/sync/sync_lifecycle_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/app_lock/presentation/app_lock_gate.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';
import 'features/splash/presentation/splash_gate.dart';

class KirainApp extends ConsumerWidget {
  const KirainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'KIRAIN',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => SyncLifecycleGate(
        child: SplashGate(child: OnboardingGate(child: AppLockGate(child: child!))),
      ),
    );
  }
}
