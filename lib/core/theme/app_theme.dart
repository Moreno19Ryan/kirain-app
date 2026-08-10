import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kirain_colors.dart';

/// KIRAIN's brand palette — mint + coral, per CLAUDE.md section 6.5's
/// "Color Palette — FINAL". Replaces the placeholder `colorSchemeSeed:
/// Colors.teal` that was never an actual design decision.
class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg: const Color(0xFFF6FAF7),
    surface: const Color(0xFFFFFFFF),
    border: const Color(0xFFDCE6E1),
    text: const Color(0xFF14201A),
    textDim: const Color(0xFF5C6D66),
    mint: const Color(0xFF7FE0C4),
    coral: const Color(0xFFFFB08A),
    kirainColors: KirainColors.light,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg: const Color(0xFF0D1412),
    surface: const Color(0xFF16211D),
    border: const Color(0xFF253630),
    text: const Color(0xFFF2F5F3),
    textDim: const Color(0xFF8FA39A),
    mint: const Color(0xFF7FE0C4),
    coral: const Color(0xFFFF8B5E),
    kirainColors: KirainColors.dark,
  );

  /// Dark text/icon color painted on top of mint/coral fills — same in both
  /// modes, since the fills themselves stay bright enough to need it either way.
  static const _onFill = Color(0xFF0D1412);

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color border,
    required Color text,
    required Color textDim,
    required Color mint,
    required Color coral,
    required KirainColors kirainColors,
  }) {
    final mintStrong = kirainColors.mintStrong;
    final coralStrong = kirainColors.coralStrong;
    final surface2 = kirainColors.surface2;

    // Every field below is an exact token from CLAUDE.md's palette table, or
    // a controlled blend of two tokens — never a `fromSeed()`-derived tone.
    // fromSeed() only fills the slots we explicitly override, leaving things
    // like primaryContainer/surfaceContainer* as algorithmic pastel tones
    // that, in light mode, produced near-invisible mint-on-pale-mint
    // elements (e.g. category icons). Full explicit definition per
    // CLAUDE.md's "Implementasi ColorScheme — WAJIB Eksplisit".
    //
    // "Zona Kirain" (over-budget) deliberately reuses coral instead of a new
    // alarm-red — same brand family, just a more urgent context (CLAUDE.md
    // 6.5). So `error` is coral, not a separate hue, which also means every
    // existing `colorScheme.error` use (delete confirmations, form
    // validation, Zona Kirain) picks this up automatically.
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: mint,
      onPrimary: _onFill,
      primaryContainer: Color.alphaBlend(mint.withValues(alpha: 0.18), surface),
      onPrimaryContainer: mintStrong,
      secondary: coral,
      onSecondary: _onFill,
      secondaryContainer: Color.alphaBlend(coral.withValues(alpha: 0.18), surface),
      onSecondaryContainer: coralStrong,
      tertiary: mint,
      onTertiary: _onFill,
      tertiaryContainer: Color.alphaBlend(mint.withValues(alpha: 0.18), surface),
      onTertiaryContainer: mintStrong,
      error: coral,
      onError: _onFill,
      errorContainer: Color.alphaBlend(coral.withValues(alpha: 0.18), surface),
      onErrorContainer: coralStrong,
      surface: bg,
      onSurface: text,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface2,
      surfaceContainerHighest: border,
      onSurfaceVariant: textDim,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: text,
      onInverseSurface: bg,
      inversePrimary: mintStrong,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(color: surface, surfaceTintColor: Colors.transparent),
      textTheme: _textTheme(brightness: brightness, text: text),
      extensions: [kirainColors],
      // Same smooth transition on every platform per CLAUDE.md's "Prinsip
      // Animasi & Transisi" — rather than each platform falling back to its
      // own native default (Android's abrupt cut vs iOS's slide), which felt
      // inconsistent across the app.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Display/heading/angka -> Sora, body/label -> Inter, per CLAUDE.md 6.5's
  /// "Tipografi — FINAL". Built off Material 3's default sizes/weights so
  /// nothing else about the type scale changes, just the font families.
  static TextTheme _textTheme({required Brightness brightness, required Color text}) {
    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final sora = GoogleFonts.soraTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);

    return inter
        .copyWith(
          displayLarge: sora.displayLarge,
          displayMedium: sora.displayMedium,
          displaySmall: sora.displaySmall,
          headlineLarge: sora.headlineLarge,
          headlineMedium: sora.headlineMedium,
          headlineSmall: sora.headlineSmall,
          titleLarge: sora.titleLarge,
          titleMedium: sora.titleMedium,
          titleSmall: sora.titleSmall,
        )
        .apply(bodyColor: text, displayColor: text);
  }
}
