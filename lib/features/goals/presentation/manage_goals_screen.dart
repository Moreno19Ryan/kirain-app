import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/format.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../data/savings_goal.dart';
import '../data/savings_goal_repository.dart';

class ManageGoalsScreen extends ConsumerWidget {
  const ManageGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Target Nabung')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) => goals.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada target nabung. Yuk bikin yang pertama, misal Dana Darurat 👀',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: goals.length,
                onReorderItem: (oldIndex, newIndex) => _onReorder(ref, goals, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return _GoalCard(key: ValueKey(goal.id), goal: goal);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetryView(
          message: 'Gagal muat target. Coba lagi ya.',
          onRetry: () => ref.invalidate(savingsGoalsProvider),
        ),
      ),
    );
  }
}

Future<void> _onReorder(
  WidgetRef ref,
  List<SavingsGoal> goals,
  int oldIndex,
  int newIndex,
) async {
  final reordered = [...goals];
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moved);

  await ref.read(savingsGoalRepositoryProvider).reorder(reordered.map((g) => g.id).toList());
  ref.invalidate(savingsGoalsProvider);
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required Key key, required this.goal}) : super(key: key);

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(goal.name)),
            if (goal.isEmergencyFund)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('Dana Darurat'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: goal.progress, minHeight: 8),
              ),
              const SizedBox(height: 4),
              Text('Rp ${formatRupiah(goal.currentAmount)} dari Rp ${formatRupiah(goal.targetAmount)}'),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'add':
                _showAdjustDialog(context, ref, goal, isAdd: true);
              case 'withdraw':
                _showAdjustDialog(context, ref, goal, isAdd: false);
              case 'edit':
                _showGoalForm(context, ref, existing: goal);
              case 'delete':
                _confirmDeleteGoal(context, ref, goal);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'add', child: Text('Tambah Saldo')),
            PopupMenuItem(value: 'withdraw', child: Text('Kurangi Saldo')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAdjustDialog(
  BuildContext context,
  WidgetRef ref,
  SavingsGoal goal, {
  required bool isAdd,
}) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  final amount = await showDialog<num>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isAdd ? 'Tambah Saldo ${goal.name}' : 'Kurangi Saldo ${goal.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
            autofocus: true,
          ),
          if (isAdd) ...[
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, num.tryParse(amountController.text.trim())),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );

  if (amount == null || amount <= 0) return;

  final repository = ref.read(savingsGoalRepositoryProvider);
  if (isAdd) {
    final note = noteController.text.trim();
    await repository.contribute(goalId: goal.id, amount: amount, note: note.isEmpty ? null : note);
  } else {
    await repository.withdraw(goal.id, amount);
  }
  ref.invalidate(savingsGoalsProvider);
}

Future<void> _confirmDeleteGoal(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yakin nih?'),
      content: Text('Target "${goal.name}" bakal dihapus permanen.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(savingsGoalRepositoryProvider).deleteGoal(goal.id);
    ref.invalidate(savingsGoalsProvider);
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    final message = e.code == '23503'
        ? 'Target ini masih punya riwayat kontribusi, jadi belum bisa dihapus.'
        : 'Yah, gagal hapus target. Coba lagi ya.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _showGoalForm(BuildContext context, WidgetRef ref, {SavingsGoal? existing}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final targetController = TextEditingController(
    text: existing == null ? '' : existing.targetAmount.toStringAsFixed(0),
  );
  var isEmergencyFund = existing?.isEmergencyFund ?? false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Target Baru' : 'Edit Target'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama target'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah target (Rp)'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isEmergencyFund,
                  title: const Text('Ini Dana Darurat'),
                  onChanged: (value) => setDialogState(() => isEmergencyFund = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved != true) return;

  final name = nameController.text.trim();
  final target = num.tryParse(targetController.text.trim());
  if (name.isEmpty || target == null || target <= 0) return;

  final repository = ref.read(savingsGoalRepositoryProvider);

  if (existing == null) {
    await repository.createGoal(name: name, targetAmount: target, isEmergencyFund: isEmergencyFund);
  } else {
    await repository.updateGoal(
      goalId: existing.id,
      name: name,
      targetAmount: target,
      isEmergencyFund: isEmergencyFund,
      targetDate: existing.targetDate,
    );
  }

  ref.invalidate(savingsGoalsProvider);
}
