import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/features/help/presentation/faq_screen.dart';
import 'package:kirain/features/legal/presentation/privacy_policy_screen.dart';
import 'package:kirain/features/legal/presentation/terms_of_service_screen.dart';

void main() {
  testWidgets('FAQ screen expands a question to reveal its answer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaqScreen()));

    expect(find.text('Apa itu KIRAIN?'), findsOneWidget);
    expect(find.textContaining('bantu kamu mikir sebelum belanja'), findsNothing);

    await tester.tap(find.text('Apa itu KIRAIN?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bantu kamu mikir sebelum belanja'), findsOneWidget);
  });

  testWidgets('FAQ screen shows the WhatsApp and email support buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaqScreen()));

    // Not tapped: url_launcher has no platform implementation under
    // flutter test and blocks indefinitely waiting on a channel response
    // instead of throwing, so this only checks the buttons are present.
    expect(find.text('Chat via WhatsApp'), findsOneWidget);
    expect(find.text('Email ke morenoryandika@gmail.com'), findsOneWidget);
  });

  testWidgets('Privacy Policy screen renders its sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

    expect(find.text('Kebijakan Privasi'), findsOneWidget);
    expect(find.text('Data apa yang KIRAIN simpan?'), findsOneWidget);
  });

  testWidgets('Terms of Service screen renders its sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));

    expect(find.text('Syarat & Ketentuan'), findsOneWidget);
    expect(find.text('Tentang KIRAIN'), findsOneWidget);
  });
}
