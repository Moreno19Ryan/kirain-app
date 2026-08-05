import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/app.dart';

void main() {
  testWidgets('renders Home tab with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KirainApp()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Catat'), findsOneWidget);
    expect(find.text('Rekap'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);
  });
}
