import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/data/dashboard_summary.dart';
import '../data/gajian_reminder_repository.dart';

/// Shown at most once per budget cycle, per CLAUDE.md's "Reminder
/// kontekstual gajian — notif pas masuk siklus budget baru, ajak alokasi
/// ke Target dulu". In-app, not a system notification — same call as the
/// budget-alert threshold: no local-notification infra exists yet, and
/// this is the same "check on app open" shape as the recurring due-prompt.
Future<void> checkAndPromptGajianReminder(BuildContext context, WidgetRef ref) async {
  final cycle = await ref.read(currentCycleProvider.future);
  final repository = ref.read(gajianReminderRepositoryProvider);

  if (!await repository.shouldShow(cycle.start) || !context.mounted) return;

  await repository.markShown(cycle.start);
  if (!context.mounted) return;

  final goToGoals = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Gajian nih?'),
      content: const Text(
        'Gajian nih? Yuk alokasiin ke Target Nabung dulu sebelum kepake '
        'buat yang lain 💰',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Nanti Aja'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ke Target Nabung'),
        ),
      ],
    ),
  );

  if (goToGoals == true && context.mounted) context.push('/target-nabung');
}
