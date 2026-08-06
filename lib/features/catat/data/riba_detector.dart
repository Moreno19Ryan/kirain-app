const _ribaKeywords = [
  'riba',
  'bunga',
  'cicilan',
  'cicil',
  'kredit',
  'paylater',
  'pay later',
  'kredivo',
  'akulaku',
  'spaylater',
  'kartu kredit',
  'pinjol',
  'pinjaman online',
  'kta',
];

/// Soft, keyword-based heuristic — not an aggressive detection system, per
/// CLAUDE.md. False positives are fine here: this only ever triggers a
/// dismissible educational notice, never blocks saving.
bool looksLikeRiba(String note) {
  final lower = note.toLowerCase();
  return _ribaKeywords.any(lower.contains);
}
