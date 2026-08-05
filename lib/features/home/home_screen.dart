import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/skeleton_box.dart';
import '../categories/data/category.dart';
import '../categories/data/category_repository.dart';
import '../recurring/presentation/recurring_due_prompt.dart';
import 'data/dashboard_summary.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndPromptDueRecurring(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('KIRAIN')),
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BudgetSection(title: 'Progress Cukup', summary: summary.wajib),
                const SizedBox(height: 24),
                _BudgetSection(title: 'Keinginan', summary: summary.keinginan),
              ],
            ),
          ),
          loading: () => const _HomeSkeleton(),
          error: (_, _) => const Center(child: Text('Gagal muat data. Coba lagi ya.')),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [_SectionSkeleton(), SizedBox(height: 24), _SectionSkeleton()],
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 120, height: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 10),
            SizedBox(height: 8),
            SkeletonBox(width: 160, height: 14),
          ],
        ),
      ),
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.title, required this.summary});

  final String title;
  final BudgetGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasLimit = summary.totalLimit > 0;
    final isOver = hasLimit && summary.ratio >= 1.0;
    final zoneLabel = hasLimit ? (isOver ? 'Zona Kirain' : 'Zona Aman') : null;
    final zoneColor = isOver
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (zoneLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      zoneLabel,
                      style: TextStyle(color: zoneColor, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasLimit)
              const Text('Belum ada limit yang diset buat kategori ini.')
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: summary.ratio.clamp(0, 1).toDouble(),
                  minHeight: 10,
                  color: zoneColor,
                  backgroundColor: zoneColor.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 8),
              Text('Rp ${formatRupiah(summary.totalSpent)} dari Rp ${formatRupiah(summary.totalLimit)}'),
              if (isOver)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Bulan ini kebablasan nih, gapapa. Yuk kita rapiin lagi bulan depan 💪',
                    style: TextStyle(color: zoneColor),
                  ),
                ),
            ],
            if (summary.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Rincian per kategori'),
                children: summary.items.map((item) => _CategoryTile(item: item)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.item});

  final CategorySpend item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = item.category.budgetLimit;
    final over = limit != null && limit > 0 && item.spent > limit;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.category.name),
      subtitle: Text(
        limit == null || limit == 0
            ? 'Rp ${formatRupiah(item.spent)} · belum ada limit'
            : 'Rp ${formatRupiah(item.spent)} dari Rp ${formatRupiah(limit)}',
        style: over ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => _showEditLimitDialog(context, ref, item.category),
    );
  }
}

Future<void> _showEditLimitDialog(BuildContext context, WidgetRef ref, Category category) async {
  final controller = TextEditingController(
    text: category.budgetLimit == null ? '' : category.budgetLimit!.toStringAsFixed(0),
  );

  final result = await showDialog<num>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Limit ${category.name}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Limit per siklus (Rp)'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final value = num.tryParse(controller.text.trim());
            Navigator.pop(dialogContext, value ?? 0);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );

  if (result == null) return;

  await ref.read(categoryRepositoryProvider).updateBudgetLimit(category.id, result);
  ref.invalidate(categoriesProvider);
  ref.invalidate(dashboardSummaryProvider);
}
