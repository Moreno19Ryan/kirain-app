import 'package:flutter/material.dart';

import 'category.dart';

/// Icon per default category name, matching the mapping used in the
/// `kirain-catat-mockup.jsx` / `kirain-categories-mockup.jsx` reference —
/// reinterpreted onto Material's outlined icon set (see CLAUDE.md 6.5:
/// "icon adalah identifier utama, warna cuma pemanis").
///
/// Custom categories a user adds themselves won't have an exact name match
/// here, so they fall back to a generic icon based on [Category.kind] rather
/// than crashing or guessing.
const _iconsByName = <String, IconData>{
  // Wajib
  'Makan & Minum': Icons.restaurant_outlined,
  'Transportasi': Icons.directions_bus_outlined,
  'Tempat Tinggal': Icons.home_outlined,
  'Tagihan': Icons.receipt_long_outlined,
  'Infak/Zakat': Icons.volunteer_activism_outlined,
  'Kesehatan': Icons.monitor_heart_outlined,
  // Keinginan
  'Jajan & Nongkrong': Icons.local_cafe_outlined,
  'Hiburan': Icons.theaters_outlined,
  'Belanja': Icons.shopping_bag_outlined,
  'Hobi': Icons.sports_esports_outlined,
  // Pemasukan
  'Gaji': Icons.account_balance_wallet_outlined,
  'Freelance/Sampingan': Icons.work_outline,
  'THR/Bonus': Icons.card_giftcard_outlined,
  'Lainnya': Icons.more_horiz,
};

IconData categoryIcon(Category category) {
  return _iconsByName[category.name] ??
      (category.kind == CategoryKind.income
          ? Icons.payments_outlined
          : Icons.category_outlined);
}

/// Wajib -> mint, Keinginan -> coral, Pemasukan -> a neutral tone, per
/// CLAUDE.md 6.5's "Kategori Wajib default pakai warna mint, Keinginan
/// default pakai warna coral". Callers pass in the current theme's tokens so
/// this stays mode-aware without importing Theme directly here.
///
/// Takes the **-strong** variants deliberately, not the raw fill tokens —
/// this paints an icon glyph directly (not inside a solid fill), which is
/// exactly the "teks atau icon langsung" case CLAUDE.md's fill-vs-strong
/// principle calls out. Passing the raw fill color here was the bug behind
/// "icon kategori Wajib nyaris gak keliatan" on a light background — mint
/// fill (`#7FE0C4`) on a pale mint-tinted chip is barely any contrast at all.
Color categoryIconColor({
  required Category category,
  required Color mintStrong,
  required Color coralStrong,
  required Color neutral,
}) {
  return switch (category.expenseType) {
    ExpenseType.wajib => mintStrong,
    ExpenseType.keinginan => coralStrong,
    null => neutral,
  };
}
