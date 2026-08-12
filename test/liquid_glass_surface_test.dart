import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/settings/data/energy_saver_repository.dart';
import 'package:kirain/core/widgets/liquid_glass_surface.dart';

void main() {
  Widget wrap(Widget child, {required bool energySaver}) {
    return ProviderScope(
      overrides: [energySaverEnabledProvider.overrideWith((ref) async => energySaver)],
      child: MaterialApp(home: Scaffold(body: LiquidGlassSurface(child: child))),
    );
  }

  group('LiquidGlassSurface', () {
    testWidgets('blurs the backdrop when Mode Hemat Energi is off', (tester) async {
      await tester.pumpWidget(wrap(const Text('nav'), energySaver: false));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
      expect(filter, isA<ImageFilter>());
    });

    testWidgets('skips the blur and falls back to a solid fill when Mode Hemat Energi is on', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Text('nav'), energySaver: true));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('nav'), findsOneWidget);
    });
  });
}
