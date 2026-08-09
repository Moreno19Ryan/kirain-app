import 'package:flutter/material.dart';

/// Brand tokens from CLAUDE.md section 6.5 that don't map cleanly onto a
/// standard Material 3 [ColorScheme] role, because they need a "fill vs
/// strong" distinction: the same hue reads fine as a solid button/badge fill
/// in both light and dark mode, but needs a darker "strong" variant when
/// used directly as text/icon color in light mode to keep contrast.
@immutable
class KirainColors extends ThemeExtension<KirainColors> {
  const KirainColors({
    required this.mint,
    required this.mintStrong,
    required this.coral,
    required this.coralStrong,
    required this.surface2,
  });

  /// Fill color for buttons/badges/progress bars — identical in both modes,
  /// always paired with a dark foreground on top.
  final Color mint;

  /// Mint used directly as text/icon color (not inside a fill). Same as
  /// [mint] in dark mode; darkened in light mode for contrast.
  final Color mintStrong;

  /// Fill color for Keinginan/Zona Kirain accents. Deliberately reused for
  /// "Zona Kirain" (over-budget) instead of introducing a separate alarm-red
  /// — same brand family, just a more urgent context.
  final Color coral;

  /// Coral used directly as text/icon color. Same as [coral] in dark mode;
  /// darkened in light mode for contrast.
  final Color coralStrong;

  /// Raised/hover surface, one step lighter than the card surface.
  final Color surface2;

  static const dark = KirainColors(
    mint: Color(0xFF7FE0C4),
    mintStrong: Color(0xFF7FE0C4),
    coral: Color(0xFFFF8B5E),
    coralStrong: Color(0xFFFF8B5E),
    surface2: Color(0xFF1E2B25),
  );

  static const light = KirainColors(
    mint: Color(0xFF7FE0C4),
    mintStrong: Color(0xFF12946E),
    coral: Color(0xFFFFB08A),
    coralStrong: Color(0xFFE2613A),
    surface2: Color(0xFFEFF5F1),
  );

  @override
  KirainColors copyWith({
    Color? mint,
    Color? mintStrong,
    Color? coral,
    Color? coralStrong,
    Color? surface2,
  }) {
    return KirainColors(
      mint: mint ?? this.mint,
      mintStrong: mintStrong ?? this.mintStrong,
      coral: coral ?? this.coral,
      coralStrong: coralStrong ?? this.coralStrong,
      surface2: surface2 ?? this.surface2,
    );
  }

  @override
  KirainColors lerp(ThemeExtension<KirainColors>? other, double t) {
    if (other is! KirainColors) return this;
    return KirainColors(
      mint: Color.lerp(mint, other.mint, t)!,
      mintStrong: Color.lerp(mintStrong, other.mintStrong, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralStrong: Color.lerp(coralStrong, other.coralStrong, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
    );
  }
}
