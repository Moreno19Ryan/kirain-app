import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category.dart';
import '../data/category_repository.dart';

/// Shared "Kategori Baru"/"Edit Kategori" dialog — used by
/// ManageCategoriesScreen and Catat's inline "+ Tambah kategori" shortcut
/// (CLAUDE.md 6.5: user harus bisa menambah kategori sendiri dari kedua
/// tempat itu), so both stay in sync with a single implementation.
///
/// Returns the newly created [Category] so a caller like Catat can select
/// it immediately; returns null if the dialog was cancelled, or when
/// editing an existing category (the caller doesn't need the updated row
/// back, just needs to know a save happened via [categoriesProvider] having
/// been invalidated, which this function always does on a successful save).
Future<Category?> showCategoryFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final limitController = TextEditingController(
    text: existing?.budgetLimit == null ? '' : existing!.budgetLimit!.toStringAsFixed(0),
  );
  var kind = existing?.kind ?? CategoryKind.expense;
  var expenseType = existing?.expenseType ?? ExpenseType.keinginan;
  var alertThresholdPct = existing?.alertThresholdPct ?? 80;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Kategori Baru' : 'Edit Kategori'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama kategori'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (existing == null) ...[
                    SegmentedButton<CategoryKind>(
                      segments: const [
                        ButtonSegment(value: CategoryKind.expense, label: Text('Pengeluaran')),
                        ButtonSegment(value: CategoryKind.income, label: Text('Pemasukan')),
                      ],
                      selected: {kind},
                      onSelectionChanged: (selection) =>
                          setDialogState(() => kind = selection.first),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (kind == CategoryKind.expense) ...[
                    SegmentedButton<ExpenseType>(
                      segments: const [
                        ButtonSegment(value: ExpenseType.wajib, label: Text('Wajib')),
                        ButtonSegment(value: ExpenseType.keinginan, label: Text('Keinginan')),
                      ],
                      selected: {expenseType},
                      onSelectionChanged: (selection) =>
                          setDialogState(() => expenseType = selection.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Limit per siklus (Rp, opsional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Alert Zona Waspada di $alertThresholdPct% dari limit'),
                    Slider(
                      value: alertThresholdPct.toDouble(),
                      min: 50,
                      max: 100,
                      divisions: 10,
                      label: '$alertThresholdPct%',
                      onChanged: (value) =>
                          setDialogState(() => alertThresholdPct = value.round()),
                    ),
                  ],
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

  if (saved != true) return null;

  final name = nameController.text.trim();
  if (name.isEmpty) return null;

  final limit = num.tryParse(limitController.text.trim());
  final repository = ref.read(categoryRepositoryProvider);

  Category? created;
  if (existing == null) {
    created = await repository.createCategory(
      name: name,
      kind: kind,
      expenseType: kind == CategoryKind.expense ? expenseType : null,
      budgetLimit: kind == CategoryKind.expense ? limit : null,
      alertThresholdPct: alertThresholdPct,
    );
  } else {
    await repository.updateCategory(
      categoryId: existing.id,
      name: name,
      expenseType: existing.kind == CategoryKind.expense ? expenseType : null,
      budgetLimit: existing.kind == CategoryKind.expense ? limit : null,
      alertThresholdPct: alertThresholdPct,
    );
  }

  ref.invalidate(categoriesProvider);
  return created;
}
