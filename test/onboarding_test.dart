import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/core/widgets/kaget_eyebrows.dart';
import 'package:kirain/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows 3 pages with the signature mark, ending on a Mulai Sekarang button', (
      tester,
    ) async {
      var done = false;

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
      );

      expect(find.text('Kirain cukup, taunya boncos.'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
      expect(find.byType(KagetEyebrows), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Bedain Wajib vs Keinginan'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Catat gampang, 2-3 tap doang'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('Lewati calls onDone immediately from the first page', (tester) async {
      var done = false;

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
      );

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
    });

    testWidgets('the active dot indicator tracks the current page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () {})),
      );

      List<double?> dotWidths() {
        return tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where((w) => w.constraints?.maxHeight == 8)
            .map((w) => w.constraints?.maxWidth)
            .toList();
      }

      expect(dotWidths(), [20, 8, 8]);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(dotWidths(), [8, 20, 8]);
    });
  });
}
