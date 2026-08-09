import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/theme/app_theme.dart';
import 'package:kirain/core/theme/kirain_colors.dart';

void main() {
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
  });
}
