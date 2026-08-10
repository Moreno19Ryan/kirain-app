import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/categories/data/category_icons.dart';

void main() {
  group('categoryIcon', () {
    test('maps every known default category to its own specific icon', () {
      const names = [
        'Makan & Minum',
        'Transportasi',
        'Tempat Tinggal',
        'Tagihan',
        'Infak/Zakat',
        'Kesehatan',
        'Jajan & Nongkrong',
        'Hiburan',
        'Belanja',
        'Hobi',
        'Gaji',
        'Freelance/Sampingan',
        'THR/Bonus',
        'Lainnya',
      ];

      final icons = names.map((name) {
        return categoryIcon(
          Category(id: name, name: name, kind: CategoryKind.expense, expenseType: ExpenseType.wajib),
        );
      }).toSet();

      // Every default category gets a distinct icon — none of them silently
      // fell through to a shared generic fallback.
      expect(icons.length, names.length);
      expect(icons, isNot(contains(Icons.category_outlined)));
    });

    test('falls back to a generic expense icon for an unrecognized expense category', () {
      const custom = Category(
        id: 'c1',
        name: 'Custom Wajib Category',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      );
      expect(categoryIcon(custom), Icons.category_outlined);
    });

    test('falls back to a generic income icon for an unrecognized income category', () {
      const custom = Category(id: 'c2', name: 'Custom Income', kind: CategoryKind.income);
      expect(categoryIcon(custom), Icons.payments_outlined);
    });
  });

  group('categoryIconColor', () {
    const mintStrong = Color(0xFF12946E);
    const coralStrong = Color(0xFFE2613A);
    const neutral = Color(0xFF8FA39A);

    test('wajib gets mintStrong, keinginan gets coralStrong, income gets neutral', () {
      const wajib = Category(
        id: 'c1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      );
      const keinginan = Category(
        id: 'c2',
        name: 'Hiburan',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.keinginan,
      );
      const income = Category(id: 'c3', name: 'Gaji', kind: CategoryKind.income);

      expect(
        categoryIconColor(
          category: wajib,
          mintStrong: mintStrong,
          coralStrong: coralStrong,
          neutral: neutral,
          brightness: Brightness.light,
        ),
        mintStrong,
      );
      expect(
        categoryIconColor(
          category: keinginan,
          mintStrong: mintStrong,
          coralStrong: coralStrong,
          neutral: neutral,
          brightness: Brightness.light,
        ),
        coralStrong,
      );
      expect(
        categoryIconColor(
          category: income,
          mintStrong: mintStrong,
          coralStrong: coralStrong,
          neutral: neutral,
          brightness: Brightness.light,
        ),
        neutral,
      );
    });

    test('a custom preset color overrides the expense-type default, mode-aware', () {
      const custom = Category(
        id: 'c4',
        name: 'Custom',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
        color: '#7EB8E8', // Langit preset from category_style_options.dart
      );

      expect(
        categoryIconColor(
          category: custom,
          mintStrong: mintStrong,
          coralStrong: coralStrong,
          neutral: neutral,
          brightness: Brightness.light,
        ),
        const Color(0xFF1D5C96),
      );
      expect(
        categoryIconColor(
          category: custom,
          mintStrong: mintStrong,
          coralStrong: coralStrong,
          neutral: neutral,
          brightness: Brightness.dark,
        ),
        const Color(0xFF7EB8E8),
      );
    });
  });

  group('categoryIcon with a custom icon key', () {
    test('a curated icon key overrides the name/kind-based default', () {
      const custom = Category(
        id: 'c5',
        name: 'Custom Wajib Category',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
        icon: 'pets',
      );
      expect(categoryIcon(custom), Icons.pets_outlined);
    });
  });
}
