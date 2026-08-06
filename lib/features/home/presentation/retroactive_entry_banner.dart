import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Local dismiss state only, same reasoning as TipCard — no persisted
/// flag needed since [hasAnyTransactionsProvider] already stops showing
/// this the moment the account has any transaction at all.
class RetroactiveEntryBanner extends StatefulWidget {
  const RetroactiveEntryBanner({super.key});

  @override
  State<RetroactiveEntryBanner> createState() => _RetroactiveEntryBannerState();
}

class _RetroactiveEntryBannerState extends State<RetroactiveEntryBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_edu_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Baru mulai nih? Yuk isi transaksi dari awal siklus ini '
                    'biar Rekap kamu gak kepotong.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: scheme.onPrimaryContainer),
                  onPressed: () => setState(() => _dismissed = true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => context.go('/catat'),
                child: const Text('Isi Transaksi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
