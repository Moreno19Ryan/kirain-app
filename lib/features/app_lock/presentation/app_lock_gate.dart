import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_repository.dart';
import 'lock_screen.dart';

/// Wraps the whole app (via MaterialApp.router's `builder`). Shows a
/// full-screen lock overlay on cold start if App Lock is enabled, and
/// re-locks whenever the app is backgrounded — standard behavior for a
/// finance app, not just "lock once at launch".
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final enabled = await ref.read(appLockRepositoryProvider).isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checked = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;

    ref.read(appLockRepositoryProvider).isEnabled().then((enabled) {
      if (enabled && mounted) setState(() => _locked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();

    return Stack(
      children: [
        widget.child,
        if (_locked) LockScreen(onUnlocked: () => setState(() => _locked = false)),
      ],
    );
  }
}
