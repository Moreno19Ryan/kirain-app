import 'package:flutter/material.dart';

/// Drop-in animated replacement for [LinearProgressIndicator] in determinate
/// mode. Plain [LinearProgressIndicator] jumps to a new `value` instantly —
/// one of the "state kecil" changes CLAUDE.md's "Prinsip Animasi & Transisi"
/// calls out as needing an implicit animation instead of a hard cut.
class AnimatedLinearProgress extends StatelessWidget {
  const AnimatedLinearProgress({
    super.key,
    required this.value,
    this.minHeight,
    this.color,
    this.backgroundColor,
  });

  final double value;
  final double? minHeight;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Only `end` matters past the first build — TweenAnimationBuilder
      // always retargets from whatever it's currently rendering, so this
      // animates from the old value to the new one on every rebuild.
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, animatedValue, _) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}
