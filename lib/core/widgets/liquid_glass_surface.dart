import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass surface per CLAUDE.md's "Liquid Glass" spec: a blurred,
/// translucent backdrop with a thin "glass edge" border and a soft shadow
/// for a floating/depth feel. Applied selectively (starting with the bottom
/// nav bar) rather than everywhere, to stay performant and avoid feeling
/// overdone.
///
/// Wrap the content that should sit *on top of* the glass — this widget
/// only paints the backdrop, it doesn't size or position anything.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({super.key, required this.child, this.topBorderOnly = false});

  final Widget child;

  /// True for edge-anchored surfaces (like a bottom nav bar) where only the
  /// edge facing the content makes sense to outline — the other sides are
  /// flush with the screen edge, so a full border would be invisible there.
  final bool topBorderOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final edgeColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.07);
    final edge = BorderSide(color: edgeColor, width: 1);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: isDark ? 0.78 : 0.82),
            border: topBorderOnly ? Border(top: edge) : Border.fromBorderSide(edge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
