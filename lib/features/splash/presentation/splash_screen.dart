import 'package:flutter/material.dart';

import '../../../core/theme/kirain_colors.dart';
import '../../../core/widgets/kaget_eyebrows.dart';

/// The Flutter-side splash — shown after the native splash hands off to the
/// Flutter engine, before Onboarding/Sign In. CLAUDE.md's "Splash Screen —
/// Native vs Flutter": this is the layer that CAN be animated (the native
/// splash can't), so it's where the "reveal/kaget" moment actually lives —
/// wordmark fades + scales in, then the alis kaget mark draws itself
/// progressively stroke by stroke, then [onDone] fires automatically.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkScale;
  late final Animation<double> _markProgress;

  // The mark finishes drawing at 85% through the controller (see
  // _markProgress below), so the remaining 15% already reads as a brief
  // hold before advancing — no extra artificial delay needed on top.
  static const _controllerDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _controllerDuration);

    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _wordmarkScale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack)),
    );
    // Progressive "stroke drawing" reveal of the signature mark — starts
    // once the wordmark has settled, per CLAUDE.md's splash spec.
    _markProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.85, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final mintStrong = kirainColors?.mintStrong ?? theme.colorScheme.primary;
    final coralStrong = kirainColors?.coralStrong ?? theme.colorScheme.secondary;

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: Transform.scale(
                    scale: _wordmarkScale.value,
                    child: Text(
                      'KIRAIN',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 140,
                  height: 63,
                  child: KagetEyebrows(
                    leftColor: mintStrong,
                    rightColor: coralStrong,
                    progress: _markProgress.value,
                    strokeWidth: 9,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
