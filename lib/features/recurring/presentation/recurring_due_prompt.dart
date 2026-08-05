import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../home/data/dashboard_summary.dart';
import '../data/recurring_transaction_repository.dart';

enum _DueAction { confirm, skip }

/// Checks for due recurring transactions and prompts for each one in turn.
/// Never auto-logs — every occurrence needs an explicit "Catat Sekarang" tap,
/// per this session's product decision (recurring is still a "decision
/// layer" moment, not a silent background job).
Future<void> checkAndPromptDueRecurring(BuildContext context, WidgetRef ref) async {
  final due = await ref.read(dueRecurringTransactionsProvider.future);
  if (due.isEmpty || !context.mounted) return;

  var confirmedAny = false;

  for (final item in due) {
    if (!context.mounted) break;

    final action = await showDialog<_DueAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transaksi Berulang Jatuh Tempo'),
        content: Text(
          '${item.categoryName} · Rp ${formatRupiah(item.amount)}\n'
          'Jatuh tempo: ${formatDate(item.nextDueDate)}'
          '${item.note != null && item.note!.isNotEmpty ? '\n${item.note}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _DueAction.skip),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _DueAction.confirm),
            child: const Text('Catat Sekarang'),
          ),
        ],
      ),
    );

    if (action == _DueAction.confirm) {
      await ref.read(recurringTransactionRepositoryProvider).confirmOccurrence(item);
      confirmedAny = true;
    }
  }

  if (confirmedAny && context.mounted) {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(dueRecurringTransactionsProvider);
  }
}
