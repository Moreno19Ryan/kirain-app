import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/features/tips/presentation/tip_card.dart';

void main() {
  group('TipCard', () {
    testWidgets('shows the given tip and hides itself when dismissed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TipCard(tip: 'Nabung dulu baru belanja.'))),
      );

      expect(find.text('Nabung dulu baru belanja.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Nabung dulu baru belanja.'), findsNothing);
    });
  });
}
