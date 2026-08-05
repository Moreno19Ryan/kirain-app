import 'package:flutter/material.dart';

/// A pulsing rounded-rect placeholder that mimics real content while it
/// loads, per CLAUDE.md's "skeleton screen, not a plain spinner" guidance.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.borderRadius = 8});

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 0.4, end: 1.0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
