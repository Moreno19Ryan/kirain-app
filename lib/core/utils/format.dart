const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Dashboard/ringkasan format ("Rp 1.500.000") per CLAUDE.md's nominal
/// formatting rule — full digits, thousands separators, no abbreviation.
String formatRupiah(num amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
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
