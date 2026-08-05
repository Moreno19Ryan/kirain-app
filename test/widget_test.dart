import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirain/features/auth/presentation/otp_verify_screen.dart';
import 'package:kirain/features/auth/presentation/sign_in_screen.dart';
import 'package:kirain/features/catat/catat_screen.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/categories/data/category_repository.dart';

void main() {
  testWidgets('sign-in screen shows an email field and submit button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Kirim Kode'), findsOneWidget);
  });

  testWidgets('otp verify screen shows the target email and a code field', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OtpVerifyScreen(email: 'reno@example.com')),
      ),
    );

    expect(find.textContaining('reno@example.com'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets(
    'catat form shows the wajib/keinginan toggle only for expense categories',
    (tester) async {
      const categories = [
        Category(
          id: 'c1',
          name: 'Makan & Minum',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.wajib,
        ),
        Category(id: 'c2', name: 'Gaji', kind: CategoryKind.income),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => categories),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jumlah (Rp)'), findsOneWidget);
      expect(find.text('Oke, Catat'), findsOneWidget);
      expect(find.text('Wajib'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<Category>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makan & Minum').last);
      await tester.pumpAndSettle();

      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Keinginan'), findsOneWidget);
    },
  );
}
