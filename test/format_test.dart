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

  group('formatDate', () {
    test('formats as "d MMM yyyy" in Indonesian', () {
      expect(formatDate(DateTime(2026, 8, 5)), '5 Agu 2026');
      expect(formatDate(DateTime(2026, 1, 1)), '1 Jan 2026');
    });
  });
}
