import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/kirain_colors.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../data/category.dart';
import '../data/category_icons.dart';
import '../data/category_repository.dart';
import 'category_form_dialog.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryFormDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) => _CategoryList(categories: categories),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetryView(
          message: 'Gagal muat kategori. Coba lagi ya.',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
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
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final iconColor = categoryIconColor(
      category: category,
      mint: kirainColors?.mint ?? theme.colorScheme.primary,
      coral: kirainColors?.coral ?? theme.colorScheme.secondary,
      neutral: theme.colorScheme.onSurfaceVariant,
    );

    return ListTile(
      leading: Icon(categoryIcon(category), color: iconColor),
      title: Text(category.name),
      subtitle: category.kind == CategoryKind.expense
          ? Text(limit == null || limit == 0 ? 'Belum ada limit' : 'Limit Rp ${limit.toStringAsFixed(0)}')
          : null,
      onTap: () => showCategoryFormDialog(context, ref, existing: category),
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
