import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/category.dart';
import '../data/category_repository.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) => _CategoryList(categories: categories),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Gagal muat kategori. Coba lagi ya.')),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final wajib = categories
        .where((c) => c.kind == CategoryKind.expense && c.expenseType == ExpenseType.wajib)
        .toList();
    final keinginan = categories
        .where((c) => c.kind == CategoryKind.expense && c.expenseType == ExpenseType.keinginan)
        .toList();
    final income = categories.where((c) => c.kind == CategoryKind.income).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _CategorySection(title: 'Wajib', categories: wajib),
        _CategorySection(title: 'Keinginan', categories: keinginan),
        _CategorySection(title: 'Pemasukan', categories: income),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.categories});

  final String title;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...categories.map((category) => _CategoryListTile(category: category)),
      ],
    );
  }
}

class _CategoryListTile extends ConsumerWidget {
  const _CategoryListTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = category.budgetLimit;

    return ListTile(
      title: Text(category.name),
      subtitle: category.kind == CategoryKind.expense
          ? Text(limit == null || limit == 0 ? 'Belum ada limit' : 'Limit Rp ${limit.toStringAsFixed(0)}')
          : null,
      onTap: () => _showCategoryForm(context, ref, existing: category),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(context, ref, category),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category category) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yakin nih?'),
      content: Text('Kategori "${category.name}" bakal dihapus permanen.'),
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
    await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    ref.invalidate(categoriesProvider);
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    final message = e.code == '23503'
        ? 'Kategori ini masih dipakai di transaksi, jadi belum bisa dihapus.'
        : 'Yah, gagal hapus kategori. Coba lagi ya.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _showCategoryForm(BuildContext context, WidgetRef ref, {Category? existing}) async {
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

  if (saved != true) return;

  final name = nameController.text.trim();
  if (name.isEmpty) return;

  final limit = num.tryParse(limitController.text.trim());
  final repository = ref.read(categoryRepositoryProvider);

  if (existing == null) {
    await repository.createCategory(
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
}
