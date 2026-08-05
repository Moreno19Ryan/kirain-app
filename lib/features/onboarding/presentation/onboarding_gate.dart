import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_repository.dart';
import 'onboarding_screen.dart';

/// Wraps the whole app (via MaterialApp.router's `builder`, outside
/// [AppLockGate]) so the intro slides are the very first thing a new user
/// sees, before sign-in ever renders. Shown at most once per install.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool _checked = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final seen = await ref.read(onboardingRepositoryProvider).hasSeenOnboarding();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !seen;
      _checked = true;
    });
  }

  Future<void> _finish() async {
    await ref.read(onboardingRepositoryProvider).markSeen();
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    if (_showOnboarding) return OnboardingScreen(onDone: _finish);
    return widget.child;
  }
}
