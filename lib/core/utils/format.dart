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
