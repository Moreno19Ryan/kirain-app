import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/theme/app_theme.dart';
import 'package:kirain/core/theme/kirain_colors.dart';

void main() {
  // google_fonts checks the asset bundle for a pre-bundled font before
  // falling back to network, which needs a binding even in a plain (non
  // testWidgets) test file.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme.dark', () {
    final scheme = AppTheme.dark.colorScheme;

    test('maps KIRAIN tokens onto the expected ColorScheme roles', () {
      expect(scheme.surface, const Color(0xFF0D1412)); // bg
      expect(scheme.onSurface, const Color(0xFFF2F5F3)); // text
      expect(scheme.onSurfaceVariant, const Color(0xFF8FA39A)); // text-dim
      expect(scheme.outline, const Color(0xFF253630)); // border
      expect(scheme.primary, const Color(0xFF7FE0C4)); // mint
      expect(scheme.onPrimary, const Color(0xFF0D1412));
      expect(scheme.secondary, const Color(0xFFFF8B5E)); // coral
      expect(scheme.onSecondary, const Color(0xFF0D1412));
    });

    test('error reuses coral, not a separate alarm color', () {
      expect(scheme.error, scheme.secondary);
      expect(scheme.onError, const Color(0xFF0D1412));
    });

    test('container roles are explicit tokens, not fromSeed-derived tones', () {
      expect(scheme.onPrimaryContainer, const Color(0xFF7FE0C4)); // mintStrong == mint in dark
      expect(scheme.onSecondaryContainer, const Color(0xFFFF8B5E)); // coralStrong == coral in dark
      expect(scheme.surfaceContainerHigh, const Color(0xFF1E2B25)); // surface2
    });

    test('scaffold background is bg, card surface is the surface token', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF0D1412));
      expect(AppTheme.dark.cardTheme.color, const Color(0xFF16211D));
    });

    test('carries the KirainColors extension with dark-mode tokens', () {
      final colors = AppTheme.dark.extension<KirainColors>();
      expect(colors, isNotNull);
      expect(colors!.mint, const Color(0xFF7FE0C4));
      expect(colors.mintStrong, colors.mint);
      expect(colors.coral, const Color(0xFFFF8B5E));
      expect(colors.coralStrong, colors.coral);
    });

    test('display/heading/title roles use Sora, body/label roles use Inter', () {
      final text = AppTheme.dark.textTheme;
      // google_fonts composes fontFamily as "Family_weight" internally, but
      // always keeps the plain family name as the first fallback — that's
      // the stable thing to assert against.
      for (final style in [text.displayLarge, text.headlineMedium, text.titleSmall]) {
        expect(style?.fontFamilyFallback, contains('Sora'));
      }
      for (final style in [text.bodyLarge, text.bodyMedium, text.labelSmall]) {
        expect(style?.fontFamilyFallback, contains('Inter'));
      }
    });

    test('text theme colors default to the text token', () {
      expect(AppTheme.dark.textTheme.bodyMedium?.color, const Color(0xFFF2F5F3));
      expect(AppTheme.dark.textTheme.headlineMedium?.color, const Color(0xFFF2F5F3));
    });
  });

  group('AppTheme.light', () {
    final scheme = AppTheme.light.colorScheme;

    test('maps KIRAIN tokens onto the expected ColorScheme roles', () {
      expect(scheme.surface, const Color(0xFFF6FAF7)); // bg
      expect(scheme.onSurface, const Color(0xFF14201A)); // text
      expect(scheme.onSurfaceVariant, const Color(0xFF5C6D66)); // text-dim
      expect(scheme.outline, const Color(0xFFDCE6E1)); // border
      expect(scheme.primary, const Color(0xFF7FE0C4)); // mint stays identical
      expect(scheme.secondary, const Color(0xFFFFB08A)); // coral, softer
    });

    test('error reuses the softer light-mode coral', () {
      expect(scheme.error, scheme.secondary);
    });

    test('mint/coral "strong" variants are darkened for text/icon contrast', () {
      final colors = AppTheme.light.extension<KirainColors>()!;
      expect(colors.mintStrong, const Color(0xFF12946E));
      expect(colors.coralStrong, const Color(0xFFE2613A));
      expect(colors.mintStrong, isNot(colors.mint));
      expect(colors.coralStrong, isNot(colors.coral));
    });

    test('container roles use the darkened strong variants, not a fromSeed pastel tone', () {
      // The regression this guards: ColorScheme.fromSeed() only fills in
      // the slots explicitly overridden, leaving onPrimaryContainer/
      // onSecondaryContainer as algorithmic light-mode tones close to the
      // container's own background — text/icons painted with those read as
      // nearly invisible (the "icon kategori nyaris gak keliatan" bug).
      expect(scheme.onPrimaryContainer, const Color(0xFF12946E)); // mintStrong
      expect(scheme.onSecondaryContainer, const Color(0xFFE2613A)); // coralStrong
      expect(scheme.surfaceContainerHigh, const Color(0xFFEFF5F1)); // surface2
    });
  });
}
