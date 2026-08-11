import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/core/widgets/kaget_eyebrows.dart';
import 'package:kirain/features/splash/presentation/splash_gate.dart';
import 'package:kirain/features/splash/presentation/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('shows the wordmark and signature mark, then calls onDone once', (tester) async {
      var doneCount = 0;

      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onDone: () => doneCount++)),
      );

      expect(find.text('KIRAIN'), findsOneWidget);
      expect(find.byType(KagetEyebrows), findsOneWidget);
      expect(doneCount, 0);

      await tester.pumpAndSettle();

      expect(doneCount, 1);
    });
  });

  group('SplashGate', () {
    testWidgets('shows the splash first, then reveals the child once it finishes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashGate(child: Text('home content'))),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('home content'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('home content'), findsOneWidget);
    });
  });
}
