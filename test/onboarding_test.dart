import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows 3 pages, ending on a Mulai button', (tester) async {
      var done = false;

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
      );

      expect(find.text('Kirain cukup, taunya boncos.'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Bedain Wajib vs Keinginan'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Catat gampang, 2-3 tap doang'), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);

      await tester.tap(find.text('Mulai'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('Skip calls onDone immediately from the first page', (tester) async {
      var done = false;

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
    });
  });
}
