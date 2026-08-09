import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/utils/format.dart';

void main() {
  group('formatRupiah', () {
    test('adds thousands separators', () {
      expect(formatRupiah(1500000), '1.500.000');
      expect(formatRupiah(999), '999');
      expect(formatRupiah(0), '0');
    });
  });

  group('formatRupiahShort', () {
    test('abbreviates millions with a comma decimal, dropping trailing ,0', () {
      expect(formatRupiahShort(1500000), '1,5jt');
      expect(formatRupiahShort(3000000), '3jt');
      expect(formatRupiahShort(12340000), '12,3jt');
    });

    test('abbreviates thousands as rb, rounded to the nearest thousand', () {
      expect(formatRupiahShort(850000), '850rb');
      expect(formatRupiahShort(45000), '45rb');
      expect(formatRupiahShort(999000), '999rb');
    });

    test('leaves sub-1000 amounts as-is', () {
      expect(formatRupiahShort(500), '500');
      expect(formatRupiahShort(0), '0');
    });
  });

  group('formatDate', () {
    test('formats as "d MMM yyyy" in Indonesian', () {
      expect(formatDate(DateTime(2026, 8, 5)), '5 Agu 2026');
      expect(formatDate(DateTime(2026, 1, 1)), '1 Jan 2026');
    });
  });
}
