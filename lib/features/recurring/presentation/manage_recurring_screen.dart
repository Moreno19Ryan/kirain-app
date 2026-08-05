import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../categories/data/category.dart';
import '../../categories/data/category_repository.dart';
import '../data/recurring_transaction.dart';
import '../data/recurring_transaction_repository.dart';

class ManageRecurringScreen extends ConsumerWidget {
  const ManageRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berulang')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada transaksi berulang. Cocok buat cicilan atau langganan bulanan 👀',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) => _RuleCard(item: items[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Gagal muat transaksi berulang. Coba lagi ya.')),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.item});

  final RecurringTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequencyLabel = item.frequency == RecurrenceFrequency.weekly ? 'Tiap minggu' : 'Tiap bulan';
    final typeLabel = item.expenseType == ExpenseType.wajib ? 'Wajib' : 'Keinginan';

    return Card(
      child: Opacity(
        opacity: item.isActive ? 1 : 0.5,
        child: ListTile(
          title: Text(item.categoryName),
          subtitle: Text(
            'Rp ${formatRupiah(item.amount)} · $frequencyLabel · $typeLabel\n'
            'Jatuh tempo berikutnya: ${formatDate(item.nextDueDate)}',
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle':
                  ref
                      .read(recurringTransactionRepositoryProvider)
                      .setActive(item.id, !item.isActive);
                  ref.invalidate(recurringTransactionsProvider);
                case 'edit':
                  _showRuleForm(context, ref, existing: item);
                case 'delete':
                  _confirmDelete(context, ref, item);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(item.isActive ? 'Jeda' : 'Aktifkan lagi'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref, RecurringTransaction item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yakin nih?'),
      content: Text('Transaksi berulang "${item.categoryName}" bakal dihapus permanen.'),
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

  await ref.read(recurringTransactionRepositoryProvider).delete(item.id);
  ref.invalidate(recurringTransactionsProvider);
}

Future<void> _showRuleForm(
  BuildContext context,
  WidgetRef ref, {
  RecurringTransaction? existing,
}) async {
  final categories = await ref.read(categoriesProvider.future);
  final expenseCategories = categories.where((c) => c.kind == CategoryKind.expense).toList();
  if (expenseCategories.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bikin kategori pengeluaran dulu ya.')));
    return;
  }
  if (!context.mounted) return;

  final amountController = TextEditingController(
    text: existing == null ? '' : existing.amount.toStringAsFixed(0),
  );
  final noteController = TextEditingController(text: existing?.note ?? '');
  var category = existing == null
      ? expenseCategories.first
      : expenseCategories.firstWhere(
          (c) => c.id == existing.categoryId,
          orElse: () => expenseCategories.first,
        );
  var expenseType = existing?.expenseType ?? ExpenseType.wajib;
  var frequency = existing?.frequency ?? RecurrenceFrequency.monthly;
  var nextDueDate = existing?.nextDueDate ?? DateTime.now();

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Transaksi Berulang Baru' : 'Edit Transaksi Berulang'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Category>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: expenseCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: existing != null
                        ? null
                        : (value) => setDialogState(() => category = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ExpenseType>(
                    segments: const [
                      ButtonSegment(value: ExpenseType.wajib, label: Text('Wajib')),
                      ButtonSegment(value: ExpenseType.keinginan, label: Text('Keinginan')),
                    ],
                    selected: {expenseType},
                    onSelectionChanged: (s) => setDialogState(() => expenseType = s.first),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<RecurrenceFrequency>(
                    segments: const [
                      ButtonSegment(value: RecurrenceFrequency.weekly, label: Text('Mingguan')),
                      ButtonSegment(value: RecurrenceFrequency.monthly, label: Text('Bulanan')),
                    ],
                    selected: {frequency},
                    onSelectionChanged: (s) => setDialogState(() => frequency = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (existing == null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Jatuh tempo pertama'),
                      subtitle: Text(formatDate(nextDueDate)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: nextDueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setDialogState(() => nextDueDate = picked);
                      },
                    ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                  ),
                ],
              ),
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

  final amount = num.tryParse(amountController.text.trim());
  if (amount == null || amount <= 0) return;

  final note = noteController.text.trim();
  final repository = ref.read(recurringTransactionRepositoryProvider);

  if (existing == null) {
    await repository.create(
      categoryId: category.id,
      amount: amount,
      expenseType: expenseType,
      frequency: frequency,
      nextDueDate: nextDueDate,
      note: note.isEmpty ? null : note,
    );
  } else {
    await repository.update(
      id: existing.id,
      amount: amount,
      expenseType: expenseType,
      frequency: frequency,
      note: note.isEmpty ? null : note,
    );
  }

  ref.invalidate(recurringTransactionsProvider);
}
