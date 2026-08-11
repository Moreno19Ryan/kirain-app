import 'package:flutter/material.dart';

import 'splash_screen.dart';

/// Wraps the whole app (via MaterialApp.router's `builder`, outermost —
/// even before [OnboardingGate]) so the animated splash is the very first
/// thing shown after the native splash hands off, every cold start. Unlike
/// [OnboardingGate] this isn't gated behind any persisted flag — it's not
/// something to skip once "seen", it's a brief branded transition.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onDone: () => setState(() => _showSplash = false));
    }
    return widget.child;
  }
}
