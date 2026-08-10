import 'package:flutter/material.dart';

/// One entry in the curated icon picker (CLAUDE.md "Kustomisasi Icon & Warna
/// Kategori"): a fixed, hand-picked set of ~20-30 icons relevant to
/// financial categories — deliberately NOT the full Material/Lucide icon
/// library, so the picker stays quick to scan and the visual style (all
/// outlined, matching [categoryIcon]'s existing default mapping) stays
/// consistent.
class CategoryIconOption {
  const CategoryIconOption({required this.key, required this.icon, required this.label});

  /// Stored in `categories.icon` — stable even if [icon]/[label] change.
  final String key;
  final IconData icon;
  final String label;
}

const kCategoryIconOptions = <CategoryIconOption>[
  CategoryIconOption(key: 'restaurant', icon: Icons.restaurant_outlined, label: 'Makan'),
  CategoryIconOption(key: 'cafe', icon: Icons.local_cafe_outlined, label: 'Kopi'),
  CategoryIconOption(key: 'fastfood', icon: Icons.lunch_dining_outlined, label: 'Jajan'),
  CategoryIconOption(key: 'groceries', icon: Icons.local_grocery_store_outlined, label: 'Belanja Harian'),
  CategoryIconOption(key: 'bus', icon: Icons.directions_bus_outlined, label: 'Transportasi Umum'),
  CategoryIconOption(key: 'car', icon: Icons.directions_car_outlined, label: 'Mobil'),
  CategoryIconOption(key: 'motorcycle', icon: Icons.two_wheeler_outlined, label: 'Motor'),
  CategoryIconOption(key: 'fuel', icon: Icons.local_gas_station_outlined, label: 'Bensin'),
  CategoryIconOption(key: 'home', icon: Icons.home_outlined, label: 'Rumah'),
  CategoryIconOption(key: 'bills', icon: Icons.receipt_long_outlined, label: 'Tagihan'),
  CategoryIconOption(key: 'electricity', icon: Icons.bolt_outlined, label: 'Listrik'),
  CategoryIconOption(key: 'internet', icon: Icons.wifi_outlined, label: 'Internet'),
  CategoryIconOption(key: 'phone', icon: Icons.smartphone_outlined, label: 'Pulsa'),
  CategoryIconOption(key: 'health', icon: Icons.monitor_heart_outlined, label: 'Kesehatan'),
  CategoryIconOption(key: 'medicine', icon: Icons.medication_outlined, label: 'Obat'),
  CategoryIconOption(key: 'fitness', icon: Icons.fitness_center_outlined, label: 'Olahraga'),
  CategoryIconOption(key: 'entertainment', icon: Icons.theaters_outlined, label: 'Hiburan'),
  CategoryIconOption(key: 'games', icon: Icons.sports_esports_outlined, label: 'Game'),
  CategoryIconOption(key: 'music', icon: Icons.music_note_outlined, label: 'Musik'),
  CategoryIconOption(key: 'books', icon: Icons.menu_book_outlined, label: 'Buku'),
  CategoryIconOption(key: 'shopping', icon: Icons.shopping_bag_outlined, label: 'Belanja'),
  CategoryIconOption(key: 'fashion', icon: Icons.checkroom_outlined, label: 'Fashion'),
  CategoryIconOption(key: 'gift', icon: Icons.card_giftcard_outlined, label: 'Hadiah'),
  CategoryIconOption(key: 'giving', icon: Icons.volunteer_activism_outlined, label: 'Infak/Zakat'),
  CategoryIconOption(key: 'family', icon: Icons.family_restroom_outlined, label: 'Keluarga'),
  CategoryIconOption(key: 'pets', icon: Icons.pets_outlined, label: 'Hewan Peliharaan'),
  CategoryIconOption(key: 'education', icon: Icons.school_outlined, label: 'Pendidikan'),
  CategoryIconOption(key: 'travel', icon: Icons.flight_outlined, label: 'Liburan'),
  CategoryIconOption(key: 'work', icon: Icons.work_outline, label: 'Kerja'),
  CategoryIconOption(key: 'wallet', icon: Icons.account_balance_wallet_outlined, label: 'Dompet'),
];

final kCategoryIconOptionsByKey = {for (final option in kCategoryIconOptions) option.key: option};

/// One entry in the curated color picker: a preset swatch, not a free color
/// picker, so custom categories stay "terasa KIRAIN" instead of turning into
/// an unrelated rainbow. Mirrors the app-wide "fill vs strong" split from
/// [KirainColors] (see app_theme.dart) so a picked color reads with the same
/// contrast discipline in both modes — [fill] is safe as a chip
/// background/border in both modes; [strongLight]/[strongDark] are for when
/// the color is painted directly as an icon/text glyph.
class CategoryColorOption {
  const CategoryColorOption({
    required this.key,
    required this.label,
    required this.fill,
    required this.strongLight,
    required this.strongDark,
  });

  /// Stored in `categories.color` as a `#RRGGBB` hex string — kept in sync
  /// with [fill] by hand at definition time below.
  final String key;
  final String label;
  final Color fill;
  final Color strongLight;
  final Color strongDark;

  Color strongFor(Brightness brightness) => brightness == Brightness.dark ? strongDark : strongLight;
}

const kCategoryColorOptions = <CategoryColorOption>[
  CategoryColorOption(
    key: '#7FE0C4',
    label: 'Mint',
    fill: Color(0xFF7FE0C4),
    strongLight: Color(0xFF12946E),
    strongDark: Color(0xFF7FE0C4),
  ),
  CategoryColorOption(
    key: '#FF8B5E',
    label: 'Coral',
    fill: Color(0xFFFF8B5E),
    strongLight: Color(0xFFE2613A),
    strongDark: Color(0xFFFF8B5E),
  ),
  CategoryColorOption(
    key: '#F3C368',
    label: 'Amber',
    fill: Color(0xFFF3C368),
    strongLight: Color(0xFF9A6B12),
    strongDark: Color(0xFFF3C368),
  ),
  CategoryColorOption(
    key: '#7EB8E8',
    label: 'Langit',
    fill: Color(0xFF7EB8E8),
    strongLight: Color(0xFF1D5C96),
    strongDark: Color(0xFF7EB8E8),
  ),
  CategoryColorOption(
    key: '#C49BEE',
    label: 'Ungu',
    fill: Color(0xFFC49BEE),
    strongLight: Color(0xFF7239B3),
    strongDark: Color(0xFFC49BEE),
  ),
  CategoryColorOption(
    key: '#F592B2',
    label: 'Merah Muda',
    fill: Color(0xFFF592B2),
    strongLight: Color(0xFFB03A5E),
    strongDark: Color(0xFFF592B2),
  ),
  CategoryColorOption(
    key: '#A9B7C4',
    label: 'Netral',
    fill: Color(0xFFA9B7C4),
    strongLight: Color(0xFF48586A),
    strongDark: Color(0xFFA9B7C4),
  ),
];

final kCategoryColorOptionsByKey = {for (final option in kCategoryColorOptions) option.key: option};
