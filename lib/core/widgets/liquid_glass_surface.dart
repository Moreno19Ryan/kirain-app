import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/data/energy_saver_repository.dart';

/// Frosted-glass surface per CLAUDE.md's "Liquid Glass" spec: a blurred,
/// translucent backdrop with a thin "glass edge" border and a soft shadow
/// for a floating/depth feel. Applied selectively (starting with the bottom
/// nav bar) rather than everywhere, to stay performant and avoid feeling
/// overdone.
///
/// Wrap the content that should sit *on top of* the glass — this widget
/// only paints the backdrop, it doesn't size or position anything.
///
/// `BackdropFilter`'s blur is GPU-heavy on entry-level chipsets (CLAUDE.md's
/// "Liquid glass WAJIB terkondisi performa"), so this reads the user's
/// "Mode Hemat Energi" setting (Kamu > Pengaturan) and, when it's on, skips
/// the blur entirely in favor of a near-opaque solid fill — same shape and
/// edge treatment, just without the compositing cost. Mirrors iOS's own
/// "Reduce Transparency" pattern: less see-through stands in for blur
/// instead of leaving a cheap-looking flat translucent panel behind.
class LiquidGlassSurface extends ConsumerWidget {
  const LiquidGlassSurface({super.key, required this.child, this.topBorderOnly = false});

  final Widget child;

  /// True for edge-anchored surfaces (like a bottom nav bar) where only the
  /// edge facing the content makes sense to outline — the other sides are
  /// flush with the screen edge, so a full border would be invisible there.
  final bool topBorderOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final edgeColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.07);
    final edge = BorderSide(color: edgeColor, width: 1);
    final energySaver = ref.watch(energySaverEnabledProvider).value ?? false;

    final surface = Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: energySaver ? 0.97 : (isDark ? 0.78 : 0.82)),
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
    );

    if (energySaver) return surface;

    return ClipRect(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: surface),
    );
  }
}
