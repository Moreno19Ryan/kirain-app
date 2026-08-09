const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Riwayat/detail format ("1.500.000") per CLAUDE.md's nominal formatting
/// rule — full digits, thousands separators, no abbreviation.
String formatRupiah(num amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Dashboard/ringkasan format ("1,5jt", "850rb") per CLAUDE.md's nominal
/// formatting rule — abbreviated for top-level summary numbers, never for
/// itemized detail (that stays [formatRupiah]). Expects a non-negative
/// amount, same convention [formatRupiah] callers already use (call `.abs()`
/// and prepend the sign yourself for deficits).
String formatRupiahShort(num amount) {
  if (amount >= 1000000) {
    final millions = (amount / 100000).round() / 10;
    final isWhole = millions == millions.roundToDouble();
    final display = isWhole
        ? millions.toStringAsFixed(0)
        : millions.toStringAsFixed(1).replaceAll('.', ',');
    return '${display}jt';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).round()}rb';
  }
  return amount.toStringAsFixed(0);
}

String formatDate(DateTime date) {
  return '${date.day} ${_monthAbbr[date.month - 1]} ${date.year}';
}

/// yyyy-MM-dd, for Postgrest `date` column filters/values.
String isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
