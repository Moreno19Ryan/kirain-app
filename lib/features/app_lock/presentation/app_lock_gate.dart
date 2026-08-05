import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_repository.dart';
import 'lock_screen.dart';

/// Wraps the whole app (via MaterialApp.router's `builder`). Shows a
/// full-screen lock overlay on cold start if App Lock is enabled. Re-locks
/// after the app has been backgrounded for at least [_gracePeriod] — a
/// quick switch to check a notification or copy something doesn't force a
/// re-auth, but leaving the phone for real does.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  static const _gracePeriod = Duration(seconds: 30);

  bool _locked = false;
  bool _checked = false;
  DateTime? _pausedAt;

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
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || DateTime.now().difference(pausedAt) < _gracePeriod) return;

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
