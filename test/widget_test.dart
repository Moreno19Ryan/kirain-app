import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/main.dart';

void main() {
  testWidgets('renders KIRAIN placeholder home', (WidgetTester tester) async {
    await tester.pumpWidget(const KirainApp());

    expect(find.text('KIRAIN'), findsOneWidget);
  });
}
